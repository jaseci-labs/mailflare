# The key buffer every mounted useHotkeys shares, so a multi-key sequence such as "g !" is matched
# against all registered shortcuts by whichever listener sees the key first, and the others skip it.
type ShortcutRef = any;
type SequenceState = any;

def createSequenceState -> any {
    g = globalThis;
    return {"buffer": [], "refs": new(g.Set), "lastEvent": NULL, "consumed": new(g.WeakSet)};
}

"""Pushes the key once per event. Returns true when the key was newly buffered."""
def recordKey(state: any, event: any, key: any) -> bool {
    if state["lastEvent"] is event {
        return False;
    }
    state["lastEvent"] = event;
    state["buffer"].append(key);
    return True;
}

"""Sequences are matched across all registered shortcuts; a single key only against the caller's own."""
def matchSequence(state: any, mine: any) -> any {
    buf = state["buffer"];
    found = [s for ref in [*state["refs"]] for s in ref["current"]] if len(buf) > 1 else mine;
    return findSequenceMatch(buf, found);
}

def consumeEvent(state: any, event: any) {
    state["consumed"].add(event);
    state["buffer"] = [];
}
