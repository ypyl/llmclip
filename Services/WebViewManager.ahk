#Include <WebView2>

class WebViewManager {
    wv := ""
    wvc := ""
    clipboardHost := {}
    articleHost := {}
    inputHost := {}
    errorCallback := ""
    saveDiagramCallback := ""
    cache := Map()  ; Cache to store loaded articles by URL
    articleReady := false
    currentArticle := ""
    isHtmlLoaded := false

    uiFilePath := A_ScriptDir . "\ui.html"
    pendingRenderType := ""
    pendingRenderContent := ""

    __New() {
        this.clipboardHost := {
            Copy: (text) => A_Clipboard := text,
            SaveDiagram: (svgData) => this.OnSaveDiagram(svgData)
        }
        this.articleHost := {
            OnArticle: (article) => this.HandleArticle(article)
        }
        this.inputHost := {
            Append: (text) => 0 ; Default placeholder
        }

        this.cache := Map()  ; Initialize the cache
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
        this.wv.AddHostObjectToScript("article", this.articleHost)
        this.wv.AddHostObjectToScript("input", this.inputHost)

        this.navStartingToken := this.wv.add_NavigationStarting((sender, args) => this.OnNavigationStarting(args))
        this.navCompletedToken := this.wv.add_NavigationCompleted((sender, args) => this.OnNavigationCompleted(sender, args))

        this.NavigateToUi()
    }

    NavigateToUi() {
        this.wv.Navigate("file:///" . StrReplace(this.uiFilePath, "\", "/"))
    }

    InitArticleMode() {
        readabilityJS := FileRead(A_ScriptDir . "\readability.min.js")
        this.scriptId := this.wv.AddScriptToExecuteOnDocumentCreatedAsync(readabilityJS).await()
        ; We use the main navigation completed handler now
    }

    LoadArticle(url) {
        ; Check if the article is already in the cache
        if (this.cache.Has(url)) {
            ; Article exists in cache, return it directly
            return this.cache[url]
        }

        ; Reset synchronization variables
        this.articleReady := false
        this.currentArticle := ""

        ; Article not in cache, load it
        this.currentUrl := url  ; Store the URL for caching
        this.InitArticleMode()
        this.wv.Navigate(url)
        this.isHtmlLoaded := false

        ; Wait for article to be ready (with timeout)
        startTime := A_TickCount
        timeout := 5000  ; 5 seconds timeout

        while (!this.articleReady) {
            if (A_TickCount - startTime > timeout) {
                this.HandleArticle("Not able to extract page content within " . (timeout / 1000) . " seconds.")  ; Handle timeout by returning empty article
                break
            }
            Sleep(100)
        }

        return this.currentArticle
    }

    Navigate(url) {
        this.wv.Navigate(url)
        this.isHtmlLoaded := false
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
            } else if (InStr(uri, "http")) {
                this.ExtractArticle()
            }
        }
    }

    ExtractArticle() {
        try {
            this.wv.ExecuteScriptAsync('
            (
                var contentType = document.contentType;
                var article = null;

                // Check if content type is text or xml based
                if (contentType && (
                    contentType.indexOf("text/plain") !== -1 ||
                    contentType.indexOf("text/xml") !== -1 ||
                    contentType.indexOf("application/xml") !== -1 ||
                    contentType.indexOf("application/rss+xml") !== -1 ||
                    contentType.indexOf("application/json") !== -1)) {
                    // For text/xml, manually construct structure matching Readability output
                    article = {
                        title: document.title || "No Title",
                        textContent: document.body ? document.body.innerText : (document.documentElement ? document.documentElement.textContent : ""),
                        content: document.documentElement ? document.documentElement.outerHTML : "",
                        byline: "",
                        dir: ""
                    };
                } else {
                    // Use Readability for HTML
                    article = new Readability(document).parse();
                }

                var obj = window.chrome.webview.hostObjects.sync.article;
                obj.OnArticle(article);
            )')
        } catch as e {
            if (this.errorCallback) {
                this.errorCallback.Call("Script error: " e.Message)
            }
            this.articleReady := true  ; Set to true to prevent infinite waiting
        }
    }

    HandleArticle(article) {
        ; Cache the article if we have a URL
        if (HasProp(this, "currentUrl")) {
            this.cache[this.currentUrl] := article
        }

        ; Store the article and signal it's ready
        this.currentArticle := article
        this.articleReady := true

        ; Clean up
        if HasProp(this, "scriptId")
            this.wv.RemoveScriptToExecuteOnDocumentCreated(this.scriptId)
        ; which in turn will ensure we navigate back to UI if needed.
        ; We don't need to navigate back to UI here.
        ; The caller (e.g. ContextViewController) will trigger an update which calls RenderMarkdown,
      
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
