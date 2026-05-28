#Requires AutoHotkey 2.0

class DeleteMessageCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    /**
     * Executes the delete message command
     * @param selectedIndices Array of indices to delete from history
     */
    Execute(selectedIndices) {
        if (selectedIndices.Length == 0)
            return

        ; Sort descending so removals don't shift indices of remaining deletions
        selectedIndices := this._SortDescending(selectedIndices)

        messages := this.sessionManager.GetCurrentSessionMessages()
        
        ; Remove messages in reverse order to maintain correct indices
        for index in selectedIndices {
            if (index > 1 && index <= messages.Length) { ; Don't include system message
                messages.RemoveAt(index)
            }
        }
    }

    _SortDescending(arr) {
        sorted := arr.Clone()
        n := sorted.Length
        Loop n - 1 {
            i := A_Index + 1
            while (i > 1 && sorted[i] > sorted[i - 1]) {
                tmp := sorted[i]
                sorted[i] := sorted[i - 1]
                sorted[i - 1] := tmp
                i--
            }
        }
        return sorted
    }
}
