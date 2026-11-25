def collapseQuotedEmailHtml(html: any, keepFirst: any = False, toggleLabel: any = None) -> any {
    if not html {
        return NULL;
    }
    label = "Toggle quoted email" if toggleLabel is None else toggleLabel;
    doc = globalThis.window.document;
    template = doc.createElement("template");
    template.innerHTML = html;
    skipped = False;
    for quote in globalThis.Array.from(template.content.querySelectorAll("blockquote")) {
        intro = quote.previousElementSibling;
        element = globalThis.HTMLElement.prototype.isPrototypeOf(intro);
        if not element
            or not rx(r"^On\b[\s\S]*\bwrote:\s*$", "i").test(either(intro.textContent, "").trim())
        {
            continue;
        }
        # The outer toggle already folded this quote, so its first attribution stays open. It need
        # not be the first element: sanitising can leave a leading <br> or wrapper before it.
        if keepFirst and not skipped {
            skipped = True;
            continue;
        }
        (details, summary, content) = [doc.createElement(t) for t in ["details", "summary", "div"]];
        (details.className, content.className) = ("email-quote-toggle", "email-quote-content");
        summary.setAttribute("aria-label", label);
        summary.setAttribute("title", label);
        if intro.parentNode {
            intro.parentNode.insertBefore(details, intro);
        }
        content.append(intro, quote);
        details.append(summary, content);
    }
    return template.innerHTML;
}
