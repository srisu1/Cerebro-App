"""
CEREBRO — Smart Quiz Generator v5 (AI-First)

This generator READS and UNDERSTANDS your content using AI — no matter what
subject it is: math, science, history, literature, languages, anything.

Priority order for AI providers:
  1. Groq    (FREE — llama-3.3-70b, sign up at console.groq.com)
  2. Anthropic (Claude — paid, best quality)
  3. OpenAI   (GPT — paid)
  4. Google   (Gemini — free tier available)

Set ONE of these env vars: GROQ_API_KEY, ANTHROPIC_API_KEY, OPENAI_API_KEY, GOOGLE_API_KEY
"""

import re
import random
import json
import os
from typing import List, Dict, Optional
import httpx


#  THE PROMPT — one universal prompt for ANY subject

def _build_prompt(content: str, question_count: int, question_types: List[str],
                  difficulty: Optional[int], topics: List[str] = None,
                  context: Optional[Dict] = None) -> str:
    """Build THE prompt that makes any content into a great quiz.

    context (optional) — carries student metadata used to tune tone & depth:
      • subject_name      (e.g. "Calculus I")
      • subject_code      (e.g. "MATH101")
      • institution_type  (school, sixth_form, college, university)
      • degree_level      (undergraduate, masters, phd)
      • course            (e.g. "Computer Science BSc")
      • affiliation       (e.g. "Affiliated with London Met University")
      • year_of_study     (int)
      • study_goals       (list of strings)
    """

    types_map = {
        "mcq": "Multiple Choice (exactly 4 options labeled A) B) C) D), one correct)",
        "true_false": "True/False (statement that is either true or false)",
        "fill_blank": 'Fill in the Blank (sentence with ___ where the key answer goes, answer should be 1-3 words)',
    }
    types_desc = [types_map[t] for t in question_types if t in types_map]

    difficulty_text = ""
    if difficulty:
        levels = {1: "very easy (basic recall)", 2: "easy", 3: "medium (understanding)",
                  4: "hard (application/analysis)", 5: "very hard (synthesis/evaluation)"}
        difficulty_text = f"\nTarget difficulty: {levels.get(difficulty, 'medium')}"

    topics_text = ""
    if topics and len(topics) > 0:
        topics_text = f"\nFocus especially on: {', '.join(topics[:5])}"

    # Compose a concise "STUDENT CONTEXT" block that the AI uses to calibrate
    # terminology, question depth, and tone. All fields are optional.
    ctx_lines: List[str] = []
    if context:
        sn = str(context.get("subject_name") or "").strip()
        sc = str(context.get("subject_code") or "").strip()
        if sn and sc:
            ctx_lines.append(f"• Subject: {sn} ({sc})")
        elif sn:
            ctx_lines.append(f"• Subject: {sn}")
        elif sc:
            ctx_lines.append(f"• Subject code: {sc}")

        crs = str(context.get("course") or "").strip()
        if crs:
            ctx_lines.append(f"• Course / programme: {crs}")

        deg = str(context.get("degree_level") or "").strip().lower()
        itype = str(context.get("institution_type") or "").strip().lower()
        yr = context.get("year_of_study")
        level_bits = []
        if deg in {"undergraduate", "masters", "phd"}:
            nice = {"undergraduate": "Undergraduate",
                    "masters": "Masters",
                    "phd": "PhD / Doctorate"}[deg]
            level_bits.append(nice)
        elif itype in {"school", "sixth_form", "college", "university"}:
            level_bits.append({"school": "School",
                               "sixth_form": "Sixth Form",
                               "college": "College",
                               "university": "University"}[itype])
        if isinstance(yr, int) and yr > 0:
            level_bits.append(f"Year {yr}")
        if level_bits:
            ctx_lines.append(f"• Academic level: {' · '.join(level_bits)}")

        aff = str(context.get("affiliation") or "").strip()
        if aff:
            ctx_lines.append(f"• Institution: {aff}")

        goals = context.get("study_goals") or []
        if isinstance(goals, (list, tuple)) and goals:
            ctx_lines.append(f"• Study goals: {', '.join(str(g) for g in goals[:4])}")

    student_context_text = ""
    if ctx_lines:
        student_context_text = (
            "\n\n═══ STUDENT CONTEXT — tune depth, terminology, and tone ═══\n"
            + "\n".join(ctx_lines)
            + "\n"
            "Use this context to calibrate difficulty (e.g. a Masters student "
            "should get analysis/synthesis questions, not just recall), and to "
            "frame questions with the right terminology for their subject and "
            "programme."
        )

    # Truncate content smartly — keep beginning and end (table of contents + actual content)
    if len(content) > 15000:
        content_to_send = content[:10000] + "\n\n[...middle sections omitted...]\n\n" + content[-5000:]
    else:
        content_to_send = content

    return f"""You are an expert teacher who has just finished reading the study material below.
Your job: create {question_count} quiz questions that test whether a student actually
UNDERSTANDS this material — not just whether they can ctrl+F for answers.

QUESTION TYPES TO GENERATE (distribute as evenly as possible):
{chr(10).join(f'  • {t}' for t in types_desc)}
{difficulty_text}{topics_text}{student_context_text}

═══ RULES (follow these EXACTLY) ═══

1. READ THE CONTENT CAREFULLY. Understand what it teaches before writing questions.
2. Every question must be answerable from the material AND test real understanding.
3. For MATH/SCIENCE content:
   - Ask about concepts, not just computation (e.g., "Why do we flip the inequality when multiplying by a negative?" not "Solve 3x > 9")
   - Test common misconceptions (e.g., "True or False: (a+b)² = a² + b²" → False)
   - Ask when/why to use methods, not just how
   - Fill-blanks should test key terminology (e.g., "The ___ tells us how many real solutions a quadratic has" → discriminant)
4. For LITERATURE/HISTORY content:
   - Ask about themes, motivations, cause-effect, significance — not trivia
   - "Why did X happen?" is better than "When did X happen?"
5. For ANY content:
   - NEVER copy a sentence verbatim and blank out a word — that's lazy and useless
   - MCQ wrong answers must be PLAUSIBLE — things a confused student would pick
   - True/False must test real misconceptions, not obvious statements
   - Fill-blank answers must be 1-3 words maximum, testing key terms
   - Questions should make sense without seeing the original material
   - Cover DIFFERENT topics/sections from the material, don't repeat the same area
6. NEVER generate a question where the answer is obvious from the question text itself

═══ STUDY MATERIAL ═══
{content_to_send}

═══ OUTPUT FORMAT ═══
Return ONLY a valid JSON array, no other text. Each element:
{{
  "type": "mcq" | "true_false" | "fill_blank",
  "question": "the question text",
  "options": ["A) ...", "B) ...", "C) ...", "D) ..."] or ["True", "False"] or [],
  "correct_answer": "the full correct option text (e.g. 'B) answer')" or "True"/"False" or "short answer",
  "explanation": "brief explanation of why this is correct",
  "topic": "which topic/section this covers",
  "difficulty": 1-5
}}

Generate exactly {question_count} questions now:"""


