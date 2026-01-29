---
trigger: always_on
---

# AHK UI Application — Architectural Instructions

## 1. Core rule

**UI, logic, and intent must never mix.**

If a file touches GUI controls, it contains **no business logic**.
If a file contains logic, it **never references GUI**.

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

---

### View (`ui/*.ahk`)

* Creates GUI controls
* Stores control references
* Forwards events to controller
* Zero decisions
* Zero commands
* Zero services

---

### Controller (`controllers/*.ahk`)

* One controller per window
* Reads control state
* Writes control state
* Coordinates UI flow
* Invokes commands
* Owns UI state
* **No business rules**

---

### Command (`commands/*.ahk`)

* Represents one use-case
* Executes synchronously
* UI-agnostic
* Small and intention-revealing
* No GUI access

---

### Service / Domain (`services/*.ahk`)

* Pure logic
* File system / OS / WinAPI access
* No GUI
* No controllers
* Reusable

---

## 3. Event flow (fixed)

```
GUI Event
 → Controller method
   → Command.Execute()
     → Service
```

No shortcuts. Ever.

---

## 4. Dependency rules

Allowed:

* Controller → View
* Controller → Command
* Command → Service

Forbidden:

* View → Command / Service
* Service → Controller / View
* Command → GUI

---

## 5. UI scaling rules

* One window = one controller
* Large windows → sub-controllers by responsibility
* Group controls logically (objects, not indexes)
* UI is not a state store
* Controller owns state

---

## 6. Dependency management

Preferred order:

1. Direct construction
2. Manual constructor injection
3. Explicit static service registry

Forbidden by default:

* DI containers
* string-based service lookup
* hidden globals

---

## 7. Error handling

* Global try/catch in `clip.ahk`
* Domain errors handled in commands
* UI shows errors, does not decide on them

---

## 8. What is explicitly forbidden

* Logic in views
* GUI code in commands
* Business rules in controllers
* God scripts
* String-based Service Locator
* MVC dogma

---

## 9. Directory layout (fixed)

```
/main.ahk
/ui
/controllers
/commands
/services
```

No circular references.

---

## 10. Sanity check

If you cannot answer:

> “Which command is this feature?”

The architecture is already broken.

---

**This is not MVC.**
It is **Controller-centric, Command-driven, UI-contained** architecture optimized for AHK.

If you want, I can also produce:

* a one-page diagram
* an agent “lint checklist”
* a refactoring guide from existing scripts