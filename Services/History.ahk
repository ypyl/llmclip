#Include LLM\Types.ahk

class History {
    messages := []

    __New(initialMessages := "") {
        this.messages := initialMessages ? initialMessages : []
    }

    Add(message) {
        if (Type(message) == "Array") {
            for msg in message
                this.messages.Push(msg)
        } else {
            this.messages.Push(message)
        }
    }

    Get(index) => this.messages[index]

    GetAll() => this.messages

    Length() => this.messages.Length

    Branch(upToIndex) {
        if (upToIndex <= 0 || upToIndex >= this.messages.Length)
            return ""
        
        newMessages := []
        Loop upToIndex
            newMessages.Push(this.messages[A_Index])
        
        return History(newMessages)
    }

    ToObject() {
        result := []
        for msg in this.messages
            result.Push(msg.ToObject(true))
        return result
    }

    static FromObject(obj, convertMapFunc) {
        messages := []
        for msg in obj {
            plainObj := convertMapFunc.Call(msg)
            messages.Push(ChatMessage.FromObject(plainObj))
        }
        return History(messages)
    }
}
