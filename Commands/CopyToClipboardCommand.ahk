#Requires AutoHotkey 2.0

class CopyToClipboardCommand {
    Execute(text) {
        A_Clipboard := text
    }
}
