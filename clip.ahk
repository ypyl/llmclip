#Requires AutoHotkey 2.0
#SingleInstance Force  ; Prevent multiple instances
#Warn
#Include AppSettings.ahk
#Include LLMClient.ahk
#Include SessionManager.ahk
#Include ClipboardParser.ahk
#Include ComSpecTool.ahk
#Include FileSystemTool.ahk
#Include <WebView2>
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

global ComSpecToolValue := ComSpecTool()
global FileSystemToolValue := FileSystemTool()

global wv, wvc

clipboardHost := {}
clipboardHost.Copy := (text) => A_Clipboard := text

htmlContent := '
    (
    <!DOCTYPE html>
    <html>
    <head>
        <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                margin: 0 auto;
                padding: 0px 5px;
            }
            .code-block-wrapper {
                margin: 16px 0;
            }
            pre {
                background-color: #f6f8fa;
                padding: 16px;
                border-radius: 6px;
                margin: 0;
            }
            code {
                font-family: Consolas, "Liberation Mono", Menlo, Courier, monospace;
            }
            .collapsed code {
                display: -webkit-box;
                -webkit-line-clamp: 1;
                -webkit-box-orient: vertical;
                overflow: hidden;
            }
            .copy-button, .toggle-button {
                margin: 4px;
                padding: 4px 8px;
            }
        </style>
    </head>
    <body>
        <div id="content"></div>
        <script>
            // Configure marked to customize code block rendering
            marked.setOptions({
                renderer: new marked.Renderer(),
                highlight: function(code, lang) {
                    return code; // No syntax highlighting for simplicity
                }
            });

            // Function to copy code to clipboard
            function copyCode(button) {
                const codeElement = button.previousElementSibling.previousElementSibling;
                const text = codeElement.textContent;
                window.chrome.webview.hostObjects.sync.clipboard.Copy(text);
            }

            // Function to toggle code block visibility
            function toggle(button) {
                const wrapper = button.closest('.code-block-wrapper');
                wrapper.classList.toggle('collapsed');
                button.textContent = wrapper.classList.contains('collapsed') ? 'Expand' : 'Collapse';
            }

            // Override the code block renderer to include copy and toggle buttons
            const renderer = new marked.Renderer();
            renderer.code = function(code, infostring, escaped) {
                return ``<div class="code-block-wrapper"><pre><code>${code.text}</code><br /><button class="copy-button" onclick="copyCode(this)">Copy</button><button class="toggle-button" onclick="toggle(this)">Collapse</button></pre></div>``;
            };

            function renderMarkdown(content) {
                document.getElementById("content").innerHTML = marked.parse(content, { renderer: renderer });
            }
        </script>
    </body>
    </html>
    )'

isRecording := false
guiShown := false

A_TrayMenu.Delete()  ; Remove default menu items
A_TrayMenu.Add("Start Recording", StartRecording)
A_TrayMenu.Add("Stop Recording", StopRecording)
A_TrayMenu.Add("Ask LLM", DisplayLLMUserInterface)
A_TrayMenu.Add("Exit", ExitApp)

