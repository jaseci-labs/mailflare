import from "nanoid" { nanoid }

def newId(prefix: any = None) -> str {
    return f"{prefix}_{nanoid()}" if prefix else nanoid();
}
