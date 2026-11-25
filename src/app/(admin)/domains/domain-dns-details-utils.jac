def getDnsRecordLabel(record: any) -> str {
    (content, priority) = (at(record, "content"), getattr(record, "priority", None));
    tail = (f" → {content}" if content else "")
        + ("" if priority is None else f" (priority {priority})");
    return f"{at(record, 'type') or 'DNS'} · {at(record, 'name') or 'Domain'}{tail}";
}
