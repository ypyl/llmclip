
class RenderMarkdownCommand {
    webViewManager := ""

    __New(webViewManager) {
        this.webViewManager := webViewManager
    }

    Execute(content) {
        this.webViewManager.RenderMarkdown(content)
    }
}
