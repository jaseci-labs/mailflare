# Geometry of the inline message action row: 32px icon buttons with gap-2; a divider is a 1px rule
# plus mx-2 on each side.
glob INLINE_ACTION_WIDTH: int = 32,
     INLINE_ACTION_GAP: int = 8,
     INLINE_ACTION_DIVIDER_WIDTH: int = 17,
     INLINE_ACTION_TRIGGER_WIDTH: int = 32;

"""How many leading actions fit before the always-visible overflow trigger. The trigger is reserved
first, so a narrow row keeps only the menu. A group divider is counted together with the first
action of the next group, so it never renders without an action after it."""
def getVisibleActionCount(opts: any) -> int {
    (avail, groups) = (opts["availableWidth"], opts["groups"]);
    if not globalThis.Number.isFinite(avail) or avail <= 0 {
        return 0;
    }
    action = at(opts, "actionWidth", INLINE_ACTION_WIDTH);
    gap = at(opts, "gap", INLINE_ACTION_GAP);
    divider = at(opts, "dividerWidth", INLINE_ACTION_DIVIDER_WIDTH);
    (used, count) = (at(opts, "triggerWidth", INLINE_ACTION_TRIGGER_WIDTH), 0);
    for (i, g) in enumerate(groups) {
        width = gap + action + (gap + divider if i > 0 and g != groups[i - 1] else 0);
        if used + width > avail {
            break;
        }
        (used, count) = (used + width, count + 1);
    }
    return count;
}
