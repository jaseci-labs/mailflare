# nanoid without the package, whose node:crypto import breaks platform-neutral bundles of Jac modules.
glob:priv URL_ALPHABET = "useandom-26T198340PX75pxJACKVERYMINDBUSHWOLF_GQZbfghjklqvwyzrict";

def newId(prefix: any = None) -> str {
    rnd = globalThis.crypto.getRandomValues(new(globalThis.Uint8Array, 21));
    id = "".join([URL_ALPHABET[b & 63] for b in rnd]);
    return f"{prefix}_{id}" if prefix else id;
}
