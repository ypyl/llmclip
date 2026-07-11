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
        body["model"] := settings.Get("model")
        body["input"] := lastUserMessage
        ; https://console.groq.com/docs/text-to-speech#available-english-voices
        body["voice"] := settings.Get("voice", "troy")
        body["response_format"] := settings.Get("response_format", "wav")

        return body
    }

    ; ParseResponse intentionally omitted — audio is handled by LLMClient directly.
    ; Falls through to BaseProvider.ParseResponse which throws "Not implemented".
}
