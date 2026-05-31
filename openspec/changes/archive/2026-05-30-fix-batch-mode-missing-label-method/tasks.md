## 1. Fix Command

- [x] 1.1 Add `cps` parameter to `SendBatchToLLMCommand.__New()` and store it as `this.cps`
- [x] 1.2 Change `this.contextManager.GetLabelFromContextItem(item)` to `this.cps.GetLabelFromContextItem(item)` on the label-generation line in `Execute()`

## 2. Update Composition Root

- [x] 2.1 Pass `cps` into `SendBatchToLLMCommand` constructor in `App.ahk` (change `SendBatchToLLMCommand(sess, cfg, llm, ctx)` to `SendBatchToLLMCommand(sess, cfg, llm, ctx, cps)`)

## 3. Verify

- [ ] 3.1 Run `main.ahk`, enable batch mode, select context items, send a prompt — confirm no crash and labels appear correctly
