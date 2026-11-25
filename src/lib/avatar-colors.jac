glob:priv BACKGROUNDS: list[str] = [
    "#FFCDD2",
    "#F8BBD0",
    "#E1BEE7",
    "#C5CAE9",
    "#BBDEFB",
    "#B2DFDB",
    "#C8E6C9",
    "#FFE0B2",
    "#D7CCC8",
    "#CFD8DC",
];

"""A stable pastel for an identity: a 32-bit string hash (x31, wrapping) picks the background."""
def getAvatarColorStyle(identity: any) -> dict[str, str] {
    stable = identity.trim().toLowerCase();
    hash = 0;
    for i in range(stable.length) {
        # Math.imul(x, 1) wraps to 32 bits as JavaScript's `| 0` does
        hash = globalThis.Math.imul(globalThis.Math.imul(hash, 31) + stable.charCodeAt(i), 1);
    }
    unsigned = hash + 4294967296 if hash < 0 else hash;
    return {"backgroundColor": BACKGROUNDS[unsigned % len(BACKGROUNDS)], "color": "#202124"};
}
