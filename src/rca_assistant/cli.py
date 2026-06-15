from pathlib import Path
import argparse

from .assistant import RCAAssistant


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Ask the Phase 1 Knowledge RCA Assistant about DICOM dashboard issues."
    )
    parser.add_argument(
        "question",
        nargs="*",
        help="Problem statement, for example: CT study count is low for yesterday.",
    )
    parser.add_argument(
        "--repo-root",
        default=".",
        help="Repository root containing docs, knowledge, and SQL files.",
    )

    args = parser.parse_args()
    question = " ".join(args.question).strip()

    if not question:
        question = input("Describe the dashboard or data issue: ").strip()

    assistant = RCAAssistant.from_default_paths(Path(args.repo_root))
    response = assistant.answer(question)
    print(response.answer)

