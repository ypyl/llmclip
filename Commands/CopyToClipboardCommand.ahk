#Requires AutoHotkey 2.0

class CopyToClipboardCommand {
    clipboardService := ""

    __New(clipboardService) {
        this.clipboardService := clipboardService
    }

    Execute(text) {
        this.clipboardService.SetText(text)
    }
}
