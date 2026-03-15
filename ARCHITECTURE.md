# llmclip Architecture Guidelines

## 1. Core Principles

**Domain Integrity**: UI, logic, intent, and state must never mix.
* **Controllers**: Own UI state. No business logic.
* **Services**: Own all non-UI state. Single source of truth. No GUI references.
* **Commands**: Gated mutation of state. UI-agnostic.

---

## 2. File Roles & Responsibilities

### [main.ahk](file:///c:/Users/ypyl/projects/llmclip/main.ahk)
* **Role**: Entry point/Bootstrap.
* **Responsibilities**: Create `App` instance and call `App.Start()`.
* ⛔ **Forbidden**: GUI code, services, commands, or logic.

### [App.ahk](file:///c:/Users/ypyl/projects/llmclip/App.ahk)
* **Role**: Composition Root.
* **Responsibilities**: **The ONLY place** where instances of Services, Commands, Controllers, and Views are created.
* **Dependency Management**: Manual Constructor Injection only.
* **Wiring Pattern**: If a View requires Controller callbacks, use property assignment after instantiation to avoid constructor circularity:
  ```ahk
  view := View()
  controller := Controller(view)
  view.controller = controller
  ```
* ⛔ **Forbidden**: Business logic or internal state.

### Views (`ui/*.ahk`)
* **Role**: Declaration of UI structure.
* **Responsibilities**: Create controls, store references, forward events to controller.
* ⛔ **Forbidden**: State ownership, decisions, commands, or services.

### Controllers (`controllers/*.ahk`)
* **Role**: UI Coordination.
* **Responsibilities**: Coordinate UI flow, read/write control state, invoke commands.
* **Access**: Can read from services (read-only).
* ⛔ **Forbidden**: Mutating external state, OS/File calls, or controller-to-controller dependencies.

### Commands (`commands/*.ahk`)
* **Role**: Single Use-Case / Intent.
* **Responsibilities**: **The ONLY place** allowed to mutate external state (services).
* ⛔ **Forbidden**: GUI access or calling other commands.

### Services (`services/*.ahk`)
* **Role**: Domain Logic & State Ownership.
* **Responsibilities**: Pure logic, OS/WinAPI/persistence access.
* ⛔ **Forbidden**: UI, controllers, or command references.

### Utility Services (`utils/*.ahk` or static methods)
* **Role**: Pure Helpers / Stateless Logic.
* **Responsibilities**: Formatting, parsing, mathematical operations, or shared pure logic.
* **Implementation**: Uses static methods only. Does **not** require instantiation in `App.ahk`.
* ⛔ **Forbidden**: Storing state, GUI access.

---

## 3. Dependency & State Rules

### State Ownership
| State Type | Owner | Persistence |
| :--- | :--- | :--- |
| **UI State** | Controller | Transient / Disposable |
| **Domain State** | Service | Durable / Shared |

### Allowed Communication
1. **Controller → View**: Full access to controls.
2. **Controller → Command**: Invoke `Execute()`.
3. **Controller → Service**: **Read-only** access.
4. **Command → Service**: Read/Write access.
5. **Any → Utility**: Full access to static methods.

### Forbidden (Instant Fail)
* ⛔ Controller mutates Service directly (use a Command).
* ⛔ Service or Command touches GUI.
* ⛔ Circular dependencies or Controller → Controller calls.
* ⛔ Instantiation outside of `App.ahk` (Utility static methods are exempt).

---

## 4. Directory Layout
```text
/main.ahk
/ui           (Passive structure)
/controllers  (UI coordination)
/commands     (Intent & Gatekeepers)
/services     (Logic & Truth)
```

---

**Summary**: Views = Structure | Controllers = Coordination | Commands = Intent | Services = Truth.
