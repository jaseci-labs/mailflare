# nanoid() without the package: its Node entry imports node:crypto, which breaks the platform-neutral
# bundles that load every Jac module. Same alphabet, 21 Web Crypto bytes, 6 bits each.
glob:priv URL_ALPHABET = "useandom-26T198340PX75pxJACKVERYMINDBUSHWOLF_GQZbfghjklqvwyzrict";

def newId(prefix: any = None) -> str {
    rnd = globalThis.crypto.getRandomValues(new(globalThis.Uint8Array, 21));
    id = "".join([URL_ALPHABET[b & 63] for b in rnd]);
    return f"{prefix}_{id}" if prefix else id;
}
