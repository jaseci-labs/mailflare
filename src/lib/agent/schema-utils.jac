import from "zod" { z }

glob:priv STRICT_EMAIL: any = z.string().email();

# Zod 4 emits z.string().email() as a JSON Schema pattern with lookaheads, which OpenRouter rejects.
glob toolEmailSchema: any = z.string().refine(
    lambda (value: any) -> bool { STRICT_EMAIL.safeParse(value).success }, "Invalid email"
).meta(record({"format": "email", "description": "A single email address"}));
