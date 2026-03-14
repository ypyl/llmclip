#Requires AutoHotkey 2.0

class CopyToClipboardCommand {
    Execute(text) {
        ClipboardService.SetText(text)
    }
}
