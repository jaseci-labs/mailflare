import from "clsx" { clsx }
import from "tailwind-merge" { twMerge }

glob:priv ANGLED: any = rx(r"<([^>]+)>$"),
          PLAIN: any = rx(r"^([^@\s]+)@([^@\s]+)$");

def cn(*inputs: any) -> str {
    return twMerge(clsx(inputs));
}

def slugify(value: any) -> str {
    dashed = rx_sub(value.toLowerCase().trim(), rx(r"[^a-z0-9]+", "g"), "-");
    return rx_sub(dashed, rx(r"^-+|-+$", "g"), "");
}

"""`local@domain`, bare or at the end of `Name <local@domain>`, lower-cased; null when it is neither."""
def parseAddress(address: any) -> any {
    trimmed = address.trim();
    angled = ANGLED.exec(trimmed);
    found = PLAIN.exec(angled[1] if angled else trimmed);
    if not found {
        return NULL;
    }
    return record({"local": found[1].toLowerCase(), "domain": found[2].toLowerCase()});
}
