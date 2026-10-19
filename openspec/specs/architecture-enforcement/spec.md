# architecture-enforcement Specification

## Purpose

Layering rules for the codebase. The composition root in `App.ahk` is the only place where services, commands, controllers and views are instantiated, so dependencies stay explicit and no layer reaches across a boundary.

## Requirements

### Requirement: Instantiation happens in the composition root
Services, commands, controllers and views SHALL be instantiated only in `App.ahk`. Classes that expose static helpers only SHALL NOT be instantiated there.

#### Scenario: A new service is introduced
- **WHEN** a new service class is added
- **THEN** its `#Include` appears in `App.ahk`
- **AND** the instance is created in `App.ahk` and handed to its consumers by constructor
