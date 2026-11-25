glob:priv NAMED: list[tuple[str, str]] = [
    ("#2563eb", "Blue"),
    ("#7c3aed", "Purple"),
    ("#db2777", "Pink"),
    ("#dc2626", "Red"),
    ("#ea580c", "Orange"),
    ("#d97706", "Amber"),
    ("#16a34a", "Green"),
    ("#0d9488", "Teal"),
];

glob FOLDER_COLOR_VALUES: any = [value for (value, _) in NAMED],
     DEFAULT_FOLDER_COLOR: str = "#2563eb",
     FOLDER_COLOR_OPTIONS: any = [
         record({"value": value, "label": label})
         for (value, label) in NAMED
     ];
