glob:priv LEGACY_CALENDAR_COLORS: any = record({
    "blue": "#2563eb",
    "violet": "#7c3aed",
    "rose": "#db2777",
    "orange": "#ea580c",
    "emerald": "#16a34a",
});

def normalizeCalendarColor(value: any = None) -> any {
    if value in FOLDER_COLOR_VALUES {
        return value;
    }
    return either(LEGACY_CALENDAR_COLORS[either(value, "")], DEFAULT_FOLDER_COLOR);
}
