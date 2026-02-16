# AHK UI Application — Architectural Instructions

## 1. Core rule

**UI, logic, intent, and state domains must never mix.**

* UI state ≠ Application / domain state
* Controllers own **UI state only**
* Services own **all non-UI state**

If a file touches GUI controls, it contains **no business logic**.
If a file contains logic or non-UI state, it **never references GUI**.

---

## 2. File roles (non-negotiable)

### `main.ahk`

* Composition root only
* Creates `App`
* Starts application
* Owns lifetime
* **No GUI, no logic, no commands**

---

### `App`

* Wires controllers
* Owns windows
* Manages startup / shutdown
* No business logic
* No state (delegates state ownership)

---

### View (`ui/*.ahk`)

* Creates GUI controls
* Stores control references
* Forwards events to controller
* Zero decisions
* Zero commands
* Zero services
* **Zero state (read/write only via controller)**

---

### Controller (`controllers/*.ahk`)

* One **root controller** per window
* Optional **sub-controllers** per responsibility
* Owns **UI state only**

  * selection
  * focus
  * visibility
  * enabled/disabled
  * transient input values
* Reads control state
* Writes control state
* Coordinates UI flow
* Invokes commands
* **May read external state directly from services**
* **Must NOT mutate external state directly**
* **Must NOT depend on other controllers**
* **No business rules**

> If multiple controllers exist for one window, **they are isolated**.
> Coordination happens **only via the root controller or services**, never via controller-to-controller calls.

Controllers are **orchestrators**, not models and not collaborators.

---

### Command (`commands/*.ahk`)

* Represents one use-case
* Executes synchronously
* UI-agnostic
* Small and intention-revealing
* **The only place allowed to mutate external state**
* No GUI access

---

### Service / Domain (`services/*.ahk`)

* Owns **all non-UI state**

  * configuration
  * persisted data
  * runtime application state
* Pure logic
* File system / OS / WinAPI access
* Exposes **read APIs** for controllers
* Exposes **mutation APIs** for commands
* No GUI
* No controllers

Services are the **single source of truth**.

---

## 3. State ownership rules

### UI State

* Owned by **Controller**
* Derived from user input and view events
* Transient and disposable
* Never persisted
* Never shared across controllers

---

### External State

* Owned by **Services**
* Durable / shared
* Never duplicated in controllers

---

## 4. State access rules

Allowed:

* Controller → Service (**read only**)
* Command → Service (**read/write**)

Forbidden:

* Controller → Service mutation
* Controller → Controller
* View → Service
* Service → UI

---

## 5. Event flow (fixed)

```
GUI Event
 → Controller
   → (optional) Service.Read()
   → Command.Execute()
     → Service.Mutate()
   → Controller updates UI state
```

---

## 6. Dependency rules

Allowed:

* Controller → View
* Controller → Command
* Controller → Service (read-only)
* Command → Service

Forbidden:

* Controller → Controller
* View → Command / Service
* Service → Controller / View
* Command → GUI

---

## 7. UI scaling rules

* One window = one root controller
* Sub-controllers split by responsibility
* Sub-controllers never reference each other
* Root controller coordinates when needed
* UI is not a state store
* Controller state is transient

If state must survive → it belongs in a service.

---

## 8. Dependency management

Preferred order:

1. Direct construction
2. Manual constructor injection
3. Explicit static service registry

Forbidden by default:

* DI containers
* string-based service lookup
* hidden globals

---

## 9. Error handling

* Global try/catch in `clip.ahk`
* Domain errors handled in commands
* Services throw domain-specific errors
* UI displays errors only

---

## 10. What is explicitly forbidden

* Logic in views
* GUI code in commands
* Business rules in controllers
* Controllers mutating services
* Controllers depending on controllers
* Services storing UI state
* God scripts
* String-based Service Locator
* MVC dogma

---

## 11. Directory layout (fixed)

```
/main.ahk
/ui
/controllers
/commands
/services
```

No circular references.

---

## 12. Sanity checks

If you cannot answer:

> “Which command mutates this state?”

or

> “Why does this controller know about another controller?”

The architecture is already broken.

---

**This is not MVC.**
It is **Controller-isolated, Command-gated, Service-owned state architecture**, designed to prevent AHK scripts from collapsing into entropy.


---


# AHK UI Architecture — Core Lint Rules (Minimal)

## Global (instant fail)

* ⛔ GUI code mixed with logic anywhere
* ⛔ Command references GUI
* ⛔ Service references GUI or controller
* ⛔ Logic in `main.ahk`

---

## `main.ahk`

* ✔ Bootstrap only (App creation + Run)
* ⛔ `Gui`, commands, services, domain logic
* ⛔ conditionals beyond startup

---

## View (`ui/*.ahk`)

* ✔ Create controls, store references, forward events
* ⛔ commands, services, logic, decisions
* ⛔ state ownership

---

## Controller (`controllers/*.ahk`)

* ✔ Owns **UI state only**
* ✔ Reads services (read-only)
* ✔ Triggers commands for all mutations
* ✔ One window responsibility
* ⛔ business rules
* ⛔ persistence / OS calls
* ⛔ GUI creation
* ⛔ controller → controller dependency

---

## Command (`commands/*.ahk`)

* ✔ One use-case, `Execute()`
* ✔ Only place allowed to mutate services
* ⛔ GUI access
* ⛔ calling other commands

---

## Service (`services/*.ahk`)

* ✔ Owns all non-UI state
* ✔ Logic / OS / persistence
* ⛔ UI, controllers, commands, events

---

## State rules

* UI state → **Controller**
* App/domain/config state → **Service**
* ⛔ Controller mutates service directly
* ⛔ UI as state store

---

## Dependency direction (only these allowed)

```
Controller → View
Controller → Command
Controller → Service (read-only)
Command → Service (read/write)
```

Anything else → ⛔

---

## Forbidden patterns (instant fail)

* God controller / god script
* String-based service lookup
* Hidden globals
* MVC assumptions
* Commands coordinating flow

---

## Final audit (binary)

> Can you name **one command** that explains this feature?

No → **architecture failed**

---

**Summary**

* Views = structure
* Controllers = coordination + UI state
* Commands = intent + mutation gate
* Services = truth

Everything else is noise.
