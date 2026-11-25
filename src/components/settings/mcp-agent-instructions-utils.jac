glob:priv MAIL: str = "Use get_calendars for calendar access and list_mailboxes for mail access when available. Use only the tools and mailbox IDs returned by this server. Calendar changes save immediately. Sending mail requires a review request and confirmation in Mailflare.",
          ADMIN: str = "Use only the admin management tools and permissions exposed by this key. This key cannot read or send mail.";

def buildMcpAgentPrompt(origin: any, props: any) -> str {
    url = f"{origin or 'https://your-mailflare-domain'}/mcp";
    key = globalThis.String(props["apiKey"]);
    how = MAIL if props["mode"] == "mail" else ADMIN;
    return f"Connect to my Mailflare MCP server using these settings:\nServer URL: {url}\nTransport: Streamable HTTP\nAuthorization header: Bearer {key}\n\n{how}\nDo not print the API key in your replies or logs. If you cannot configure the MCP connection directly, tell me which settings to enter in my client.";
}
