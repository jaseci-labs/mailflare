glob:priv HTML_SPECIAL: any = rx(r"""[&<>"']""", "g"),
          LINE_BREAK: any = rx(r"\r?\n", "g"),
          ESCAPES: dict[str, str] = {
              "&": "&amp;",
              "<": "&lt;",
              ">": "&gt;",
              '"': "&quot;",
              "'": "&#39;",
          };

# A file sent as a link: `{filename, size, url}`.
type SharedFileLink = dict[str, any];

def escapeHtml(value: str) -> str {
    return rx_sub(value, HTML_SPECIAL, lambda (ch: str) -> str { ESCAPES[ch] });
}

def:priv megabytes(file: any) -> str {
    return globalThis.Number(file["size"] / 1_000_000).toFixed(1) + " MB";
}

"""The note appended to a message whose large files went out as download links, in the sender's language."""
def sharedFileNotice(files: any, linkDays: any, t: any = None) -> any {
    translate = defaultTranslator if t is None else t;
    intro = translate("attachment.sharedIntro", {"days": linkDays});
    download = translate("attachment.sharedDownload");
    text = "\n".join([f"{file['filename']} ({megabytes(file)}): {file['url']}" for file in files]);
    html = "".join([
        f'<li>{escapeHtml(file["filename"])} ({megabytes(file)}): <a href="{escapeHtml(file["url"])}">{escapeHtml(download)}</a></li>'
        for file in files
    ]);
    paragraph = f"<p>{rx_sub(escapeHtml(intro), LINE_BREAK, '<br>')}</p>" if intro else "";
    return record({
        "intro": intro,
        "text": text,
        "html": html,
        "htmlBlock": f"<div>{paragraph}<ul>{html}</ul></div>",
        "textBlock": lambda (body: any = None) -> str {
            "\n\n".join([part for part in [body.trim() if body else "", intro, text] if part])
        },
    });
}
