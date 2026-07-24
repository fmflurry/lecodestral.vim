# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] — dev/zap-improvements (in progress)

### ⚠️ Breaking Changes

- **No default keybindings** (since initial release). You must map `<Plug>` actions yourself, e.g.:

  ```vim
  imap <Tab>      <Plug>(lecodestral-accept)
  imap <C-]>      <Plug>(lecodestral-dismiss)
  imap <C-n>      <Plug>(lecodestral-cycle-suggestions)
  imap <S-Tab>    <Plug>(lecodestral-cycle-context)
  imap <S-Space>  <Plug>(lecodestral-complete)
  ```

### ✨ Added

- **Multiple suggestions with cycling** — fetches N candidate completions; cycle through them with `:call lecodestral#cycle(1)` / `lecodestral#cycle(-1)` or the `<Plug>` mappings.
- **Cycle context options** — cycle through 'preview', 'full', 'line', and 'word' views via `<Plug>(lecodestral-cycle-context)`.

### 🔧 Changed

- **Better FIM endpoint** — switched to a Mistral fill-in-the-middle completion endpoint based on Mistral documentation.
- **Docs & config refinements** — updated documentation and configuration options.


## [Initial Release]

- Ghost-text autocomplete powered by Codestral (Vim 9, `+textprop` + `+job`, zero deps beyond `curl`).
- Fill-in-the-middle completion: sends code before *and* after the cursor.
- Async debounced requests with stale-cancel.
