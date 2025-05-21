#Requires AutoHotkey 2.0
#Include <Json>

class AppSettings {
    providers := Map()
    selectedLLMType := ""
    selectedLLMTypeIndex := 1
    llmTypes := []

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
                this.selectedLLMTypeIndex := A_Index
            }
        }
    }

    GetSelectedSettings(llmIndex) {
        selectedLLMType := this.llmTypes[llmIndex]
        settings := this.providers[selectedLLMType]
        settings["type"] := selectedLLMType  ; Add type to settings
        return settings
    }

    GetSystemPromptValue(llmIndex, promptIndex) {
        defaultPrompt := "You are a helpful assistant. Be concise and direct in your responses."
        settings := this.GetSelectedSettings(llmIndex)
        if (prompts := settings.Get("system_prompts", [])) {
            return prompts[promptIndex]["value"]
        }
        return defaultPrompt
    }

    GetInputTemplate(llmIndex, promptIndex) {
        defaultPrompt := ""
        settings := this.GetSelectedSettings(llmIndex)
        if (prompts := settings.Get("system_prompts", [])) {
            if (inputTempalte := prompts[promptIndex].Get("input_template", "")) {
                return inputTempalte
            }
        }
        return defaultPrompt
    }

    GetContext(llmIndex, promptIndex) {
        settings := this.GetSelectedSettings(llmIndex)
        if (prompts := settings.Get("system_prompts", "")) {
            if (context := prompts[promptIndex].Get("context", [])) {
                return context
            }
        }
        return []
    }

    GetSystemPromptNames(llmIndex) {
        settings := this.GetSelectedSettings(llmIndex)
        names := []
        if (prompts := settings.Get("system_prompts", "")) {
            for prompt in prompts {
                names.Push(prompt["name"])
            }
            return names
        }
        return []
    }
}
