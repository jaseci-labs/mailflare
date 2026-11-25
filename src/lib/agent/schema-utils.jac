import from "zod" { z }

# Zod 4 emits z.string().email() as a JSON Schema pattern with lookaheads, which OpenRouter rejects.
glob toolEmailSchema: any = z.string().refine(
    lambda (v: any) -> bool { z.string().email().safeParse(v).success }, "Invalid email"
).meta(record({"format": "email", "description": "A single email address"}));
