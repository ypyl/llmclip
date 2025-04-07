#Requires AutoHotkey 2.0
#SingleInstance Force  ; Prevent multiple instances
#Warn
#Include AppSettings.ahk
#Include LLMClient.ahk
#Include SessionManager.ahk
#Include ClipboardParser.ahk
; There is a content of settings.ahk file that you can create near the current script file.
; It contains the function GetLLMSettings() that returns a map with settings for different LLMs.
; GetSettings()
; {
;      return {
;          selectedLLMType: "groq",
;          providers: Map(
;              "groq", Map(
;                  "curl", 'curl -s -S -X POST "https://api.groq.com/openai/v1/chat/completions" -H "Content-Type: application/json" -H "Authorization: Bearer <<KEY>" -d "@{1}" -o "{2}"',
;                  "model", "llama-3.3-70b-versatile",
;                  "temperature", 0.7,
;                  "system_prompt", "You are a helpful assistant. Be concise and direct in your responses.",
;              ),
;              "google", Map(
;                  "curl", 'curl -s -S -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=<<KEY>>" -H "Content-Type: application/json" -d "@{1}" -o "{2}"',
;                  "system_prompt", "You are a helpful assistant. Be concise and direct in your responses.",
;                  "temperature", 0.7,
;              )),
;              "ol-phi4", Map(
;                  "curl", 'curl -s -S -X POST "http://localhost:11434/api/chat" -H "Content-Type: application/json" -d "@{1}" -o "{2}"',
;                  "model", "phi4",
;                  "stream", false,
;                  "system_prompt", "You are a helpful assistant. Be concise and direct in your responses. My name is Yauhen.",
;                  "temperature", 0.7,
;              )
;       }
; }

; cURL is also should be installed as it is used to actually call LLM providers. Please install it using:`nwinget install cURL.cURL`nor visit https://curl.se/download.html

; Initialize variables

global askButton
global MyGui

; Create settings instance
global AppSettingsValue := AppSettings()

; Create session manager instance
global SessionManagerValue := SessionManager(AppSettingsValue)

; Create clipboard parser instance
global ClipboardParserValue := ClipboardParser()

isRecording := false
guiShown := false

A_TrayMenu.Delete()  ; Remove default menu items
A_TrayMenu.Add("Start Recording", StartRecording)
A_TrayMenu.Add("Stop Recording", StopRecording)
A_TrayMenu.Add("Ask LLM", AskLLM)
A_TrayMenu.Add("Exit", ExitApp)

F3:: {
    global isRecording, MyGui, guiShown
    if (!isRecording) {
        StartRecording()
    } else if (!guiShown) {
        AskLLM()
    } else {
        StopRecording()
    }
}

; Set default tray icon and tooltip
SetTrayStatus(false)  ; Default state (not recording)

OnMessage(0x404, TrayIconClick)

TrayIconClick(wParam, lParam, msg, hwnd) {
    if (lParam = 0x202) {  ; Left click
        if (isRecording) {
            StopRecording()  ; Stop recording
        } else {
            StartRecording()  ; Start recording
        }
    }
}

SetTrayStatus(isRecording) {
    if (isRecording) {
        TraySetIcon("shell32.dll", 294)  ; Red circle (recording)
        A_IconTip := "📍 Recording Clipboard..."
        A_TrayMenu.Disable("Start Recording")
        A_TrayMenu.Enable("Stop Recording")
    } else {
        TraySetIcon("shell32.dll", 171)  ; Default clipboard icon
        A_IconTip := ""
        A_TrayMenu.Enable("Start Recording")
        A_TrayMenu.Disable("Stop Recording")
    }
}

StartRecording(*) {
    global isRecording, MyGui
    if (!isRecording) {
        isRecording := true
        SetTrayStatus(true)  ; Update icon & tooltip
        if (MyGui) {
            MyGui["Record"].Text := "Stop"
        }
    }
}

