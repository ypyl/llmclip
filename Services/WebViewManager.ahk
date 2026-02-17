#Include <WebView2>

class WebViewManager {
    wv := ""
    wvc := ""
    clipboardHost := {}
    inputHost := {}
    errorCallback := ""
    saveDiagramCallback := ""
    isHtmlLoaded := false

    uiFilePath := A_ScriptDir . "\ui.html"
    pendingRenderType := ""
    pendingRenderContent := ""

    __New() {
        this.clipboardHost := {
            Copy: (text) => A_Clipboard := text,
            SaveDiagram: (svgData) => this.OnSaveDiagram(svgData)
        }
        this.inputHost := {
            Append: (text) => 0 ; Default placeholder
        }
    }

    SetInputCallback(callback) {
        this.inputHost.Append := callback
    }

    SetErrorCallback(callback) {
        this.errorCallback := callback
    }

    SetSaveDiagramCallback(callback) {
        this.saveDiagramCallback := callback
    }

    Init(hwnd) {
        this.wvc := WebView2.CreateControllerAsync(hwnd).await2()
        this.wv := this.wvc.CoreWebView2

        this.wv.AddHostObjectToScript("clipboard", this.clipboardHost)
        this.wv.AddHostObjectToScript("input", this.inputHost)

        this.navStartingToken := this.wv.add_NavigationStarting((sender, args) => this.OnNavigationStarting(args))
        this.navCompletedToken := this.wv.add_NavigationCompleted((sender, args) => this.OnNavigationCompleted(sender, args))

        this.NavigateToUi()
    }

    NavigateToUi() {
        this.wv.Navigate("file:///" . StrReplace(this.uiFilePath, "\", "/"))
    }



    OnNavigationStarting(args) {
        try {
            uri := args.Uri
            if (SubStr(uri, 1, 4) = "http") {
                this.isHtmlLoaded := false
            }
        }
    }

    OnNavigationCompleted(sender, args) {
        if (args.IsSuccess) {
            uri := ""
            try uri := this.wv.Source

            if (InStr(uri, "ui.html")) {
                this.isHtmlLoaded := true
                if (this.pendingRenderType == "markdown") {
                    this.RenderMarkdown(this.pendingRenderContent)
                }
                this.pendingRenderType := ""
                this.pendingRenderContent := ""
            }
        }
    }

    EscapeForJs(content) {
        escapedMd := StrReplace(content, "\", "\\")       ; escape backslashes first
        escapedMd := StrReplace(escapedMd, "`"", '\"')     ; escape double quotes
        escapedMd := StrReplace(escapedMd, "$", '\$')     ; escape double quotes
        escapedMd := StrReplace(escapedMd, "`n", "\n")     ; escape newline
        escapedMd := StrReplace(escapedMd, "`r", "\r")     ; escape carriage return
        escapedMd := StrReplace(escapedMd, "`t", "\t")     ; escape tab (optional)
        escapedMd := StrReplace(escapedMd, "`b", "\b")     ; backspace (optional)
        escapedMd := StrReplace(escapedMd, "`f", "\f")     ; form feed (optional)

        escapedMd := StrReplace(escapedMd, "``", "\``")     ; escape double backticks (optional)
        if (InStr(escapedMd, "<audio") != 1) {
            escapedMd := StrReplace(escapedMd, "<", "&lt;")     ; escape less than sign (optional)
            escapedMd := StrReplace(escapedMd, ">", "&gt;")     ; escape greater than sign (optional)
        }

        escapedMd := Trim(escapedMd)                    ; Remove leading/trailing whitespace
        escapedMd := RegExReplace(escapedMd, "\n\n+", "\n\n")  ; Replace multiple newlines with double newline
        escapedMd := RegExReplace(escapedMd, "\t+", " ")        ; Remove tabs

        return escapedMd
    }

    RenderMarkdown(content) {
        if (this.isHtmlLoaded) {
            this.wv.ExecuteScriptAsync("renderMarkdown(``" . this.EscapeForJs(content) . "``)")
        } else {
            this.pendingRenderType := "markdown"
            this.pendingRenderContent := content
            this.NavigateToUi()
        }
    }

    Resize(rect) {
        if (this.wvc) {
            this.wvc.Bounds := rect
        }
    }

    NavigateBackToMarkdown(contentToRender := "") {
        ; Navigate back to the markdown HTML and render content if provided
        if (contentToRender != "") {
            this.RenderMarkdown(contentToRender)
        } else {
            this.NavigateToUi()
        }
    }

    OnSaveDiagram(svgData) {
        if (this.saveDiagramCallback) {
            this.saveDiagramCallback.Call(svgData)
        }
    }
}
