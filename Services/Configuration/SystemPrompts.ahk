#Requires AutoHotkey 2.0
#Include ..\..\Lib\Json.ahk

class SystemPrompts {
    prompts := Map()
    static PROMPTS_DIR := "prompts"
    static DEFAULT_NAME := "default"

    __New() {
        this.Reload()
    }

    Reload() {
        this.prompts := Map()

        if (!DirExist(SystemPrompts.PROMPTS_DIR)) {
            DirCreate(SystemPrompts.PROMPTS_DIR)
        }

        hasFiles := false
        Loop Files, SystemPrompts.PROMPTS_DIR . "\*.json" {
            hasFiles := true
            break
        }

        if (!hasFiles) {
            initJson := '{`n  "' . SystemPrompts.DEFAULT_NAME . '": {`n    "value": "You are a helpful assistant. Be concise and direct in your responses. User name is Yauhen.\nInstructions:\n- Zero tolerance for excuses, rationalizations or bullshit\n- Pure focus on deconstructing problems to fundamental truths\n- Relentless drive for actionable solutions and results\n- No regard for conventional wisdom or \"common knowledge\"\n- Absolute commitment to intellectual honesty\nCONSTRAINTS:\n- No motivational fluff\n- No vague advice\n- No social niceties\n- No unnecessary context\n- No theoretical discussions without immediate application"`n  }`n}'
            FileAppend(initJson, SystemPrompts.PROMPTS_DIR . "\_init.json", "UTF-8")
        }

        Loop Files, SystemPrompts.PROMPTS_DIR . "\*.json" {
            try {
                parsed := JSON.LoadFile(A_LoopFilePath)
                for key, value in parsed {
                    this.prompts[key] := value
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
            if (name = SystemPrompts.DEFAULT_NAME) {
                names.RemoveAt(i)
                names.InsertAt(1, SystemPrompts.DEFAULT_NAME)
                break
            }
        }
        return names
    }
}
