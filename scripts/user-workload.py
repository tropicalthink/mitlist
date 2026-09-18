#!/usr/bin/env python3
"""Production capacity test using real mitlist screen-read workloads.

Run this on a mitlist VPS. It creates disposable verified users directly in
PostgreSQL, seeds their household data through the API, signs short-lived
access tokens with the running backend's key, and cleans up in all cases.
"""

from __future__ import annotations

import argparse
import base64
import concurrent.futures
import hashlib
import hmac
import http.client
import json
import math
import os
import random
import socket
import statistics
import subprocess
import threading
import time
import uuid
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date, timedelta
from urllib.parse import quote, urlparse


API_PREFIX = "/api/v1"


def percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    index = max(0, math.ceil(len(ordered) * fraction) - 1)
    return round(ordered[index], 2)


def parse_stages(raw: str) -> list[tuple[float, int]]:
    stages: list[tuple[float, int]] = []
    for item in raw.split(","):
        rate_raw, separator, duration_raw = item.partition(":")
        if not separator:
            raise argparse.ArgumentTypeError("stages must use RATE:DURATION")
        rate = float(rate_raw)
        duration = int(duration_raw)
        if rate <= 0 or duration <= 0:
            raise argparse.ArgumentTypeError("stage rate and duration must be positive")
        stages.append((rate, duration))
    return stages


def run(command: list[str], *, input_text: str | None = None) -> str:
    completed = subprocess.run(
        command,
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise RuntimeError(f"command failed ({command[0]}): {detail}")
    return completed.stdout


def psql(sql: str, *, port: int) -> str:
    return run(
        [
            "runuser",
            "-u",
            "postgres",
            "--",
            "psql",
            "-X",
            "-v",
            "ON_ERROR_STOP=1",
            "-p",
            str(port),
            "-d",
            "mitlist",
            "-At",
            "-F",
            "|",
            "-c",
            sql,
        ]
    )


def backend_environment(container: str) -> dict[str, str]:
    output = run(
        [
            "docker",
            "inspect",
            "--format={{range .Config.Env}}{{println .}}{{end}}",
            container,
        ]
    )
    environment: dict[str, str] = {}
    for line in output.splitlines():
        key, separator, value = line.partition("=")
        if separator:
            environment[key] = value
    return environment


def base64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def access_token(user_id: str, environment: dict[str, str]) -> str:
    secret = environment.get("SECRET_KEY")
    if not secret:
        raise RuntimeError("running backend has no SECRET_KEY")
    now = int(time.time())
    ttl = int(environment.get("ACCESS_TOKEN_EXPIRE_MINUTES", "15")) * 60
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "roles": [],
        "typ": "access",
        "jti": str(uuid.uuid4()),
        "sub": user_id,
        "iss": environment.get("TOKEN_ISSUER", "mitlist"),
        "aud": [environment.get("TOKEN_AUDIENCE", "mitlist-api")],
        "iat": now,
        "nbf": now,
        "exp": now + ttl,
    }
    encoded = ".".join(
        base64url(json.dumps(part, separators=(",", ":")).encode("utf-8"))
        for part in (header, payload)
    )
    signature = hmac.new(secret.encode("utf-8"), encoded.encode("ascii"), hashlib.sha256).digest()
    return f"{encoded}.{base64url(signature)}"


@dataclass
class Account:
    user_id: str
    email: str
    token: str
    client_ip: str
    group_id: str = ""
    list_id: str = ""


@dataclass
class RequestResult:
    route: str
    status: int
    latency_ms: float
    size: int
    error: str = ""


