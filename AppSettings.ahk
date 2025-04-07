#Requires AutoHotkey 2.0
#Include <Json>

class AppSettings {
    providers := Map()
    selectedLLMType := ""
    llmTypes := []
    selectedIndex := 1

    __New() {
        settings := JSON.LoadFile("settings.json")
        this.providers := Map()
        for provider in settings["providers"] {
            value := settings["providers"][provider]
            this.providers[provider] := Map()
            for k, v in value
                this.providers[provider][k] := v
        }
        this.selectedLLMType := settings["selectedLLMType"]

        ; Initialize LLM types
        this.llmTypes := []
        for key in this.providers {
            this.llmTypes.Push(key)
            if (key = this.selectedLLMType) {
                this.selectedIndex := A_Index
            }
        }
    }

    GetSelectedSettings() {
        selectedLLMType := this.llmTypes[this.selectedIndex]
        settings := this.providers[selectedLLMType]
        settings["type"] := selectedLLMType  ; Add type to settings
        return settings
    }

    GetDefaultSystemPrompt() {
        defaultPrompt := "You are a helpful assistant. Be concise and direct in your responses."
        if (prompt := this.GetSelectedSettings().Get("system_prompt", ""))
            defaultPrompt := prompt
        return defaultPrompt
    }
}
