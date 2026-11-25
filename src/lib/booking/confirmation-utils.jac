# The names a confirmation can use as {placeholder}.
glob BOOKING_TEMPLATE_PLACEHOLDERS: list[str] = [
    "guestName",
    "eventName",
    "hostName",
    "when",
    "location",
    "notes",
];

glob CONFIRMATION_SUBJECT_MAX: int = 200;

glob CONFIRMATION_BODY_MAX: int = 5000;

# The built-in confirmation, used for whichever of subject and body an event leaves empty. It deliberately leaves out
# {notes}: the booking page is public, so the booker's free text must not appear in mail sent from the host's address
# unless the host chose to put it there in a custom template.
glob DEFAULT_CONFIRMATION_SUBJECT: str = "Confirmed: {eventName} with {hostName}";

glob DEFAULT_CONFIRMATION_BODY: str = "\n".join([
    "Hi {guestName},",
    "",
    "your booking is confirmed: {eventName} with {hostName}.",
    "",
    "When: {when}",
    "Where: {location}",
    "",
    "The attached calendar file adds the meeting to your calendar. Reply to this email if you need to change or cancel it.",
]);

glob:priv FALLBACK_LOCALE: str = "en-GB",
          PLACEHOLDER: any = rx(r"\{(\w+)\}", "g"),
          LINE_BREAKS: any = rx(r"[\r\n]+", "g");

type BookingConfirmationContent = any;

type BookingTemplatePlaceholder = any;

type BookingConfirmationTemplate = any;

"""`rx_sub` whose result keeps JavaScript's string methods."""
def:priv sub(s: any, regex: any, to: any) -> any {
    return rx_sub(s, regex, to);
}

def:priv formatter(locale: any, options: dict[str, any]) -> any {
    return new(globalThis.Intl.DateTimeFormat, locale, record(options));
}

"""The locale for {when}: the language the guest picked on the booking page, else their browser's, else English."""
def pickGuestLocale(localeCookie: any = None, acceptLanguage: any = None) -> str {
    candidates: list[any] = [localeCookie] + [
        part.split(";")[0]
        for part in either(acceptLanguage, "").split(",")
    ];
    for candidate in candidates {
        tag = candidate.trim() if not nil(candidate) else "";
        if not tag or tag == "*" {
            continue;
        }
        try {
            if globalThis.Intl.DateTimeFormat.supportedLocalesOf([tag]).length {
                return tag;
            }
        } except Exception {
            # Not a valid language tag; try the next one.
        }
    }
    return FALLBACK_LOCALE;
}

""""Friday 13 November 2026, 10:00–10:30 (Europe/Berlin)" in the event's time zone, worded for the guest's locale."""
def formatBookingWhen(startsAt: any, endsAt: any, timeZone: any, locale: any = None) -> str {
    locale = FALLBACK_LOCALE if locale is None else locale;
    zone = timeZone;
    try {
        formatter(locale, {"timeZone": zone});
    } except Exception {
        zone = "UTC";
    }
    day = formatter(
        locale,
        {"timeZone": zone, "weekday": "long", "day": "numeric", "month": "long", "year": "numeric"},
    ).format(startsAt);
    time = formatter(locale, {"timeZone": zone, "hour": "2-digit", "minute": "2-digit"});
    return f"{day}, {time.format(startsAt)}–{time.format(endsAt)} ({zone})";
}

"""
Replaces known {placeholders}; anything else in braces is left as written. A line whose placeholders all come out
empty is dropped, so "Where: {location}" disappears for an event without a location.
"""
def renderBookingTemplate(template: any, values: any) -> str {
    def filled(line: any) -> bool {
        names = [
            found[1]
            for found in globalThis.Array.from(line.matchAll(PLACEHOLDER))
            if owns(values, found[1])
        ];
        return not names or any([values[name].trim() for name in names]);
    }
    def value_of(whole: str, name: str) -> str {
        return values[name] if owns(values, name) else whole;
    }
    return "\n".join([
        rx_sub(line, PLACEHOLDER, value_of)
        for line in template.split("\n")
        if filled(line)
    ]);
}

"""
Reads the confirmation fields of a booking event request: undefined when the request leaves them out (keep what
is saved), null when they are invalid.
"""
def parseConfirmationTemplateInput(value: any = None) -> any {
    if nil(value)
        or globalThis.Object(value) is not value
        or globalThis.Function.prototype.isPrototypeOf(value)
    {
        return None;
    }
    (subject, body) = (value["confirmationSubject"], value["confirmationBody"]);
    if subject is None and body is None {
        return None;
    }
    (subject, body) = (either(subject, ""), either(body, ""));
    if not isinstance(subject, str) or not isinstance(body, str) {
        return NULL;
    }
    cleanSubject = sub(subject, LINE_BREAKS, " ").trim();
    cleanBody = sub(body, rx(r"\r\n?", "g"), "\n").trim();
    if cleanSubject.length > CONFIRMATION_SUBJECT_MAX or cleanBody.length > CONFIRMATION_BODY_MAX {
        return NULL;
    }
    return {"subject": cleanSubject, "body": cleanBody};
}

"""The guest confirmation: the event's own subject and body where set, the default template otherwise."""
def buildBookingConfirmation(
    content: any, locale: any = None, template: any = None
) -> dict[str, str] {
    # The booker is anonymous: keep their name on one line so it cannot add lines to the message or subject.
    values = record({
        "guestName": sub(content["guestName"], rx(r"\s+", "g"), " ").trim(),
        "eventName": content["eventName"],
        "hostName": content["hostName"],
        "when": formatBookingWhen(
            content["startsAt"], content["endsAt"], content["timeZone"], locale
        ),
        "location": content["location"],
        "notes": content["notes"],
    });
    # A guest's name can go into the subject, so keep it on one header line whatever they typed.
    def subject_of(pattern: str) -> str {
        return sub(renderBookingTemplate(pattern, values), LINE_BREAKS, " ").trim();
    }
    (own_subject, own_body) = (at(template, "subject"), at(template, "body"))
        if template
        else (NULL, NULL);
    return {
        "subject": subject_of(own_subject or DEFAULT_CONFIRMATION_SUBJECT)
            or subject_of(DEFAULT_CONFIRMATION_SUBJECT),
        "text": renderBookingTemplate(own_body or DEFAULT_CONFIRMATION_BODY, values),
    };
}

"""
The calendar file attached to the confirmation. It is a plain PUBLISH event, not a meeting request: the booking is
already confirmed, the guest's answer would not reach the host's events, and Outlook cannot import an attached
REQUEST file.
"""
def buildBookingCalendarFile(input: any) -> any {
    return createCalendarInvitation(merged(input, {"method": "PUBLISH", "sequence": 0}));
}
