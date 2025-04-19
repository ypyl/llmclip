#Requires AutoHotkey 2.0
#Include <WebView2>

class WebViewManager {
    wv := ""
    wvc := ""
    clipboardHost := {}

    __New() {
        this.clipboardHost := {
            Copy: (text) => A_Clipboard := text
        }
    }

    Init(responseCtr) {
        this.wvc := WebView2.CreateControllerAsync(responseCtr.Hwnd).await2()
        this.wv := this.wvc.CoreWebView2
        this.wv.NavigateToString(this.GetHtmlContent())
        this.wv.AddHostObjectToScript("clipboard", this.clipboardHost)
    }

    GetHtmlContent() {
        return '
        (
        <!DOCTYPE html>
        <html>
        <head>
            <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
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
                    padding: 4px 8px;
                }
            </style>
        </head>
        <body>
            <div id="content"></div>
            <script>
                // Configure marked to customize code block rendering
                marked.setOptions({
                    renderer: new marked.Renderer(),
                    highlight: function(code, lang) {
                        return code; // No syntax highlighting for simplicity
                    }
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
                    document.getElementById("content").innerHTML = marked.parse(content, { renderer: renderer });
                }
            </script>
        </body>
        </html>
        )'
    }

    RenderMarkdown(content) {
        escapedMd := StrReplace(content, "`"", '\"') ; simple quote escaping
        escapedMd := StrReplace(escapedMd, "`n", "\n") ; simple quote escaping
        this.wv.ExecuteScript("renderMarkdown(`"" escapedMd "`")")
    }

    Resize(rect) {
        if (this.wvc) {
            this.wvc.Bounds := rect
        }
    }
}