class ApiClient:
    def __init__(self, base_url: str, timeout: float):
        parsed = urlparse(base_url)
        if parsed.scheme != "http" or not parsed.hostname:
            raise ValueError("the on-host runner requires an http:// container URL")
        self.host = parsed.hostname
        self.port = parsed.port or 80
        self.timeout = timeout
        self.local = threading.local()

    def _connection(self) -> http.client.HTTPConnection:
        connection = getattr(self.local, "connection", None)
        if connection is None:
            connection = http.client.HTTPConnection(self.host, self.port, timeout=self.timeout)
            self.local.connection = connection
        return connection

    def close_thread_connection(self) -> None:
        connection = getattr(self.local, "connection", None)
        if connection is not None:
            connection.close()
            self.local.connection = None

    def request(
        self,
        account: Account,
        method: str,
        path: str,
        *,
        body: dict | None = None,
        expected: tuple[int, ...] = (200,),
        client_ip: str | None = None,
        route: str | None = None,
    ) -> tuple[RequestResult, object | None]:
        payload = None if body is None else json.dumps(body, separators=(",", ":")).encode("utf-8")
        headers = {
            "Accept": "application/json",
            "Authorization": f"Bearer {account.token}",
            "Connection": "keep-alive",
            "User-Agent": "mitlist-user-workload/1.0",
            "X-Real-Ip": client_ip or account.client_ip,
        }
        if payload is not None:
            headers["Content-Type"] = "application/json"
        started = time.perf_counter()
        status = 0
        response_body = b""
        error = ""
        try:
            connection = self._connection()
            connection.request(method, path, body=payload, headers=headers)
            response = connection.getresponse()
            status = response.status
            response_body = response.read()
            if response.getheader("Connection", "").lower() == "close":
                self.close_thread_connection()
        except (OSError, http.client.HTTPException, socket.timeout) as exc:
            error = type(exc).__name__
            self.close_thread_connection()
        latency_ms = (time.perf_counter() - started) * 1000
        label = route or path.split("?", 1)[0]
        result = RequestResult(label, status, latency_ms, len(response_body), error)
        decoded: object | None = None
        if response_body:
            try:
                decoded = json.loads(response_body)
            except json.JSONDecodeError:
                decoded = response_body.decode("utf-8", errors="replace")[:500]
        if status not in expected or error:
            detail = decoded if decoded is not None else error or "empty response"
            raise RuntimeError(f"{method} {path} returned {status}: {detail}")
        return result, decoded

    def measured_get(self, account: Account, path: str, client_ip: str, route: str) -> RequestResult:
        started = time.perf_counter()
        status = 0
        size = 0
        error = ""
        try:
            connection = self._connection()
            connection.request(
                "GET",
                path,
                headers={
                    "Accept": "application/json",
                    "Authorization": f"Bearer {account.token}",
                    "Connection": "keep-alive",
                    "User-Agent": "mitlist-user-workload/1.0",
                    "X-Real-Ip": client_ip,
                },
            )
            response = connection.getresponse()
            status = response.status
            body = response.read()
            size = len(body)
            if response.getheader("Connection", "").lower() == "close":
                self.close_thread_connection()
        except (OSError, http.client.HTTPException, socket.timeout) as exc:
            error = type(exc).__name__
            self.close_thread_connection()
        return RequestResult(route, status, (time.perf_counter() - started) * 1000, size, error)


def process_cpu_ticks(pid: int) -> int | None:
    try:
        stat = open(f"/proc/{pid}/stat", encoding="ascii").read()
        fields = stat.rsplit(")", 1)[1].split()
        return int(fields[11]) + int(fields[12])
    except (FileNotFoundError, PermissionError, IndexError, ValueError):
        return None


def process_rss_mib(pid: int) -> float | None:
    try:
        with open(f"/proc/{pid}/status", encoding="ascii") as status:
            for line in status:
                if line.startswith("VmRSS:"):
                    return int(line.split()[1]) / 1024
    except (FileNotFoundError, PermissionError, ValueError):
        pass
    return None


def host_cpu_ticks() -> tuple[int, int] | None:
    try:
        with open("/proc/stat", encoding="ascii") as proc_stat:
            fields = proc_stat.readline().split()[1:]
        values = [int(value) for value in fields]
        idle = values[3] + values[4]
        return sum(values), idle
    except (FileNotFoundError, IndexError, ValueError):
        return None


