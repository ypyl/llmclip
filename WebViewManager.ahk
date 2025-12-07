#Requires AutoHotkey 2.0
#Include <WebView2>

class WebViewManager {
    wv := ""
    wvc := ""
    clipboardHost := {}
    articleHost := {}
    inputHost := {}
    cache := Map()  ; Cache to store loaded articles by URL
    articleReady := false
    currentArticle := ""

    __New() {
        this.clipboardHost := {
            Copy: (text) => A_Clipboard := text
        }
        this.articleHost := {
            OnArticle: (article) => this.HandleArticle(article)
        }
        this.inputHost := {
            Append: (text) => MsgBox(text) ; Default placeholder
        }
        this.cache := Map()  ; Initialize the cache
    }

    SetInputCallback(callback) {
        this.inputHost.Append := callback
    }

    Init(responseCtr) {
        this.wvc := WebView2.CreateControllerAsync(responseCtr.Hwnd).await2()
        this.wv := this.wvc.CoreWebView2
        this.wv.NavigateToString(this.GetHtmlContent())
        this.wv.AddHostObjectToScript("clipboard", this.clipboardHost)
        this.wv.AddHostObjectToScript("article", this.articleHost)
        this.wv.AddHostObjectToScript("input", this.inputHost)
    }

    InitArticleMode() {
        readabilityJS := FileRead(A_ScriptDir . "\readability.min.js")
        this.scriptId := this.wv.AddScriptToExecuteOnDocumentCreatedAsync(readabilityJS).await()
        this.navCompletedToken := this.wv.add_NavigationCompleted(WebView2.Handler((handler, ICoreWebView2, NavigationCompletedEventArgs) => this.OnNavigationCompleted()))
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

    OnNavigationCompleted() {
        this.ExtractArticle()
    }

    ExtractArticle() {
        try {
            this.wv.ExecuteScriptAsync('
            (
                var article = new Readability(document).parse();
                var obj = window.chrome.webview.hostObjects.sync.article;
                obj.OnArticle(article);
            )')
        } catch as e {
            MsgBox("Script error: " e.Message)
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
        if HasProp(this, "navCompletedToken")
            this.wv.remove_NavigationCompleted(this.navCompletedToken)
        if HasProp(this, "scriptId")
            this.wv.RemoveScriptToExecuteOnDocumentCreated(this.scriptId)

        this.wv.NavigateToString(this.GetHtmlContent())
    }

    GetHtmlContent() {
        markedJS := FileRead(A_ScriptDir . "\marked.min.js")
        var := "
        (
        <!DOCTYPE html>
        <html>
        <head>
            <script>
        )"
        var .= markedJS
        var .= "
        (
        </script>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                    margin: 0 auto;
                    padding: 0px 5px;
                }
                .code-block-wrapper {
                    margin: 16px 0;
                }
                pre {
                    background-color: #f6f8fa;
                    padding: 16px;
                    border-radius: 6px;
                    margin: 0;
                }
                code {
                    font-family: Consolas, "Liberation Mono", Menlo, Courier, monospace;
                }
                .collapsed code {
                    display: -webkit-box;
                    -webkit-line-clamp: 1;
                    -webkit-box-orient: vertical;
                    overflow: hidden;
                }
                .copy-button, .toggle-button {
                    margin: 4px;
                    padding: 6px 12px;
                    background-color: #ffffff;
                    color: #333333;
                    border: 1px solid #cccccc;
                    border-radius: 4px;
                    cursor: pointer;
                    font-size: 14px;
                    box-shadow: none;
                }
                .copy-button:hover, .toggle-button:hover {
                    background-color: #e6f2fa;
                    border-color: #0078d4;
                }
                .quote-button {
                    position: fixed;
                    display: none;
                    background-color: #ffffff;
                    color: #333333;
                    border: 1px solid #cccccc;
                    border-radius: 4px;
                    padding: 6px 12px;
                    cursor: pointer;
                    font-size: 14px;
                    box-shadow: 0 2px 5px rgba(0,0,0,0.1);
                    z-index: 1000;
                }
                .quote-button:hover {
                    background-color: #e6f2fa;
                    border-color: #0078d4;
                }
            </style>
        </head>
        <body>
            <div id="content"></div>
            <button id="quoteBtn" class="quote-button">Quote</button>
            <script>
                // Configure marked to customize code block rendering
                marked.setOptions({
                    renderer: new marked.Renderer(),
                    highlight: function(code, lang) {
                        return code; // No syntax highlighting for simplicity
                    },
                    gfm: true,
                    breaks: true,
                    sanitize: false, // This must be false to allow HTML
                });

                // Function to copy code to clipboard
                function copyCode(button) {
                    const codeElement = button.previousElementSibling.previousElementSibling;
                    const text = codeElement.textContent;
                    window.chrome.webview.hostObjects.sync.clipboard.Copy(text);
                }

                // Function to toggle code block visibility
                function toggle(button) {
                    const wrapper = button.closest(".code-block-wrapper");
                    wrapper.classList.toggle("collapsed");
                    button.textContent = wrapper.classList.contains("collapsed") ? "Expand" : "Collapse";
                }

                // Override the code block renderer to include copy and toggle buttons
                const renderer = new marked.Renderer();
                renderer.code = function(code, infostring, escaped) {
                    return ``<div class="code-block-wrapper"><pre><code>${code.text}</code><br /><button class="copy-button" onclick="copyCode(this)">Copy</button><button class="toggle-button" onclick="toggle(this)">Collapse</button></pre></div>``;
                };

                function renderMarkdown(content) {
                    const quoteBtn = document.getElementById('quoteBtn');
                    if (quoteBtn) {
                        quoteBtn.style.display = 'none';
                    }
                    document.getElementById("content").innerHTML = marked.parse(content, { renderer: renderer });
                }

                // Quote button logic
                const quoteBtn = document.getElementById('quoteBtn');

                document.addEventListener('selectionchange', () => {
                    const selection = window.getSelection();
                    if (selection.isCollapsed) {
                        quoteBtn.style.display = 'none';
                    }
                });

                document.addEventListener('mouseup', (e) => {
                    const selection = window.getSelection();
                    const text = selection.toString().trim();

                    if (text) {
                        const range = selection.getRangeAt(0);
                        const rect = range.getBoundingClientRect();

                        // Position button above the selection
                        let top = rect.top - 40;
                        let left = rect.left + (rect.width / 2) - (quoteBtn.offsetWidth / 2);

                        // Ensure button stays within viewport
                        if (top < 0) top = rect.bottom + 10;
                        if (left < 0) left = 10;
                        if (left + quoteBtn.offsetWidth > window.innerWidth) {
                            left = window.innerWidth - quoteBtn.offsetWidth - 10;
                        }

                        quoteBtn.style.top = ``${top}px``;
                        quoteBtn.style.left = ``${left}px``;
                        quoteBtn.style.display = 'block';
                    } else {
                        quoteBtn.style.display = 'none';
                    }
                });

                quoteBtn.addEventListener('click', () => {
                    const text = window.getSelection().toString().trim();
                    if (text) {
                        window.chrome.webview.hostObjects.sync.input.Append(text);
                        window.getSelection().removeAllRanges();
                        quoteBtn.style.display = 'none';
                    }
                });
            </script>
        </body>
        </html>
        )"
        return var
    }

    RenderMarkdown(content) {
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

        this.wv.ExecuteScript("renderMarkdown(``" escapedMd "``)")
    }

    Resize(rect) {
        if (this.wvc) {
            this.wvc.Bounds := rect
        }
    }
}
