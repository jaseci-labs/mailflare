def isModifierKey(key: any) -> bool {
    return key in ["shift", "control", "alt", "meta"];
}

def hasCommandModifier(e: any) -> any {
    return e["metaKey"] or e["ctrlKey"] or e["altKey"];
}

"""The shortcut the end of `buffer` spells, longest sequence first; a lone last key of a longer
buffer is not tried."""
def findSequenceMatch(buffer: any, shortcuts: any) -> any {
    n = len(buffer);
    for start in range(n - 1 if n > 1 else n) {
        seq = " ".join(buffer[start:]);
        hit = first([s for s in shortcuts if s["key"].toLowerCase() == seq]);
        if hit {
            return hit;
        }
    }
    return None;
}
