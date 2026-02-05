#Requires AutoHotkey 2.0
#Include <Json>

class Providers {
    providers := Map()

    __New() {
        this.Reload()
    }

    Reload() {
        if (FileExist("providers.json")) {
            this.providers := JSON.LoadFile("providers.json")
        } else {
            this.providers := Map()
        }
    }

    Get(name) {
        if (this.providers.Has(name)) {
            return this.providers[name]
        }
        return Map()
    }
    
    GetAll() {
        return this.providers
    }
    
    GetNames() {
        names := []
        for name in this.providers {
            names.Push(name)
        }
        return names
    }
}
