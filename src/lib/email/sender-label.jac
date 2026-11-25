# Bidi and control characters can make a display name render as something other than its
# stored text. Keep the same set the Web Push hardening used.
glob:priv UNSAFE_LABEL_CHARS: any = rx(r"[\u0000-\u001f‪-‮⁦-⁩]", "g");

"""One-line sender label for OS notifications.

The resolved display name beside the real address, so a spoofed name cannot hide where the
message came from. A message's `from` is its full `"Name" <address>` header, so only the bare
address is used inside the angle brackets.
"""
def formatSenderLabel(sender: any, name: any = None) -> str {
    bare: any = getEmailAddress(sender);
    address: any = bare.trim() or sender.trim();
    cleaned: any = rx_sub(either(name, ""), UNSAFE_LABEL_CHARS, "");
    shown: any = cleaned.trim();
    label: any = f"{shown.slice(0, 120)} <{address}>"
        if shown and shown.lower() != address.lower()
        else address;
    return label.slice(0, 240);
}
