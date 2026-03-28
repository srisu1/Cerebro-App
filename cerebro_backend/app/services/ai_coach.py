"""
CEREBRO — AI Study Coach

Takes a structured snapshot of a user's study analytics and asks an LLM to
synthesize a narrative "coach briefing" the app can render on the analytics
page. The response includes:
    • headline   — one-sentence mood read of where the user is right now
    • narrative  — a 2-3 sentence story-style summary
    • strengths  — concrete wins ("You're averaging 82% on Database quizzes")
    • focus      — 2-4 behavioral observations (focus/time-of-day/cadence)
    • next_moves — 3 ranked next-actions the user should take this week

Design mirrors topic_extractor.py:
    • Non-fatal: no AI key → heuristic fallback so the Coach tab still renders.
    • Provider fallback: Groq → Anthropic → OpenAI.
    • Strict JSON output, tolerant to fences / trailing commentary.
"""

from __future__ import annotations

import json
import os
import re
from typing import Any, Dict, List, Optional

import httpx


def _build_prompt(snapshot: Dict[str, Any]) -> str:
    """Compact the analytics snapshot into a prompt the LLM can reason over."""
    return f"""You are an encouraging, specific study coach briefing a student.

Given their study stats below, write a JSON object with these keys EXACTLY:
{{
  "headline": "One sentence (max 14 words) reading their current state — warm, honest, specific.",
  "narrative": "2-3 sentences that tell the story of what's been happening. Reference real numbers from the snapshot.",
  "strengths": ["2-4 concrete wins, each a short phrase with a number or subject name"],
  "focus": ["2-4 behavioral observations about focus, time-of-day, cadence, or consistency"],
  "next_moves": [
    {{"title": "imperative verb-first title (e.g., 'Review 2NF before Thursday')", "why": "one short sentence tying it to data", "minutes": 30}},
    ... (exactly 3 moves, sorted most urgent first)
  ],
  "mood": "one of: on_fire, steady, drifting, rebuilding"
}}

RULES:
- Reference real subjects and topics from the snapshot — no generic advice.
- If a field is empty (e.g., no quizzes yet), say that directly.
- Tone: warm, concrete, zero fluff. No emojis.
- All strings must be plain text (no markdown).
- `minutes` integer between 15-90.
- Return ONLY the JSON object.

SNAPSHOT:
{json.dumps(snapshot, indent=2)}
"""



def _call_groq(prompt: str) -> Optional[str]:
    key = os.environ.get("GROQ_API_KEY")
    if not key:
        return None
    r = httpx.post(
        "https://api.groq.com/openai/v1/chat/completions",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        json={
            "model": "llama-3.3-70b-versatile",
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 900,
            "temperature": 0.4,
            "response_format": {"type": "json_object"},
        },
        timeout=30.0,
    )
    r.raise_for_status()
    return r.json()["choices"][0]["message"]["content"]


def _call_anthropic(prompt: str) -> Optional[str]:
    key = os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        return None
    r = httpx.post(
        "https://api.anthropic.com/v1/messages",
        headers={
            "x-api-key": key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        },
        json={
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 900,
            "messages": [{"role": "user", "content": prompt}],
        },
        timeout=30.0,
    )
    r.raise_for_status()
    return r.json()["content"][0]["text"]


def _call_openai(prompt: str) -> Optional[str]:
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        return None
    r = httpx.post(
        "https://api.openai.com/v1/chat/completions",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        json={
            "model": "gpt-4o-mini",
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 900,
            "temperature": 0.4,
            "response_format": {"type": "json_object"},
        },
        timeout=30.0,
    )
    r.raise_for_status()
    return r.json()["choices"][0]["message"]["content"]


def _parse_json(raw: str) -> Optional[Dict[str, Any]]:
    s = raw.strip()
    if s.startswith("```"):
        s = re.sub(r"^```(?:json)?\s*", "", s)
        s = re.sub(r"\s*```$", "", s)
    try:
        data = json.loads(s)
    except json.JSONDecodeError:
        m = re.search(r"\{[\s\S]*\}", s)
        if not m:
            return None
        try:
            data = json.loads(m.group())
        except json.JSONDecodeError:
            return None
    return data if isinstance(data, dict) else None


def _validate(obj: Dict[str, Any]) -> Dict[str, Any]:
    """Normalise the AI output into a predictable shape the UI can trust."""
    headline = str(obj.get("headline", "")).strip()
    narrative = str(obj.get("narrative", "")).strip()

    strengths = obj.get("strengths") or []
    if not isinstance(strengths, list):
        strengths = []
    strengths = [str(s).strip() for s in strengths if str(s).strip()][:4]

    focus = obj.get("focus") or []
    if not isinstance(focus, list):
        focus = []
    focus = [str(f).strip() for f in focus if str(f).strip()][:4]

    moves_raw = obj.get("next_moves") or []
    if not isinstance(moves_raw, list):
        moves_raw = []
    moves: List[Dict[str, Any]] = []
    for m in moves_raw[:3]:
        if not isinstance(m, dict):
            continue
        title = str(m.get("title", "")).strip()
        if not title:
            continue
        why = str(m.get("why", "")).strip()
        try:
            minutes = int(m.get("minutes", 30))
        except (TypeError, ValueError):
            minutes = 30
        minutes = max(15, min(90, minutes))
        moves.append({"title": title, "why": why, "minutes": minutes})

    mood = str(obj.get("mood", "steady")).strip().lower()
    if mood not in {"on_fire", "steady", "drifting", "rebuilding"}:
        mood = "steady"

    return {
        "headline": headline,
        "narrative": narrative,
        "strengths": strengths,
        "focus": focus,
        "next_moves": moves,
        "mood": mood,
    }



