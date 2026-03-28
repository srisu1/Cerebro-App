"""
CEREBRO — AI Topic Extractor

Given raw study-material content, return a small list of fine-grained
topic names that represent the material's key concepts. Used by the
material upload / create endpoints so the Subject → Topics tab
self-populates instead of forcing the user into manual CRUD.

Design goals:
  • Non-fatal — if no AI key is configured or the request fails, we
    return an empty list and let the material save anyway. Topic
    extraction is a "nice to have" at upload time.
  • Scoped to the subject — returns deduped, normalized names the
    caller merges into the existing subject topic graph via
    `resolve_topics_from_names`. We don't talk to the DB here.
  • Provider fallback mirrors `quiz_generator.py` / flashcard gen:
    Groq → Anthropic → OpenAI. Pick whichever key is set.

Tuning:
  • Target 6–12 names. Shorter material → fewer; longer → more.
  • Names are 1–4 words, Title Case. No duplicates, no generic fluff
    like "Introduction" / "Summary" / "Chapter N".
"""

from __future__ import annotations

import json
import os
import re
from typing import List

import httpx


_MAX_CHARS_FOR_PROMPT = 12_000  # truncate very long uploads, keep both ends
_MIN_TOPICS = 3
_MAX_TOPICS = 12

# Generic low-signal names we never want to surface as topics.
_BLOCKLIST = {
    "introduction", "conclusion", "summary", "overview",
    "references", "bibliography", "appendix", "abstract",
    "preface", "foreword", "table of contents", "notes",
    "untitled", "chapter", "section", "unit",
}


def _build_prompt(content: str, existing_names: List[str]) -> str:
    existing_block = ""
    if existing_names:
        bullet = "\n".join(f"  - {n}" for n in existing_names[:40])
        existing_block = (
            "\n\nEXISTING TOPICS UNDER THIS SUBJECT — reuse these names "
            "exactly when the material covers them (case-sensitive match), "
            "so they dedupe cleanly:\n" + bullet + "\n"
        )

    return f"""You are a study-skills assistant extracting topics from a student's notes.

Read the material below and output a JSON array of {_MIN_TOPICS}-{_MAX_TOPICS}
fine-grained topic names that best describe what this material teaches.

RULES:
1. Each topic is a concrete concept, technique, theorem, or named
   entity — something a student would actually study ("Bellman-Ford
   Algorithm", "Functional Dependencies", "Photosynthesis Light
   Reactions"). NOT vague sections ("Introduction", "Chapter 3").
2. 1-4 words. Title Case. No trailing punctuation.
3. No duplicates. No near-duplicates (pick the better of two similar
   names).
4. Prefer fine-grained over broad — "Second Normal Form" beats
   "Normalization" when the material discusses 2NF specifically.
5. {_MIN_TOPICS}-{_MAX_TOPICS} names total. Shorter material → fewer.{existing_block}

MATERIAL:
{content}

Return ONLY a JSON array of strings, nothing else. Example:
["First Normal Form", "Partial Dependency", "Transitive Dependency"]"""


def _truncate_content(content: str) -> str:
    """Keep beginning + end of long content so we catch intro + summary."""
    if len(content) <= _MAX_CHARS_FOR_PROMPT:
        return content
    head = _MAX_CHARS_FOR_PROMPT * 2 // 3
    tail = _MAX_CHARS_FOR_PROMPT - head - 40
    return content[:head] + "\n\n[... middle truncated ...]\n\n" + content[-tail:]



def _call_groq(prompt: str) -> str | None:
    key = os.environ.get("GROQ_API_KEY")
    if not key:
        return None
    r = httpx.post(
        "https://api.groq.com/openai/v1/chat/completions",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        json={
            "model": "llama-3.3-70b-versatile",
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 512, "temperature": 0.2,
        },
        timeout=30.0,
    )
    r.raise_for_status()
    return r.json()["choices"][0]["message"]["content"]


