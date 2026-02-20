#Include UIConfig.ahk

class PromptView {
    promptEdit := ""
    systemPromptCombo := ""
    askButton := ""

    Create(gui, window, systemPromptNames, currentSystemPromptIndex, settingsController, rootController) {
        this.promptEdit := gui.Add("Edit", "vPromptEdit x" UIConfig.promptEditX " y" UIConfig.promptEditY " w" UIConfig.promptEditWidth " h" UIConfig.promptEditHeight " Multi WantReturn", "")
        this.promptEdit.OnEvent("Change", ObjBindMethod(window, "OnPromptChange"))

        this.systemPromptCombo := gui.Add("DropDownList", "x" UIConfig.systemPromptX " y" (UIConfig.systemPromptY + 2) " w" UIConfig.systemPromptWidth " vSystemPrompt", systemPromptNames)
        this.systemPromptCombo.Value := currentSystemPromptIndex
        this.systemPromptCombo.OnEvent("Change", ObjBindMethod(settingsController, "SystemPromptChanged"))

        this.askButton := gui.Add("Button", "x" UIConfig.askLLMX " y" UIConfig.askLLMY " w" UIConfig.askLLMWidth " vAskLLM", "Ask LLM")
        this.askButton.OnEvent("Click", ObjBindMethod(rootController, "AskToLLM"))
    }

    GetValue() => this.promptEdit.Value
    SetValue(text) => this.promptEdit.Value := text
    Clear() => this.promptEdit.Value := ""
    
    GetSystemPromptValue() => this.systemPromptCombo.Value
    SetSystemPromptValue(value) => this.systemPromptCombo.Value := value
    ClearSystemPrompt() => this.systemPromptCombo.Delete()
    AddSystemPrompts(items) => this.systemPromptCombo.Add(items)
    SetSystemPromptEnabled(enabled) => this.systemPromptCombo.Enabled := enabled

    SetAskButtonText(text) => this.askButton.Text := text
    SetAskButtonEnabled(enabled) => this.askButton.Enabled := enabled
    
    Move(width, height) {
        if (!this.promptEdit)
            return
        promptEditHeight := height - UIConfig.promptEditY - UIConfig.bottomControlsHeight
        this.promptEdit.Move(UIConfig.promptEditX, UIConfig.promptEditY, UIConfig.promptEditWidth, promptEditHeight)
        
        bottomY := height - 35
        this.systemPromptCombo.Move(UIConfig.systemPromptX, bottomY + 2)
        this.askButton.Move(UIConfig.askLLMX, bottomY)
    }
}