F3:: {
    global isRecording, MyGui, guiShown
    if (!isRecording) {
        StartRecording()
    } else if (!guiShown) {
        DisplayLLMUserInterface()
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

RenderMarkdown(content) {
    global wv
    escapedMd := StrReplace(content, "`"", '\"') ; simple quote escaping
    escapedMd := StrReplace(escapedMd, "`n", "\n") ; simple quote escaping
    wv.ExecuteScript("renderMarkdown(`"" escapedMd "`")")
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
        if (guiShown) {
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
        if (guiShown) {
            MyGui["Stop"].Text := "Record"
        }
    }
}

DisplayLLMUserInterface(*) {
    global MyGui, guiShown, askButton, AppSettingsValue, SessionManagerValue, wv, wvc
    if (guiShown) {
        MyGui.Show()
        return
    }
    MyGui := Gui()
    MyGui.Title := "LLM Assistant"
    MyGui.SetFont("s9", "Segoe UI")
    MyGui.Opt("+Resize +MinSize800x610")  ; Only main window gets resize option

    MyGui.OnEvent("Size", GuiResize)

    ; Add session selector
    sessionCombo := MyGui.Add("DropDownList", "x10 y10 w70 vSessionSelect", SessionManagerValue.sessionNames)
    sessionCombo.Value := SessionManagerValue.currentSessionIndex
    sessionCombo.OnEvent("Change", SessionChanged)

    ; Add record button
    recordButtonTitle := isRecording ? "Stop" : "Record"
    recordButton := MyGui.Add("Button", "x90 y10 w90", recordButtonTitle)
    recordButton.OnEvent("Click", ToggleRecording)

    ; Button section moved down
    resetButton := MyGui.Add("Button", "x300 y10 w90", "Reset All")
    resetButton.OnEvent("Click", ResetAll)

    ; Add context list with reduced height
    context := SessionManagerValue.GetCurrentSessionContext()
    listBox := MyGui.Add("ListBox", "vListBox x10 y40 w380 h150 VScroll Multi", context)
    listBox.OnEvent("Change", ListBoxSelect)  ; Add this line

    ; Context buttons moved up
    clearAllButton := MyGui.Add("Button", "x10 y190 w120", "Clear All")
    clearAllButton.OnEvent("Click", ClearAllContext)

    clearSelectionButton := MyGui.Add("Button", "x140 y190 w120", "Clear Selection")
    clearSelectionButton.OnEvent("Click", ClearSelection)

    deleteButton := MyGui.Add("Button", "x270 y190 w120", "Delete Selected")
    deleteButton.OnEvent("Click", DeleteSelected)

    ; Add ListView for chat history
    chatHistory := MyGui.Add("ListView", "vChatHistory x10 y220 w380 h150 NoSort", ["Role", "Text"])
    chatHistory.ModifyCol(1, 60)  ; Role column width
    chatHistory.ModifyCol(2, 310) ; Text column width
    chatHistory.OnEvent("ItemSelect", ChatHistorySelect)

    deleteMessageButton := MyGui.Add("Button", "x10 y375 w120", "Delete Selected")
    deleteMessageButton.OnEvent("Click", DeleteSelectedMessage)

    runToolButton := MyGui.Add("Button", "vRunToolButton x140 y375 w120 Hidden", "Run Tool")
    runToolButton.OnEvent("Click", RunSelectedTool)

    clearHistoryButton := MyGui.Add("Button", "x270 y375 w120", "Clear History")
    clearHistoryButton.OnEvent("Click", ClearChatHistory)

    ; Prompt section with increased height
    promptEdit := MyGui.Add("Edit", "vPromptEdit x10 y405 w380 h140 Multi WantReturn", "")
    promptEdit.OnEvent("Change", PromptChange)

    ; Add LLM type selector near Reset All button
    llmTypeCombo := MyGui.Add("DropDownList", "x10 y570 w70 vLLMType", AppSettingsValue.llmTypes)
    llmTypeCombo.Value := SessionManagerValue.GetCurrentSessionLLMType()
    llmTypeCombo.OnEvent("Change", LLMTypeChanged)

    ; Add system prompt selector
    systemPromptCombo := MyGui.Add("DropDownList", "x90 y570 w100 vSystemPrompt", AppSettingsValue.GetSystemPromptNames(SessionManagerValue.GetCurrentSessionLLMType()))
    systemPromptCombo.Value := SessionManagerValue.GetCurrentSessionSystemPrompt()
    systemPromptCombo.OnEvent("Change", SystemPromptChanged)

    askButton := MyGui.Add("Button", "x200 y570 w190 vAskLLM", "Ask LLM")
    askButton.OnEvent("Click", AskToLLM)

    ; Right panel remains unchanged
    responseCtr := MyGui.Add("Edit", "vResponseCtr x420 y10 w790 h580 -VScroll", "")

    MyGui.OnEvent("Close", GuiClose)
    MyGui.Show("w1230 h610")

    wvc := WebView2.CreateControllerAsync(responseCtr.Hwnd).await2()
    wv := wvc.CoreWebView2
    wv.NavigateToString(htmlContent)
    wv.AddHostObjectToScript("clipboard", clipboardHost)
    guiShown := true

    UpdateChatHistoryView()
}

SystemPromptChanged(*) {
    global MyGui, SessionManagerValue
    SessionManagerValue.SetCurrentSessionSystemPrompt(MyGui["SystemPrompt"].Value)
}

LLMTypeChanged(*) {
    global MyGui, AppSettingsValue, SessionManagerValue
    SessionManagerValue.SetCurrentSessionLLMType(MyGui["LLMType"].Value)

    systemPromptCombo := MyGui["SystemPrompt"]
    systemPromptCombo.Delete()
    systemPromptCombo.Add(AppSettingsValue.GetSystemPromptNames(SessionManagerValue.GetCurrentSessionLLMType()))
    systemPromptCombo.Value := 1  ; Reset to first prompt when LLM type changes
    SessionManagerValue.SetCurrentSessionSystemPrompt(1)
}

; Update session switching function
SessionChanged(*) {
    global MyGui, AppSettingsValue, SessionManagerValue

    ; Switch to new session
    SessionManagerValue.SwitchSession(MyGui["SessionSelect"].Value)

    UpdateContextView()
    UpdateChatHistoryView()

    ; Update LLM type and system prompt selections
    MyGui["LLMType"].Value := SessionManagerValue.GetCurrentSessionLLMType()

    ; Update system prompts for the selected LLM type
    systemPromptCombo := MyGui["SystemPrompt"]
    systemPromptCombo.Delete()
    systemPromptCombo.Add(AppSettingsValue.GetSystemPromptNames(SessionManagerValue.GetCurrentSessionLLMType()))
    systemPromptCombo.Value := SessionManagerValue.GetCurrentSessionSystemPrompt()

    ; Clear response field
    RenderMarkdown("")  ; Clear the response area
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
    messages := SessionManagerValue.GetCurrentSessionMessagesAsStrings()
    chatHistory := MyGui["ChatHistory"]
    chatHistory.Delete()
    for msg in messages {
        chatHistory.Add(, msg.role, SubStr(msg.content, 1, 70) (StrLen(msg.content) > 70 ? "..." : ""))
    }
}

AskToLLM(*) {
    messages := SessionManagerValue.GetCurrentSessionMessages()
    promptText := MyGui["PromptEdit"].Value
    messages.Push({ role: "user", content: promptText })
    SendToLLM()
    MyGui["PromptEdit"].Value := ""  ; Clear prompt field
}

SendToLLM() {
    messages := SessionManagerValue.GetCurrentSessionMessages()
    messages[1].content := AppSettingsValue.GetSystemPromptValue(SessionManagerValue.GetCurrentSessionLLMType(), SessionManagerValue.GetCurrentSessionSystemPrompt())
    context := SessionManagerValue.GetCurrentSessionContext()

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
        messages[1].content .= "`nHere is the context:`n" contextText "`nPlease consider this context when answering the following question."

        ; Add selected items as special focus points
        if (selectedIndices.Length > 0) {
            messages[1].content .= "`nThe user has selected these items which may be particularly relevant:`n"
            for index in selectedIndices {
                messages[1].content .= GetTextFromContextItem(context[index])
            }
        }
    }

    ; Disable Ask LLM button while processing
    if (MyGui) {
        askButton.Enabled := false
    }

    try {
        ; Create LLM client if it doesn't exist yet
        LLMClientInstance := LLMClient(AppSettingsValue.GetSelectedSettings(SessionManagerValue.GetCurrentSessionLLMType()))

        assistantResponse := LLMClientInstance.Call(messages)
        if (assistantResponse.Type = "tool_call") {
            ; Create proper assistant message with tool_calls
            newMessage := {
                role: "assistant",
                content: "",  ; Empty content as we have tool_calls
                tool_calls: [{
                    id: assistantResponse.content.id,
                    type: "function",
                    function: {
                        name: assistantResponse.content.name,
                        arguments: assistantResponse.content.arguments
                    }
                }]
            }
        } else {
            newMessage := { role: "assistant", content: assistantResponse.content }
        }
    } catch as e {
        newMessage := { role: "assistant", content: e.Message }
    } finally {
        ; Re-enable Ask LLM button
        if (MyGui) {
            askButton.Enabled := true
        }
    }
    messages.Push(newMessage)
    UpdateChatHistoryView()  ; Update the chat history view
    RenderMarkdown(SessionManagerValue.GetMessageAsString(newMessage))
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

    RenderMarkdown(textContent)  ; Render the selected item(s) in the WebView
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
    global MyGui, SessionManagerValue
    SessionManagerValue.ClearCurrentMessages()

    UpdateChatHistoryView()  ; Update the chat history view
    RenderMarkdown("")  ; Clear the response area
}

ResetAll(*) {
    global MyGui, SessionManagerValue

    ; Reset current session
    SessionManagerValue.ResetCurrentSession()

    ; Update UI
    UpdateChatHistoryView()
    UpdateContextView()

    ; Clear response and prompt
    RenderMarkdown("")  ; Clear the response area
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
        msg := messages[focused_row]
        RenderMarkdown(SessionManagerValue.GetMessageAsString(msg))  ; Render the selected message in the WebView

        ; Show/hide Run Tool button based on message type
        if (msg.HasOwnProp("tool_calls") && msg.tool_calls.Length > 0) {
            ; Check if there's already a tool response for this tool call
            hasToolResponse := false
            for toolCall in msg.tool_calls {
                for i in messages {
                    if (i.HasOwnProp("role") && i.role = "tool" && i.HasOwnProp("tool_call_id") && i.tool_call_id = toolCall.id) {
                        hasToolResponse := true
                        break
                    }
                }
                if (hasToolResponse)
                    break
            }
            MyGui["RunToolButton"].Visible := !hasToolResponse
        } else {
            MyGui["RunToolButton"].Visible := false
        }
    }
}

RunSelectedTool(*) {
    global MyGui
    messages := SessionManagerValue.GetCurrentSessionMessages()
    chatHistory := MyGui["ChatHistory"]
    if (focused_row := chatHistory.GetNext()) {
        msg := messages[focused_row]
        if (msg.HasOwnProp("tool_calls")) {
            try {
                MyGui["RunToolButton"].Enable := false
                for tool_call in msg.tool_calls {
                    if result := ComSpecToolValue.ExecuteToolCall(tool_call) {
                        messages.Push(result)
                    }
                    if result := FileSystemToolValue.ExecuteToolCall(tool_call) {
                        messages.Push(result)
                    }
                }
                RenderMarkdown(SessionManagerValue.GetMessageAsString(messages[messages.Length]))  ; Render the response in the WebView
                UpdateChatHistoryView()
                SendToLLM()
            } finally {
                MyGui["RunToolButton"].Enable := true
            }
        }
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
            AskToLLM()
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

    selectedIndices := []
    focused_row := 0

    ; Collect all selected rows
    while (focused_row := chatHistory.GetNext(focused_row))
        if (focused_row > 1)  ; Don't include system message
            selectedIndices.InsertAt(1, focused_row)

    ; Remove messages in reverse order to maintain correct indices
    for index in selectedIndices
        messages.RemoveAt(index)

    UpdateChatHistoryView()
    RenderMarkdown("")  ; Clear the response area
}

GuiResize(thisGui, MinMax, Width, Height) {
    global wvc  ; Add wv to globals
    if (MinMax = -1)  ; If window is minimized
        return

    ; Calculate new dimensions for ResponseCtr
    responseCtrX := 420
    responseCtrY := 10
    responseCtrWidth := Width - 430
    responseCtrHeight := Height - 20

    ; Resize the ResponseCtr control
    thisGui["ResponseCtr"].Move(responseCtrX, responseCtrY, responseCtrWidth, responseCtrHeight)

    ; Resize the WebView2 control to match ResponseCtr
    if (IsSet(wvc) && wvc) {  ; Check if WebView2 controller exists
        hCtrl := thisGui["ResponseCtr"].Hwnd
        rect := Buffer(16, 0)  ; RECT: left, top, right, bottom
        DllCall("GetClientRect", "ptr", hCtrl, "ptr", rect)

        width := NumGet(rect, 8, "Int")   ; right
        height := NumGet(rect, 12, "Int") ; bottom
        ; Set bounds relative to the ResponseCtr — top-left is (0,0)
        wvRect := Buffer(16, 0)
        NumPut("Int", 0, wvRect, 0)                          ; left
        NumPut("Int", 0, wvRect, 4)                          ; top
        NumPut("Int", width, wvRect, 8)           ; right
        NumPut("Int", height, wvRect, 12)         ; bottom
        wvc.Bounds := wvRect
    }

    ; Resize the prompt edit control
    promptEditHeight := 140  ; Original height
    bottomControlsHeight := 40  ; Height reserved for bottom controls
    thisGui["PromptEdit"].Move(10, 405, 380, Height - 405 - bottomControlsHeight)

    ; Move bottom controls
    bottomY := Height - 35  ; 35 pixels from bottom
    thisGui["LLMType"].Move(10, bottomY)
    thisGui["SystemPrompt"].Move(90, bottomY)
    thisGui["AskLLM"].Move(200, bottomY)
}
