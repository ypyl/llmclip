; UI Builder - Helper functions for creating UI sections
#Include UIConfig.ahk

class UIBuilder {
    static CreateMenuBar(gui, controller, llmTypes, currentLLMTypeIndex, menuController, conversationController) {
        FileMenu := Menu()
        FileMenu.Add("Save Conversation", ObjBindMethod(conversationController, "SaveConversation"))
        FileMenu.Add("Load Conversation", ObjBindMethod(conversationController, "LoadConversation"))
        FileMenu.Add()  ; Separator
        FileMenu.Add("Reload Settings", ObjBindMethod(conversationController, "ReloadSettings"))
        FileMenu.Add()  ; Separator
        FileMenu.Add("Exit", ObjBindMethod(controller, "ExitApplication"))

        ModelMenu := Menu()
        for index, modelName in llmTypes {
            ModelMenu.Add(modelName, ObjBindMethod(menuController, "SelectModel"))
        }

        ; Get current model name for menu label
        currentModelName := "Model: " . llmTypes[currentLLMTypeIndex]

        ; Set initial checkmark in Model menu
        for index, modelName in llmTypes {
            if (index = currentLLMTypeIndex) {
                ModelMenu.Check(modelName)
            }
        }

        ; Create Answer Size menu
        AnswerSizeMenu := Menu()
        AnswerSizeMenu.Add("Small", ObjBindMethod(menuController, "SelectAnswerSize"))
        AnswerSizeMenu.Add("Default", ObjBindMethod(menuController, "SelectAnswerSize"))
        AnswerSizeMenu.Add("Long", ObjBindMethod(menuController, "SelectAnswerSize"))

        ; Set initial checkmark (Default = index 2)
        AnswerSizeMenu.Check("Default")

        ; Create History menu
        HistoryMenu := Menu()
        HistoryMenu.Add("Compress", ObjBindMethod(conversationController, "CompressHistory"))
        HistoryMenu.Add("Extract Notes", ObjBindMethod(conversationController, "ExtractLearnings"))

        ; Create Mode menu
        ModeMenu := Menu()
        ModeMenu.Add("Batch Mode", ObjBindMethod(controller, "ToggleBatchMode"))

        MyMenuBar := MenuBar()
        MyMenuBar.Add("&File", FileMenu)
        MyMenuBar.Add("History", HistoryMenu)
        MyMenuBar.Add("Mode", ModeMenu)
        
        ; Create Tools menu
        ToolsMenu := Menu()
        ToolsMenu.Add("PowerShell", ObjBindMethod(menuController, "ToggleTool", "powerShellTool"))
        ToolsMenu.Add("File System", ObjBindMethod(menuController, "ToggleTool", "fileSystemTool"))
        ToolsMenu.Add("Web Search", ObjBindMethod(menuController, "ToggleTool", "webSearch"))
        ToolsMenu.Add("Web Fetch", ObjBindMethod(menuController, "ToggleTool", "webFetch"))
        MyMenuBar.Add("Tools", ToolsMenu)

        MyMenuBar.Add("Answer Size", AnswerSizeMenu)
        MyMenuBar.Add(currentModelName, ModelMenu)  ; Use model name instead of "&Model"
        gui.MenuBar := MyMenuBar
        
        ; Initialize controller's current model name to match the menu
        controller.currentModelName := currentModelName

        return {menuBar: MyMenuBar, modelMenu: ModelMenu, historyMenu: HistoryMenu, toolsMenu: ToolsMenu, modeMenu: ModeMenu}  ; Return menuBar, modelMenu, historyMenu, toolsMenu and modeMenu
    }

    static CreateTopControls(gui, sessionNames, currentSessionIndex, isRecording, controller, conversationController) {
        ; Add session selector
        sessionCombo := gui.Add("DropDownList", "x10 y12 w70 vSessionSelect", sessionNames)
        sessionCombo.Value := currentSessionIndex
        sessionCombo.OnEvent("Change", ObjBindMethod(conversationController, "SessionChanged"))

        ; Add record button
        recordButtonTitle := isRecording ? "Stop" : "Record"
        recordButton := gui.Add("Button", "x90 y10 w90 vRecordButton", recordButtonTitle)
        recordButton.OnEvent("Click", ObjBindMethod(controller, "ToggleRecording"))

        ; Add reset button
        resetButton := gui.Add("Button", "x300 y10 w90", "Reset All")
        resetButton.OnEvent("Click", ObjBindMethod(conversationController, "ResetAll"))
    }

    static CreateContextSection(gui, contextViewController) {
        ; Add context list with reduced height - ListView with Checkboxes
        contextBox := gui.Add("ListView", "vContextBox x10 y40 w380 h150 Checked -Hdr", ["Item"]) ; -Hdr to hide header
        contextBox.OnEvent("ItemSelect", ObjBindMethod(contextViewController, "ContextBoxSelect"))
        contextBox.OnEvent("DoubleClick", ObjBindMethod(contextViewController, "ContextBoxDoubleClick"))
        
        ; LVN_ITEMCHANGED = -101
        contextBox.OnNotify(-101, (ctrl, lParam) => contextViewController.view.OnContextBoxNotify(ctrl, lParam))
        ; We will populate it in ContextViewController.UpdateContextView

        ; Context buttons
        deleteButton := gui.Add("Button", "x10 y190 w120", "Delete Selected")
        deleteButton.OnEvent("Click", ObjBindMethod(contextViewController, "DeleteSelected"))

        clearSelectionButton := gui.Add("Button", "x140 y190 w120", "Reset Selection")
        clearSelectionButton.OnEvent("Click", ObjBindMethod(contextViewController, "ResetSelection"))

        clearAllButton := gui.Add("Button", "x270 y190 w120", "Clear Context")
        clearAllButton.OnEvent("Click", ObjBindMethod(contextViewController, "ClearAllContext"))
    }

