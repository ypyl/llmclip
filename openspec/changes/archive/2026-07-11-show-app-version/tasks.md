## 1. Version source

- [ ] 1.1 Create `version.txt` at repo root with current version string `1.3.4`

## 2. App.ahk — read and pass version

- [ ] 2.1 In `App.__New`, read `version.txt` (with fallback to `"dev"`), store as a local variable
- [ ] 2.2 Pass version string to `MainView` constructor

## 3. MainView — display version label

- [ ] 3.1 Add `versionText` property and constructor parameter to `MainView`
- [ ] 3.2 In `BuildUI`, add a `Text` control at top-right showing the version
- [x] 3.3 In `OnResize`, reposition the version label to `Width - 80`

## 4. Integration check

- [ ] 4.1 Run `main.ahk` — verify version appears top-right, repositions on resize
