import re
import random
import json
import os
from typing import List, Dict, Optional
import httpx


def _build_prompt(content: str, question_count: int, question_types: List[str],
                  difficulty: Optional[int], topics: List[str] = None) -> str:
    """Build the prompt that makes any content into a quiz."""

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

    if len(content) > 15000:
        content_to_send = content[:10000] + "\n\n[...middle sections omitted...]\n\n" + content[-5000:]
    else:
        content_to_send = content

    return f"""You are an expert teacher who has just finished reading the study material below.
Your job: create {question_count} quiz questions that test whether a student actually
UNDERSTANDS this material — not just whether they can ctrl+F for answers.

QUESTION TYPES TO GENERATE (distribute as evenly as possible):
{chr(10).join(f'  - {t}' for t in types_desc)}
{difficulty_text}{topics_text}

RULES:
1. READ THE CONTENT CAREFULLY. Understand what it teaches before writing questions.
2. Every question must be answerable from the material AND test real understanding.
3. For MATH/SCIENCE: ask about concepts, test common misconceptions, ask when/why to use methods.
4. For LITERATURE/HISTORY: ask about themes, motivations, cause-effect, significance.
5. For ANY content: never copy a sentence verbatim and blank out a word, MCQ wrong answers must be plausible,
   true/false must test real misconceptions, fill-blank answers must be 1-3 words, cover different topics.
6. NEVER generate a question where the answer is obvious from the question text itself.

STUDY MATERIAL:
{content_to_send}

OUTPUT FORMAT:
Return ONLY a valid JSON array. Each element:
{{
  "type": "mcq" | "true_false" | "fill_blank",
  "question": "the question text",
  "options": ["A) ...", "B) ...", "C) ...", "D) ..."] or ["True", "False"] or [],
  "correct_answer": "the full correct option text" or "True"/"False" or "short answer",
  "explanation": "brief explanation of why this is correct",
  "topic": "which topic/section this covers",
  "difficulty": 1-5
}}

Generate exactly {question_count} questions now:"""


# ai providers

def _try_groq(prompt: str) -> Optional[List[Dict]]:
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
            print(f"[QUIZ-AI] Groq generated {len(result)} questions")
        return result
    except Exception as e:
        print(f"[QUIZ-AI] Groq failed: {e}")
        return None


def _try_anthropic(prompt: str) -> Optional[List[Dict]]:
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
            print(f"[QUIZ-AI] Anthropic generated {len(result)} questions")
        return result
    except Exception as e:
        print(f"[QUIZ-AI] Anthropic failed: {e}")
        return None


def _try_openai(prompt: str) -> Optional[List[Dict]]:
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
            print(f"[QUIZ-AI] OpenAI generated {len(result)} questions")
        return result
    except Exception as e:
        print(f"[QUIZ-AI] OpenAI failed: {e}")
        return None


def _try_google(prompt: str) -> Optional[List[Dict]]:
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
            print(f"[QUIZ-AI] Google generated {len(result)} questions")
        return result
    except Exception as e:
        print(f"[QUIZ-AI] Google failed: {e}")
        return None


def _parse_json_response(text: str) -> Optional[List[Dict]]:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        questions = json.loads(text)
        if isinstance(questions, list) and len(questions) > 0:
            return questions
    except json.JSONDecodeError:
        match = re.search(r"\[[\s\S]*\]", text)
        if match:
            try:
                questions = json.loads(match.group())
                if isinstance(questions, list) and len(questions) > 0:
                    return questions
            except json.JSONDecodeError:
                pass
    return None


# main entry point

def generate_questions(
    content: str,
    question_count: int = 10,
    question_types: List[str] = None,
    difficulty: Optional[int] = None,
    topics: List[str] = None,
) -> tuple[List[Dict], str]:
    """
    Generate quiz questions from any content using AI.
    Tries providers in order: Groq (free) -> Anthropic -> OpenAI -> Google.
    Returns (questions, source).
    """
    if question_types is None:
        question_types = ["mcq", "true_false", "fill_blank"]

    prompt = _build_prompt(content, question_count, question_types, difficulty, topics)

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
        print("  NO AI API KEY FOUND — Quiz generator needs one to work!")
        print("")
        print("EASIEST (free): Get a Groq API key:")
        print("  1. Go to console.groq.com and sign up (free)")
        print("  2. Create an API key")
        print("  3. Run your backend with:")
        print('     GROQ_API_KEY="gsk_your_key_here" uvicorn app.main:app --reload')
        print("")
        print("Other options:")
        print("  ANTHROPIC_API_KEY (Claude)")
        print("  OPENAI_API_KEY   (GPT)")
        print("  GOOGLE_API_KEY   (Gemini — free tier)")
        print("=" * 60 + "\n")
        return [], "no_api_key"

    print(f"[QUIZ-AI] Available providers: {', '.join(available_keys)}")

    providers = [
        ("groq", _try_groq),
        ("anthropic", _try_anthropic),
        ("openai", _try_openai),
        ("google", _try_google),
    ]

    for name, try_fn in providers:
        result = try_fn(prompt)
        if result and len(result) >= question_count // 2:
            cleaned = _validate_questions(result, question_types)
            if cleaned:
                for i, q in enumerate(cleaned):
                    q["order_index"] = i
                return cleaned[:question_count], f"ai_{name}"

    print("[QUIZ-AI] All providers failed to generate valid questions")
    return [], "ai_failed"


def _validate_questions(questions: List[Dict], expected_types: List[str]) -> List[Dict]:
    valid = []
    for q in questions:
        if not all(k in q for k in ("type", "question", "correct_answer")):
            continue

        q_type = q["type"].lower().strip()
        if q_type in ("multiple_choice", "multiple choice", "mc"):
            q_type = "mcq"
        elif q_type in ("tf", "truefalse", "true/false"):
            q_type = "true_false"
        elif q_type in ("fill_in_the_blank", "fill_in_blank", "fill-blank", "fill blank", "fitb"):
            q_type = "fill_blank"
        q["type"] = q_type

        if "options" not in q:
            if q_type == "mcq":
                continue
            elif q_type == "true_false":
                q["options"] = ["True", "False"]
            else:
                q["options"] = []

        if "explanation" not in q:
            q["explanation"] = ""
        if "topic" not in q:
            q["topic"] = ""

        try:
            q["difficulty"] = int(q.get("difficulty", 3))
        except (ValueError, TypeError):
            q["difficulty"] = 3

        valid.append(q)

    return valid
