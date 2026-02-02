#Requires AutoHotkey 2.0

class ClipboardService {
    SetText(text) {
        A_Clipboard := text
    }

    GetText() {
        return A_Clipboard
    }
}