StopRecording(*) {
    global isRecording, MyGui
    if (isRecording) {
        isRecording := false
        SetTrayStatus(false)  ; Update icon & tooltip
        recordedText := ""  ; Clear recorded text
        context := SessionManagerValue.GetCurrentSessionContext()
        for item in context {
            recordedText .= GetTextFromContextItem(item)
        }
        A_Clipboard := recordedText  ; Copy recorded text to clipboard
        if (MyGui) {
            MyGui["Stop"].Text := "Record"
        }
    }
}

AskLLM(*) {
    global MyGui, guiShown, askButton, AppSettingsValue, SessionManagerValue
    if (guiShown) {
        MyGui.Show()
        return
    }
    MyGui := Gui()
    MyGui.Title := "LLM Assistant"

    ; Add session selector
    sessionCombo := MyGui.Add("DropDownList", "x20 y10 w70 vSessionSelect", SessionManagerValue.sessionNames)
    sessionCombo.Value := SessionManagerValue.currentSessionIndex
    sessionCombo.OnEvent("Change", SessionChanged)

    ; Add record button
    recordButton := MyGui.Add("Button", "x100 y10 w90", "Record")
    recordButton.OnEvent("Click", ToggleRecording)

    ; Button section moved down
    resetButton := MyGui.Add("Button", "x310 y10 w90", "Reset All")
    resetButton.OnEvent("Click", ResetAll)

    ; Add context list with reduced height
    context := SessionManagerValue.GetCurrentSessionContext()
    listBox := MyGui.Add("ListBox", "vListBox x20 y40 w380 h150 VScroll Multi", context)
    listBox.OnEvent("Change", ListBoxSelect)  ; Add this line

    ; Context buttons moved up
    clearAllButton := MyGui.Add("Button", "x20 y190 w120", "Clear All")
    clearAllButton.OnEvent("Click", ClearAllContext)

    clearSelectionButton := MyGui.Add("Button", "x150 y190 w120", "Clear Selection")
    clearSelectionButton.OnEvent("Click", ClearSelection)

    deleteButton := MyGui.Add("Button", "x280 y190 w120", "Delete Selected")
    deleteButton.OnEvent("Click", DeleteSelected)

    ; Add ListView for chat history
    chatHistory := MyGui.Add("ListView", "vChatHistory x20 y225 w380 h150 NoSort", ["Role", "Text"])
    chatHistory.ModifyCol(1, 60)  ; Role column width
    chatHistory.ModifyCol(2, 290) ; Text column width
    chatHistory.OnEvent("ItemSelect", ChatHistorySelect)

    ; Split the Clear History button into two
    deleteMessageButton := MyGui.Add("Button", "x20 y385 w120", "Delete Selected")
    deleteMessageButton.OnEvent("Click", DeleteSelectedMessage)

    clearHistoryButton := MyGui.Add("Button", "x280 y385 w120", "Clear History")
    clearHistoryButton.OnEvent("Click", ClearChatHistory)

    ; Prompt section with increased height
    promptEdit := MyGui.Add("Edit", "vPromptEdit x20 y420 w380 h140 Multi WantReturn")  ; Add WantReturn option
    promptEdit.OnEvent("Change", PromptChange)

    ; Add LLM type selector near Reset All button
    llmTypeCombo := MyGui.Add("DropDownList", "x20 y570 w70 vLLMType", AppSettingsValue.llmTypes)
    llmTypeCombo.Value := AppSettingsValue.selectedIndex
    llmTypeCombo.OnEvent("Change", LLMTypeChanged)

    askButton := MyGui.Add("Button", "x210 y570 w190", "Ask LLM")
    askButton.OnEvent("Click", SendToLLM)

    ; Right panel remains unchanged
    MyGui.Add("Edit", "vResponse x420 y10 w790 h590 ReadOnly Multi VScroll Wrap", "")

    MyGui.OnEvent("Close", GuiClose)
    MyGui.Show("w1230 h610")
    guiShown := true

    UpdateChatHistoryView()
}

LLMTypeChanged(*) {
    global MyGui, AppSettingsValue
    AppSettingsValue.selectedIndex := MyGui["LLMType"].Value
}

