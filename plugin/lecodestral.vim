" lecodestral.vim — Copilot-style inline autocomplete for classic Vim 9 via
" Mistral Codestral (FIM). Grey ghost text after the cursor;
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
  autocmd InsertLeave,BufLeave * call lecodestral#dismiss()
augroup END

inoremap <silent> <Plug>(lecodestral-complete)   <cmd>call lecodestral#complete()<cr>
inoremap <silent> <Plug>(lecodestral-accept)     <c-g>u<cmd>call lecodestral#accept()<cr>
inoremap <silent> <Plug>(lecodestral-dismiss)    <cmd>call lecodestral#dismiss()<cr>
inoremap <silent> <Plug>(lecodestral-cycle-next) <cmd>call lecodestral#cycle(1)<cr>
inoremap <silent> <Plug>(lecodestral-cycle-prev) <cmd>call lecodestral#cycle(-1)<cr>
inoremap <silent> <Plug>(lecodestral-expand)     <cmd>call lecodestral#expand()<cr>

command! LeCodestralToggle call lecodestral#toggle()
command! LeCodestralDismiss call lecodestral#dismiss()
