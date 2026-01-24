#Requires AutoHotkey 2.0
#Include <Json>

class SystemPrompts {
    prompts := Map()

    __New() {
        this.Reload()
    }

    Reload() {
        if (FileExist("system_prompts.json")) {
            this.prompts := JSON.LoadFile("system_prompts.json")
        } else {
            this.prompts := Map()
        }
    }

    Get(name) {
        if (this.prompts.Has(name)) {
            return this.prompts[name]
        }
        return Map()
    }

    GetNames() {
        names := []
        for name in this.prompts {
            names.Push(name)
        }
        return names
    }
}