; Add session switching function
SessionChanged(*) {
    global MyGui, SessionManagerValue

    ; Switch to new session
    SessionManagerValue.SwitchSession(MyGui["SessionSelect"].Value)

    UpdateContextView()
    UpdateChatHistoryView()

    ; Clear response field
    MyGui["Response"].Value := ""
}

UpdateContextView(*) {
    ; Update local references
    context := SessionManagerValue.GetCurrentSessionContext()

    ; Update UI
    listBox := MyGui["ListBox"]
    listBox.Delete()
    listBox.Add(context)
}

UpdateChatHistoryView(*) {
    global MyGui
    messages := SessionManagerValue.GetCurrentSessionMessages()
    chatHistory := MyGui["ChatHistory"]
    chatHistory.Delete()
    for msg in messages {
        chatHistory.Add(, msg.role, SubStr(msg.content, 1, 50) (StrLen(msg.content) > 50 ? "..." : ""))
    }
}

SendToLLM(*) {
    global MyGui, AppSettingsValue
    messages := SessionManagerValue.GetCurrentSessionMessages()
    context := SessionManagerValue.GetCurrentSessionContext()
    promptText := MyGui["PromptEdit"].Value
    listBox := MyGui["ListBox"]

    ; Update context in system message if needed
    if (context.Length > 0) {
        contextText := ""
        selectedIndices := []

        ; Get selected indices
        if (listBox.Value is Array) {
            selectedIndices := listBox.Value
        } else if (listBox.Value) {
            selectedIndices := [listBox.Value]
        }

        ; Build context excluding selected items
        for index, item in context {
            if !HasVal(selectedIndices, index) {
                contextText .= GetTextFromContextItem(item)
            }
        }
        messages[1].content := AppSettingsValue.GetDefaultSystemPrompt() "`n"
        messages[1].content .= "Here is the context:`n" contextText "`nPlease consider this context when answering the following question."

        ; Add selected items as special focus points
        if (selectedIndices.Length > 0) {
            messages[1].content .= "`nThe user has selected these items which may be particularly relevant:`n"
            for index in selectedIndices {
                messages[1].content .= GetTextFromContextItem(context[index])
            }
        }
    }

    messages.Push({ role: "user", content: promptText })

    ; Disable Ask LLM button while processing
    if (MyGui) {
        askButton.Enabled := false
    }

    try {
        ; Create LLM client if it doesn't exist yet
        LLMClientInstance := LLMClient(AppSettingsValue.GetSelectedSettings())

        assistantResponse := LLMClientInstance.Call(messages)
        messages.Push({ role: "assistant", content: assistantResponse })
        MyGui["Response"].Value := assistantResponse
        UpdateChatHistoryView()  ; Update the chat history view
    } catch as e {
        MyGui["Response"].Value := "Error: " e.Message
    } finally {
        ; Re-enable Ask LLM button
        if (MyGui) {
            askButton.Enabled := true
        }
    }
}

GetTextFromContextItem(item) {
    return ClipboardParserValue.GetTextFromContextItem(item)
}

GuiClose(*) {
    global MyGui, guiShown
    MyGui.Destroy()
    guiShown := false
}

ListBoxSelect(*) {
    global MyGui
    context := SessionManagerValue.GetCurrentSessionContext()
    listBox := MyGui["ListBox"]
    selectedItems := []
    textContent := ""

    ; Handle multi-select values
    if (listBox.Value is Array) {
        ; Process multiple selections
        for index in listBox.Value {
            selectedItems.Push(context[index])
        }
    } else if (listBox.Value) {
        ; Single selection
        selectedItems.Push(context[listBox.Value])
    }

    ; Process each selected item
    for item in selectedItems {
        textContent .= GetTextFromContextItem(item) "`n"
    }

    MyGui["Response"].Value := textContent
}

