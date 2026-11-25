glob:priv current: any = NULL,
          next_id: int = 1,
          listeners: any = new(globalThis.Set);
type PromotionToastEntry = any;

def:priv emit {
    listeners.forEach(lambda (listener: any) -> any { listener() });
}

def subscribePromotionToast(listener: any) -> any {
    listeners.add(listener);
    return lambda -> any { listeners.delete(listener) };
}

def getPromotionToast -> any {
    return current;
}

"""One toast at a time: a newer move replaces the previous one and its offer."""
def showPromotionToast(e: any) -> int {
    (current, next_id) = (merged(e, {"id": next_id}), next_id + 1);
    emit();
    return current["id"];
}

def updatePromotionToast(id: any, patch: any) {
    if not nil(current) and current["id"] == id {
        current = merged(current, patch);
        emit();
    }
}

def dismissPromotionToast(id: any = None) {
    if not nil(current) and (id is None or current["id"] == id) {
        current = NULL;
        emit();
    }
}
