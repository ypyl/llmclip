#Requires AutoHotkey 2.0

class CopyToClipboardCommand {
    Execute(text) {
        ClipboardHelper.SetText(text)
    }
}
