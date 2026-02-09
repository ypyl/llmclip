---
trigger: always_on
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
