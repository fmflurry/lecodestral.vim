" lecodestral.vim — Copilot-style inline autocomplete for classic Vim 9 via
" DeepSeek FIM (beta). Grey ghost text after the cursor; <Tab> accepts.
" Logic lives in autoload/lecodestral.vim (stable across re-sourcing).

if exists('g:loaded_lecodestral')
  finish
endif
let g:loaded_lecodestral = 1

if !has('patch-9.0.0067') || !has('textprop') || !has('job')
  echohl WarningMsg
  echom 'LeCodestral: needs Vim 9.0.0067+ with +textprop and +job'
  echohl None
  finish
endif

highlight default link LeCodestralGhost Comment
if empty(prop_type_get('lecodestral_ghost'))
  call prop_type_add('lecodestral_ghost', {'highlight': 'LeCodestralGhost'})
endif

augroup LeCodestral
  autocmd!
  autocmd TextChangedI * call lecodestral#on_change()
  autocmd InsertLeave,BufLeave * call lecodestral#on_leave()
augroup END

let s:accept_key = get(g:, 'lecodestral_accept_key', '<Tab>')
execute 'inoremap <silent> ' . s:accept_key . ' <Cmd>call lecodestral#accept()<CR>'
inoremap <silent> <C-]> <Cmd>call lecodestral#dismiss()<CR>

command! LeCodestralToggle call lecodestral#toggle()
command! LeCodestralDismiss call lecodestral#dismiss()
