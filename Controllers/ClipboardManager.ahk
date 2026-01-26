#Requires AutoHotkey 2.0

class ClipboardManager {
    controller := ""
    sessionManager := ""
    contextManager := ""

    __New(controller, sessionManager, contextManager) {
        this.controller := controller
        this.sessionManager := sessionManager
        this.contextManager := contextManager
    }

    HasVal(haystack, needle) {
        for index, value in haystack {
            if (value = needle)
                return true
        }
        return false
    }

    CheckContentInMessages(messages, newContent) {
        for msg in messages {
            if (InStr(msg.GetText(), newContent))
                return true
        }
        return false
    }

    HasContent(haystack, newContent) {
        if (newContent = "")
            return true

        ; First check exact matches
        if (this.HasVal(haystack, newContent))
            return true

        ; Also check in chat history
        if (this.CheckContentInMessages(this.sessionManager.GetCurrentSessionMessages(), newContent))
            return true

        return false
    }

    ClipChanged(DataType) {
        if (this.controller.TrayManagerValue.isRecording) {
            localTxtFromClipboardArray := this.controller.ClipboardParserValue.Parse()

            ; Add non-duplicate items to context
            context := this.sessionManager.GetCurrentSessionContext()

            for item in localTxtFromClipboardArray {
                ; Add the original item first
                if !this.HasContent(context, item) {
                    context.Push(item)

                    ; PDF processing logic could go here if needed
                }
            }

            ; Update session contexts
            this.sessionManager.SetCurrentSessionContext(context)

            ; Update Context in GUI if shown
            if (this.controller.guiShown) {
                this.controller.ContextViewControllerValue.UpdateContextView()
            }
        }
    }
}
