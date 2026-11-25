# Per-user WebSocket fan-out in place of the RealtimeHub Durable Object (`namespace()` is its stub).
obj RealtimeHubRegistry(globalThis.Object) {
    def init {
        super.init();
        (self.sockets, self.env) = (new(globalThis.Map), NULL);
    }

    def bindEnv(env: any) {
        self.env = env;
    }

    def attach(userId: str, ws: any) {
        m = self.sockets;
        g = either(m.get(userId), new(globalThis.Set));
        g.add(ws);
        m.set(userId, g);
        ws.on("message", lambda (d: any) -> any { heard(self, userId, ws, d.toString()) });
        # ws emits "error" for malformed frames; without a listener it is thrown.
        ws.on("error", lambda (e: any) -> any { ws.terminate() });
        ws.on("close", lambda (e: any) -> any { [g.delete(ws), g.size == 0 and m.delete(userId)] });
    }

    def notify(userId: str, payload: any) {
        message = globalThis.JSON.stringify(payload);
        for socket in globalThis.Array.from(either(self.sockets.get(userId), [])) {
            try {
                socket.send(message);
            } except Exception {
                socket.close(1011, "Delivery failed");
            }
        }
    }

    def connections -> int {
        return sum([group.size for group in globalThis.Array.from(self.sockets.values())]);
    }

    def namespace -> any {
        by_name = lambda (n: any) -> any { stub(self, n) };
        named = lambda (n: any) -> any { record({"toString": lambda -> any { n }, "name": n}) };
        by_id = lambda (id: any) -> any { stub(self, id.toString()) };
        return record({"getByName": by_name, "idFromName": named, "get": by_id});
    }
}

def:priv stub(hub: any, u: any) -> any {
    return record({"fetch": lambda (i: any, o: any) -> any { promise(fetched(hub, u, i, o)) }});
}

def:priv heard(h: any, u: str, s: any, t: str) -> any {
    if t == "ping" {
        return s.send("pong");
    }
    fail = lambda (e: any) -> any { s.close(1011, "Revision lookup failed") };
    try {
        ping = globalThis.JSON.parse(t);
    } except Exception {
        return None;
    }
    if nil(ping) {
        return globalThis.Promise.reject(NULL).catch(fail);
    }
    if globalThis.Object(ping)["type"] == "ping" and h.env {
        promise(answer(h, u, s, globalThis.Object(ping)["revision"])).catch(fail);
    }
}

async def:priv answer(h: any, u: str, s: any, v: any) {
    rev = await getUserMailRevision(h.env, u);
    note = record({"type": "revision", "revision": rev, "changed": v is not NULL and v is not rev});
    s.send(globalThis.JSON.stringify(note));
}

async def:priv fetched(hub: any, userId: any, i: any, o: any) -> any {
    request = i if isinstance(i, globalThis.Request) else new(globalThis.Request, i, o);
    if new(globalThis.URL, request.url).pathname == "/notify" and request.method == "POST" {
        hub.notify(userId, await request.json());
        return new(globalThis.Response, NULL, record({"status": 204}));
    }
    return new(globalThis.Response, "Not found", record({"status": 404}));
}
