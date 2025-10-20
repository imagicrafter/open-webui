"""
DigitalOcean Function pipe for Open WebUI.

This pipe forwards chat completion requests to a DigitalOcean Function endpoint
and normalises the responses so that Open WebUI can consume task outputs such
as chat title and follow-up question generation.
"""

from __future__ import annotations

import copy
import json
import os
import re
import time
import uuid
from collections import deque
from typing import Any, Dict, List, Optional

import requests
from pydantic import BaseModel, Field, field_validator

from open_webui.constants import TASKS


class Pipe:
    class Valves(BaseModel):
        DIGITALOCEAN_FUNCTION_URL: str = Field(
            default_factory=lambda: os.getenv("DIGITALOCEAN_FUNCTION_URL")
            or os.getenv("DO_FUNCTION_URL")
            or "https://your-digitalocean-function-endpoint"
        )
        DIGITALOCEAN_FUNCTION_TOKEN: Optional[str] = Field(
            default_factory=lambda: os.getenv("DIGITALOCEAN_FUNCTION_TOKEN")
            or os.getenv("DO_FUNCTION_TOKEN")
            or "replace-with-digitalocean-function-token"
        )
        REQUEST_TIMEOUT_SECONDS: float = Field(
            default_factory=lambda: float(
                os.getenv("DIGITALOCEAN_FUNCTION_TIMEOUT_SECONDS")
                or os.getenv("DO_FUNCTION_TIMEOUT_SECONDS")
                or "60"
            )
        )
        VERIFY_SSL: bool = Field(
            default_factory=lambda: (
                os.getenv("DIGITALOCEAN_FUNCTION_VERIFY_SSL")
                or os.getenv("DO_FUNCTION_VERIFY_SSL")
                or "true"
            ).lower()
            != "false"
        )

        @field_validator("DIGITALOCEAN_FUNCTION_URL")
        @classmethod
        def _trim_url(cls, value: str) -> str:
            return value.strip()

        @field_validator("REQUEST_TIMEOUT_SECONDS")
        @classmethod
        def _validate_timeout(cls, value: float) -> float:
            if value <= 0:
                raise ValueError("REQUEST_TIMEOUT_SECONDS must be greater than zero.")
            return value

    def __init__(self) -> None:
        self.type = "pipe"
        self.name = "DigitalOcean Function"
        self.valves = self.Valves()

    # Public API ---------------------------------------------------------
    def pipe(
        self,
        body: Dict[str, Any],
        __task__: Optional[str] = None,
        __task_body__: Optional[Dict[str, Any]] = None,
        __metadata__: Optional[Dict[str, Any]] = None,
        __user__: Optional[Dict[str, Any]] = None,
        **kwargs: Any,
    ) -> Dict[str, Any]:
        raw_response = self._invoke_function(
            body=body,
            task=__task__,
            task_body=__task_body__,
            metadata=__metadata__,
            user=__user__,
            extras=kwargs,
        )

        if self._is_openai_chat_completion(raw_response):
            return self._ensure_task_payload_in_choices(
                raw_response, __task__, __task_body__
            )

        formatted = self._format_task_response(
            task=__task__,
            raw_response=raw_response,
            model=body.get("model", ""),
            task_body=__task_body__,
        )
        if formatted is not None:
            return formatted

        content = self._coerce_to_string(raw_response)
        return self._build_completion(body.get("model", ""), content)

    # DigitalOcean invocation --------------------------------------------
    def _invoke_function(
        self,
        body: Dict[str, Any],
        task: Optional[str],
        task_body: Optional[Dict[str, Any]],
        metadata: Optional[Dict[str, Any]],
        user: Optional[Dict[str, Any]],
        extras: Dict[str, Any],
    ) -> Any:
        if not self.valves.DIGITALOCEAN_FUNCTION_URL:
            raise ValueError("DIGITALOCEAN_FUNCTION_URL valve is not configured.")

        payload: Dict[str, Any] = {"body": body}

        context: Dict[str, Any] = {}
        if task is not None:
            context["task"] = task
        if task_body is not None:
            context["task_body"] = task_body
        if metadata is not None:
            context["metadata"] = metadata
        if user is not None:
            context["user"] = user

        optional_keys = {
            "chat_id": extras.get("__chat_id__"),
            "session_id": extras.get("__session_id__"),
            "message_id": extras.get("__message_id__"),
            "files": extras.get("__files__"),
            "oauth_token": extras.get("__oauth_token__"),
        }
        context.update({k: v for k, v in optional_keys.items() if v is not None})

        if context:
            payload["context"] = context

        headers = {"Content-Type": "application/json"}
        if self.valves.DIGITALOCEAN_FUNCTION_TOKEN:
            headers["Authorization"] = f"Bearer {self.valves.DIGITALOCEAN_FUNCTION_TOKEN}"

        try:
            response = requests.post(
                self.valves.DIGITALOCEAN_FUNCTION_URL,
                json=payload,
                headers=headers,
                timeout=self.valves.REQUEST_TIMEOUT_SECONDS,
                verify=self.valves.VERIFY_SSL,
            )
            response.raise_for_status()
        except requests.RequestException as exc:  # pragma: no cover - network failure
            raise RuntimeError(
                f"DigitalOcean Function request failed: {exc}"
            ) from exc

        try:
            return response.json()
        except ValueError:
            text = response.text.strip()
            return text if text else {}

    # Response handling --------------------------------------------------
    @staticmethod
    def _build_completion(model: str, content: str) -> Dict[str, Any]:
        return {
            "id": f"do-function-{uuid.uuid4()}",
            "object": "chat.completion",
            "created": int(time.time()),
            "model": model,
            "choices": [
                {
                    "index": 0,
                    "finish_reason": "stop",
                    "message": {
                        "role": "assistant",
                        "content": content,
                    },
                }
            ],
        }

    def _format_task_response(
        self,
        task: Optional[str],
        raw_response: Any,
        model: str,
        task_body: Optional[Dict[str, Any]],
    ) -> Optional[Dict[str, Any]]:
        if task == str(TASKS.TITLE_GENERATION):
            title = self._extract_title(raw_response)
            if not title:
                title = self._fallback_title(task_body)
            content = self._wrap_hidden_json({"title": title or ""})
            return self._build_completion(model, content)

        if task == str(TASKS.FOLLOW_UP_GENERATION):
            follow_ups = self._extract_follow_ups(raw_response)
            if not follow_ups:
                follow_ups = self._fallback_follow_ups(task_body)
            content = self._wrap_hidden_json({"follow_ups": follow_ups})
            return self._build_completion(model, content)

        return None

    @staticmethod
    def _is_openai_chat_completion(response: Any) -> bool:
        if not isinstance(response, dict):
            return False
        choices = response.get("choices")
        if not isinstance(choices, list) or not choices:
            return False
        first = choices[0]
        if not isinstance(first, dict):
            return False
        message = first.get("message")
        if not isinstance(message, dict):
            return False
        return "content" in message

    def _ensure_task_payload_in_choices(
        self,
        response: Dict[str, Any],
        task: Optional[str],
        task_body: Optional[Dict[str, Any]],
    ) -> Dict[str, Any]:
        if task not in (
            str(TASKS.TITLE_GENERATION),
            str(TASKS.FOLLOW_UP_GENERATION),
        ):
            return response

        updated = copy.deepcopy(response)
        mutated = False

        for choice in updated.get("choices", []):
            if not isinstance(choice, dict):
                continue

            message = choice.get("message")
            if not isinstance(message, dict):
                continue

            content = message.get("content")
            if task == str(TASKS.TITLE_GENERATION):
                if self._content_has_key(content, "title"):
                    continue
                title = self._extract_title(content)
                if not title:
                    title = self._fallback_title(task_body)
                message["content"] = self._wrap_hidden_json({"title": title or ""})
                mutated = True
            else:
                if self._content_has_key(content, "follow_ups"):
                    continue
                follow_ups = self._extract_follow_ups(content)
                if not follow_ups:
                    follow_ups = self._fallback_follow_ups(task_body)
                message["content"] = self._wrap_hidden_json({"follow_ups": follow_ups})
                mutated = True

        return updated if mutated else response

    def _content_has_key(self, content: Any, key: str) -> bool:
        if not isinstance(content, str):
            return False
        parsed = self._maybe_parse_json(content)
        return isinstance(parsed, dict) and key in parsed and parsed[key] not in (
            None,
            "",
            [],
        )

    # Extraction helpers -------------------------------------------------
    def _extract_title(self, raw: Any) -> str:
        candidate = self._recursive_find(
            raw, {"title", "chat_title", "chatTitle", "name", "headline"}
        )
        if candidate is None:
            candidate = raw
        title = self._first_non_empty_string(candidate)
        return title[:100] if title else ""

    def _extract_follow_ups(self, raw: Any) -> List[str]:
        candidate = self._recursive_find(
            raw,
            {
                "follow_ups",
                "followUps",
                "follow_up_questions",
                "followUpQuestions",
                "followup_questions",
                "suggestions",
                "questions",
                "prompts",
            },
        )
        if candidate is None:
            candidate = raw
        follow_ups = self._normalize_follow_up_collection(candidate)
        return follow_ups[:5]

    def _fallback_title(self, task_body: Optional[Dict[str, Any]]) -> str:
        if not task_body:
            return ""
        messages = task_body.get("messages") or []
        for message in reversed(messages):
            if isinstance(message, dict) and message.get("role") == "user":
                content = message.get("content")
                if isinstance(content, str) and content.strip():
                    return content.strip()[:100]
        return ""

    @staticmethod
    def _fallback_follow_ups(
        _task_body: Optional[Dict[str, Any]]
    ) -> List[str]:
        return []

    # General utilities --------------------------------------------------
    @staticmethod
    def _coerce_to_string(value: Any) -> str:
        if isinstance(value, str):
            return value
        try:
            return json.dumps(value)
        except TypeError:
            return str(value)

    @staticmethod
    def _wrap_hidden_json(payload: Dict[str, Any]) -> str:
        json_payload = json.dumps(payload, separators=(",", ":"))
        return (
            "<span data-openwebui-task-json='true' hidden>"
            f"{json_payload}"
            "</span>"
        )

    def _maybe_parse_json(self, value: Any) -> Any:
        if isinstance(value, str):
            text = value.strip()
            prefix = "<span data-openwebui-task-json='true' hidden>"
            suffix = "</span>"
            if text.startswith(prefix) and text.endswith(suffix):
                text = text[len(prefix) : -len(suffix)]
            if text and text[0] in ("{", "["):
                try:
                    return json.loads(text)
                except json.JSONDecodeError:
                    return value
        return value

    def _recursive_find(self, data: Any, keys: set[str]) -> Any:
        queue: deque[Any] = deque([data])
        seen: set[int] = set()

        while queue:
            current = queue.popleft()

            if isinstance(current, str):
                parsed = self._maybe_parse_json(current)
                if parsed is not current:
                    queue.append(parsed)
                continue

            current_id = id(current)
            if current_id in seen:
                continue
            seen.add(current_id)

            if isinstance(current, dict):
                for key, value in current.items():
                    if key in keys:
                        return value
                    queue.append(value)
            elif isinstance(current, list):
                queue.extend(current)

        return None

    def _collect_strings(self, data: Any) -> List[str]:
        queue: deque[Any] = deque([data])
        seen: set[int] = set()
        strings: List[str] = []

        while queue:
            current = queue.popleft()

            if isinstance(current, str):
                stripped = current.strip()
                if stripped:
                    parsed = self._maybe_parse_json(current)
                    if parsed is not current:
                        queue.append(parsed)
                    else:
                        strings.append(stripped)
                continue

            current_id = id(current)
            if current_id in seen:
                continue
            seen.add(current_id)

            if isinstance(current, dict):
                queue.extend(current.values())
            elif isinstance(current, list):
                queue.extend(current)

        return strings

    def _first_non_empty_string(self, data: Any) -> str:
        strings = self._collect_strings(data)
        return strings[0] if strings else ""

    def _normalize_follow_up_collection(self, value: Any) -> List[str]:
        strings = self._collect_strings(value)
        follow_ups: List[str] = []

        for entry in strings:
            follow_ups.extend(self._split_follow_up_string(entry))

        unique: List[str] = []
        seen: set[str] = set()
        for item in follow_ups:
            if not item or item in seen:
                continue
            seen.add(item)
            unique.append(item)

        return unique

    @staticmethod
    def _split_follow_up_string(text: str) -> List[str]:
        lines = []
        for raw_line in text.splitlines():
            cleaned = raw_line.strip()
            if not cleaned:
                continue
            cleaned = re.sub(r"^\d+[\.\)\-:]*\s*", "", cleaned)
            cleaned = re.sub(r"^[\-\*\u2022]+\s*", "", cleaned)
            cleaned = cleaned.strip()
            if cleaned:
                lines.append(cleaned)
        if lines:
            return lines
        cleaned_text = text.strip()
        return [cleaned_text] if cleaned_text else []
