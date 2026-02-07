#Requires AutoHotkey 2.0

class DeleteContextItemsCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    Execute(indices) {
        context := this.sessionManager.GetCurrentSessionContext()
        
        ; Remove selected items in reverse order to maintain index integrity
        for index in indices {
            if (index > 0 && index <= context.Length) {
                context.RemoveAt(index)
            }
        }
        
        this.sessionManager.SetCurrentSessionContext(context)
        return true
    }
}
