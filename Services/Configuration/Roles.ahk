#Requires AutoHotkey 2.0
#Include <Json>

class Roles {
    roles := Map()
    ; DISABLED: Role-based prompt filtering is disabled
    ; All providers now have access to all system prompts by default
    ; To re-enable role-based filtering, set ROLES_DISABLED := false
    ROLES_DISABLED := true

    __New() {
        this.Reload()
    }

    Reload() {
        if (FileExist("roles.json")) {
            this.roles := JSON.LoadFile("roles.json")
        } else {
            this.roles := Map()
        }
    }

    GetPromptsForProvider(providerName) {
        ; DISABLED: Returning empty array to indicate all prompts should be used
        ; When ROLES_DISABLED is true, the caller should fetch all system prompts
        if (!this.ROLES_DISABLED) {
            ; OLD LOGIC (disabled):
            ; if (this.roles.Has(providerName)) {
            ;     return this.roles[providerName]
            ; }
            ; return []
        }
        return []
    }
}
