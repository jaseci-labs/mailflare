import from "nanoid" { nanoid }

def newId(prefix: any = None) -> str {
    fresh = nanoid();
    return f"{prefix}_{fresh}" if prefix else fresh;
}
