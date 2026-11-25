glob:priv NAMED: list[any] = [p.split("=") for p in """#2563eb=Blue #7c3aed=Purple #db2777=Pink
    #dc2626=Red #ea580c=Orange #d97706=Amber #16a34a=Green #0d9488=Teal""".split()];

glob FOLDER_COLOR_VALUES: any = [v for (v, _) in NAMED],
     DEFAULT_FOLDER_COLOR: str = "#2563eb",
     FOLDER_COLOR_OPTIONS: any = [record({"value": v, "label": l}) for (v, l) in NAMED];
