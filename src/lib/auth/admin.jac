def isAdmin(user: any) -> bool {
    return user["role"] == "admin";
}

def assertAdmin(user: any) {
    if not isAdmin(user) {
        raise new(globalThis.Error, "Forbidden");
    }
}

"""The primary admin is the single account created during setup. Only it can
manage other admins and reach owner-only administration pages."""
def isPrimaryAdmin(user: any) -> any {
    return isAdmin(user) and user["isPrimaryAdmin"];
}

def assertPrimaryAdmin(user: any) {
    if not isPrimaryAdmin(user) {
        raise new(globalThis.Error, "Forbidden");
    }
}

"""Domains can be managed by the primary admin or an admin the primary granted it to."""
def canManageDomains(user: any) -> any {
    return isPrimaryAdmin(user) or (isAdmin(user) and user["canManageDomains"]);
}

"""User accounts can be managed by the primary admin or an admin the primary granted it to."""
def canManageUsers(user: any) -> any {
    return isPrimaryAdmin(user) or (isAdmin(user) and user["canManageUsers"]);
}

"""Only the primary admin can manage another administrator's account."""
def canManageUserAccount(user: any, account: any) -> any {
    return isPrimaryAdmin(user)
        or (canManageUsers(user) and account["role"] == "user" and not account["isPrimaryAdmin"]);
}
