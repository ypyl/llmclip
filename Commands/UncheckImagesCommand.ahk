#Requires AutoHotkey 2.0

/**
 * Command to uncheck all image items in the current session context.
 * UI-agnostic logic for modifying session state.
 */
class UncheckImagesCommand {
    sessionManager := ""
    
    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    /**
     * Executes the command.
     * @returns {Boolean} True if any items were unchecked, false otherwise.
     */
    Execute() {
        return this.sessionManager.UncheckAllImages()
    }
}