def postgres_pids(port: int) -> list[int]:
    main_pid: int | None = None
    process_rows: list[tuple[int, int]] = []
    for raw_pid in os.listdir("/proc"):
        if not raw_pid.isdigit():
            continue
        pid = int(raw_pid)
        try:
            stat = open(f"/proc/{pid}/stat", encoding="ascii").read()
            fields = stat.rsplit(")", 1)[1].split()
            parent_pid = int(fields[1])
            cmdline = open(f"/proc/{pid}/cmdline", "rb").read().split(b"\0")
        except (FileNotFoundError, PermissionError, IndexError, ValueError):
            continue
        process_rows.append((pid, parent_pid))
        if (
            cmdline
            and cmdline[0].endswith(b"/postgres")
            and b"-p" in cmdline
            and str(port).encode("ascii") in cmdline
        ):
            main_pid = pid
    if main_pid is None:
        return []
    return [main_pid, *(pid for pid, parent_pid in process_rows if parent_pid == main_pid)]


class ResourceMonitor:
    def __init__(self, container: str, db_port: int):
        self.container = container
        self.db_port = db_port
        self.samples: list[dict[str, float]] = []
        self.stop_event = threading.Event()
        self.thread: threading.Thread | None = None

    def start(self) -> None:
        self.thread = threading.Thread(target=self._run, daemon=True)
        self.thread.start()

    def stop(self) -> dict[str, float | int | None]:
        self.stop_event.set()
        if self.thread:
            self.thread.join(timeout=5)
        def values(name: str) -> list[float]:
            return [sample[name] for sample in self.samples if name in sample]

        cpu = values("backend_cpu")
        memory = values("backend_memory_mib")
        postgres_cpu = values("postgres_cpu")
        generator_cpu = values("generator_cpu")
        host_cpu = values("host_cpu")
        return {
            "samples": len(self.samples),
            "backend_cpu_avg_pct": round(statistics.fmean(cpu), 2) if cpu else None,
            "backend_cpu_max_pct": round(max(cpu), 2) if cpu else None,
            "backend_memory_max_mib": round(max(memory), 2) if memory else None,
            "postgres_cpu_avg_pct": round(statistics.fmean(postgres_cpu), 2) if postgres_cpu else None,
            "postgres_cpu_max_pct": round(max(postgres_cpu), 2) if postgres_cpu else None,
            "generator_cpu_avg_pct": round(statistics.fmean(generator_cpu), 2) if generator_cpu else None,
            "generator_cpu_max_pct": round(max(generator_cpu), 2) if generator_cpu else None,
            "host_cpu_avg_pct": round(statistics.fmean(host_cpu), 2) if host_cpu else None,
            "host_cpu_max_pct": round(max(host_cpu), 2) if host_cpu else None,
        }

    def _run(self) -> None:
        try:
            backend_pid = int(
                run(["docker", "inspect", "--format={{.State.Pid}}", self.container]).strip()
            )
        except (RuntimeError, ValueError):
            backend_pid = 0
        clock_ticks = os.sysconf("SC_CLK_TCK")
        previous_time = time.monotonic()
        previous_backend = process_cpu_ticks(backend_pid)
        previous_postgres = sum(
            ticks
            for pid in postgres_pids(self.db_port)
            if (ticks := process_cpu_ticks(pid)) is not None
        )
        previous_generator = process_cpu_ticks(os.getpid())
        previous_host = host_cpu_ticks()
        while not self.stop_event.is_set():
            self.stop_event.wait(1)
            now = time.monotonic()
            elapsed = now - previous_time
            backend = process_cpu_ticks(backend_pid)
            postgres = sum(
                ticks
                for pid in postgres_pids(self.db_port)
                if (ticks := process_cpu_ticks(pid)) is not None
            )
            generator = process_cpu_ticks(os.getpid())
            host = host_cpu_ticks()
            sample: dict[str, float] = {}
            if previous_backend is not None and backend is not None:
                sample["backend_cpu"] = 100 * (backend - previous_backend) / (clock_ticks * elapsed)
            if previous_postgres is not None:
                sample["postgres_cpu"] = 100 * (postgres - previous_postgres) / (clock_ticks * elapsed)
            if previous_generator is not None and generator is not None:
                sample["generator_cpu"] = 100 * (generator - previous_generator) / (clock_ticks * elapsed)
            if previous_host is not None and host is not None:
                total_delta = host[0] - previous_host[0]
                idle_delta = host[1] - previous_host[1]
                if total_delta > 0:
                    sample["host_cpu"] = 100 * (total_delta - idle_delta) / total_delta
            memory = process_rss_mib(backend_pid)
            if memory is not None:
                sample["backend_memory_mib"] = memory
            if sample:
                self.samples.append(sample)
            previous_time = now
            previous_backend = backend
            previous_postgres = postgres
            previous_generator = generator
            previous_host = host


