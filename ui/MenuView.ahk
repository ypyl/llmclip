class MenuView {
    menuBar := ""
    sessionMenu := ""
    sessionCallback := ""
    modelMenu := ""
    historyMenu := ""
    toolsMenu := ""
    modeMenu := ""
    answerSizeMenu := ""
    currentModelLabel := ""
    currentSessionLabel := ""

    static ToolMapping := [
        { id: PowerShellTool.TOOL_NAME, label: "PowerShell", stateKey: PowerShellTool.TOOL_NAME },
        { id: FileSystemTool.TOOL_NAME, label: "File System", stateKey: FileSystemTool.TOOL_NAME },
        { id: WebSearchTool.TOOL_NAME, label: "Web Search",  stateKey: WebSearchTool.TOOL_NAME },
        { id: WebFetchTool.TOOL_NAME, label: "Web Fetch",   stateKey: WebFetchTool.TOOL_NAME },
        { id: MarkdownNewTool.TOOL_NAME, label: "Read URL Markdown", stateKey: MarkdownNewTool.TOOL_NAME }
    ]

    Create(gui, rootController, settingsController, llmTypes, currentLLMTypeIndex, sessionNames, currentSessionIndex) {
        FileMenu := Menu()
        FileMenu.Add("Save Conversation", ObjBindMethod(rootController, "SaveConversation"))
        FileMenu.Add("Load Conversation", ObjBindMethod(rootController, "LoadConversation"))
        FileMenu.Add()
        FileMenu.Add("Reload Settings", ObjBindMethod(settingsController, "ReloadSettings"))
        FileMenu.Add()
        FileMenu.Add("Exit", ObjBindMethod(rootController, "ExitApplication"))

        this.modelMenu := Menu()
        for index, modelName in llmTypes {
            this.modelMenu.Add(modelName, ObjBindMethod(settingsController, "SelectModel"))
            if (index = currentLLMTypeIndex) {
                this.modelMenu.Check(modelName)
            }
        }

        currentModelLabel := llmTypes[currentLLMTypeIndex]
        this.currentModelLabel := currentModelLabel

        this.sessionMenu := Menu()
        this.sessionCallback := ObjBindMethod(settingsController, "SelectSession")
        for index, sessionName in sessionNames {
            itemLabel := index . ": " . sessionName
            this.sessionMenu.Add(itemLabel, this.sessionCallback)
            if (index = currentSessionIndex) {
                this.sessionMenu.Check(itemLabel)
            }
        }

        currentSessionLabel := currentSessionIndex . ": " . sessionNames[currentSessionIndex]
        this.currentSessionLabel := currentSessionLabel

        this.answerSizeMenu := Menu()
        this.answerSizeMenu.Add("Small", ObjBindMethod(settingsController, "SelectAnswerSize"))
        this.answerSizeMenu.Add("Default", ObjBindMethod(settingsController, "SelectAnswerSize"))
        this.answerSizeMenu.Add("Long", ObjBindMethod(settingsController, "SelectAnswerSize"))
        this.answerSizeMenu.Check("Default")

        this.historyMenu := Menu()
        this.historyMenu.Add("Compress", ObjBindMethod(rootController, "CompressHistory"))
        this.historyMenu.Add("Extract Notes", ObjBindMethod(rootController, "ExtractLearnings"))

        this.modeMenu := Menu()
        this.modeMenu.Add("Batch Mode", ObjBindMethod(rootController, "ToggleBatchMode"))

        this.toolsMenu := Menu()
        for toolInfo in MenuView.ToolMapping {
            this.toolsMenu.Add(toolInfo.label, ObjBindMethod(settingsController, "ToggleTool", toolInfo.id))
        }

        this.menuBar := MenuBar()
        this.menuBar.Add("&File", FileMenu)
        this.menuBar.Add(this.currentSessionLabel, this.sessionMenu)
        this.menuBar.Add("History", this.historyMenu)
        this.menuBar.Add("Mode", this.modeMenu)
        this.menuBar.Add("Tools", this.toolsMenu)
        this.menuBar.Add("Answer Size", this.answerSizeMenu)
        this.menuBar.Add(currentModelLabel, this.modelMenu)

        gui.MenuBar := this.menuBar
    }

    UpdateBatchMode(enabled) {
        if (!this.modeMenu)
            return
        if (enabled) {
            this.modeMenu.Check("Batch Mode")
        } else {
            this.modeMenu.Uncheck("Batch Mode")
        }
    }

    UpdateModelMenu(selectedIndex, modelNames) {
        if (!this.modelMenu)
            return

        currentModelName := modelNames[selectedIndex]
        currentModelLabel := currentModelName

        ; Update checkmarks
        for index, modelName in modelNames {
            if (index = selectedIndex) {
                this.modelMenu.Check(modelName)
            } else {
                this.modelMenu.Uncheck(modelName)
            }
        }

        ; Renaming the menu bar item
        try {
            if (this.currentModelLabel != currentModelLabel) {
                this.menuBar.Rename(this.currentModelLabel, currentModelLabel)
                this.currentModelLabel := currentModelLabel
            }
        }
    }

    UpdateAnswerSizeMenu(selectedSize) {
        if (!this.answerSizeMenu)
            return

        for _, size in ["Small", "Default", "Long"] {
            if (size = selectedSize) {
                this.answerSizeMenu.Check(size)
            } else {
                this.answerSizeMenu.Uncheck(size)
            }
        }
    }

    UpdateToolsMenu(toolStates) {
        if (!this.toolsMenu)
            return

        for toolInfo in MenuView.ToolMapping {
            if (toolStates.HasProp(toolInfo.stateKey) && toolStates.%toolInfo.stateKey%) {
                this.toolsMenu.Check(toolInfo.label)
            } else {
                this.toolsMenu.Uncheck(toolInfo.label)
            }
        }
    }

    UpdateCompressionState(isEnabled) {
        if (!this.historyMenu)
            return

        if (isEnabled) {
            this.historyMenu.Enable("Compress")
        } else {
            this.historyMenu.Disable("Compress")
        }
    }

    RebuildModelMenu(modelNames, selectModelCallback) {
        if (!this.modelMenu)
            return

        this.modelMenu.Delete()
        for index, modelName in modelNames {
            this.modelMenu.Add(modelName, selectModelCallback)
        }
    }

    UpdateSessionMenu(selectedIndex, sessionNames) {
        if (!this.sessionMenu)
            return

        currentSessionLabel := selectedIndex . ": " . sessionNames[selectedIndex]

        ; Rebuild items with index-prefixed labels to ensure uniqueness
        this.sessionMenu.Delete()
        for index, sessionName in sessionNames {
            itemLabel := index . ": " . sessionName
            this.sessionMenu.Add(itemLabel, this.sessionCallback)
        }

        ; Update checkmarks
        for index, sessionName in sessionNames {
            itemLabel := index . ": " . sessionName
            if (index = selectedIndex) {
                this.sessionMenu.Check(itemLabel)
            } else {
                this.sessionMenu.Uncheck(itemLabel)
            }
        }

        ; Rename the menu bar label
        try {
            if (this.currentSessionLabel != currentSessionLabel) {
                this.menuBar.Rename(this.currentSessionLabel, currentSessionLabel)
                this.currentSessionLabel := currentSessionLabel
            }
        }
    }

    RebuildSessionMenu(sessionNames, selectSessionCallback) {
        if (!this.sessionMenu)
            return

        this.sessionMenu.Delete()
        for index, sessionName in sessionNames {
            this.sessionMenu.Add(index . ": " . sessionName, selectSessionCallback)
        }
    }

    CheckModel(name) => this.modelMenu.Check(name)
    UncheckModel(name) => this.modelMenu.Uncheck(name)
    CheckSession(name) => this.sessionMenu.Check(name)
    UncheckSession(name) => this.sessionMenu.Uncheck(name)
    RenameMenu(oldName, newName) => this.menuBar.Rename(oldName, newName)
}