#  AI PROVIDERS

def _try_groq(prompt: str) -> Optional[List[Dict]]:
    """Groq — FREE tier, llama-3.3-70b, very fast."""
    api_key = os.environ.get("GROQ_API_KEY")
    if not api_key:
        return None
    try:
        print("[QUIZ-AI] Trying Groq (llama-3.3-70b)...")
        resp = httpx.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": "llama-3.3-70b-versatile",
                "messages": [{"role": "user", "content": prompt}],
                "max_tokens": 4096,
                "temperature": 0.7,
            },
            timeout=60.0,
        )
        resp.raise_for_status()
        text = resp.json()["choices"][0]["message"]["content"]
        result = _parse_json_response(text)
        if result:
            print(f"[QUIZ-AI] Groq generated {len(result)} questions ✓")
        return result
    except Exception as e:
        print(f"[QUIZ-AI] Groq failed: {e}")
        return None


def _try_anthropic(prompt: str) -> Optional[List[Dict]]:
    """Anthropic Claude — paid, highest quality."""
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        return None
    try:
        print("[QUIZ-AI] Trying Anthropic (Claude)...")
        resp = httpx.post(
            "https://api.anthropic.com/v1/messages",
            headers={
                "x-api-key": api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            json={
                "model": "claude-sonnet-4-20250514",
                "max_tokens": 4096,
                "messages": [{"role": "user", "content": prompt}],
            },
            timeout=60.0,
        )
        resp.raise_for_status()
        text = resp.json()["content"][0]["text"]
        result = _parse_json_response(text)
        if result:
            print(f"[QUIZ-AI] Anthropic generated {len(result)} questions ✓")
        return result
    except Exception as e:
        print(f"[QUIZ-AI] Anthropic failed: {e}")
        return None


def _try_openai(prompt: str) -> Optional[List[Dict]]:
    """OpenAI GPT — paid."""
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        return None
    try:
        print("[QUIZ-AI] Trying OpenAI (GPT-4o-mini)...")
        resp = httpx.post(
            "https://api.openai.com/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": "gpt-4o-mini",
                "messages": [{"role": "user", "content": prompt}],
                "max_tokens": 4096,
                "temperature": 0.7,
            },
            timeout=60.0,
        )
        resp.raise_for_status()
        text = resp.json()["choices"][0]["message"]["content"]
        result = _parse_json_response(text)
        if result:
            print(f"[QUIZ-AI] OpenAI generated {len(result)} questions ✓")
        return result
    except Exception as e:
        print(f"[QUIZ-AI] OpenAI failed: {e}")
        return None


def _try_google(prompt: str) -> Optional[List[Dict]]:
    """Google Gemini — free tier available."""
    api_key = os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        return None
    try:
        print("[QUIZ-AI] Trying Google (Gemini)...")
        resp = httpx.post(
            f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={api_key}",
            headers={"Content-Type": "application/json"},
            json={
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"maxOutputTokens": 4096, "temperature": 0.7},
            },
            timeout=60.0,
        )
        resp.raise_for_status()
        text = resp.json()["candidates"][0]["content"]["parts"][0]["text"]
        result = _parse_json_response(text)
        if result:
            print(f"[QUIZ-AI] Google generated {len(result)} questions ✓")
        return result
    except Exception as e:
        print(f"[QUIZ-AI] Google failed: {e}")
        return None


