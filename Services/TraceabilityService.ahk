#Requires AutoHotkey 2.0
#Include ..\Lib\Json.ahk

class TraceabilityService {
    filePath := ""

    __New() {
        ; Create sessions directory next to executable
        sessionsDir := A_ScriptDir "\sessions"
        if (!DirExist(sessionsDir))
            DirCreate(sessionsDir)

        ; Set file path named by current timestamp
        timestamp := FormatTime(, "yyyy-MM-dd-HH-mm-ss")
        this.filePath := sessionsDir "\" timestamp ".jsonl"
    }

    LogInteraction(sessionIndex, provider, model, requestBody, responseRaw, responseParsed, durationMs, tokens := unset, error := unset) {
        entry := Map()
        entry["ts"] := FormatTime(, "yyyy-MM-ddTHH:mm:ss")
        entry["session"] := sessionIndex
        entry["provider"] := provider
        entry["model"] := model

        ; Build request info without full message history (avoids line-by-line duplication)
        requestInfo := Map()
        for key, value in requestBody {
            if (key = "messages") {
                ; Only store count and the last new message (the prompt that triggered this call)
                requestInfo["message_count"] := Type(value) = "Array" ? value.Length : 0
                if (Type(value) = "Array" && value.Length > 0) {
                    requestInfo["prompt"] := value[value.Length]
                }
            } else {
                requestInfo[key] := value
            }
        }
        entry["request"] := requestInfo

        entry["response_raw"] := responseRaw
        entry["duration_ms"] := durationMs

        ; Serialize parsed messages to plain objects
        parsedArr := []
        for msg in responseParsed
            parsedArr.Push(msg.ToObject(true))
        entry["response_parsed"] := parsedArr

        if (IsSet(tokens))
            entry["tokens"] := tokens

        if (IsSet(error))
            entry["error"] := error

        line := JSON.Stringify(entry)
        FileAppend(line "`n", this.filePath, "UTF-8")
    }
}
