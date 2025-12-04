#Requires AutoHotkey 2.0
#Include <Json>
#Include "LLM\Types.ahk"
#Include "PowerShellTool.ahk"
#Include "Providers\OpenAIProvider.ahk"
#Include "Providers\OllamaProvider.ahk"
#Include "Providers\GoogleProvider.ahk"
#Include "Providers\GroqAudioProvider.ahk"

class LLMClient {
    ; Private properties
    settings := {}
    tempDir := A_Temp "\llmclip"
    pid := 0
    isCancelled := false
    providers := Map()

    __New(settings) {
        this.settings := settings

        ; Ensure temp directory exists
        if !DirExist(this.tempDir)
            DirCreate(this.tempDir)
            
        ; Initialize providers
        this.providers["openai"] := OpenAIProvider()
        this.providers["ollama"] := OllamaProvider()
        this.providers["google"] := GoogleProvider()
        this.providers["audio"] := GroqAudioProvider()
    }

    Cancel() {
        this.isCancelled := true
        if (this.pid > 0) {
            try ProcessClose(this.pid)
        }
    }

    Call(messages) {
        try {
            this.isCancelled := false
            selectedSettings := this.settings
            curl := selectedSettings["curl"]
            selectedLLMType := selectedSettings.Has("type") ? selectedSettings["type"] : "groq"

            ; Get the appropriate provider
            provider := this.GetProvider(selectedLLMType)

            ; Prepare request body
            body := provider.GetRequestBody(messages, selectedSettings)

            ; Create temporary files for input/output
            inputFile := this.tempDir "\request.json"

            ; Handle audio output differently
            if (InStr(selectedLLMType, "gr-audio") = 1) {
                outputFile := this.tempDir "\response.wav"
            } else {
                outputFile := this.tempDir "\response.json"
            }

            ; Write request body to temp file
            try FileDelete(inputFile)
            FileAppend(JSON.Dump(body), inputFile)

            ; Prepare curl command
            curlCmd := Format(curl, inputFile, outputFile)

            ; Execute curl
            Run(curlCmd, , "Hide", &pid)
            this.pid := pid

            ; Wait for process to finish or cancellation
            while (ProcessExist(this.pid)) {
                if (this.isCancelled) {
                    throw Error("Request cancelled")
                }
                Sleep(100)
            }

            if (this.isCancelled) {
                throw Error("Request cancelled")
            }

            ; Show error if response file doesn't exist
            if (!FileExist(outputFile)) {
                throw Error("No response file created")
            }

            ; Handle audio response
            if (InStr(selectedLLMType, "gr-audio") = 1) {
                audioMsg := ChatMessage("assistant")
                audioMsg.Contents.Push(AudioContent(outputFile, "wav"))
                return [audioMsg]
            }

            ; Read response for non-audio types
            if FileExist(outputFile) {
                response := FileRead(outputFile, "UTF-8")
                if (response != "") {
                    ; Providers now return ChatMessage instances directly
                    return provider.ParseResponse(response)
                }
            }
            throw Error("No response received")

        } catch as e {
            if (e.Message == "Request cancelled") {
                throw e
            }
            errorMsg := ChatMessage("assistant", e.Message)
            return [errorMsg]
        } finally {
            ; Cleanup temp files but don't delete audio files
            try {
                FileDelete(inputFile)

                ; Only delete JSON response files, not audio files
                if (!InStr(selectedLLMType, "gr-audio") = 1) {
                    FileDelete(outputFile)
                }
            }
            this.pid := 0
        }
    }

    GetProvider(type) {
        if (InStr(type, "gr-audio") = 1)
            return this.providers["audio"]
        else if (InStr(type, "gr") = 1 || InStr(type, "az") = 1 || InStr(type, "git") = 1)
            return this.providers["openai"]
        else if (InStr(type, "ol-") = 1)
            return this.providers["ollama"]
        else if (InStr(type, "go") = 1)
            return this.providers["google"]
        throw Error("Unknown model type: " type)
    }
}
