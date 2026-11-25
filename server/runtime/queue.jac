# The Queue API with an in-process consumer, retrying as wrangler.jsonc does (3 retries, 10 s apart).
# Jobs live in memory; inbound mail is on disk first, and the raw-mail sweeper clears lost ones in 24 h.
obj InProcessQueue(globalThis.Object) {
    def init(name: any, options: any = None) {
        super.init();
        (self.consumer, self.name, self.maxRetries) = (NULL, name, dig(options, ["maxRetries"], 3));
        self.timers = new(globalThis.Set);
    }

    def setConsumer(consumer: any) {
        self.consumer = consumer;
    }

    def send(body: any, options: any = None) -> any {
        delay = dig(options, ["delaySeconds"], 0) * 1000;
        return globalThis.Promise.resolve(self.schedule({"body": body, "attempts": 0}, delay));
    }

    def sendBatch(messages: any) -> any {
        for m in globalThis.Array.from(messages) {
            self.send(m["body"], record({"delaySeconds": m["delaySeconds"]}));
        }
        return globalThis.Promise.resolve();
    }

    def metrics -> any {
        return globalThis.Promise.resolve(record({"backlogCount": self.timers.size}));
    }

    def schedule(pending: any, delayMs: any) {
        timer: any = None;
        fire = lambda -> any { [self.timers.delete(timer), promise(self.deliver(pending))] };
        timer = globalThis.setTimeout(fire, delayMs);
        self.timers.add(timer);
    }

    async def deliver(pending: any) {
        if not self.consumer {
            self.schedule(pending, 1000);
            return;
        }
        try {
            await self.consumer(pending["body"]);
        } except Exception as e {
            err: any = e;
            (body, tries) = (pending["body"], pending["attempts"]);
            globalThis.console.error(f"Queue {self.name}: job failed", getattr(err, "js", err));
            if tries < self.maxRetries {
                self.schedule({"body": body, "attempts": tries + 1}, 10000);
            } else {
                retries = globalThis.String(self.maxRetries);
                globalThis.console.error(
                    f"Queue {self.name}: giving up after {retries} retries", body
                );
            }
        }
    }

    def stop {
        self.timers.forEach(lambda (timer: any) -> any { globalThis.clearTimeout(timer) });
        self.timers.clear();
    }
}

def openQueue(name: str) -> any {
    return InProcessQueue(name);
}
