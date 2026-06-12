"""LLM API clients (OpenAI-compatible) — DeepSeek for P1–P2, OpenRouter for P3–P5."""

from __future__ import annotations

import os
import time
from dataclasses import dataclass
from typing import Any

from openai import OpenAI

OPENROUTER_PROMPTS = frozenset({"3", "4", "5"})


@dataclass
class CompletionResult:
    content: str
    model: str
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int
    latency_ms: int
    raw_response: dict[str, Any]


class DeepSeekClient:
    """OpenAI-compatible chat client (DeepSeek, OpenRouter, etc.)."""

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
        max_retries: int = 3,
        timeout: int = 300,
        *,
        provider: str = "DeepSeek",
        default_headers: dict[str, str] | None = None,
    ):
        self.provider = provider
        self.api_key = api_key or os.environ["DEEPSEEK_API_KEY"]
        self.base_url = base_url or os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
        self.model = model or os.getenv("DEEPSEEK_MODEL", "deepseek-chat")
        self.max_retries = max_retries
        self.timeout = timeout
        self._client = OpenAI(
            api_key=self.api_key,
            base_url=self.base_url,
            timeout=timeout,
            default_headers=default_headers,
        )

    def complete(
        self,
        prompt: str,
        *,
        temperature: float = 0.9,
        system: str | None = None,
        max_tokens: int | None = None,
    ) -> CompletionResult:
        messages: list[dict[str, str]] = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})

        if max_tokens is None:
            max_tokens = int(os.getenv("MAX_COMPLETION_TOKENS", "8192"))

        last_err: Exception | None = None
        for attempt in range(self.max_retries):
            try:
                start = time.monotonic()
                response = self._client.chat.completions.create(
                    model=self.model,
                    messages=messages,
                    temperature=temperature,
                    max_tokens=max_tokens,
                    stream=False,
                )
                latency_ms = int((time.monotonic() - start) * 1000)
                choice = response.choices[0]
                usage = response.usage
                msg = choice.message
                content = msg.content or ""
                if not content.strip():
                    reasoning = getattr(msg, "reasoning_content", None) or ""
                    if reasoning:
                        content = reasoning
                if not content.strip():
                    if attempt < self.max_retries - 1:
                        time.sleep(2 ** attempt)
                        continue
                raw = response.model_dump()
                raw["finish_reason"] = choice.finish_reason
                return CompletionResult(
                    content=content,
                    model=response.model,
                    prompt_tokens=usage.prompt_tokens if usage else 0,
                    completion_tokens=usage.completion_tokens if usage else 0,
                    total_tokens=usage.total_tokens if usage else 0,
                    latency_ms=latency_ms,
                    raw_response=raw,
                )
            except Exception as e:
                last_err = e
                wait = 2 ** attempt
                time.sleep(wait)
        raise RuntimeError(f"{self.provider} API failed after {self.max_retries} retries") from last_err


def uses_openrouter(prompt_id: str) -> bool:
    return prompt_id in OPENROUTER_PROMPTS


def openrouter_model_for_prompt(prompt_id: str) -> str:
    return os.getenv(f"OPENROUTER_MODEL_P{prompt_id}") or os.getenv(
        "OPENROUTER_MODEL", "google/gemini-2.5-flash-preview"
    )


def api_key_error_for_prompt(prompt_id: str) -> str | None:
    if uses_openrouter(prompt_id):
        if not os.environ.get("OPENROUTER_API_KEY"):
            return f"OPENROUTER_API_KEY not set in .env (P{prompt_id} uses OpenRouter)"
        return None
    if not os.environ.get("DEEPSEEK_API_KEY"):
        return "DEEPSEEK_API_KEY not set in .env"
    return None


def client_for_prompt(prompt_id: str) -> DeepSeekClient:
    """Return the LLM client — P1–P2 DeepSeek, P3–P5 OpenRouter."""
    if uses_openrouter(prompt_id):
        key = os.environ.get("OPENROUTER_API_KEY")
        if not key:
            raise RuntimeError("OPENROUTER_API_KEY not set in .env")
        headers: dict[str, str] = {}
        site = os.getenv("OPENROUTER_SITE_URL")
        app = os.getenv("OPENROUTER_APP_NAME", "mitlist-intelligence")
        if site:
            headers["HTTP-Referer"] = site
        if app:
            headers["X-Title"] = app
        return DeepSeekClient(
            api_key=key,
            base_url=os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1"),
            model=openrouter_model_for_prompt(prompt_id),
            timeout=int(os.getenv("REQUEST_TIMEOUT", "300")),
            provider="OpenRouter",
            default_headers=headers or None,
        )
    return DeepSeekClient(
        timeout=int(os.getenv("REQUEST_TIMEOUT", "300")),
    )


def provider_label_for_prompt(prompt_id: str) -> str:
    if uses_openrouter(prompt_id):
        return f"OpenRouter ({openrouter_model_for_prompt(prompt_id)})"
    return f"DeepSeek ({os.getenv('DEEPSEEK_MODEL', 'deepseek-chat')})"
