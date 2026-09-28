#Include ..\..\Lib\Json.ahk

; Shared HTTP plumbing for the Ollama-backed web tools (search, fetch):
; POST a JSON body, poll for the response while honoring Cancel().
class OllamaHttpTool {
    currentHttpObject := ""
    isCancelled := false

    /**
     * @param label Human-readable tool name used in error messages, e.g. "Web search"
     * @returns {ok: true, response: <parsed JSON>} or {ok: false, error: <string>}
     */
    PostJson(url, body, apiKey, label) {
        try {
            if (this.isCancelled)
                return {ok: false, error: "Operation cancelled by user"}

            http := ComObject("WinHttp.WinHttpRequest.5.1")
            this.currentHttpObject := http
            http.Open("POST", url, true)
            http.SetRequestHeader("Content-Type", "application/json")
            if (apiKey != "")
                http.SetRequestHeader("Authorization", "Bearer " . apiKey)

            http.Send(JSON.Dump(body))

            ; Wait for response with cancellation check
            while (!http.WaitForResponse(100)) {
                if (this.isCancelled) {
                    try http.Abort()
                    return {ok: false, error: "Operation cancelled by user"}
                }
            }

            if (http.Status != 200)
                return {ok: false, error: "Error: " . label . " failed with status " . http.Status . " - " . http.ResponseText}

            return {ok: true, response: JSON.Load(http.ResponseText)}

        } catch as e {
            return {ok: false, error: "Error executing " . StrLower(label) . ": " . e.Message}
        } finally {
            this.currentHttpObject := ""
        }
    }

    Cancel() {
        this.isCancelled := true
        if (this.currentHttpObject != "") {
            try this.currentHttpObject.Abort()
            this.currentHttpObject := ""
        }
    }
}
