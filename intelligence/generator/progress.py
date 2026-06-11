"""SQLite-backed progress and cost tracking."""

from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _utcnow() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class BatchJob:
    id: str
    prompt_id: str
    batch_key: str
    status: str  # pending | running | completed | failed
    model: str
    temperature: float
    prompt_tokens: int
    completion_tokens: int
    cost_usd: float
    rows_generated: int
    error: str | None
    started_at: str | None
    completed_at: str | None


class ProgressStore:
    def __init__(self, db_path: Path):
        self.db_path = db_path
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        return conn

    def _init_db(self) -> None:
        with self._connect() as conn:
            conn.executescript("""
                CREATE TABLE IF NOT EXISTS batches (
                    id TEXT PRIMARY KEY,
                    prompt_id TEXT NOT NULL,
                    batch_key TEXT NOT NULL,
                    status TEXT NOT NULL DEFAULT 'pending',
                    model TEXT,
                    temperature REAL DEFAULT 0.9,
                    prompt_tokens INTEGER DEFAULT 0,
                    completion_tokens INTEGER DEFAULT 0,
                    cost_usd REAL DEFAULT 0,
                    rows_generated INTEGER DEFAULT 0,
                    error TEXT,
                    started_at TEXT,
                    completed_at TEXT,
                    output_path TEXT,
                    UNIQUE(prompt_id, batch_key)
                );
                CREATE TABLE IF NOT EXISTS runs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    batch_id TEXT NOT NULL,
                    model TEXT,
                    prompt_tokens INTEGER,
                    completion_tokens INTEGER,
                    cost_usd REAL,
                    latency_ms INTEGER,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY (batch_id) REFERENCES batches(id)
                );
                CREATE TABLE IF NOT EXISTS model_versions (
                    name TEXT PRIMARY KEY,
                    version TEXT,
                    status TEXT,
                    metadata TEXT,
                    updated_at TEXT
                );
            """)

    def batch_id(self, prompt_id: str, batch_key: str) -> str:
        return f"p{prompt_id}_{batch_key}"

    def get_batch(self, prompt_id: str, batch_key: str) -> BatchJob | None:
        bid = self.batch_id(prompt_id, batch_key)
        with self._connect() as conn:
            row = conn.execute("SELECT * FROM batches WHERE id = ?", (bid,)).fetchone()
        if not row:
            return None
        return self._row_to_job(row)

    def is_completed(self, prompt_id: str, batch_key: str) -> bool:
        job = self.get_batch(prompt_id, batch_key)
        return job is not None and job.status == "completed"

    def reset_stale_running(self) -> int:
        """Reset batches stuck in 'running' (e.g. after crash). Returns count reset."""
        with self._connect() as conn:
            cur = conn.execute(
                "UPDATE batches SET status = 'pending', error = 'interrupted' WHERE status = 'running'"
            )
            return cur.rowcount

    def list_batches(self, prompt_id: str | None = None, limit: int = 100) -> list[dict[str, Any]]:
        with self._connect() as conn:
            if prompt_id:
                rows = conn.execute(
                    """
                    SELECT prompt_id, batch_key, status, rows_generated, cost_usd, error, completed_at
                    FROM batches WHERE prompt_id = ?
                    ORDER BY COALESCE(completed_at, started_at) DESC LIMIT ?
                    """,
                    (prompt_id, limit),
                ).fetchall()
            else:
                rows = conn.execute(
                    """
                    SELECT prompt_id, batch_key, status, rows_generated, cost_usd, error, completed_at
                    FROM batches ORDER BY COALESCE(completed_at, started_at) DESC LIMIT ?
                    """,
                    (limit,),
                ).fetchall()
        return [dict(r) for r in rows]

    def start_batch(
        self,
        prompt_id: str,
        batch_key: str,
        *,
        model: str,
        temperature: float,
        output_path: str,
    ) -> str:
        bid = self.batch_id(prompt_id, batch_key)
        now = _utcnow()
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO batches (id, prompt_id, batch_key, status, model, temperature, started_at, output_path)
                VALUES (?, ?, ?, 'running', ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    status = 'running',
                    model = excluded.model,
                    temperature = excluded.temperature,
                    started_at = excluded.started_at,
                    error = NULL
                """,
                (bid, prompt_id, batch_key, model, temperature, now, output_path),
            )
        return bid

    def complete_batch(
        self,
        batch_id: str,
        *,
        prompt_tokens: int,
        completion_tokens: int,
        cost_usd: float,
        rows_generated: int,
        latency_ms: int,
        model: str,
    ) -> None:
        now = _utcnow()
        with self._connect() as conn:
            conn.execute(
                """
                UPDATE batches SET
                    status = 'completed',
                    prompt_tokens = prompt_tokens + ?,
                    completion_tokens = completion_tokens + ?,
                    cost_usd = cost_usd + ?,
                    rows_generated = rows_generated + ?,
                    completed_at = ?
                WHERE id = ?
                """,
                (prompt_tokens, completion_tokens, cost_usd, rows_generated, now, batch_id),
            )
            conn.execute(
                """
                INSERT INTO runs (batch_id, model, prompt_tokens, completion_tokens, cost_usd, latency_ms, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (batch_id, model, prompt_tokens, completion_tokens, cost_usd, latency_ms, now),
            )

    def fail_batch(self, batch_id: str, error: str) -> None:
        now = _utcnow()
        with self._connect() as conn:
            conn.execute(
                "UPDATE batches SET status = 'failed', error = ?, completed_at = ? WHERE id = ?",
                (error[:2000], now, batch_id),
            )

    def get_stats(self) -> dict[str, Any]:
        with self._connect() as conn:
            totals = conn.execute("""
                SELECT
                    COUNT(*) as total_batches,
                    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
                    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed,
                    SUM(CASE WHEN status = 'running' THEN 1 ELSE 0 END) as running,
                    SUM(prompt_tokens) as prompt_tokens,
                    SUM(completion_tokens) as completion_tokens,
                    SUM(cost_usd) as total_cost_usd,
                    SUM(rows_generated) as total_rows
                FROM batches
            """).fetchone()

            by_prompt = conn.execute("""
                SELECT prompt_id,
                    COUNT(*) as total,
                    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
                    SUM(rows_generated) as rows,
                    SUM(cost_usd) as cost
                FROM batches GROUP BY prompt_id ORDER BY prompt_id
            """).fetchall()

            recent = conn.execute("""
                SELECT b.prompt_id, b.batch_key, b.status, b.rows_generated, b.cost_usd, b.completed_at, b.error
                FROM batches b
                ORDER BY COALESCE(b.completed_at, b.started_at) DESC
                LIMIT 20
            """).fetchall()

            models = conn.execute("SELECT * FROM model_versions").fetchall()

        return {
            "totals": dict(totals) if totals else {},
            "by_prompt": [dict(r) for r in by_prompt],
            "recent_batches": [dict(r) for r in recent],
            "model_versions": [dict(r) for r in models],
            "updated_at": _utcnow(),
        }

    def update_model_version(self, name: str, version: str, status: str, metadata: dict) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO model_versions (name, version, status, metadata, updated_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(name) DO UPDATE SET
                    version = excluded.version,
                    status = excluded.status,
                    metadata = excluded.metadata,
                    updated_at = excluded.updated_at
                """,
                (name, version, status, json.dumps(metadata), _utcnow()),
            )

    def _row_to_job(self, row: sqlite3.Row) -> BatchJob:
        return BatchJob(
            id=row["id"],
            prompt_id=row["prompt_id"],
            batch_key=row["batch_key"],
            status=row["status"],
            model=row["model"] or "",
            temperature=row["temperature"] or 0.9,
            prompt_tokens=row["prompt_tokens"] or 0,
            completion_tokens=row["completion_tokens"] or 0,
            cost_usd=row["cost_usd"] or 0.0,
            rows_generated=row["rows_generated"] or 0,
            error=row["error"],
            started_at=row["started_at"],
            completed_at=row["completed_at"],
        )
