#Include ..\Lib\Json.ahk

class WebContentFetcher {
    static tempDir := A_ScriptDir "\temp"

    /**
     * Parse a markdown.new response. Successful calls may return raw markdown
     * or a JSON envelope; failures return JSON with success=false.
     * @returns {ok, raw, content, title, error}
     */
    static ParseMarkdownResponse(response) {
        parsed := {ok: true, raw: response, content: response, title: "", error: ""}

        trimmed := Trim(response, " `t`n`r")
        if (SubStr(trimmed, 1, 1) != "{" || SubStr(trimmed, -1) != "}")
            return parsed

        try {
            jsonObj := JSON.Load(trimmed)
        } catch {
            return parsed ; Not valid JSON, treat as raw markdown
        }

        if (!jsonObj.Has("success"))
            return parsed

        if (!jsonObj["success"]) {
            parsed.ok := false
            parsed.error := "Error from markdown.new: " . (jsonObj.Has("message") ? jsonObj["message"] : "Unknown error")
            return parsed
        }

        if (jsonObj.Has("content"))
            parsed.content := jsonObj["content"]
        if (jsonObj.Has("title"))
            parsed.title := jsonObj["title"]

        return parsed
    }
    /**
     * Fetch web content as markdown using markdown.new API via curl.
     * Pure HTTP — no cancellation support. Callers handle their own cancellation.
     * @param targetUrl - The URL to fetch
     * @returns Raw response string (may be markdown or JSON)
     */
    static FetchMarkdown(targetUrl) {
        try {
            apiUrl := "https://markdown.new/"

            body := Map()
            body["url"] := targetUrl
            body["method"] := "auto"

            ; Create temporary files for request and response
            requestFile := WebContentFetcher.tempDir "\" Format("{1}_{2}", A_TickCount, "request.json")
            responseFile := WebContentFetcher.tempDir "\" Format("{1}_{2}", A_TickCount, "response.json")

            ; Write request body to temp file
            if FileExist(requestFile)
                FileDelete(requestFile)
            FileAppend(JSON.Dump(body), requestFile)

            ; Prepare curl command
            curlCmd := Format('curl.exe -s -X POST "{1}" -H "Content-Type: application/json" -d "@{2}" -o "{3}"', apiUrl, requestFile, responseFile)

            ; Execute curl and wait for completion
            Run(curlCmd, , "Hide", &pid)
            while (ProcessExist(pid))
                Sleep(100)

            ; Check if response file exists and read it
            if (FileExist(responseFile)) {
                response := FileRead(responseFile, "UTF-8")
                WebContentFetcher.CleanupFiles(requestFile, responseFile)

                if (response == "") {
                    return "Error: Empty response received from markdown.new"
                }

                return response
            } else {
                WebContentFetcher.CleanupFiles(requestFile, responseFile)
                return "Error: Failed to fetch content (no response file)"
            }

        } catch as e {
            return "Error executing markdown fetch: " . e.Message
        }
    }

    static CleanupFiles(requestFile, responseFile) {
        try {
            if (FileExist(requestFile))
                FileDelete(requestFile)
            if (FileExist(responseFile))
                FileDelete(responseFile)
        }
    }
}
