"""HTTP server for the generation dashboard with run controls."""

from __future__ import annotations

import json
import mimetypes
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import yaml

from generator.job_controller import JobSpec, get_controller
from generator.progress import ProgressStore

ROOT = Path(__file__).resolve().parent.parent
DASHBOARD_DIR = ROOT / "dashboard"
DB_PATH = ROOT / "progress.db"


def _load_model_versions() -> dict:
    cfg_path = ROOT / "config" / "batches.yaml"
    if cfg_path.exists():
        with open(cfg_path) as f:
            cfg = yaml.safe_load(f)
        return cfg.get("model_versions", {})
    return {}


def build_dashboard_payload() -> dict:
    store = ProgressStore(DB_PATH)
    stats = store.get_stats()
    controller = get_controller()

    yaml_versions = _load_model_versions()
    db_versions = {v["name"]: v for v in stats.get("model_versions", [])}

    models = []
    for name, meta in yaml_versions.items():
        db = db_versions.get(name, {})
        db_meta = json.loads(db.get("metadata", "{}")) if db.get("metadata") else {}
        models.append({
            "name": name,
            "version": db.get("version") or meta.get("version", "0.0.0"),
            "status": db.get("status") or meta.get("status", "unknown"),
            **meta,
            **db_meta,
        })

    data_dir = ROOT / "ml" / "data"
    files = {}
    for fname in ("seed.json", "ocr_corpus.jsonl", "triplets.jsonl", "aisles.jsonl", "corrections.jsonl"):
        fpath = data_dir / fname
        if fpath.exists():
            size = fpath.stat().st_size
            lines = 0
            if fname.endswith(".jsonl"):
                lines = sum(1 for _ in open(fpath, encoding="utf-8"))
            elif fname.endswith(".json"):
                data = json.loads(fpath.read_text())
                lines = len(data) if isinstance(data, list) else 0
            files[fname] = {"bytes": size, "rows": lines, "path": str(fpath.relative_to(ROOT))}

    cfg_path = ROOT / "config" / "batches.yaml"
    with open(cfg_path) as f:
        cfg = yaml.safe_load(f)

    batch_targets = {}
    for pid, pcfg in cfg["prompts"].items():
        from generator.runner import build_batch_list
        total = len(build_batch_list(pid, cfg, require_seed=False))
        batch_targets[pid] = {
            "name": pcfg["name"],
            "total_batches": total,
            "output": pcfg["output"],
        }

    return {
        **stats,
        "models": models,
        "data_files": files,
        "batch_targets": batch_targets,
        "deepseek_model": os.getenv("DEEPSEEK_MODEL", "deepseek-chat"),
        "job": controller.status(),
        "api_key_set": bool(os.getenv("DEEPSEEK_API_KEY")),
    }


class DashboardHandler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args) -> None:
        pass

    def _send_json(self, data: dict, status: int = 200) -> None:
        body = json.dumps(data, indent=2).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json_body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        raw = self.rfile.read(length)
        return json.loads(raw.decode("utf-8"))

    def _send_file(self, path: Path) -> None:
        if not path.exists():
            self.send_error(404)
            return
        content = path.read_bytes()
        mime, _ = mimetypes.guess_type(str(path))
        self.send_response(200)
        self.send_header("Content-Type", mime or "application/octet-stream")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self) -> None:
        parsed = urlparse(self.path)

        if parsed.path == "/api/stats":
            self._send_json(build_dashboard_payload())
            return

        if parsed.path == "/api/job":
            self._send_json(get_controller().status())
            return

        if parsed.path == "/api/batches":
            qs = parse_qs(parsed.query)
            prompt_id = qs.get("prompt", [None])[0]
            limit = int(qs.get("limit", ["50"])[0])
            store = ProgressStore(DB_PATH)
            self._send_json({"batches": store.list_batches(prompt_id, limit=limit)})
            return

        if parsed.path in ("/", "/index.html"):
            self._send_file(DASHBOARD_DIR / "index.html")
            return

        asset = DASHBOARD_DIR / parsed.path.lstrip("/")
        if asset.exists() and asset.is_relative_to(DASHBOARD_DIR):
            self._send_file(asset)
            return

        self.send_error(404)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        controller = get_controller()

        try:
            body = self._read_json_body()
        except json.JSONDecodeError:
            self._send_json({"ok": False, "error": "Invalid JSON"}, status=400)
            return

        if parsed.path == "/api/job/start":
            prompt = body.get("prompt")
            if prompt is None:
                self._send_json({"ok": False, "error": "prompt is required"}, status=400)
                return
            spec = JobSpec(
                prompt_id=str(prompt),
                mode=body.get("mode", "pending"),
                batch_key=body.get("batch"),
                category=body.get("category"),
                temperature=body.get("temperature"),
                force=bool(body.get("force", False)),
            )
            result = controller.start(spec)
            self._send_json(result, status=200 if result.get("ok") else 409)
            return

        if parsed.path == "/api/job/pipeline":
            # Recommended order: P1 → P2 → P5 → P3 → P4 (pending only)
            specs = [
                JobSpec(prompt_id="1", mode="pending"),
                JobSpec(prompt_id="2", mode="pending"),
                JobSpec(prompt_id="5", mode="pending"),
                JobSpec(prompt_id="3", mode="pending"),
                JobSpec(prompt_id="4", mode="pending"),
            ]
            result = controller.enqueue(specs)
            self._send_json(result, status=200 if result.get("ok") else 409)
            return

        if parsed.path == "/api/job/stop":
            result = controller.stop()
            self._send_json(result, status=200 if result.get("ok") else 409)
            return

        self.send_error(404)


def serve(host: str = "127.0.0.1", port: int = 8765) -> None:
    try:
        from dotenv import load_dotenv
        load_dotenv(ROOT / ".env")
    except ImportError:
        pass

    server = HTTPServer((host, port), DashboardHandler)
    print(f"Dashboard → http://{host}:{port}")
    print(f"API       → http://{host}:{port}/api/stats")
    print("Controls  → start/stop jobs from the web UI")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    serve(
        host=os.getenv("DASHBOARD_HOST", "127.0.0.1"),
        port=int(os.getenv("DASHBOARD_PORT", "8765")),
    )
