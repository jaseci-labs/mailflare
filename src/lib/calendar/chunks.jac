# D1 allows at most 100 bound parameters per statement; id-IN lists stay at 90 like messages.
glob D1_IN_CHUNK: int = 90;

"""Splits an id list into D1-safe IN-list chunks."""
def chunkIds(ids: list[str]) -> list[list[str]] {
    return [ids[i:i + D1_IN_CHUNK] for i in range(0, len(ids), D1_IN_CHUNK)];
}