def _heuristic_coach(snapshot: Dict[str, Any]) -> Dict[str, Any]:
    """Rule-based briefing used when no AI provider is reachable.

    Doesn't pretend to be insightful — it reads the numbers, picks obvious
    signals, and composes a human-ish blurb so the Coach tab still has
    something honest to show.
    """
    preds = snapshot.get("predictions") or {}
    readiness = float(preds.get("exam_readiness") or 0)
    streak = int(snapshot.get("streak_days") or 0)
    momentum = float(snapshot.get("momentum_minutes_delta") or 0)
    weekly_mins = preds.get("weekly_minutes") or []
    total_week = sum(weekly_mins) if isinstance(weekly_mins, list) else 0

    strengths: List[str] = []
    focus: List[str] = []
    moves: List[Dict[str, Any]] = []

    # Strengths signal
    if readiness >= 75:
        strengths.append(f"Exam readiness at {int(readiness)}% — you're ahead of pace.")
    if streak >= 3:
        strengths.append(f"{streak}-day study streak holding steady.")
    top_subjects = snapshot.get("top_subjects") or []
    for s in top_subjects[:2]:
        name = s.get("name", "")
        prof = int(s.get("proficiency", 0))
        if name and prof >= 60:
            strengths.append(f"{name} proficiency at {prof}%.")

    # Focus / cadence signal
    if total_week < 60:
        focus.append(f"Only {int(total_week)} min logged this week — the week is light.")
    elif total_week > 300:
        focus.append(f"You clocked {int(total_week)} min this week — strong output.")

    best_hour = snapshot.get("best_study_hour")
    if isinstance(best_hour, int):
        h = best_hour
        suffix = "am" if h < 12 else "pm"
        h12 = h if 1 <= h <= 12 else (h - 12 if h > 12 else 12)
        focus.append(f"You focus best around {h12}{suffix}.")

    if momentum > 20:
        focus.append(f"You're up {int(momentum)} min vs last week.")
    elif momentum < -20:
        focus.append(f"You're down {int(abs(momentum))} min vs last week.")

    # Next moves — pull from schedule recommendations
    recs = snapshot.get("top_recommendations") or []
    for r in recs[:3]:
        topic = r.get("topic", "")
        subject = r.get("subject_name", "")
        mins = int(r.get("recommended_mins") or 45)
        title = f"Review {topic}" if topic else "Review weakest topic"
        if subject and topic:
            title = f"Drill {topic} ({subject})"
        why = r.get("reason") or "Flagged as a knowledge gap."
        moves.append({"title": title, "why": why, "minutes": mins})

    while len(moves) < 3:
        # Filler when we don't have 3 real recs.
        if not moves:
            moves.append({
                "title": "Log one 25-min focus session today",
                "why": "Build the daily habit before chasing scores.",
                "minutes": 25,
            })
        elif len(moves) == 1:
            moves.append({
                "title": "Run a 10-card flashcard review",
                "why": "Short spaced review compounds fastest.",
                "minutes": 15,
            })
        else:
            moves.append({
                "title": "Schedule one quiz this week",
                "why": "Quizzes are the strongest readiness signal.",
                "minutes": 30,
            })

    # Headline + narrative + mood
    if readiness >= 80:
        mood = "on_fire"
        headline = f"You're at {int(readiness)}% exam-ready — keep the ship steady."
    elif readiness >= 60:
        mood = "steady"
        headline = f"Solid footing at {int(readiness)}% — small sharpening moves next."
    elif readiness >= 35:
        mood = "rebuilding"
        headline = f"You're at {int(readiness)}% — momentum beats intensity right now."
    else:
        mood = "drifting"
        headline = "Light data so far — a couple of logged sessions will unlock real insights."

    weak = len(snapshot.get("gaps") or [])
    narrative = (
        f"You've put in {int(total_week)} minutes this week with {weak} weak topics flagged. "
    )
    if top_subjects:
        narrative += f"Your strongest signal is {top_subjects[0].get('name', 'your top subject')}. "
    narrative += "The next moves below focus on the fastest wins."

    if not strengths:
        strengths = ["Data is still building — this read improves with every session."]
    if not focus:
        focus = ["Not enough sessions yet to detect cadence patterns."]

    return {
        "headline": headline,
        "narrative": narrative.strip(),
        "strengths": strengths[:4],
        "focus": focus[:4],
        "next_moves": moves[:3],
        "mood": mood,
    }



def generate_coach_briefing(snapshot: Dict[str, Any]) -> Dict[str, Any]:
    """Return a coach briefing dict. Always returns — falls back to heuristic."""
    prompt = _build_prompt(snapshot)
    raw: Optional[str] = None
    used: Optional[str] = None
    for provider, call in (
        ("Groq", _call_groq),
        ("Anthropic", _call_anthropic),
        ("OpenAI", _call_openai),
    ):
        try:
            raw = call(prompt)
            if raw:
                used = provider
                print(f"[AI-COACH] {provider} succeeded")
                break
        except Exception as e:  # noqa: BLE001
            print(f"[AI-COACH] {provider} failed: {e}")

    if raw:
        parsed = _parse_json(raw)
        if parsed:
            out = _validate(parsed)
            out["source"] = used or "ai"
            return out
        print("[AI-COACH] AI returned unparseable JSON — falling back to heuristic")

    out = _heuristic_coach(snapshot)
    out["source"] = "heuristic"
    return out