class StageMetrics:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.requests: list[RequestResult] = []
        self.session_latencies: list[float] = []
        self.pages: Counter[str] = Counter()
        self.dropped_sessions = 0

    def add_session(self, page: str, latency_ms: float, results: list[RequestResult]) -> None:
        with self.lock:
            self.pages[page] += 1
            self.session_latencies.append(latency_ms)
            self.requests.extend(results)


def create_accounts(count: int, run_id: str, environment: dict[str, str], db_port: int) -> list[Account]:
    rows = psql(
        f"""
        INSERT INTO users (
            email, password_hash, first_name, last_name,
            is_active, is_verified, is_guest, tips_emails_enabled
        )
        SELECT
            'mitlist-load-{run_id}-' || n || '@example.invalid',
            '!synthetic-load-test!', 'Load', 'Test', true, true, false, false
        FROM generate_series(1, {count}) AS n
        RETURNING id, email;
        """,
        port=db_port,
    )
    accounts: list[Account] = []
    returned_rows = [line for line in rows.splitlines() if "|" in line]
    for index, row in enumerate(returned_rows):
        user_id, email = row.split("|", 1)
        accounts.append(
            Account(
                user_id=user_id,
                email=email,
                token=access_token(user_id, environment),
                client_ip=f"198.18.{index // 250}.{index % 250 + 1}",
            )
        )
    if len(accounts) != count:
        raise RuntimeError(f"created {len(accounts)} synthetic users, expected {count}")
    return accounts


def seed_account(client: ApiClient, account: Account, items: int) -> None:
    _, group = client.request(
        account,
        "POST",
        f"{API_PREFIX}/groups",
        body={"name": f"Load test {account.user_id[:8]}", "currency": "USD"},
        expected=(201,),
    )
    account.group_id = group["id"]
    _, item_list = client.request(
        account,
        "POST",
        f"{API_PREFIX}/lists",
        body={"group_id": account.group_id, "name": "Weekly groceries", "type": "shopping"},
        expected=(201,),
    )
    account.list_id = item_list["id"]
    for index in range(items):
        client.request(
            account,
            "POST",
            f"{API_PREFIX}/lists/{account.list_id}/items",
            body={"name": f"Item {index + 1}", "quantity": index % 3 + 1, "unit": "pc"},
            expected=(201,),
        )
    for index in range(3):
        client.request(
            account,
            "POST",
            f"{API_PREFIX}/chores",
            body={
                "group_id": account.group_id,
                "name": f"Chore {index + 1}",
                "rotation_type": "none",
                "frequency": "weekly",
                "period_interval": 1,
                "period_config": [],
                "assignment_type": "round-robin",
                "assignment_config": [account.user_id],
                "is_active": True,
            },
            expected=(201,),
        )
    for index in range(5):
        client.request(
            account,
            "POST",
            f"{API_PREFIX}/expenses",
            body={
                "group_id": account.group_id,
                "payer_id": account.user_id,
                "amount": 500 + index * 125,
                "description": f"Expense {index + 1}",
                "category": "Groceries",
                "currency": "USD",
                "date": f"{date.today().isoformat()}T12:00:00Z",
                "split_user_ids": [account.user_id],
                "split_mode": "equal",
            },
            expected=(201,),
        )
    for index in range(3):
        client.request(
            account,
            "POST",
            f"{API_PREFIX}/pinwall/posts",
            body={"group_id": account.group_id, "content": f"Load test note {index + 1}"},
            expected=(201,),
        )


