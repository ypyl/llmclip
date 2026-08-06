#Requires AutoHotkey 2.0
#Include ..\..\Lib\Json.ahk

class SystemPrompts {
    prompts := Map()
    static PROMPTS_DIR := "prompts"
    static DEFAULT_NAME := "_"

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

    UpdatePromptValue(name, newValue) {
        if (!this.prompts.Has(name)) {
            return false
        }

        Loop Files, SystemPrompts.PROMPTS_DIR . "\*.json" {
            try {
                parsed := JSON.LoadFile(A_LoopFilePath)
                if (parsed.Has(name)) {
                    ; Update the value in the object
                    parsed[name]["value"] := newValue
                    
                    ; Convert back to JSON string and write to file
                    JSON.DumpFile(parsed, A_LoopFilePath, 2, "UTF-8")
                    
                    ; Update the in-memory cache
                    this.prompts[name]["value"] := newValue
                    return true
                }
            }
        }
        return false
    }

    GetToolAutoApprovalPatterns(name) {
        if (!this.prompts.Has(name)) {
            return Map()
        }
        
        prompt := this.prompts[name]
        patterns := Map()
        
        ; Look for tools.{toolName}.{paramName} keys
        for key, value in prompt {
            if (SubStr(key, 1, 6) = "tools.") {
                parts := StrSplit(key, ".")
                if (parts.Length = 3) {
                    toolName := parts[2]
                    paramName := parts[3]
                    
                    if (!patterns.Has(toolName)) {
                        patterns[toolName] := Map()
                    }
                    patterns[toolName][paramName] := value
                }
            }
        }
        
        return patterns
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
