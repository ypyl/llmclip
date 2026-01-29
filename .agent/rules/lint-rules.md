---
trigger: always_on
---

# AHK UI Architecture — Lint Checklist

## 0. Global invariants (fail = stop)

* ⛔ Any file mixes **GUI + business logic**
* ⛔ Any command references GUI controls
* ⛔ Any service references GUI or controller
* ⛔ Any logic in `main.ahk`

If any of these trigger → **architecture violation**

---

## 1. `main.ahk` checks

**Must contain only:**

* `#Requires`, `#SingleInstance`
* `#Include`
* `App` creation
* `Run()` call
* optional global try/catch

**Must NOT contain:**

* `Gui()`
* `.Add(`
* `.OnEvent(`
* `Command.Execute()`
* File/OS calls
* Conditionals (`if`, `loop`) beyond bootstrap

---

## 2. View (`ui/*.ahk`) checks

### Allowed

* `Gui()`
* `.Add(...)`
* `.Show()`
* `.OnEvent(...)` forwarding to controller
* Storing control references

### Forbidden

* `Execute()`
* Services
* File/OS calls
* Logic (`if`, `switch`, `loop`) except layout
* State decisions

**Fail if found:**

```ahk
SaveConfigCommand(...)
ConfigService.Save(...)
```

---

## 3. Controller (`controllers/*.ahk`) checks

### Must

* Have exactly **one window responsibility**
* Own UI state
* Translate UI → commands
* Expose intent methods (`OnSave`, `OnClose`, …)

### Allowed

* Reading `.Value`
* Writing `.Enabled`, `.Visible`
* Creating commands
* Calling `Execute()`

### Forbidden

* File/OS calls
* Domain rules
* Persistence logic
* GUI creation (`Gui()`, `.Add()`)

---

## 4. Command (`commands/*.ahk`) checks

### Must

* Represent one use-case
* Have `Execute()`
* Be UI-agnostic

### Allowed

* Constructor parameters
* Calling services
* Error handling relevant to the use-case

### Forbidden

* `.Value`
* `.Enabled`
* `Gui`
* `MsgBox` (unless domain error surfaced intentionally)

---

## 5. Service / Domain (`services/*.ahk`) checks

### Must

* Contain pure logic or OS access
* Be reusable
* Be callable from multiple commands

### Forbidden

* GUI references
* Controllers
* Commands
* Event handlers

---

## 6. Dependency direction check

Verify **only** these arrows exist:

```
Controller → View
Controller → Command
Command → Service
```

Any reverse or sideways reference = **fail**

---

## 7. UI scale checks (large forms)

* ⛔ Controller > ~300 LOC → split
* ⛔ >1 responsibility in a controller
* ⛔ Control names like `Edit23`, `Button7`
* ⛔ Direct access to `GuiCtrl[]` by index

Must see:

* grouped controls
* sub-controllers when needed

---

## 8. State management checks

Fail if:

```ahk
if (this.chkEnabled.Value)
```

Pass if:

```ahk
this.state.enabled := this.view.chkEnabled.Value
```

UI reflects state. UI is not state.

---

## 9. Service access checks

### Allowed

```ahk
ConfigService.Save()
Services.config.Save()
```

### Forbidden

```ahk
ServiceLocator.Resolve("Config")
GetService("config")
```

No strings. Ever.

---

## 10. Anti-pattern blacklist (instant fail)

* God controller
* God script
* String-based DI
* Hidden globals
* MVC dogma (“Model owns logic + View”)
* Commands calling commands

---

## 11. Final audit question (binary)

> Can you point to **one command** that explains this feature?

No → **architecture failed**

---

## Summary for agents

* Structure > cleverness
* Explicit > abstract
* Commands = intent
* Controllers = coordination
* Views = structure
* Services = reality
