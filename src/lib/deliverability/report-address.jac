import from "drizzle-orm" { and as all_of, eq }

"""The one address DMARC reports go to on every domain that turned reporting on. It is not a mailbox."""
glob REPORT_ADDRESS_LOCAL_PART: str = "mailflare-reports";

def reportAddress(hostname: any) -> str {
    return f"{REPORT_ADDRESS_LOCAL_PART}@{hostname.toLowerCase()}";
}

"""
The domain a recipient address belongs to when it is the reserved report address of a domain with reporting
on, otherwise null. Anything else (including a domain that never enabled reporting) routes as usual, so the
reserved address never swallows normal mail. Reads as "off" before the migration is applied.
"""
async def matchReportAddress(env: any, to: any) -> any {
    address: any = to.trim().toLowerCase();
    split: int = address.lastIndexOf("@");
    if split < 0 or address.slice(0, split) != REPORT_ADDRESS_LOCAL_PART {
        return NULL;
    }
    hostname = address.slice(split + 1);
    try {
        rows = await getDb(env).select({"domainId": domains.id}).from(domains).innerJoin(
            domainDeliverability, eq(domainDeliverability.domainId, domains.id)
        ).where(
            all_of(eq(domains.hostname, hostname), eq(domainDeliverability.reportsEnabled, True))
        ).limit(1);
        return {"domainId": rows[0].domainId, "hostname": hostname} if rows.length else NULL;
    } except Exception as e {
        if isMissingTableError(thrown(e)) {
            return NULL;
        }
        raise thrown(e);
    }
}

"""
True when `localPart` is the reserved report local part and reporting is on for the domain, so no mailbox or alias may
take it (the address is intercepted before any mailbox, so it would silently receive nothing). Reads as false before
the migration is applied.
"""
async def isReportAddressReserved(env: any, domainId: str, localPart: any) -> bool {
    if localPart.trim().toLowerCase() != REPORT_ADDRESS_LOCAL_PART {
        return False;
    }
    try {
        rows = await getDb(env).select({"domainId": domainDeliverability.domainId}).from(
            domainDeliverability
        ).where(
            all_of(
                eq(domainDeliverability.domainId, domainId),
                eq(domainDeliverability.reportsEnabled, True),
            ),
        ).limit(1);
        return rows.length > 0;
    } except Exception as e {
        if isMissingTableError(thrown(e)) {
            return False;
        }
        raise thrown(e);
    }
}

"""What JavaScript threw: a caught exception is Jac's wrapper of it, and raising the wrapper would hand callers another error."""
def:priv thrown(e: any) -> any {
    return getattr(e, "js", e);
}
