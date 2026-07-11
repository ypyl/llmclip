## 1. LLMClient — remove dead cleanup code

- [x] 1.1 In `LLMClient.Call`, remove the `; Cleanup temp files` comment and the entire commented-out `try { ... }` block from `finally`, leaving only `this.pid := 0`
- [x] 1.2 Run `main.ahk`, send a message — verify no errors from the removed dead code
