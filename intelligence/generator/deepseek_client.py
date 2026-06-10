"""DeepSeek API client (OpenAI-compatible)."""

from __future__ import annotations

import os
import time
from dataclasses import dataclass
from typing import Any

from openai import OpenAI


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
    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
        max_retries: int = 3,
        timeout: int = 300,
    ):
        self.api_key = api_key or os.environ["DEEPSEEK_API_KEY"]
        self.base_url = base_url or os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
        self.model = model or os.getenv("DEEPSEEK_MODEL", "deepseek-chat")
        self.max_retries = max_retries
        self.timeout = timeout
        self._client = OpenAI(api_key=self.api_key, base_url=self.base_url, timeout=timeout)

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
                content = choice.message.content or ""
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
        raise RuntimeError(f"DeepSeek API failed after {self.max_retries} retries") from last_err
