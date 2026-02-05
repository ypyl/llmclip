
class ClipboardController {
    controller := ""
    processClipboardCommand := ""

    __New(controller, processClipboardCommand) {
        this.controller := controller
        this.processClipboardCommand := processClipboardCommand
    }

    ClipChanged(DataType) {
        if (this.processClipboardCommand.Execute()) {
            ; Update Context in GUI if shown
            if (this.controller.view.guiShown) {
                this.controller.contextViewController.UpdateContextView()
            }
        }
    }
}
