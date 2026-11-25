# Translation keys for the names of the shared folder/event colors.
glob folderColorKeys: any = record({k: v for (k, _, v) in [p.partition("=") for p in """
    #2563eb=color.blue #7c3aed=color.purple #db2777=color.pink #dc2626=color.red
    #ea580c=color.orange #d97706=color.amber #16a34a=color.green #0d9488=color.teal""".split()]});
