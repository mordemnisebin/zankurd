from __future__ import annotations

import random
import re
import runpy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OFFLINE_BANK = ROOT / "lib" / "src" / "data" / "offline_question_bank.dart"
PURE_GENERATOR = ROOT / "tools" / "generate_pure_kurdish_questions.py"
TARGET_NEW_QUESTIONS = 2000
START_ID = 20000


def dart_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n") + "'"


def normalized(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().casefold())


def pick_three(pool: list[str], forbidden: str, salt: int) -> list[str]:
    choices = [item for item in pool if normalized(item) != normalized(forbidden)]
    if len(choices) < 3:
        raise ValueError("Not enough distractors")
    rng = random.Random(9127 + salt)
    return rng.sample(choices, 3)


def rotated_answers(correct: str, distractors: list[str], salt: int) -> list[str]:
    answers = [correct, *distractors]
    shift = salt % 4
    return answers[shift:] + answers[:shift]


def is_answer_leak(prompt: str, correct: str) -> bool:
    correct_norm = normalized(correct)
    return len(correct_norm) >= 6 and correct_norm in normalized(prompt)


def existing_prompts(content: str) -> set[str]:
    pattern = re.compile(r"prompt:\s*('(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\")", re.DOTALL)

    def unquote(token: str) -> str:
        text = token[1:-1]
        return text.replace("\\'", "'").replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")

    return {normalized(unquote(match.group(1))) for match in pattern.finditer(content)}


def next_id(existing_content: str) -> int:
    numbers = [
        int(match.group(1))
        for match in re.finditer(r"id:\s*'offline_curated_(\d+)'", existing_content)
    ]
    return max([START_ID - 1, *numbers]) + 1


def build_questions() -> list[dict[str, object]]:
    ns = runpy.run_path(str(PURE_GENERATOR))
    seeds_by_category: dict[str, list[dict[str, str]]] = ns["SEEDS"]
    questions: list[dict[str, object]] = []
    contexts = [
        "di asta destpêkê",
        "di asta navîn de",
        "di asta pêşketî de",
        "di gotûbêja dersê de",
        "di nirxandina xwendekaran de",
    ]

    for category, seeds in seeds_by_category.items():
        terms = [seed["term"] for seed in seeds]
        descriptions = [seed["desc"] for seed in seeds]
        for seed_index, seed in enumerate(seeds):
            term = seed["term"]
            desc = seed["desc"]
            for variant in range(25):
                salt = len(questions) + seed_index * 31 + variant
                difficulty = 1 + ((seed_index + variant) % 5)
                mode = variant % 5
                context = contexts[variant // 5]

                if mode == 0:
                    prompt = (
                        f"{context.capitalize()}, di qada {category.lower()} de têgeha '{term}' "
                        f"bi kîjan ravekirinê çêtir tê fêmkirin?"
                    )
                    correct = desc
                    answers = rotated_answers(correct, pick_three(descriptions, correct, salt), salt)
                    qtype = "multipleChoice"
                    explanation = f"Têgeha '{term}' di qada {category.lower()} de bi vê ravekirinê tê bikaranîn."
                elif mode == 1:
                    prompt = (
                        f"{context.capitalize()}, kîjan têgeh li qada {category.lower()} "
                        "bi vê ravekirinê tê nasîn: "
                        f"'{desc}'?"
                    )
                    correct = term
                    answers = rotated_answers(correct, pick_three(terms, correct, salt), salt)
                    qtype = "multipleChoice"
                    explanation = f"Ev ravekirin têgeha '{term}' nîşan dide."
                elif mode == 2:
                    prompt = (
                        f"{context.capitalize()}, di xwendina {category.lower()} de têgeha '{term}' "
                        "wekî mijareke bingehîn dikare were nirxandin."
                    )
                    correct = "Rast"
                    answers = ["Rast", "Şaş"]
                    qtype = "trueFalse"
                    explanation = f"'{term}' di vê kategoriyê de têgeheke giring e."
                elif mode == 3:
                    prompt = (
                        f"{context.capitalize()}, ravekirina '{desc}' "
                        f"bi tevahî ji qada {category.lower()} dûr e."
                    )
                    correct = "Şaş"
                    answers = ["Rast", "Şaş"]
                    qtype = "trueFalse"
                    explanation = f"Ev ravekirin bi '{term}' û qada {category.lower()} re girêdayî ye."
                else:
                    prompt = (
                        f"{context.capitalize()}, ji bo dersa {category.lower()} kîjan vebijark "
                        f"ravekirina têgeha '{term}' bi awayekî rast temam dike?"
                    )
                    correct = desc
                    answers = rotated_answers(correct, pick_three(descriptions, correct, salt), salt)
                    qtype = "multipleChoice"
                    explanation = f"Ravekirina rast ji bo '{term}' ev e: {desc}."

                if is_answer_leak(prompt, correct):
                    continue

                questions.append(
                    {
                        "category": category,
                        "prompt": prompt,
                        "answers": answers,
                        "correctAnswer": correct,
                        "explanation": explanation,
                        "difficulty": difficulty,
                        "type": qtype,
                    }
                )

    return questions


def render_question(question_id: str, question: dict[str, object]) -> str:
    answers = ", ".join(dart_string(str(answer)) for answer in question["answers"])  # type: ignore[index]
    qtype = str(question["type"])
    return (
        "  QuizQuestion(\n"
        f"    id: {dart_string(question_id)},\n"
        f"    category: {dart_string(str(question['category']))},\n"
        f"    prompt: {dart_string(str(question['prompt']))},\n"
        f"    answers: [{answers}],\n"
        f"    correctAnswer: {dart_string(str(question['correctAnswer']))},\n"
        f"    explanation: {dart_string(str(question['explanation']))},\n"
        f"    difficulty: {question['difficulty']},\n"
        f"    type: QuestionType.{qtype},\n"
        "  ),\n"
    )


def main() -> None:
    content = OFFLINE_BANK.read_text(encoding="utf-8")
    seen_prompts = existing_prompts(content)
    current_id = next_id(content)
    new_blocks: list[str] = []

    for question in build_questions():
        prompt_key = normalized(str(question["prompt"]))
        if prompt_key in seen_prompts:
            continue
        if is_answer_leak(str(question["prompt"]), str(question["correctAnswer"])):
            continue
        seen_prompts.add(prompt_key)
        new_blocks.append(render_question(f"offline_curated_{current_id}", question))
        current_id += 1
        if len(new_blocks) >= TARGET_NEW_QUESTIONS:
            break

    if len(new_blocks) < TARGET_NEW_QUESTIONS:
        raise SystemExit(f"Only generated {len(new_blocks)} new questions")

    marker = "\n];"
    if marker not in content:
        raise SystemExit("Could not find offline bank list terminator")

    updated = content.replace(marker, "\n" + "".join(new_blocks) + "];", 1)
    OFFLINE_BANK.write_text(updated, encoding="utf-8")
    print(f"Appended {len(new_blocks)} curated offline questions")


if __name__ == "__main__":
    main()
