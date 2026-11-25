"""Only move the reader for the message whose delivery state changed."""
def resolveSendViewRoute(pathname: any, messageId: any, status: any) -> any {
    (sched, sent) = (f"/scheduled/{messageId}", f"/sent/{messageId}");
    routes = {("draft", sched): "/scheduled", ("draft", sent): "/sent", ("sent", sched): sent};
    return either(routes.get((status, pathname)), NULL);
}
