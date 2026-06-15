from dataclasses import dataclass
from pathlib import Path
import math
import re


TOKEN_PATTERN = re.compile(r"[a-zA-Z0-9_]+")


@dataclass(frozen=True)
class DocumentChunk:
    source: str
    title: str
    text: str


@dataclass(frozen=True)
class SearchResult:
    chunk: DocumentChunk
    score: float


def tokenize(text: str) -> list[str]:
    return [token.lower() for token in TOKEN_PATTERN.findall(text)]


def chunk_text(source: str, text: str, max_lines: int = 32) -> list[DocumentChunk]:
    chunks: list[DocumentChunk] = []
    current_title = Path(source).name
    current_lines: list[str] = []

    def flush() -> None:
        if current_lines:
            chunks.append(
                DocumentChunk(
                    source=source,
                    title=current_title,
                    text="\n".join(current_lines).strip(),
                )
            )
            current_lines.clear()

    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        if line.startswith("#"):
            flush()
            current_title = line.lstrip("#").strip() or Path(source).name
            current_lines.append(line)
            continue

        if len(current_lines) >= max_lines:
            flush()
        current_lines.append(line)

    flush()
    return [chunk for chunk in chunks if chunk.text]


class KnowledgeBase:
    def __init__(self, chunks: list[DocumentChunk]):
        self.chunks = chunks
        self._chunk_tokens = [tokenize(chunk.text) for chunk in chunks]
        self._idf = self._build_idf()

    @classmethod
    def from_paths(cls, paths: list[Path]) -> "KnowledgeBase":
        chunks: list[DocumentChunk] = []
        for path in paths:
            if not path.exists():
                continue
            text = path.read_text(encoding="utf-8")
            chunks.extend(chunk_text(str(path), text))
        return cls(chunks)

    def search(self, query: str, limit: int = 5) -> list[SearchResult]:
        query_tokens = tokenize(query)
        if not query_tokens:
            return []

        query_weights = self._weights(query_tokens)
        results: list[SearchResult] = []

        for chunk, tokens in zip(self.chunks, self._chunk_tokens):
            score = self._cosine(query_weights, self._weights(tokens))
            if score > 0:
                results.append(SearchResult(chunk=chunk, score=score))

        return sorted(results, key=lambda item: item.score, reverse=True)[:limit]

    def _build_idf(self) -> dict[str, float]:
        document_count = max(len(self._chunk_tokens), 1)
        document_frequency: dict[str, int] = {}
        for tokens in self._chunk_tokens:
            for token in set(tokens):
                document_frequency[token] = document_frequency.get(token, 0) + 1

        return {
            token: math.log((1 + document_count) / (1 + frequency)) + 1
            for token, frequency in document_frequency.items()
        }

    def _weights(self, tokens: list[str]) -> dict[str, float]:
        weights: dict[str, float] = {}
        for token in tokens:
            weights[token] = weights.get(token, 0.0) + self._idf.get(token, 1.0)
        return weights

    @staticmethod
    def _cosine(left: dict[str, float], right: dict[str, float]) -> float:
        shared = set(left).intersection(right)
        if not shared:
            return 0.0

        numerator = sum(left[token] * right[token] for token in shared)
        left_norm = math.sqrt(sum(value * value for value in left.values()))
        right_norm = math.sqrt(sum(value * value for value in right.values()))
        if left_norm == 0 or right_norm == 0:
            return 0.0
        return numerator / (left_norm * right_norm)

