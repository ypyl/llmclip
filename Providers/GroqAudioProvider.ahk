#Include "BaseProvider.ahk"

class GroqAudioProvider extends BaseProvider {
    GetRequestBody(messages, settings) {
        ; For audio generation, we use the last user message as input text
        lastUserMessage := ""
        loop messages.Length {
            idx := messages.Length - A_Index + 1
            msg := messages[idx]
            
            if (msg.Role = "user") {
                lastUserMessage := msg.GetText()
                break
            }
        }

        body := Map()
        body["model"] := settings.Get("model", "playai-tts")
        body["input"] := lastUserMessage
        ; https://console.groq.com/docs/text-to-speech#available-english-voices
        body["voice"] := settings.Get("voice", "Arista-PlayAI")
        body["response_format"] := settings.Get("response_format", "wav")

        return body
    }

    ParseResponse(response) {
        ; This provider returns audio file path, which is handled differently in LLMClient.
        ; However, if we need to parse a JSON error response or similar, we can do it here.
        ; For now, LLMClient handles the audio file output directly.
        ; If this method is called, it might be an error response or we need to return a dummy result.
        
        ; In LLMClient, if it's audio, it returns early.
        ; But if we want to unify, we might want to return something here.
        ; For now, let's assume LLMClient handles the file creation and this is only called for text responses (errors).
        
        try {
            obj := JSON.Load(response)
            if (obj.Has("error")) {
                throw Error(obj["error"]["message"])
            }
        }
        
        return []
    }
}