def route_sets(account: Account) -> dict[str, list[tuple[str, str]]]:
    group = quote(account.group_id)
    today = date.today()
    week_end = today + timedelta(days=7)
    month_start = today - timedelta(days=14)
    month_end = today + timedelta(days=30)
    return {
        "home": [
            ("auth.me", f"{API_PREFIX}/auth/me"),
            ("group.detail", f"{API_PREFIX}/groups/{group}"),
            ("activity.list", f"{API_PREFIX}/activity?group_id={group}&limit=10"),
            ("finance.summary", f"{API_PREFIX}/finance/summary?group_id={group}"),
            ("lists.list", f"{API_PREFIX}/lists?group_id={group}&limit=50&offset=0"),
            ("chores.current", f"{API_PREFIX}/chores/current?group_id={group}&due_soon_days=7"),
            ("pinwall.list", f"{API_PREFIX}/pinwall/posts?group_id={group}&limit=50&offset=0"),
            ("mealplans.week", f"{API_PREFIX}/meal-plans?group_id={group}&from={today}&to={week_end}"),
            ("notifications.unread", f"{API_PREFIX}/notifications/unread-count"),
        ],
        "lists": [
            ("lists.list", f"{API_PREFIX}/lists?group_id={group}&limit=50&offset=0"),
            ("lists.items", f"{API_PREFIX}/lists/{quote(account.list_id)}/items?limit=100&offset=0"),
            ("shopping.locations", f"{API_PREFIX}/shopping-locations?group_id={group}"),
        ],
        "chores": [
            ("chores.list", f"{API_PREFIX}/chores?group_id={group}&limit=50&offset=0"),
            ("chores.current", f"{API_PREFIX}/chores/current?group_id={group}&due_soon_days=7"),
            ("chores.load", f"{API_PREFIX}/chores/load?group_id={group}"),
        ],
        "money": [
            ("expenses.list", f"{API_PREFIX}/expenses?group_id={group}&limit=50&offset=0"),
            ("finance.summary", f"{API_PREFIX}/finance/summary?group_id={group}"),
            ("finance.settlements", f"{API_PREFIX}/finance/settlements?group_id={group}&limit=50&offset=0"),
            ("expenses.recurring", f"{API_PREFIX}/recurring-expenses?group_id={group}&limit=50&offset=0"),
        ],
        "recipes": [
            ("recipes.list", f"{API_PREFIX}/recipes?group_id={group}&limit=50&offset=0"),
            ("recipes.tags", f"{API_PREFIX}/recipes/tags?group_id={group}"),
        ],
        "calendar": [
            (
                "calendar.aggregate",
                f"{API_PREFIX}/calendar?group_id={group}&from={month_start}&to={month_end}",
            ),
        ],
    }


def virtual_client_ip(sequence: int) -> str:
    # Keep virtual users stable across sessions and stages. A fresh IP for every
    # page load is not representative and drives the API's bounded limiter into
    # its high-cardinality eviction path once 10,000 buckets have accumulated.
    value = 10000 + sequence % 7500
    return f"198.19.{value // 250}.{value % 250 + 1}"


def run_page(
    client: ApiClient,
    request_pool: concurrent.futures.ThreadPoolExecutor,
    account: Account,
    page: str,
    client_ip: str,
    metrics: StageMetrics,
) -> None:
    started = time.perf_counter()
    requests = route_sets(account)[page]
    futures = [
        request_pool.submit(client.measured_get, account, path, client_ip, route)
        for route, path in requests
    ]
    results = [future.result() for future in futures]
    metrics.add_session(page, (time.perf_counter() - started) * 1000, results)


def database_connections(port: int) -> int | None:
    try:
        value = psql("SELECT count(*) FROM pg_stat_activity WHERE datname = 'mitlist';", port=port).strip()
        return int(value)
    except (RuntimeError, ValueError):
        return None