def _parse_json_response(text: str) -> Optional[List[Dict]]:
    """Parse JSON from AI response, handling markdown code blocks."""
    text = text.strip()
    # Strip markdown code fences
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        questions = json.loads(text)
        if isinstance(questions, list) and len(questions) > 0:
            return questions
    except json.JSONDecodeError:
        # Try to find a JSON array in the response
        match = re.search(r"\[[\s\S]*\]", text)
        if match:
            try:
                questions = json.loads(match.group())
                if isinstance(questions, list) and len(questions) > 0:
                    return questions
            except json.JSONDecodeError:
                pass
    return None


#  MAIN ENTRY POINT

def generate_questions(
    content: str,
    question_count: int = 10,
    question_types: List[str] = None,
    difficulty: Optional[int] = None,
    topics: List[str] = None,
    context: Optional[Dict] = None,
) -> tuple[List[Dict], str]:
    """
    Generate quiz questions from ANY content using AI.

    Tries providers in order: Groq (free) → Anthropic → OpenAI → Google.
    Returns (questions, source).

    `context` carries optional student metadata (subject_name, subject_code,
    degree_level, institution_type, course, affiliation, study_goals,
    year_of_study) used to tune depth, terminology, and tone.
    """
    if question_types is None:
        question_types = ["mcq", "true_false", "fill_blank"]

    # Build the prompt
    prompt = _build_prompt(content, question_count, question_types, difficulty,
                           topics, context=context)

    # Check which API keys are available
    available_keys = []
    if os.environ.get("GROQ_API_KEY"):
        available_keys.append("GROQ")
    if os.environ.get("ANTHROPIC_API_KEY"):
        available_keys.append("ANTHROPIC")
    if os.environ.get("OPENAI_API_KEY"):
        available_keys.append("OPENAI")
    if os.environ.get("GOOGLE_API_KEY"):
        available_keys.append("GOOGLE")

    if not available_keys:
        print("\n" + "=" * 60)
        print("⚠️  NO AI API KEY FOUND — Quiz generator needs one to work!")
        print("")
        print("EASIEST (free): Get a Groq API key:")
        print("  1. Go to console.groq.com and sign up (free)")
        print("  2. Create an API key")
        print("  3. Run your backend with:")
        print('     GROQ_API_KEY="gsk_your_key_here" uvicorn app.main:app --reload')
        print("")
        print("Other options (also work):")
        print("  • ANTHROPIC_API_KEY (Claude — paid)")
        print("  • OPENAI_API_KEY   (GPT — paid)")
        print("  • GOOGLE_API_KEY   (Gemini — free tier)")
        print("=" * 60 + "\n")
        return [], "no_api_key"

    print(f"[QUIZ-AI] Available providers: {', '.join(available_keys)}")

    # Try each provider in priority order
    providers = [
        ("groq", _try_groq),
        ("anthropic", _try_anthropic),
        ("openai", _try_openai),
        ("google", _try_google),
    ]

    for name, try_fn in providers:
        result = try_fn(prompt)
        if result and len(result) >= question_count // 2:
            # Validate and clean up the questions
            cleaned = _validate_questions(result, question_types)
            if cleaned:
                # Add order indices
                for i, q in enumerate(cleaned):
                    q["order_index"] = i
                return cleaned[:question_count], f"ai_{name}"

    print("[QUIZ-AI] All providers failed to generate valid questions")
    return [], "ai_failed"


def _validate_questions(questions: List[Dict], expected_types: List[str]) -> List[Dict]:
    """Validate and clean AI-generated questions."""
    valid = []
    for q in questions:
        # Must have required fields
        if not all(k in q for k in ("type", "question", "correct_answer")):
            continue

        # Normalize type
        q_type = q["type"].lower().strip()
        if q_type in ("multiple_choice", "multiple choice", "mc"):
            q_type = "mcq"
        elif q_type in ("tf", "truefalse", "true/false"):
            q_type = "true_false"
        elif q_type in ("fill_in_the_blank", "fill_in_blank", "fill-blank", "fill blank", "fitb"):
            q_type = "fill_blank"
        q["type"] = q_type

        # Ensure options exist
        if "options" not in q:
            if q_type == "mcq":
                continue  # MCQ needs options
            elif q_type == "true_false":
                q["options"] = ["True", "False"]
            else:
                q["options"] = []

        # Ensure explanation exists
        if "explanation" not in q:
            q["explanation"] = ""

        # Ensure topic exists
        if "topic" not in q:
            q["topic"] = ""

        # Ensure difficulty is an int
        try:
            q["difficulty"] = int(q.get("difficulty", 3))
        except (ValueError, TypeError):
            q["difficulty"] = 3

        valid.append(q)

    return valid
