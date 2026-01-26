#Requires AutoHotkey 2.0
#Include ServiceContainer.ahk
#Include ..\Settings\ConfigurationManager.ahk
#Include ..\SessionManager.ahk
#Include ..\ClipboardParser.ahk
#Include ..\WebViewManager.ahk
#Include ..\ContextManager.ahk
#Include ..\TrayManager.ahk
#Include ..\LLM\LLMService.ahk
#Include ..\ContextViewController.ahk
#Include ..\HistoryViewController.ahk
#Include ..\Controllers\MenuManager.ahk
#Include ..\Controllers\ChatManager.ahk
#Include ..\Controllers\ConversationHandler.ahk
#Include ..\Controllers\ClipboardManager.ahk

class ServiceRegistry {
    static RegisterServices() {
        container := ServiceContainer.GetInstance()

        ; Core services - register directly
        container.Register("ConfigurationManager", ObjBindMethod(ServiceRegistry, "CreateConfigurationManager"), true)
        container.Register("ClipboardParser", ObjBindMethod(ServiceRegistry, "CreateClipboardParser"), true)
        container.Register("WebViewManager", ObjBindMethod(ServiceRegistry, "CreateWebViewManager"), true)
        container.Register("ContextManager", ObjBindMethod(ServiceRegistry, "CreateContextManager"), true)
        container.Register("LLMService", ObjBindMethod(ServiceRegistry, "CreateLLMService"), true)
        container.Register("SessionManager", ObjBindMethod(ServiceRegistry, "CreateSessionManager"), true)

        ; View controllers
        container.Register("ContextViewController", ObjBindMethod(ServiceRegistry, "CreateContextViewController"), false)
        container.Register("HistoryViewController", ObjBindMethod(ServiceRegistry, "CreateHistoryViewController"), false)

        ; Factories for app-dependent services
        container.Register("MenuManagerFactory", ObjBindMethod(ServiceRegistry, "CreateMenuManager"), false)
        container.Register("ChatManagerFactory", ObjBindMethod(ServiceRegistry, "CreateChatManager"), false)
        container.Register("ConversationHandlerFactory", ObjBindMethod(ServiceRegistry, "CreateConversationHandler"), false)
        container.Register("ClipboardManagerFactory", ObjBindMethod(ServiceRegistry, "CreateClipboardManager"), false)
        container.Register("TrayManagerFactory", ObjBindMethod(ServiceRegistry, "CreateTrayManager"), false)
    }

    ; Factory methods
    static CreateConfigurationManager() => ConfigurationManager.GetInstance()
    static CreateClipboardParser() => ClipboardParser()
    static CreateWebViewManager() => WebViewManager()
    static CreateContextManager() => ContextManager()

    static CreateLLMService() {
        container := ServiceContainer.GetInstance()
        return LLMService(container.Get("ConfigurationManager"))
    }

    static CreateSessionManager() {
        container := ServiceContainer.GetInstance()
        config := container.Get("ConfigurationManager")
        return SessionManager(config.selectedLLMTypeIndex, config.GetSystemPromptValue(config.selectedLLMTypeIndex, 1))
    }

    static CreateContextViewController() {
        container := ServiceContainer.GetInstance()
        return ContextViewController(container.Get("SessionManager"), container.Get("ConfigurationManager"), container.Get("ContextManager"), container.Get("WebViewManager"))
    }

    static CreateHistoryViewController() {
        container := ServiceContainer.GetInstance()
        return HistoryViewController(container.Get("SessionManager"), container.Get("WebViewManager"), container.Get("ConfigurationManager"))
    }

    static CreateMenuManager(app) {
        container := ServiceContainer.GetInstance()
        return MenuManager(app, container.Get("ConfigurationManager"), container.Get("SessionManager"))
    }

    static CreateChatManager(app) {
        container := ServiceContainer.GetInstance()
        return ChatManager(app, container.Get("ConfigurationManager"), container.Get("SessionManager"), container.Get("LLMService"), container.Get("ContextManager"))
    }

    static CreateConversationHandler(app) {
        container := ServiceContainer.GetInstance()
        return ConversationHandler(app, container.Get("ConfigurationManager"), container.Get("SessionManager"), container.Get("LLMService"), container.Get("MenuManagerFactory", app))
    }

    static CreateClipboardManager(app) {
        container := ServiceContainer.GetInstance()
        return ClipboardManager(app, container.Get("SessionManager"), container.Get("ContextManager"))
    }

    static CreateTrayManager(displayCallback, updateCallback, exitCallback) {
        container := ServiceContainer.GetInstance()
        return TrayManager(displayCallback, updateCallback, exitCallback, container.Get("ContextManager"))
    }
}
