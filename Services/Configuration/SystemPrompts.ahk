#Requires AutoHotkey 2.0
#Include ..\..\Lib\Json.ahk

class SystemPrompts {
    prompts := Map()

    __New() {
        this.Reload()
    }

    Reload() {
        this.prompts := Map()
        if (DirExist("system_prompts")) {
            Loop Files, "system_prompts\*.json" {
                try {
                    parsed := JSON.LoadFile(A_LoopFilePath)
                    for key, value in parsed {
                        this.prompts[key] := value
                    }
                }
            }
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
