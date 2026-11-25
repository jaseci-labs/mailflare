glob:priv GAP: int = 8,
          PAD: int = 8;

def getTooltipPosition(trigger: any, tooltip: any, placement: any = None) -> any {
    (t, tip) = (trigger.getBoundingClientRect(), tooltip.getBoundingClientRect());
    (M, w) = (globalThis.Math, globalThis.window);
    (max_left, max_top) = (w.innerWidth - tip.width - PAD, w.innerHeight - tip.height - PAD);
    if placement == "right" {
        top = M.min(M.max(t.top + t.height / 2 - tip.height / 2, PAD), max_top);
        return {"left": M.min(t.right + GAP, max_left), "top": top};
    }
    left = M.min(M.max(t.left + t.width / 2 - tip.width / 2, PAD), max_left);
    below = w.innerHeight - t.bottom >= tip.height + GAP;
    return {"left": left, "top": M.max(PAD, t.bottom + GAP if below else t.top - tip.height - GAP)};
}
