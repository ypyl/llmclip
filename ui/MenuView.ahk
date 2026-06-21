class MenuView {
    menuBar := ""
    sessionMenu := ""
    sessionCallback := ""
    modelMenu := ""
    toolsMenu := ""
    currentModelLabel := ""
    currentSessionLabel := ""

    Create(gui, rootController, settingsController, llmTypes, currentLLMTypeIndex, sessionNames, currentSessionIndex, toolDefs) {
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

        this.toolsMenu := Menu()
        for def in toolDefs {
            this.toolsMenu.Add(def.label, ObjBindMethod(settingsController, "ToggleTool", def.id))
        }

        this.menuBar := MenuBar()
        this.menuBar.Add("&File", FileMenu)
        this.menuBar.Add(this.currentSessionLabel, this.sessionMenu)
        this.menuBar.Add("Tools", this.toolsMenu)
        this.menuBar.Add(currentModelLabel, this.modelMenu)

        gui.MenuBar := this.menuBar
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

    UpdateToolsMenu(toolStates) {
        if (!this.toolsMenu)
            return

        for item in toolStates {
            if (item.checked) {
                this.toolsMenu.Check(item.label)
            } else {
                this.toolsMenu.Uncheck(item.label)
            }
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
