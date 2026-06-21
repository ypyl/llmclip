# llmclip Architecture Guidelines

## 1. Core Principles

**Domain Integrity**: UI, logic, intent, and state must never mix.
* **Controllers**: Own UI state. No business logic.
* **Services**: Own all non-UI state. Single source of truth. No GUI references.
* **Commands**: Gated mutation of state. UI-agnostic.
* **Domain Objects**: Pure data. No behavior beyond serialization/cloning. No external dependencies.

---

## 2. File Roles & Responsibilities

### [main.ahk](file:///c:/Users/ypyl/projects/llmclip/main.ahk)
* **Role**: Entry point / Bootstrap.
* **Responsibilities**: Create `App` instance and call `App.Start()`.
* ⛔ **Forbidden**: GUI code, services, commands, or logic.

### [App.ahk](file:///c:/Users/ypyl/projects/llmclip/App.ahk)
* **Role**: Composition Root.
* **Responsibilities**: **The ONLY place** where instances of Services, Commands, Controllers, Tools, and Views are created.
* **Dependency Registry**: The `#Include` list at the top of `App.ahk` IS the project's dependency graph. Every class file used by the application must be included here. Sub-files use relative `#Include` paths from their own directory.
* **Dependency Management**: Manual Constructor Injection only.
* **Wiring Pattern**: If View requires Controller callbacks (or vice versa), use property assignment after construction to avoid constructor circularity:
  ```ahk
  controller := MainController(cfg, sess, llm, wv, rec, ctx)
  view := MainView(controller)
  controller.SetView(view)
  ```
  The Controller is created first with its service dependencies, the View receives the controller reference, then the View is back-wired into the Controller.
  The same pattern applies when a sub-controller needs to notify its parent controller — set a callback on the sub-controller after construction rather than reaching through the View's back-references.
* ⛔ **Forbidden**: Business logic or internal state.

### Views (`ui/*.ahk`)
* **Role**: Declaration of UI structure.
* **Responsibilities**: Create controls, store references, forward events to controller.
* ⛔ **Forbidden**: State ownership, decisions, commands, or services.

### Controllers (`controllers/*.ahk`)
* **Role**: UI Coordination.
* **Responsibilities**: Coordinate UI flow, read/write control state, invoke commands.
* **Access**: Can read from services (read-only). Can hold references to sub-controllers.
* ⛔ **Forbidden**: Mutating service state directly (use a Command), OS/File calls, or controller-to-controller calls.

### Commands (`commands/*.ahk`)
* **Role**: Single Use-Case / Intent.
* **Responsibilities**: **The ONLY place** allowed to mutate service state.
* ⛔ **Forbidden**: GUI access or calling other commands.

### Services (`services/*.ahk`)
* **Role**: Domain Logic & State Ownership.
* **Responsibilities**: Pure logic, OS/WinAPI/persistence access. Own durable state.
* **Tools** (`services/LLM/*Tool.ahk`): A specialized sub-category of services. Tools are callable by LLMs and include both a tool definition (static schema) and an `ExecuteToolCall()` method. They are instantiated in `App.ahk` and stored in the `toolsMap`.
* **Singleton**: `ConfigurationService` uses `GetInstance()` instead of constructor injection because it must be accessible from tools that are invoked outside the normal DI chain. All other services use constructor injection.
* ⛔ **Forbidden**: UI, controllers, or command references. (See §5 for boundary exceptions.)

### Domain Objects (`Services/Types.ahk`, `Services/Session.ahk`, etc.)
* **Role**: Pure data containers.
* **Responsibilities**: Hold structured data with serialization (`ToObject()`, `FromObject()`) and cloning (`Clone()`) support.
* **Examples**: `ChatMessage`, `TextContent`, `FunctionCallContent`, `Session`, `History`, `ContextItem`, `ChatRole`, `ProcessingState`.
* **Implementation**: May have convenience methods (e.g., `GetText()`, `HasToolCalls()`) but no external dependencies, no OS access, no state mutation of other objects.
* ⛔ **Forbidden**: File I/O, GUI references, service/command references, or instantiation in `App.ahk` (they are created by services/commands as needed).

### Utils (`utils/*.ahk`)
* **Role**: Pure Helpers / Stateless Logic.
* **Responsibilities**: Formatting, parsing, clipboard access, base64 encoding, or shared pure logic.
* **Implementation**: Static methods only. Does **not** require instantiation in `App.ahk`.
* ⛔ **Forbidden**: Storing state, GUI access.

---

## 3. Dependency & State Rules

### State Ownership
| State Type | Owner | Persistence |
| :--- | :--- | :--- |
| **UI State** | Controller | Transient / Disposable |
| **Domain State** | Service | Durable / Shared |
| **Message Data** | Domain Objects | Passed by value (Clone) |

### Allowed Communication
1. **Controller → View**: Full access to controls.
2. **Controller → Command**: Invoke `Execute()`.
3. **Controller → Service**: **Read-only** access.
4. **Command → Service**: Read/Write access.
5. **Service → Domain Objects**: Create, clone, serialize.
6. **Any → Utils**: Full access to static methods.

### Forbidden (Instant Fail)
* ⛔ Controller mutates Service directly (use a Command).
* ⛔ Service or Command touches GUI.
* ⛔ Circular dependencies or Controller → Controller calls.
* ⛔ Instantiation (`new`) outside of `App.ahk` (Utils static methods and Domain Objects are exempt — Domain Objects are created by services/commands at runtime).

---

## 4. Directory Layout
```text
/main.ahk
/App.ahk              (Composition root + #Include registry)
/ui                   (Passive GUI structure — MainView, ContextView, etc.)
/controllers          (UI coordination — one per view area)
/commands             (Intent & gatekeepers — one per use-case)
/services
  /Configuration      (Provider config, system prompts, roles)
  /LLM                (LLM client, providers, tool implementations)
  SessionManager.ahk  (Multi-session chat state)
  ContextManager.ahk  (Clipboard/file context processing)
  WebViewManager.ahk  (WebView2 bridge — see §5)
  Session.ahk         (Domain Object — session data)
  History.ahk         (Domain Object — message history tree)
  ContextItem.ahk     (Domain Object — context list item)
/utils                (Static helpers — clipboard, files, base64, JSON)
/Lib                  (Vendored — thqby/ahk2_lib — DO NOT EDIT)
```

---

## 5. Exceptions & Boundary Cases

Some classes legitimately cross architectural boundaries. These are deliberate exceptions, not violations:

| Class | Crosses | Why |
|:---|:---|:---|
| **`WebViewManager`** | Service ↔ GUI | Must hold a WebView2 HWND and controller reference. Encapsulates all WebView2 interop in one place rather than leaking it into controllers. |
| **`ContextPresentationService`** | Service → View formatting | Formats domain data (context items) into UI-ready labels. Stateless — could be a Utils class, but imports domain types. |
| **`MessagePresentationHelper`** | Utils → View formatting | Static helper that formats ChatMessage objects into markdown strings for the WebView. Pure utility, stateless. |
| **`ConfigurationService`** | Breaks DI (singleton) | Accessed via `GetInstance()` so tools created outside the normal DI chain can trigger config reloads after creating prompts. |

When adding new code that crosses boundaries, document it here.

---

**Summary**: Views = Structure | Controllers = Coordination | Commands = Intent | Services = Truth | Domain Objects = Data.
