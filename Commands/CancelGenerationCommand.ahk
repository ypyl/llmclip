#Requires AutoHotkey 2.0

/**
 * Command to cancel an ongoing LLM generation.
 */
class CancelGenerationCommand {
    llmService := ""

    __New(llmService) {
        this.llmService := llmService
    }

    Execute() {
        if (this.llmService) {
            this.llmService.Cancel()
        }
    }
}
