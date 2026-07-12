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

    ; ponytail: duplicated from PromptCreatorTool — 5 lines cheaper than new util file
    static SanitizeFileName(name) {
        sanitized := StrLower(name)
        sanitized := RegExReplace(sanitized, "[^a-z0-9\-]", "-")
        sanitized := RegExReplace(sanitized, "-{2,}", "-")
        sanitized := RegExReplace(sanitized, "^-+", "")
        sanitized := RegExReplace(sanitized, "-+$", "")
        return sanitized
    }

    /**
     * Update an existing prompt with partial field updates.
     * Handles inline→file-ref migration, rename, and empty JSON cleanup.
     * @param name - The display name of the prompt to update
     * @param updates - Map with optional keys: new_name, value, input_template, hidden
     * @returns Map with "success" (bool) and "error" or "details" (string)
     */
    UpdatePrompt(name, updates) {
        result := Map("success", false, "error", "", "details", "")

        if (!this.prompts.Has(name)) {
            result["error"] := "Prompt '" . name . "' not found."
            return result
        }

        ; Find which JSON file contains this prompt
        sourceJsonPath := ""
        sourceParsed := ""
        Loop Files, SystemPrompts.PROMPTS_DIR . "\*.json" {
            try {
                parsed := JSON.LoadFile(A_LoopFilePath)
                if (parsed.Has(name)) {
                    sourceJsonPath := A_LoopFilePath
                    sourceParsed := parsed
                    break
                }
            }
        }

        if (sourceJsonPath == "") {
            result["error"] := "Prompt '" . name . "' found in memory but not on disk."
            return result
        }

        oldEntry := sourceParsed[name]
        oldValue := oldEntry.Has("value") ? oldEntry["value"] : ""
        isFileRef := (SubStr(oldValue, 1, 2) = ".\\")

        hasNewName := updates.Has("new_name") && updates["new_name"] != ""
        hasValue := updates.Has("value") && updates["value"] != ""
        hasInputTemplate := updates.Has("input_template")
        hasHidden := updates.Has("hidden")

        newName := hasNewName ? updates["new_name"] : name
        newSanitized := SystemPrompts.SanitizeFileName(newName)
        oldSanitized := SystemPrompts.SanitizeFileName(name)

        ; --- RENAME: check for filename collisions ---
        if (hasNewName && newSanitized != oldSanitized) {
            collisionPath := SystemPrompts.PROMPTS_DIR . "\" . newSanitized . ".json"
            if (FileExist(collisionPath)) {
                result["error"] := "Cannot rename: a prompt with sanitized filename '" . newSanitized . "' already exists."
                return result
            }
        }

        ; --- VALUE UPDATE ---
        if (hasValue) {
            newValueText := updates["value"]
            if (isFileRef) {
                ; File-ref: overwrite the .md file
                mdRelPath := SubStr(oldValue, 3)  ; strip ".\"
                mdPath := SystemPrompts.PROMPTS_DIR . "\" . mdRelPath
                try {
                    if (FileExist(mdPath))
                        FileDelete(mdPath)
                    FileAppend(newValueText, mdPath, "UTF-8-RAW")
                } catch as e {
                    result["error"] := "Error writing prompt file: " . e.Message
                    return result
                }
                ; value stays as file-ref, no JSON value change needed
            } else {
                ; Inline → migrate to file-ref
                mdPath := SystemPrompts.PROMPTS_DIR . "\" . oldSanitized . ".md"
                jsonPath := SystemPrompts.PROMPTS_DIR . "\" . oldSanitized . ".json"
                try {
                    if (FileExist(mdPath))
                        FileDelete(mdPath)
                    FileAppend(newValueText, mdPath, "UTF-8-RAW")

                    ; Build new JSON metadata for standalone file
                    newEntry := Map()
                    newEntry["value"] := ".\\" . oldSanitized . ".md"
                    ; Preserve existing metadata
                    if (oldEntry.Has("input_template"))
                        newEntry["input_template"] := oldEntry["input_template"]
                    if (oldEntry.Has("hidden"))
                        newEntry["hidden"] := oldEntry["hidden"]
                    ; Preserve tool auto-approval patterns
                    for k, v in oldEntry {
                        if (SubStr(k, 1, 6) = "tools.")
                            newEntry[k] := v
                    }
                    newJson := Map()
                    newJson[name] := newEntry
                    JSON.DumpFile(newJson, jsonPath, 2, "UTF-8")

                    ; Remove from source JSON
                    sourceParsed.Delete(name)
                    if (sourceParsed.Count > 0) {
                        JSON.DumpFile(sourceParsed, sourceJsonPath, 2, "UTF-8")
                    } else {
                        FileDelete(sourceJsonPath)
                    }
                } catch as e {
                    result["error"] := "Error migrating prompt to file: " . e.Message
                    return result
                }
                isFileRef := true
                oldValue := ".\\" . oldSanitized . ".md"
                oldEntry["value"] := oldValue
            }
        }

        ; --- METADATA UPDATES (input_template, hidden) ---
        needJsonRewrite := false
        if (hasInputTemplate) {
            ; After migration, the prompt may be in a new standalone JSON
            ; Find the current JSON file for this prompt
            currentJsonPath := sourceJsonPath
            currentParsed := ""
            Loop Files, SystemPrompts.PROMPTS_DIR . "\*.json" {
                try {
                    p := JSON.LoadFile(A_LoopFilePath)
                    if (p.Has(name)) {
                        currentJsonPath := A_LoopFilePath
                        currentParsed := p
                        break
                    }
                }
            }
            if (currentParsed != "") {
                if (updates["input_template"] == "") {
                    currentParsed[name].Delete("input_template")
                } else {
                    currentParsed[name]["input_template"] := updates["input_template"]
                }
                JSON.DumpFile(currentParsed, currentJsonPath, 2, "UTF-8")
                this.prompts[name]["input_template"] := updates["input_template"]
            }
        }
        if (hasHidden) {
            currentJsonPath := sourceJsonPath
            currentParsed := ""
            Loop Files, SystemPrompts.PROMPTS_DIR . "\*.json" {
                try {
                    p := JSON.LoadFile(A_LoopFilePath)
                    if (p.Has(name)) {
                        currentJsonPath := A_LoopFilePath
                        currentParsed := p
                        break
                    }
                }
            }
            if (currentParsed != "") {
                if (!updates["hidden"]) {
                    currentParsed[name].Delete("hidden")
                } else {
                    currentParsed[name]["hidden"] := true
                }
                JSON.DumpFile(currentParsed, currentJsonPath, 2, "UTF-8")
                this.prompts[name]["hidden"] := updates["hidden"]
            }
        }

        ; --- RENAME ---
        if (hasNewName) {
            if (newSanitized == oldSanitized) {
                ; Same sanitized filename — just update the display name in JSON
                currentJsonPath := sourceJsonPath
                currentParsed := ""
                Loop Files, SystemPrompts.PROMPTS_DIR . "\*.json" {
                    try {
                        p := JSON.LoadFile(A_LoopFilePath)
                        if (p.Has(name)) {
                            currentJsonPath := A_LoopFilePath
                            currentParsed := p
                            break
                        }
                    }
                }
                if (currentParsed != "") {
                    entryData := currentParsed[name]
                    currentParsed.Delete(name)
                    currentParsed[newName] := entryData
                    JSON.DumpFile(currentParsed, currentJsonPath, 2, "UTF-8")
                }
            } else {
                ; Different sanitized name → new file pair
                ; Find current state after any value/metadata updates
                currentJsonPath := sourceJsonPath
                currentParsed := ""
                Loop Files, SystemPrompts.PROMPTS_DIR . "\*.json" {
                    try {
                        p := JSON.LoadFile(A_LoopFilePath)
                        if (p.Has(name)) {
                            currentJsonPath := A_LoopFilePath
                            currentParsed := p
                            break
                        }
                    }
                }

                if (currentParsed == "") {
                    ; Prompt was migrated inline→file-ref above, find its new JSON
                    newJsonPath := SystemPrompts.PROMPTS_DIR . "\" . oldSanitized . ".json"
                    if (FileExist(newJsonPath)) {
                        try {
                            currentParsed := JSON.LoadFile(newJsonPath)
                            currentJsonPath := newJsonPath
                        }
                    }
                }

                if (currentParsed != "" && currentParsed.Has(name)) {
                    entryData := currentParsed[name]
                    newEntryValue := entryData.Has("value") ? entryData["value"] : ""

                    ; Build new JSON for the renamed prompt
                    newEntry := Map()
                    for k, v in entryData {
                        if (k == "value") {
                            ; Update value ref to new sanitized name
                            if (SubStr(v, 1, 2) = ".\\") {
                                newEntry["value"] := ".\\" . newSanitized . ".md"
                                ; Rename the .md file
                                oldMdPath := SystemPrompts.PROMPTS_DIR . "\" . SubStr(v, 3)
                                newMdPath := SystemPrompts.PROMPTS_DIR . "\" . newSanitized . ".md"
                                if (FileExist(oldMdPath)) {
                                    FileMove(oldMdPath, newMdPath, 1)
                                }
                            } else {
                                newEntry["value"] := ".\\" . newSanitized . ".md"
                                ; Create .md from inline text
                                newMdPath := SystemPrompts.PROMPTS_DIR . "\" . newSanitized . ".md"
                                if (FileExist(newMdPath))
                                    FileDelete(newMdPath)
                                FileAppend(v, newMdPath, "UTF-8-RAW")
                            }
                        } else {
                            newEntry[k] := v
                        }
                    }

                    ; Write new JSON
                    newJson := Map()
                    newJson[newName] := newEntry
                    newJsonPath := SystemPrompts.PROMPTS_DIR . "\" . newSanitized . ".json"
                    JSON.DumpFile(newJson, newJsonPath, 2, "UTF-8")

                    ; Remove old entry from source
                    currentParsed.Delete(name)
                    if (currentParsed.Count > 0) {
                        JSON.DumpFile(currentParsed, currentJsonPath, 2, "UTF-8")
                    } else {
                        FileDelete(currentJsonPath)
                    }
                }
            }
        }

        result["success"] := true
        result["details"] := "Prompt '" . name . "' updated successfully."
        if (hasNewName) {
            result["details"] := "Prompt renamed from '" . name . "' to '" . newName . "'."
        }
        return result
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