DeleteSelected(*) {
    global MyGui
    context := SessionManagerValue.GetCurrentSessionContext()
    listBox := MyGui["ListBox"]
    selectedIndices := []

    ; Handle multi-select values
    if (listBox.Value is Array) {
        ; Get indices in reverse order (to avoid index shifting when removing)
        for index in listBox.Value {
            selectedIndices.InsertAt(1, index)
        }
    } else if (listBox.Value) {
        selectedIndices.Push(listBox.Value)
    }

    ; Remove selected items
    for index in selectedIndices {
        context.RemoveAt(index)
    }

    ; Refresh the listbox
    listBox.Delete()
    listBox.Add(context)
}

ClearSelection(*) {
    global MyGui
    MyGui["ListBox"].Value := 0  ; Set selection to 0 to clear it
}

ClearChatHistory(*) {
    global MyGui, SessionManagerValue, AppSettingsValue
    SessionManagerValue.ClearCurrentMessages()

    UpdateChatHistoryView()  ; Update the chat history view
    MyGui["Response"].Value := ""  ; Clear response area
}

ResetAll(*) {
    global MyGui, SessionManagerValue

    ; Reset current session
    SessionManagerValue.ResetCurrentSession()

    ; Update UI
    UpdateChatHistoryView()
    UpdateContextView()

    ; Clear response and prompt
    MyGui["Response"].Value := ""
    MyGui["PromptEdit"].Value := ""
}

ExitApp(*) {
    ExitApp
}

HasVal(haystack, needle) {
    for index, value in haystack {
        if (value = needle)
            return true
    }
    return false
}

HasContent(haystack, newContent) {
    if (newContent = "")
        return true

    ; First check exact matches
    if (HasVal(haystack, newContent))
        return true

    ; Also check in chat history
    messages := SessionManagerValue.GetCurrentSessionMessages()
    for msg in messages {
        v := InStr(msg.content, newContent)
        if (v)
            return true
    }

    ; Then check content matches for files and folders
    newContentText := ClipboardParserValue.GetTextFromContextItem(newContent)
    for item in haystack {
        if (ClipboardParserValue.GetTextFromContextItem(item) = newContentText)
            return true
    }

    return false
}

OnClipboardChange ClipChanged

ClipChanged(DataType) {
    global isRecording, MyGui, guiShown, SessionManagerValue, ClipboardParserValue
    if (isRecording) {
        localTxtFromClipboardArray := ClipboardParserValue.Parse()

        ; Add non-duplicate items to context
        context := SessionManagerValue.GetCurrentSessionContext()
        for item in localTxtFromClipboardArray {
            if !HasContent(context, item)
                context.Push(item)
        }

        ; Update session contexts
        SessionManagerValue.SetCurrentSessionContext(context)

        ; Update ListBox in GUI if shown
        if (guiShown) {
            listBox := MyGui["ListBox"]
            listBox.Delete()
            listBox.Add(context)
        }
    }
}

ChatHistorySelect(*) {
    global MyGui
    messages := SessionManagerValue.GetCurrentSessionMessages()
    chatHistory := MyGui["ChatHistory"]
    if (focused_row := chatHistory.GetNext()) {
        MyGui["Response"].Value := messages[focused_row].content
    }
}

PromptChange(GuiCtrl, Info) {
    if (GetKeyState("Enter") && !GetKeyState("Shift")) {
        ; Get the last character
        text := GuiCtrl.Value
        if (SubStr(text, -1) == "`n") {
            ; Remove the trailing newline
            GuiCtrl.Value := SubStr(text, 1, -1)
            ; Send the prompt
            SendToLLM()
            return true
        }
    }
}

ClearAllContext(*) {
    global MyGui, SessionManagerValue

    SessionManagerValue.SetCurrentSessionContext([])
    UpdateContextView()
}

ToggleRecording(*) {
    global isRecording
    if (isRecording) {
        StopRecording()
    } else {
        StartRecording()
    }
}

DeleteSelectedMessage(*) {
    global MyGui, SessionManagerValue
    messages := SessionManagerValue.GetCurrentSessionMessages()
    chatHistory := MyGui["ChatHistory"]

    if (focused_row := chatHistory.GetNext()) {
        if (focused_row > 1) { ; Don't delete system message
            messages.RemoveAt(focused_row)
            UpdateChatHistoryView()
            MyGui["Response"].Value := ""
        }
    }
}