def summarize_stage(
    rate: float,
    duration: int,
    elapsed: float,
    metrics: StageMetrics,
    resources: dict[str, float | int | None],
    db_connections: int | None,
) -> dict:
    requests = metrics.requests
    request_latencies = [result.latency_ms for result in requests]
    failed = [result for result in requests if result.status != 200 or result.error]
    statuses = Counter(str(result.status) if result.status else result.error for result in requests)
    route_latencies: dict[str, list[float]] = defaultdict(list)
    route_failures: Counter[str] = Counter()
    for result in requests:
        route_latencies[result.route].append(result.latency_ms)
        if result.status != 200 or result.error:
            route_failures[result.route] += 1
    route_summary = {
        route: {
            "count": len(latencies),
            "p95_ms": percentile(latencies, 0.95),
            "errors": route_failures[route],
        }
        for route, latencies in sorted(route_latencies.items())
    }
    return {
        "target_sessions_per_second": rate,
        "duration_seconds": duration,
        "wall_time_seconds": round(elapsed, 3),
        "completed_sessions": len(metrics.session_latencies),
        "dropped_sessions": metrics.dropped_sessions,
        "achieved_requests_per_second": round(len(requests) / elapsed, 2),
        "requests": len(requests),
        "response_bytes": sum(result.size for result in requests),
        "error_rate_pct": round(100 * len(failed) / len(requests), 3) if requests else 100.0,
        "statuses": dict(sorted(statuses.items())),
        "pages": dict(sorted(metrics.pages.items())),
        "request_latency_ms": {
            "p50": percentile(request_latencies, 0.50),
            "p95": percentile(request_latencies, 0.95),
            "p99": percentile(request_latencies, 0.99),
            "max": percentile(request_latencies, 1.0),
        },
        "page_latency_ms": {
            "p50": percentile(metrics.session_latencies, 0.50),
            "p95": percentile(metrics.session_latencies, 0.95),
            "p99": percentile(metrics.session_latencies, 0.99),
            "max": percentile(metrics.session_latencies, 1.0),
        },
        "routes": route_summary,
        "resources": resources,
        "database_connections": db_connections,
    }


def run_stage(
    client: ApiClient,
    accounts: list[Account],
    rate: float,
    duration: int,
    max_sessions: int,
    request_workers: int,
    container: str,
    db_port: int,
    seed: int,
) -> dict:
    metrics = StageMetrics()
    monitor = ResourceMonitor(container, db_port)
    monitor.start()
    choices = ["home", "lists", "chores", "money", "recipes", "calendar"]
    weights = [45, 20, 15, 10, 5, 5]
    randomizer = random.Random(seed)
    started = time.perf_counter()
    deadline = started + duration
    next_session = started
    sequence = 0
    active: set[concurrent.futures.Future] = set()
    with concurrent.futures.ThreadPoolExecutor(max_workers=request_workers) as request_pool:
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_sessions) as session_pool:
            while next_session < deadline:
                wait = next_session - time.perf_counter()
                if wait > 0:
                    time.sleep(wait)
                active = {future for future in active if not future.done()}
                if len(active) >= max_sessions:
                    metrics.dropped_sessions += 1
                else:
                    account = accounts[sequence % len(accounts)]
                    page = randomizer.choices(choices, weights=weights, k=1)[0]
                    future = session_pool.submit(
                        run_page,
                        client,
                        request_pool,
                        account,
                        page,
                        virtual_client_ip(seed * 10000 + sequence),
                        metrics,
                    )
                    active.add(future)
                sequence += 1
                next_session += 1 / rate
            for future in concurrent.futures.as_completed(active):
                future.result()
    elapsed = time.perf_counter() - started
    resources = monitor.stop()
    return summarize_stage(
        rate,
        duration,
        elapsed,
        metrics,
        resources,
        database_connections(db_port),
    )


def cleanup(client: ApiClient, accounts: list[Account], run_id: str, db_port: int) -> None:
    for account in accounts:
        if account.group_id:
            try:
                client.request(
                    account,
                    "DELETE",
                    f"{API_PREFIX}/groups/{quote(account.group_id)}",
                    expected=(204, 404),
                )
            except RuntimeError:
                pass
    psql(
        f"""
        DELETE FROM groups
        WHERE created_by IN (
            SELECT id FROM users
            WHERE email LIKE 'mitlist-load-{run_id}-%@example.invalid'
        );
        DELETE FROM users
        WHERE email LIKE 'mitlist-load-{run_id}-%@example.invalid';
        """,
        port=db_port,
    )


