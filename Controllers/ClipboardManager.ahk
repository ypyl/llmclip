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

    ClipChanged(DataType) {
        if (this.controller.TrayManagerValue.isRecording) {
            localTxtFromClipboardArray := this.controller.ClipboardParserValue.Parse()

            ; Add non-duplicate items to context
            context := this.sessionManager.GetCurrentSessionContext()

            for item in localTxtFromClipboardArray {
                ; Add the original item first
                if !this.sessionManager.IsContentDuplicate(item) {
                    context.Push(item)

                    ; PDF processing logic could go here if needed
                }
            }

            ; Update session contexts
            this.sessionManager.SetCurrentSessionContext(context)

            ; Update Context in GUI if shown
            if (this.controller.view.guiShown) {
                this.controller.ContextViewControllerValue.UpdateContextView()
            }
        }
    }
}
