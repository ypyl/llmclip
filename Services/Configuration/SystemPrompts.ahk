#Requires AutoHotkey 2.0
#Include ..\..\Lib\Json.ahk

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
        ; Ensure "Default" is first
        for i, name in names {
            if (name = "Default") {
                names.RemoveAt(i)
                names.InsertAt(1, "Default")
                break
            }
        }
        return names
    }
}