    static CreateChatHistorySection(gui, historyViewController) {
        ; Add ListView for chat history
        chatHistory := gui.Add("ListView", "vChatHistory x10 y220 w380 h150 NoSort", ["Role", "Text", "⏱️", "Tokens"])
        chatHistory.ModifyCol(1, 30)  ; Role column width
        chatHistory.ModifyCol(2, 250) ; Text column width
        chatHistory.ModifyCol(3, 50)  ; Time column width
        chatHistory.ModifyCol(4, 50)  ; Tokens column width
        chatHistory.OnEvent("ItemSelect", ObjBindMethod(historyViewController, "ChatHistorySelect"))

        ; Chat history buttons
        deleteMessageButton := gui.Add("Button", "x10 y375 w120", "Delete Selected")
        deleteMessageButton.OnEvent("Click", ObjBindMethod(historyViewController, "DeleteSelectedMessage"))

        chatMessageButton := gui.Add("Button", "vChatMessageActionButton x140 y375 w120 Hidden", "Copy")
        chatMessageButton.OnEvent("Click", ObjBindMethod(historyViewController, "CopySelectedMessage"))

        clearHistoryButton := gui.Add("Button", "x270 y375 w120", "Clear History")
        clearHistoryButton.OnEvent("Click", ObjBindMethod(historyViewController, "ClearChatHistory"))
    }


    static CreatePromptSection(gui, window) {
        ; Prompt edit control
        promptEdit := gui.Add("Edit", "vPromptEdit x" UIConfig.promptEditX " y" UIConfig.promptEditY " w" UIConfig.promptEditWidth " h" UIConfig.promptEditHeight " Multi WantReturn", "")
        promptEdit.OnEvent("Change", ObjBindMethod(window, "OnPromptChange"))
    }

    static CreateBottomControls(gui, systemPromptNames, currentSystemPromptIndex, controller) {
        ; PowerShell tool checkbox and icon removed

        ; Add system prompt selector
        systemPromptCombo := gui.Add("DropDownList", "x" UIConfig.systemPromptX " y" (UIConfig.systemPromptY + 2) " w" UIConfig.systemPromptWidth " vSystemPrompt", systemPromptNames)
        systemPromptCombo.Value := currentSystemPromptIndex
        systemPromptCombo.OnEvent("Change", ObjBindMethod(controller, "SystemPromptChanged"))

        ; Add Ask LLM button
        askButton2 := gui.Add("Button", "x" UIConfig.askLLMX " y" UIConfig.askLLMY " w" UIConfig.askLLMWidth " vAskLLM", "Ask LLM")
        askButton2.OnEvent("Click", ObjBindMethod(controller, "AskToLLM"))

        return askButton2
    }

    static CreateResponseArea(gui) {
        responseCtr := gui.Add("Edit", "vResponseCtr x" UIConfig.responseCtrX " y" UIConfig.responseCtrY " w" UIConfig.responseCtrWidth " h" UIConfig.responseCtrHeight " -VScroll", "")
        return responseCtr
    }

    static GuiResize(thisGui, MinMax, Width, Height, controller) {
        if (MinMax = -1)  ; If window is minimized
            return

        ; Resize the ResponseCtr control
        thisGui["ResponseCtr"].Move(UIConfig.responseCtrX, UIConfig.responseCtrY, Width - 410, Height - 20)

        ; Resize the WebView2 control to match ResponseCtr
        hCtrl := thisGui["ResponseCtr"].Hwnd
        rect := Buffer(16, 0)  ; RECT: left, top, right, bottom
        DllCall("GetClientRect", "ptr", hCtrl, "ptr", rect)

        widthResponseCtr := NumGet(rect, 8, "Int")   ; right
        heightResponseCtr := NumGet(rect, 12, "Int") ; bottom
        ; Set bounds relative to the ResponseCtr — top-left is (0,0)
        wvRect := Buffer(16, 0)
        NumPut("Int", 0, wvRect, 0)                          ; left
        NumPut("Int", 0, wvRect, 4)                          ; top
        NumPut("Int", widthResponseCtr, wvRect, 8)           ; right
        NumPut("Int", heightResponseCtr, wvRect, 12)         ; bottom
        if controller.view.guiShown {
            controller.webViewManager.Resize(wvRect)
        }

        ; Resize the prompt edit control
        promptEditHeight := Height - UIConfig.promptEditY - UIConfig.bottomControlsHeight
        thisGui["PromptEdit"].Move(UIConfig.promptEditX, UIConfig.promptEditY, UIConfig.promptEditWidth, promptEditHeight)

        ; Move bottom controls
        bottomY := Height - 35  ; 35 pixels from bottom
        thisGui["SystemPrompt"].Move(UIConfig.systemPromptX, bottomY + 2)
        thisGui["AskLLM"].Move(UIConfig.askLLMX, bottomY)
    }

}
