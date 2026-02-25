#Include <Json>

class Providers {
    providers := Map()

    __New() {
        this.Reload()
    }

    Reload() {
        this.providers := Map()
        if (DirExist("providers")) {
            Loop Files, "providers\*.json" {
                try {
                    parsed := JSON.LoadFile(A_LoopFilePath)
                    for key, value in parsed {
                        this.providers[key] := value
                    }
                }
            }
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
