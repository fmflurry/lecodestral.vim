# lecodestral.vim

Copilot-style **inline ghost-text autocomplete** for **classic Vim 9**, powered by
Mistral [**Codestral**](https://mistral.ai/news/codestral/) via its fill-in-the-middle
(FIM) endpoint. No Neovim, no Node, no dependencies beyond `curl`.

> Most LLM autocomplete plugins are Neovim-only. This one targets plain Vim 9
> using native `+textprop` virtual text and async `+job`.

## Features

- Grey inline ghost text after the cursor, Copilot-style
- True **fill-in-the-middle**: sends code before *and* after the cursor
- Fully async (`job_start` + `curl`), debounced, cancels stale requests
- Multi-line suggestions (inline first line + virtual lines below)
- `<Tab>` falls through to a real tab / popup-menu nav when no ghost is shown
- Zero dependencies beyond `curl`

## Requirements

- Vim **9.0.0067+** compiled with `+textprop` and `+job` (`:echo has('patch-9.0.0067')`)
- `curl` on `$PATH`
- A Codestral API key (free tier: https://console.mistral.ai)

## Install

### vim-plug

```vim
Plug 'fmflurry/lecodestral.vim'
```

Then `:PlugInstall`.

### Native packages (no plugin manager)

```bash
git clone https://github.com/fmflurry/lecodestral.vim \
  ~/.vim/pack/plugins/start/lecodestral.vim
```

## Setup

Export your key (add to your shell rc):

```bash
export CODESTRAL_API_KEY="your-key-here"
```

Launch Vim from a shell where that variable is set.

## Usage

| Action            | Default              |
| ----------------- | -------------------- |
| Trigger           | type in insert mode  |
| Accept suggestion | `<Tab>`              |
| Dismiss           | `<C-]>`              |
| Toggle on/off     | `:LeCodestralToggle` |
| Clear current     | `:LeCodestralDismiss`|

## Configuration

Set before the plugin loads (e.g. in your vimrc). Defaults shown:

```vim
let g:lecodestral_enabled     = v:true
let g:lecodestral_model       = 'codestral-latest'
let g:lecodestral_debounce_ms = 150
let g:lecodestral_max_tokens  = 256
let g:lecodestral_max_prefix  = 4000
let g:lecodestral_max_suffix  = 2000
let g:lecodestral_temperature = 0.2
let g:lecodestral_accept_key  = '<Tab>'
let g:lecodestral_api_key_env = 'CODESTRAL_API_KEY'
let g:lecodestral_endpoint    = 'https://codestral.mistral.ai/v1/fim/completions'
```

Ghost text uses the `LeCodestralGhost` highlight group (links to `Comment` by default):

```vim
highlight LeCodestralGhost ctermfg=245 guifg=#6c7086
```

## Notes & limitations

- FIM = fill-in-the-middle: `prompt` = text before cursor, `suffix` = text after,
  so completions are context-aware mid-file.
- Free Codestral keys are rate-limited; rapid typing may hit limits.
- No streaming yet — one request per debounce window.

## License

[MIT](LICENSE)
