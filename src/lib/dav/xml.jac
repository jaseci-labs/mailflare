import from "saxes" { SaxesParser }

# One parsed element: {ns, name, attrs, children, text}. `ns` is the resolved namespace URI, so clients may use any prefix.
type DavElement = any;

"""The body is not acceptable XML for DAV; the message is safe to show a client."""
obj DavXmlError(globalThis.Error) {
    def init(message: str) {
        super.init(message);
    }
}

glob:priv MAX_DEPTH: int = 32,
          MAX_ELEMENTS: int = 20000,
          MAX_TEXT: int = 64 * 1024;

"""
Parse a request body into a small tree. Anything that could expand or fetch is refused instead of handled:
a DOCTYPE (external entities, entity bombs) and processing instructions other than the XML declaration.
saxes only knows the five predefined entities, so any other `&name;` is an error.
Never throws anything but DavXmlError.
"""
def parseDavXml(input: str) -> any {
    parser = new(SaxesParser, record({"xmlns": True}));
    stack: list[any] = [];
    tree: any = None;
    failure: any = None;
    elements = 0;
    def fail(message: str) {
        if failure is None {
            failure = DavXmlError(message);
        }
    }
    def addText(text: str) {
        if not stack {
            return;
        }
        current = stack[-1];
        current.text += text;
        if current.text.length > MAX_TEXT {
            fail("Text content too large");
        }
    }
    def open(tag: any) {
        elements += 1;
        if elements > MAX_ELEMENTS {
            fail("Too many elements");
            return;
        }
        if len(stack) >= MAX_DEPTH {
            fail("Elements nested too deeply");
            return;
        }
        attrs: any = globalThis.Object();
        for attribute in globalThis.Object.values(tag.attributes) {
            if attribute.uri != "http://www.w3.org/2000/xmlns/" {
                attrs[attribute.local] = attribute.value;
            }
        }
        element: any = record({
            "ns": tag.uri,
            "name": tag.local,
            "attrs": attrs,
            "children": [],
            "text": "",
        });
        if stack {
            stack[-1].children.push(element);
        }
        stack.append(element);
        if tree is None {
            tree = element;
        }
    }
    def close(tag: any) {
        stack.pop();
    }
    parser.on("error", lambda (error: any) { fail(error.message); });
    parser.on("doctype", lambda (d: any) { fail("DOCTYPE is not allowed"); });
    parser.on(
        "processinginstruction",
        lambda (p: any) { fail("Processing instructions are not allowed"); },
    );
    parser.on("opentag", open);
    parser.on("closetag", close);
    parser.on("text", addText);
    parser.on("cdata", addText);
    try {
        parser.write(input).close();
    } except Exception as e {
        fail(e.message if globalThis.Error.prototype.isPrototypeOf(e) else "Invalid XML");
    }
    if failure is not None {
        raise failure;
    }
    if tree is None {
        raise DavXmlError("Empty document");
    }
    return tree;
}