def _call_anthropic(prompt: str) -> str | None:
    key = os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        return None
    r = httpx.post(
        "https://api.anthropic.com/v1/messages",
        headers={
            "x-api-key": key, "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        },
        json={
            "model": "claude-sonnet-4-20250514", "max_tokens": 512,
            "messages": [{"role": "user", "content": prompt}],
        },
        timeout=30.0,
    )
    r.raise_for_status()
    return r.json()["content"][0]["text"]


def _call_openai(prompt: str) -> str | None:
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        return None
    r = httpx.post(
        "https://api.openai.com/v1/chat/completions",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        json={
            "model": "gpt-4o-mini",
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 512, "temperature": 0.2,
        },
        timeout=30.0,
    )
    r.raise_for_status()
    return r.json()["choices"][0]["message"]["content"]


def _parse_names(raw: str) -> List[str]:
    """Tolerant JSON-array parse. Accepts fences and trailing commentary."""
    s = raw.strip()
    if s.startswith("```"):
        s = re.sub(r"^```(?:json)?\s*", "", s)
        s = re.sub(r"\s*```$", "", s)
    try:
        data = json.loads(s)
    except json.JSONDecodeError:
        m = re.search(r"\[[\s\S]*\]", s)
        if not m:
            return []
        try:
            data = json.loads(m.group())
        except json.JSONDecodeError:
            return []
    if not isinstance(data, list):
        return []
    return [str(x).strip() for x in data if isinstance(x, (str, int))]


def _clean(names: List[str]) -> List[str]:
    """Normalize + dedupe + drop blocklist + enforce min/max bounds."""
    seen: dict[str, str] = {}  # lowercased -> original
    for n in names:
        n = re.sub(r"\s+", " ", n.strip(" \t\r\n-*•·"))
        # Strip trailing punctuation / numbering.
        n = re.sub(r"^\d+[\.\)]\s*", "", n)
        n = re.sub(r"[:\.!?,;]+$", "", n)
        if not n or len(n) > 60:
            continue
        low = n.lower()
        if low in _BLOCKLIST:
            continue
        # Skip pure-numeric or single-char junk.
        if len(low) < 2 or low.isdigit():
            continue
        # Skip anything that looks like a sentence rather than a topic.
        if len(n.split()) > 5:
            continue
        seen.setdefault(low, n)
    return list(seen.values())[:_MAX_TOPICS]



def extract_topics(
    content: str,
    existing_names: List[str] | None = None,
) -> List[str]:
    """Return up to `_MAX_TOPICS` topic names for `content`.

    Safe to call without any AI key set — returns `[]` in that case so
    the caller can still persist the material. Never raises; network
    errors and bad AI output both degrade to an empty list, which
    `resolve_topics_from_names` then treats as a no-op.
    """
    if not content or len(content.strip()) < 80:
        return []  # too short to extract anything useful

    prompt = _build_prompt(_truncate_content(content), existing_names or [])

    raw: str | None = None
    for provider, call in (("Groq", _call_groq),
                           ("Anthropic", _call_anthropic),
                           ("OpenAI", _call_openai)):
        try:
            raw = call(prompt)
            if raw:
                print(f"[TOPIC-EXTRACT] {provider} succeeded "
                      f"(content={len(content)} chars)")
                break
        except Exception as e:  # noqa: BLE001
            print(f"[TOPIC-EXTRACT] {provider} failed: {e}")

    if not raw:
        print("[TOPIC-EXTRACT] no AI key available — returning [] "
              "(material saved without auto-topics)")
        return []

    names = _clean(_parse_names(raw))
    print(f"[TOPIC-EXTRACT] extracted {len(names)} topics: {names}")
    if len(names) < _MIN_TOPICS:
        # Nothing useful came back; treat as a soft failure so the
        # caller doesn't pollute the subject with a single weak topic.
        return names if len(names) >= 1 else []
    return names
