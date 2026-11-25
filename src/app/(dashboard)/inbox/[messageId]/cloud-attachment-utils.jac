# Outlook's cloud attachment line: `[icon url]File name<file url>`.
glob:priv OUTLOOK_CLOUD_ATTACHMENT: any = rx(
    r"^\s*\[(https?:\/\/[^\]\s]+)\]([^<\r\n]+)<(https?:\/\/[^>\s]+)>\s*$", "gm"
);

def:priv is_microsoft_cloud_file_url(value: any) -> bool {
    try {
        host: any = new(globalThis.URL, value).hostname.toLowerCase();
    } except Exception {
        return False;
    }
    return host in ["1drv.ms", "onedrive.live.com"] or host.endsWith(".sharepoint.com");
}

def extractCloudAttachments(content: any) -> any {
    attachments: list[any] = [];

    def pick(found: str, icon: any, raw: any, url: any, *more: any) -> str {
        filename = raw.trim();
        if not is_microsoft_cloud_file_url(url) or not filename {
            return found;
        }
        item = {"id": f"{url}-{len(attachments)}", "filename": filename, "provider": "OneDrive"};
        attachments.append(merged(item, {"url": url}));
        return "";
    }

    visible = rx_sub(content, rx(r"[​-‍⁠﻿]", "g"), "");
    body: any = rx_sub(visible, OUTLOOK_CLOUD_ATTACHMENT, pick);
    return {"attachments": attachments, "content": sub(body, rx(r"\n{3,}", "g"), "\n\n").trim()};
}
