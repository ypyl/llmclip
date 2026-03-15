#Include ..\..\Lib\Json.ahk
#Include "Types.ahk"
#Include "PowerShellTool.ahk"
#Include "Providers\OpenAIProvider.ahk"
#Include "Providers\OllamaProvider.ahk"
#Include "Providers\GoogleProvider.ahk"
#Include "Providers\GroqAudioProvider.ahk"
#Include "..\..\Utils\TempFileManager.ahk"

class LLMClient {
    ; Private properties
    providers := Map()
    tempDir := TempFileManager.TempDir
    pid := 0
    isCancelled := false

    __New(providers) {
        this.providers := providers
    }

    Cancel() {
        this.isCancelled := true
        if (this.pid > 0) {
            try ProcessClose(this.pid)
        }
    }

    Call(messages, settings) {
        try {
            this.isCancelled := false
            curl := settings["curl"]
            selectedLLMType := settings.Has("type") ? settings["type"] : "groq"

            providerName := settings.Has("provider_name") ? settings["provider_name"] : ""

            ; Get the appropriate provider
            provider := this.GetProvider(settings)

            ; Prepare request body
            body := provider.GetRequestBody(messages, settings)

            ; Create temporary files for input/output
            inputFile := this.tempDir "\request.json"

            ; Handle audio output differently
            if (providerName = "GroqAudio" || providerName = "Groq Audio" || providerName = "Audio") {
                outputFile := this.tempDir "\response.wav"
            } else {
                outputFile := this.tempDir "\response.json"
            }

            ; Write request body to temp file
            try FileDelete(inputFile)
            FileAppend(JSON.Dump(body), inputFile)

            ; Prepare curl command
            curlCmd := Format(curl, inputFile, outputFile)
            
            ; Replace API_KEY placeholder if present
            if (settings.Has("api_key")) {
                curlCmd := StrReplace(curlCmd, "{API_KEY}", settings["api_key"])
            }

            ; Report error if API_KEY is still missing but required by the template
            if (InStr(curlCmd, "{API_KEY}")) {
                throw Error("Missing API_KEY for provider: " . selectedLLMType)
            }

            ; Replace MODEL placeholder if present
            if (settings.Has("model")) {
                curlCmd := StrReplace(curlCmd, "{MODEL}", settings["model"])
            }

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
            if (providerName = "GroqAudio" || providerName = "Groq Audio" || providerName = "Audio") {
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
            errorMsg := ChatMessage("assistant", [TextContent(e.Message)])
            return [errorMsg]
        } finally {
            ; Cleanup temp files but don't delete audio files
            try {
                ; FileDelete(inputFile)

                ; Only delete JSON response files, not audio files
                ; if (!InStr(selectedLLMType, "gr-audio") = 1) {
                ;    FileDelete(outputFile)
                ; }
            }
            this.pid := 0
        }
    }

    GetProvider(settings) {
        providerName := settings.Has("provider_name") ? settings["provider_name"] : ""
        
        if (providerName = "GroqAudio" || providerName = "Groq Audio" || providerName = "Audio")
            return this.providers["audio"]
        else if (providerName = "Groq" || providerName = "GitHub" || providerName = "OpenRouter" || providerName = "OpenAI" || providerName = "Azure" || providerName = "Nvidia")
            return this.providers["openai"]
        else if (InStr(providerName, "Ollama") = 1)
            return this.providers["ollama"]
        else if (providerName = "Google")
            return this.providers["google"]
            
        throw Error("Unknown provider type: " providerName " (" settings.Get("type", "") ")")
    }
}
