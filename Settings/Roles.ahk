#Requires AutoHotkey 2.0
#Include <Json>

class Roles {
    roles := Map()

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
        if (this.roles.Has(providerName)) {
            return this.roles[providerName]
        }
        return []
    }
}
