class CancelRequestCommand {
    llmService := ""
    
    __New(llmService) {
        this.llmService := llmService
    }
    
    Execute() {
        this.llmService.Cancel()
        return { action: "idle" }
    }
}