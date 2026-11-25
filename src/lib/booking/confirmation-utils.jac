# The names a confirmation can use as {placeholder}.
glob BOOKING_TEMPLATE_PLACEHOLDERS: list[str] = """guestName eventName hostName when location
         notes""".split(),
     CONFIRMATION_SUBJECT_MAX: int = 200,
     CONFIRMATION_BODY_MAX: int = 5000,
     # The built-in confirmation, for whichever of subject and body an event leaves empty. It leaves out
     # {notes} on purpose: the booking page is public, so the booker's free text must not appear in mail
     # sent from the host's address unless the host put it there in a custom template.
     DEFAULT_CONFIRMATION_SUBJECT: str = "Confirmed: {eventName} with {hostName}",
     DEFAULT_CONFIRMATION_BODY: str = "Hi {guestName},\n\nyour booking is confirmed: {eventName} with {hostName}.\n\n"
         + "When: {when}\nWhere: {location}\n\nThe attached calendar file adds the meeting to your calendar. "
         + "Reply to this email if you need to change or cancel it.";

glob:priv PLACEHOLDER: any = rx(r"\{(\w+)\}", "g"),
          NL: any = rx(r"[\r\n]+", "g"),
          DTF: any = globalThis.Intl.DateTimeFormat,
          DAY: any = {"weekday": "long", "day": "numeric", "month": "long", "year": "numeric"};

type BookingConfirmationTemplate = any;

def:priv dtf(locale: any, options: any) -> any {
    return new(DTF, locale, merged(options));
}

"""The locale for {when}: the language the guest picked on the booking page, else their browser's, else English."""
def pickGuestLocale(localeCookie: any = None, acceptLanguage: any = None) -> str {
    parts = [part.split(";")[0] for part in either(acceptLanguage, "").split(",")];
    for candidate in [localeCookie] + parts {
        tag = "" if nil(candidate) else candidate.trim();
        try {
            if tag and tag != "*" and DTF.supportedLocalesOf([tag]).length {
                return tag;
            }
        } except Exception {
            # Not a valid language tag; try the next one.
        }
    }
    return "en-GB";
}

""""Friday 13 November 2026, 10:00–10:30 (Europe/Berlin)" in the event's time zone, worded for the guest's locale."""
def formatBookingWhen(startsAt: any, endsAt: any, timeZone: any, locale: any = None) -> str {
    (locale, zone) = ("en-GB" if locale is None else locale, timeZone);
    try {
        dtf(locale, {"timeZone": zone});
    } except Exception {
        zone = "UTC";
    }
    day = dtf(locale, merged({"timeZone": zone}, DAY));
    time = dtf(locale, {"timeZone": zone, "hour": "2-digit", "minute": "2-digit"});
    return f"{day.format(startsAt)}, {time.format(startsAt)}–{time.format(endsAt)} ({zone})";
}

# Replaces known {placeholders}; anything else in braces is left as written. A line whose placeholders
# all come out empty is dropped, so "Where: {location}" disappears for an event without a location.
def renderBookingTemplate(template: any, values: any) -> str {
    def filled(line: any) -> bool {
        found = globalThis.Array.from(line.matchAll(PLACEHOLDER));
        names = [m[1] for m in found if owns(values, m[1])];
        return not names or any([values[name].trim() for name in names]);
    }
    value_of = lambda (w: str, n: str) -> str { values[n] if owns(values, n) else w };
    kept = [line for line in template.split("\n") if filled(line)];
    return "\n".join([sub(line, PLACEHOLDER, value_of) for line in kept]);
}

# The confirmation fields of a booking event request: undefined when the request leaves them out (keep
# what is saved), null when they are invalid.
def parseConfirmationTemplateInput(value: any = None) -> any {
    v = value if is_object(value) else record({});
    (s, b) = (v["confirmationSubject"], v["confirmationBody"]);
    if s is None and b is None {
        return None;
    }
    (s, b) = (either(s, ""), either(b, ""));
    if not isinstance(s, str) or not isinstance(b, str) {
        return NULL;
    }
    (s, b) = (sub(s, NL, " ").trim(), sub(b, rx(r"\r\n?", "g"), "\n").trim());
    return NULL if s.length > 200 or b.length > 5000 else {"subject": s, "body": b};
}

"""The guest confirmation: the event's own subject and body where set, the default template otherwise."""
def buildBookingConfirmation(content: any, locale: any = None, template: any = None) -> any {
    # The booker is anonymous: keep their name on one line so it cannot add lines to the message or subject.
    guest = sub(content["guestName"], rx(r"\s+", "g"), " ").trim();
    when = formatBookingWhen(content["startsAt"], content["endsAt"], content["timeZone"], locale);
    names = {k: content[k] for k in ["eventName", "hostName"]};
    places = {"location": content["location"], "notes": content["notes"]};
    values = merged({"guestName": guest}, names, {"when": when}, places);
    # A guest's name can go into the subject, so keep it on one header line whatever they typed.
    one_line = lambda (t: str) -> any { sub(renderBookingTemplate(t, values), NL, " ").trim() };
    (subject, body) = (at(template, "subject"), at(template, "body")) if template else (NULL, NULL);
    subject = one_line(subject or DEFAULT_CONFIRMATION_SUBJECT);
    subject = subject or one_line(DEFAULT_CONFIRMATION_SUBJECT);
    text = renderBookingTemplate(body or DEFAULT_CONFIRMATION_BODY, values);
    return {"subject": subject, "text": text};
}

# The calendar file attached to the confirmation: a plain PUBLISH event, not a meeting request, since the
# booking is already confirmed, the guest's answer would not reach the host, and Outlook cannot import an
# attached REQUEST.
def buildBookingCalendarFile(input: any) -> any {
    return createCalendarInvitation(merged(input, {"method": "PUBLISH", "sequence": 0}));
}
