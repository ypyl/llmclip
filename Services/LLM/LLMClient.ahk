#Include ..\..\Lib\Json.ahk
#Include "Types.ahk"
#Include "PowerShellTool.ahk"
#Include "Providers\OpenAIProvider.ahk"
#Include "Providers\OllamaProvider.ahk"
#Include "Providers\GoogleProvider.ahk"
#Include "Providers\GroqAudioProvider.ahk"

class LLMClient {
    ; Private properties
    providers := Map()
    tempDir := A_ScriptDir "\temp"
    pid := 0
    isCancelled := false

    __New(traceabilityService, providers) {
        this.traceabilityService := traceabilityService
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
            startTime := A_TickCount
            sessionIndex := settings.Has("session_index") ? settings["session_index"] : 0
            body := Map()
            response := ""
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
                parsedMessages := [audioMsg]
                this.TraceLog(sessionIndex, settings, body, "", parsedMessages, startTime)
                return parsedMessages
            }

            ; Read response for non-audio types
            if FileExist(outputFile) {
                response := FileRead(outputFile, "UTF-8")
                if (response != "") {
                    ; Providers now return ChatMessage instances directly
                    parsedMessages := provider.ParseResponse(response)
                    this.TraceLog(sessionIndex, settings, body, response, parsedMessages, startTime)
                    return parsedMessages
                }
            }
            throw Error("No response received")

        } catch as e {
            if (e.Message == "Request cancelled") {
                throw e
            }
            parsedMessages := [ChatMessage("assistant", [TextContent(e.Message)])]
            this.TraceLog(sessionIndex, settings, body, response, parsedMessages, startTime, e.Message)
            return parsedMessages
        } finally {
            this.pid := 0
        }
    }

    GetProvider(settings) {
        t := settings.Get("provider_type", "openai")
        if this.providers.Has(t)
            return this.providers[t]
        throw Error("Unknown provider type: " t)
    }

    TraceLog(sessionIndex, settings, body, responseRaw, parsedMessages, startTime, errorMsg := "") {
        if (!this.traceabilityService)
            return

        providerName := settings.Has("provider_name") ? settings["provider_name"] : settings.Get("type", "")
        model := settings.Has("model") ? settings["model"] : ""
        durationMs := A_TickCount - startTime

        ; Extract tokens from parsed messages if available
        tokens := unset
        for msg in parsedMessages {
            if (msg.AdditionalProperties.Has("tokens")) {
                tokens := msg.AdditionalProperties["tokens"]
                break
            }
        }

        if (errorMsg != "") {
            this.traceabilityService.LogInteraction(sessionIndex, providerName, model, body, responseRaw, parsedMessages, durationMs, , errorMsg)
        } else {
            this.traceabilityService.LogInteraction(sessionIndex, providerName, model, body, responseRaw, parsedMessages, durationMs, tokens)
        }
    }
}
