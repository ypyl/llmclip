class MenuView {
    menuBar := ""
    modelMenu := ""
    historyMenu := ""
    toolsMenu := ""
    modeMenu := ""
    currentModelLabel := ""

    static ToolMapping := [
        { id: "powerShellTool", label: "PowerShell", stateKey: "powerShell" },
        { id: "fileSystemTool", label: "File System", stateKey: "fileSystem" },
        { id: "webSearch",      label: "Web Search",  stateKey: "webSearch" },
        { id: "webFetch",       label: "Web Fetch",   stateKey: "webFetch" },
        { id: "markdownNew",    label: "Markdown New", stateKey: "markdownNew" }
    ]

    Create(gui, rootController, settingsController, llmTypes, currentLLMTypeIndex) {
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

        currentModelLabel := "Model: " . llmTypes[currentLLMTypeIndex]

        AnswerSizeMenu := Menu()
        AnswerSizeMenu.Add("Small", ObjBindMethod(settingsController, "SelectAnswerSize"))
        AnswerSizeMenu.Add("Default", ObjBindMethod(settingsController, "SelectAnswerSize"))
        AnswerSizeMenu.Add("Long", ObjBindMethod(settingsController, "SelectAnswerSize"))
        AnswerSizeMenu.Check("Default")

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
        this.menuBar.Add("History", this.historyMenu)
        this.menuBar.Add("Mode", this.modeMenu)
        this.menuBar.Add("Tools", this.toolsMenu)
        this.menuBar.Add("Answer Size", AnswerSizeMenu)
        this.menuBar.Add(currentModelLabel, this.modelMenu)

        gui.MenuBar := this.menuBar
        this.currentModelLabel := currentModelLabel
        rootController.currentModelName := currentModelLabel
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
        currentModelLabel := "Model: " . currentModelName

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
            ; We need a way to track the previous label to rename it correctly
            ; This is usually handled by a property in MenuView
            if (this.currentModelLabel != currentModelLabel) {
                this.menuBar.Rename(this.currentModelLabel, currentModelLabel)
                this.currentModelLabel := currentModelLabel
            }
        }
    }

    CheckModel(name) => this.modelMenu.Check(name)
    UncheckModel(name) => this.modelMenu.Uncheck(name)
    RenameMenu(oldName, newName) => this.menuBar.Rename(oldName, newName)
}
