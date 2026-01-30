#Requires AutoHotkey 2.0

class TrayView {
    __New(controller) {
        this.controller := controller

        ; Initialize tray menu
        A_TrayMenu.Delete()  ; Remove default menu items
        A_TrayMenu.Add("Start Recording", (*) => this.controller.OnStartRecording())
        A_TrayMenu.Add("Stop Recording", (*) => this.controller.OnStopRecording())
        A_TrayMenu.Add("Ask LLM", (*) => this.controller.OnDisplayLLM())
        A_TrayMenu.Add("Exit", (*) => this.controller.OnExit())

        ; Set default tray icon and tooltip
        this.UpdateStatus(false)  ; Default state (not recording)

        ; Set up tray icon click handler
        OnMessage(0x404, ObjBindMethod(this, "TrayIconClick"))
    }

    TrayIconClick(wParam, lParam, msg, hwnd) {
        if (lParam = 0x202) {  ; Left click
            this.controller.OnToggleRecording()
        }
    }

    UpdateStatus(isRecording) {
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
}
