"""Seconds a send waits so it can still be cancelled; 0 sends at once."""
glob UNDO_SEND_OPTIONS: any = [0, 5, 10, 15, 30],
     DEFAULT_UNDO_SEND_SECONDS: int = 15;

def parseUndoSendSeconds(value: any = None) -> any {
    seconds = globalThis.Number(value) if isinstance(value, str) and value.strip() != "" else value;
    return seconds
        if globalThis.Number.isFinite(seconds) and seconds in UNDO_SEND_OPTIONS
        else NULL;
}