def print_stage(stage: dict, index: int) -> None:
    latency = stage["request_latency_ms"]
    page_latency = stage["page_latency_ms"]
    resources = stage["resources"]
    print(
        f"stage {index}: {stage['target_sessions_per_second']} sessions/s, "
        f"{stage['achieved_requests_per_second']} req/s, "
        f"{stage['requests']} requests, {stage['error_rate_pct']}% errors"
    )
    print(
        f"  request latency p50={latency['p50']}ms p95={latency['p95']}ms "
        f"p99={latency['p99']}ms max={latency['max']}ms"
    )
    print(
        f"  page latency    p50={page_latency['p50']}ms p95={page_latency['p95']}ms "
        f"p99={page_latency['p99']}ms max={page_latency['max']}ms"
    )
    print(
        f"  backend CPU avg={resources['backend_cpu_avg_pct']}% "
        f"max={resources['backend_cpu_max_pct']}% "
        f"memory max={resources['backend_memory_max_mib']}MiB "
        f"db connections={stage['database_connections']}"
    )
    print(f"  statuses={stage['statuses']} dropped_sessions={stage['dropped_sessions']}", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", required=True, help="private backend container URL")
    parser.add_argument("--backend-container", default="mitlist-backend-1")
    parser.add_argument("--db-port", type=int, default=5433)
    parser.add_argument("--users", type=int, default=20)
    parser.add_argument("--items-per-user", type=int, default=10)
    parser.add_argument(
        "--stages",
        type=parse_stages,
        default=parse_stages("1:15,5:15,15:15,30:15,60:15"),
        help="comma-separated session-rate:duration stages",
    )
    parser.add_argument("--request-workers", type=int, default=256)
    parser.add_argument("--max-sessions", type=int, default=128)
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("--stop-error-rate", type=float, default=1.0)
    parser.add_argument("--stop-p95-ms", type=float, default=2000.0)
    parser.add_argument("--allow-production-data", action="store_true")
    parser.add_argument("--json-output")
    parser.add_argument(
        "--start-at",
        type=float,
        help="Unix timestamp at which stages begin, for synchronizing multiple generators",
    )
    args = parser.parse_args()
    if not args.allow_production_data:
        parser.error("--allow-production-data is required")
    if not 1 <= args.users <= 100:
        parser.error("--users must be between 1 and 100")
    if any(rate > 2000 for rate, _ in args.stages):
        parser.error("session rates above 2000/s are intentionally blocked")

    run_id = uuid.uuid4().hex[:12]
    environment = backend_environment(args.backend_container)
    client = ApiClient(args.base_url, args.timeout)
    accounts: list[Account] = []
    report = {
        "run_id": run_id,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "host": socket.gethostname(),
        "target": args.base_url,
        "backend_container": args.backend_container,
        "synthetic_users": args.users,
        "stages": [],
    }
    try:
        print(f"creating {args.users} isolated synthetic users", flush=True)
        accounts = create_accounts(args.users, run_id, environment, args.db_port)
        with concurrent.futures.ThreadPoolExecutor(max_workers=min(args.users, 20)) as pool:
            futures = [pool.submit(seed_account, client, account, args.items_per_user) for account in accounts]
            for future in concurrent.futures.as_completed(futures):
                future.result()
        print("seeded households through the production API", flush=True)
        if args.start_at is not None:
            delay = args.start_at - time.time()
            if delay > 0:
                print(f"waiting {delay:.1f}s for synchronized start", flush=True)
                time.sleep(delay)

        for index, (rate, duration) in enumerate(args.stages, start=1):
            stage = run_stage(
                client,
                accounts,
                rate,
                duration,
                args.max_sessions,
                args.request_workers,
                args.backend_container,
                args.db_port,
                index,
            )
            report["stages"].append(stage)
            print_stage(stage, index)
            p95 = stage["request_latency_ms"]["p95"] or 0
            if stage["error_rate_pct"] > args.stop_error_rate or p95 > args.stop_p95_ms:
                report["stopped_early"] = True
                report["stop_reason"] = (
                    f"error rate {stage['error_rate_pct']}% or request p95 {p95}ms crossed threshold"
                )
                print(f"stopping ramp: {report['stop_reason']}", flush=True)
                break
        return 0
    finally:
        try:
            cleanup(client, accounts, run_id, args.db_port)
            report["cleanup"] = "complete"
            print("synthetic data cleanup complete", flush=True)
        except Exception as exc:  # cleanup failure must remain visible
            report["cleanup"] = f"FAILED: {exc}"
            print(f"synthetic data cleanup FAILED: {exc}", flush=True)
        if args.json_output:
            with open(args.json_output, "w", encoding="utf-8") as output:
                json.dump(report, output, indent=2)


if __name__ == "__main__":
    raise SystemExit(main())
