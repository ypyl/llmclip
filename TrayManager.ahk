#Requires AutoHotkey 2.0

class TrayManager {
    __New(displayLLMUserInterfaceCallback := "", toggleCallback := "") {
        this.isRecording := false
        this.displayLLMUserInterfaceMethod := displayLLMUserInterfaceCallback
        this.toggleCallback := toggleCallback

        ; Initialize tray menu
        A_TrayMenu.Delete()  ; Remove default menu items
        A_TrayMenu.Add("Start Recording", ObjBindMethod(this, "StartRecording"))
        A_TrayMenu.Add("Stop Recording", ObjBindMethod(this, "StopRecording"))
        A_TrayMenu.Add("Ask LLM", ObjBindMethod(this, "DisplayLLMUserInterface"))
        A_TrayMenu.Add("Exit", ExitApplication)

        ; Set default tray icon and tooltip
        this.SetTrayStatus(false)  ; Default state (not recording)

        ; Set up tray icon click handler
        OnMessage(0x404, ObjBindMethod(this, "TrayIconClick"))
    }

    TrayIconClick(wParam, lParam, msg, hwnd) {
        if (lParam = 0x202) {  ; Left click
            if (this.isRecording) {
                this.StopRecording()  ; Stop recording
            } else {
                this.StartRecording()  ; Start recording
            }
        }
    }

    SetTrayStatus(isRecording) {
        if (isRecording) {
            TraySetIcon("shell32.dll", 294)  ; Red circle (recording)
            A_IconTip := "📍 Recording Clipboard..."
            A_TrayMenu.Disable("Start Recording")
            A_TrayMenu.Enable("Stop Recording")
        } else {
            TraySetIcon("shell32.dll", 171)  ; Default clipboard icon
            A_IconTip := ""
            A_TrayMenu.Enable("Start Recording")
            A_TrayMenu.Disable("Stop Recording")
        }
    }

    StartRecording() {
        if (!this.isRecording) {
            this.isRecording := true
            this.SetTrayStatus(true)  ; Update icon & tooltip
            if (this.toggleCallback) {
                this.toggleCallback()  ; Notify other components
            }
            return true
        }
        return false
    }

    StopRecording(sessionManager := "") {
        if (this.isRecording) {
            this.isRecording := false
            this.SetTrayStatus(false)  ; Update icon & tooltip

            if (sessionManager) {
                recordedText := ""  ; Clear recorded text
                context := sessionManager.GetCurrentSessionContext()
                for item in context {
                    recordedText .= ContextManagerValue.GetTextFromContextItem(item)
                }
                A_Clipboard := recordedText  ; Copy recorded text to clipboard
            }
            if (this.toggleCallback) {
                this.toggleCallback()  ; Notify other components
            }
            return true
        }
        return false
    }

    ToggleRecording(sessionManager) {
        if (this.isRecording) {
            this.StopRecording(sessionManager)
        } else {
            this.StartRecording()
        }
    }

    DisplayLLMUserInterface(*) {
        this.displayLLMUserInterfaceMethod()
    }
}
