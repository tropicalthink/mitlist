"""Background job runner — controlled from the dashboard."""

from __future__ import annotations

import os
import threading
import traceback
from collections import deque
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from generator.progress import ProgressStore
from generator.runner import (
    DB_PATH,
    ROOT,
    build_batch_list,
    load_config,
    load_pricing,
    run_batch,
)

MAX_LOG_LINES = 200


def _utcnow() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class JobSpec:
    prompt_id: str
    mode: str = "pending"  # pending | all | batch | category
    batch_key: str | None = None
    category: str | None = None
    temperature: float | None = None
    force: bool = False


@dataclass
class JobState:
    status: str = "idle"  # idle | queued | running | done | cancelled | error
    spec: JobSpec | None = None
    current_batch: str | None = None
    total: int = 0
    completed: int = 0
    failed: int = 0
    skipped: int = 0
    index: int = 0
    started_at: str | None = None
    finished_at: str | None = None
    error: str | None = None
    logs: deque[str] = field(default_factory=lambda: deque(maxlen=MAX_LOG_LINES))
    queue: list[JobSpec] = field(default_factory=list)


class JobController:
    """Singleton background worker for batch generation."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._cancel = threading.Event()
        self._thread: threading.Thread | None = None
        self._state = JobState()
        store = ProgressStore(DB_PATH)
        n = store.reset_stale_running()
        if n:
            self._log(f"Reset {n} stale running batch(es) from previous session")

    def _log(self, msg: str) -> None:
        line = f"[{_utcnow()[:19]}] {msg}"
        self._state.logs.append(line)

    def start(self, spec: JobSpec) -> dict[str, Any]:
        with self._lock:
            if self._state.status in ("running", "queued"):
                return {"ok": False, "error": "A job is already running. Stop it first or wait."}
            self._cancel.clear()
            self._state = JobState(status="queued", spec=spec, queue=[spec])
            self._thread = threading.Thread(target=self._run_loop, daemon=True)
            self._thread.start()
        return {"ok": True, "message": f"Started prompt {spec.prompt_id} ({spec.mode})"}

    def enqueue(self, specs: list[JobSpec]) -> dict[str, Any]:
        """Queue multiple prompts to run sequentially."""
        with self._lock:
            if self._state.status in ("running", "queued"):
                return {"ok": False, "error": "A job is already running."}
            if not specs:
                return {"ok": False, "error": "No jobs to enqueue"}
            self._cancel.clear()
            self._state = JobState(status="queued", spec=specs[0], queue=list(specs))
            self._thread = threading.Thread(target=self._run_loop, daemon=True)
            self._thread.start()
        labels = ", ".join(f"P{s.prompt_id}" for s in specs)
        return {"ok": True, "message": f"Queued pipeline: {labels}"}

    def stop(self) -> dict[str, Any]:
        with self._lock:
            if self._state.status not in ("running", "queued"):
                return {"ok": False, "error": "No job is running"}
            self._cancel.set()
            self._log("Stop requested — finishing current batch then stopping")
        return {"ok": True, "message": "Cancellation requested"}

    def status(self) -> dict[str, Any]:
        with self._lock:
            s = self._state
            spec = s.spec
            return {
                "status": s.status,
                "prompt_id": spec.prompt_id if spec else None,
                "mode": spec.mode if spec else None,
                "current_batch": s.current_batch,
                "progress": {
                    "index": s.index,
                    "total": s.total,
                    "completed": s.completed,
                    "failed": s.failed,
                    "skipped": s.skipped,
                },
                "queue_remaining": len(s.queue),
                "started_at": s.started_at,
                "finished_at": s.finished_at,
                "error": s.error,
                "logs": list(s.logs),
            }

    def _run_loop(self) -> None:
        try:
            from dotenv import load_dotenv
            load_dotenv(ROOT / ".env")
        except ImportError:
            pass

        while self._state.queue:
            if self._cancel.is_set():
                self._state.status = "cancelled"
                self._state.finished_at = _utcnow()
                self._log("Job cancelled")
                self._state.queue.clear()
                return

            spec = self._state.queue.pop(0)
            self._state.spec = spec
            self._state.status = "running"
            self._state.started_at = self._state.started_at or _utcnow()
            self._run_spec(spec)

        with self._lock:
            if self._cancel.is_set():
                self._state.status = "cancelled"
            elif self._state.failed > 0 and self._state.completed == 0:
                self._state.status = "error"
            else:
                self._state.status = "done"
            self._state.finished_at = _utcnow()
            self._state.current_batch = None
            self._log(f"Finished — {self._state.completed} ok, {self._state.failed} failed, {self._state.skipped} skipped")

    def _run_spec(self, spec: JobSpec) -> None:
        from generator.deepseek_client import DeepSeekClient

        cfg = load_config()
        pricing = load_pricing()
        store = ProgressStore(DB_PATH)

        if not os.environ.get("DEEPSEEK_API_KEY"):
            self._state.status = "error"
            self._state.error = "DEEPSEEK_API_KEY not set in .env"
            self._log(self._state.error)
            self._state.queue.clear()
            return

        try:
            client = DeepSeekClient()
        except Exception as e:
            self._state.status = "error"
            self._state.error = str(e)
            self._log(f"Client init failed: {e}")
            self._state.queue.clear()
            return

        prompt_id = spec.prompt_id
        pcfg = cfg["prompts"][prompt_id]
        temps = (
            [spec.temperature]
            if spec.temperature is not None
            else pcfg.get("temperatures", [float(os.getenv("DEFAULT_TEMPERATURE", "0.9"))])
        )

        if spec.mode == "category" and spec.category:
            batches = [(spec.category, {"CATEGORY": spec.category})]
        elif spec.mode == "batch" and spec.batch_key:
            all_batches = build_batch_list(prompt_id, cfg, require_seed=True)
            batches = [(k, v) for k, v in all_batches if k == spec.batch_key]
            if not batches:
                self._log(f"Unknown batch: {spec.batch_key}")
                return
        else:
            batches = build_batch_list(prompt_id, cfg, require_seed=True)

        expanded: list[tuple[str, dict, float]] = []
        for batch_key, variables in batches:
            for temp in temps:
                key = f"{batch_key}_t{str(temp).replace('.', '')}" if len(temps) > 1 else batch_key
                expanded.append((key, variables, temp))

        if spec.mode == "pending":
            expanded = [
                (k, v, t) for k, v, t in expanded
                if spec.force or not store.is_completed(prompt_id, k)
            ]

        self._state.total = len(expanded)
        self._state.index = 0
        self._log(f"Prompt {prompt_id} ({spec.mode}): {len(expanded)} batch(es) to run")

        for batch_key, variables, temp in expanded:
            if self._cancel.is_set():
                return

            self._state.index += 1
            self._state.current_batch = batch_key

            if not spec.force and store.is_completed(prompt_id, batch_key):
                self._state.skipped += 1
                self._log(f"Skip {batch_key} (already done)")
                continue

            self._log(f"Running [{self._state.index}/{self._state.total}] {batch_key} (temp={temp})")
            try:
                ok = run_batch(
                    prompt_id, batch_key, variables,
                    temperature=temp, client=client, store=store,
                    cfg=cfg, pricing=pricing, force=spec.force,
                )
                if ok:
                    self._state.completed += 1
                    self._log(f"OK {batch_key}")
                else:
                    self._state.failed += 1
                    self._log(f"FAIL {batch_key}")
            except Exception as e:
                self._state.failed += 1
                self._log(f"ERROR {batch_key}: {e}")


# Module singleton — shared by dashboard server
_controller: JobController | None = None


def get_controller() -> JobController:
    global _controller
    if _controller is None:
        _controller = JobController()
    return _controller
