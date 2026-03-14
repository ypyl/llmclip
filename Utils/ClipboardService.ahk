#Requires AutoHotkey 2.0

class ClipboardService {
    static SetText(text) {
        A_Clipboard := text
    }

    static GetText() {
        return A_Clipboard
    }
}
