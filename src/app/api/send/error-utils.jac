glob:priv TOO_BIG = [p.strip() for p in """Attachments exceed|Subject exceeds|Headers exceed|
              Message exceeds Cloudflare|A message can include at most""".split("|")],
          FORBIDDEN = [p.strip() for p in """Mailbox not found|Sender account not found|
              You do not have permission to send from this mailbox|
              Sender address does not match the selected mailbox""".split("|")];

def getSendErrorStatus(message: any) -> int {
    if message == "Mailbox is required" or any(message.startsWith(p) for p in TOO_BIG) {
        return 400;
    }
    return 403 if message in FORBIDDEN else 500;
}
