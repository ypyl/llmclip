#Include UIConfig.ahk

class ResponseView {
    responseCtr := ""

    Create(gui) {
        this.responseCtr := gui.Add("Edit", "vResponseCtr x" UIConfig.responseCtrX " y" UIConfig.responseCtrY " w" UIConfig.responseCtrWidth " h" UIConfig.responseCtrHeight " -VScroll", "")
    }

    GetHwnd() => this.responseCtr.Hwnd

    Resize(width, height, webViewManager, guiShown) {
        if (!this.responseCtr)
            return
        this.responseCtr.Move(UIConfig.responseCtrX, UIConfig.responseCtrY, width - 410, height - 20)

        ; Resize WebView
        hCtrl := this.responseCtr.Hwnd
        rect := Buffer(16, 0)
        DllCall("GetClientRect", "ptr", hCtrl, "ptr", rect)

        widthResponseCtr := NumGet(rect, 8, "Int")
        heightResponseCtr := NumGet(rect, 12, "Int")
        
        wvRect := Buffer(16, 0)
        NumPut("Int", 0, wvRect, 0)
        NumPut("Int", 0, wvRect, 4)
        NumPut("Int", widthResponseCtr, wvRect, 8)
        NumPut("Int", heightResponseCtr, wvRect, 12)
        
        if (guiShown) {
            webViewManager.Resize(wvRect)
        }
    }
}
