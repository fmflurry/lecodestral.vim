" lecodestral.vim — autoload engine. Functions here are globally addressable
" (lecodestral#...), lazy-loaded, and stable across plugin re-sourcing.

let s:default_endpoint = 'https://codestral.mistral.ai/v1/fim/completions'

function! s:get(key, default) abort
  return get(g:, 'lecodestral_' . a:key, a:default)
endfunction

function! s:log(msg) abort
  if get(g:, 'lecodestral_debug', 0)
    call writefile([strftime('%H:%M:%S') . ' ' . a:msg], '/tmp/lecodestral.log', 'a')
  endif
endfunction

let s:enabled = s:get('enabled', 1)
let s:ghost_lines = []
let s:ghost_active = 0
let s:timer_id = -1
let s:cur_job = v:null
let s:job_chunks = []
let s:req_lnum = 0
let s:req_col = 0
let s:req_buf = 0
let s:warned_key = 0

function! s:clear_ghost() abort
  if s:ghost_active
    silent! call prop_remove({'type': 'lecodestral_ghost', 'all': v:true}, 1, line('$'))
    let s:ghost_lines = []
    let s:ghost_active = 0
  endif
endfunction

function! s:render_ghost(lines) abort
  call s:clear_ghost()
  if empty(a:lines) || (len(a:lines) == 1 && a:lines[0] ==# '')
    return
  endif
  let l:lnum = line('.')
  let l:curlen = strlen(getline(l:lnum))
  let l:c = col('.')
  if l:c > l:curlen
    call prop_add(l:lnum, 0, {'type': 'lecodestral_ghost', 'text': a:lines[0], 'text_align': 'after'})
  else
    call prop_add(l:lnum, l:c, {'type': 'lecodestral_ghost', 'text': a:lines[0]})
  endif
  for l:extra in a:lines[1:]
    call prop_add(l:lnum, 0, {'type': 'lecodestral_ghost', 'text': l:extra, 'text_align': 'below'})
  endfor
  let s:ghost_lines = a:lines
  let s:ghost_active = 1
endfunction

function! s:on_out(ch, msg) abort
  call add(s:job_chunks, a:msg)
endfunction

function! s:on_err(ch, msg) abort
  call s:log('ERR ' . a:msg)
endfunction

function! s:finish(job, status) abort
  call s:log('finish status=' . a:status . ' chunks=' . len(s:job_chunks))
  if bufnr('%') != s:req_buf || line('.') != s:req_lnum || col('.') != s:req_col
    call s:log('bail: cursor moved (buf/lnum/col mismatch)')
    return
  endif
  if mode() !~# '^i'
    call s:log('bail: not insert mode (' . mode() . ')')
    return
  endif
  let l:raw = join(s:job_chunks, '')
  if l:raw ==# ''
    call s:log('bail: empty response')
    return
  endif
  try
    let l:data = json_decode(l:raw)
  catch
    call s:log('bail: json_decode failed: ' . v:exception . ' raw=' . l:raw[0:300])
    return
  endtry
  if type(l:data) != v:t_dict || !has_key(l:data, 'choices') || empty(l:data.choices)
    call s:log('bail: no choices. raw=' . l:raw[0:300])
    return
  endif
  let l:ch0 = l:data.choices[0]
  let l:text = ''
  if has_key(l:ch0, 'message') && type(l:ch0.message) == v:t_dict && has_key(l:ch0.message, 'content')
    let l:text = l:ch0.message.content
  elseif has_key(l:ch0, 'text')
    let l:text = l:ch0.text
  endif
  if l:text ==# ''
    return
  endif
  let l:lines = split(l:text, "\n", 1)
  let l:maxl = s:get('max_lines', 3)
  if l:maxl > 0 && len(l:lines) > l:maxl
    let l:lines = l:lines[0 : l:maxl - 1]
  endif
  call s:render_ghost(l:lines)
endfunction

function! s:trigger(...) abort
  let s:timer_id = -1
  if !s:enabled || mode() !~# '^i'
    return
  endif
  call s:log('trigger fired')
  let l:env = s:get('api_key_env', 'CODESTRAL_API_KEY')
  let l:key = getenv(l:env)
  if type(l:key) != v:t_string || l:key ==# ''
    call s:log('bail: env ' . l:env . ' not set in Vim')
    if !s:warned_key
      let s:warned_key = 1
      echohl WarningMsg | echom 'LeCodestral: env ' . l:env . ' not set' | echohl None
    endif
    return
  endif
  if type(s:cur_job) == v:t_job && job_status(s:cur_job) ==# 'run'
    call job_stop(s:cur_job)
  endif

  let l:lnum = line('.')
  let l:c = col('.')
  let s:req_lnum = l:lnum
  let s:req_col = l:c
  let s:req_buf = bufnr('%')

  let l:all = getline(1, '$')
  let l:cur = l:all[l:lnum - 1]
  let l:before_cur = strpart(l:cur, 0, l:c - 1)
  let l:after_cur = strpart(l:cur, l:c - 1)

  let l:prefix = ''
  if l:lnum > 1
    let l:prefix = join(l:all[0 : l:lnum - 2], "\n") . "\n"
  endif
  let l:prefix .= l:before_cur

  let l:suffix = l:after_cur
  if l:lnum < len(l:all)
    let l:suffix .= "\n" . join(l:all[l:lnum :], "\n")
  endif

  let l:maxp = s:get('max_prefix', 8000)
  let l:maxs = s:get('max_suffix', 4000)
  if strlen(l:prefix) > l:maxp
    let l:prefix = strpart(l:prefix, strlen(l:prefix) - l:maxp)
    let l:nl = stridx(l:prefix, "\n")
    if l:nl >= 0
      let l:prefix = strpart(l:prefix, l:nl + 1)
    endif
  endif
  if strlen(l:suffix) > l:maxs
    let l:suffix = strpart(l:suffix, 0, l:maxs)
    let l:nl = strridx(l:suffix, "\n")
    if l:nl >= 0
      let l:suffix = strpart(l:suffix, 0, l:nl)
    endif
  endif

  let l:payload = {
        \ 'model': s:get('model', 'codestral-latest'),
        \ 'prompt': l:prefix,
        \ 'suffix': l:suffix,
        \ 'max_tokens': s:get('max_tokens', 256),
        \ 'temperature': s:get('temperature', 0.2),
        \ 'stream': v:false,
        \ }
  let l:stop = s:get('stop', ["\n\n\n"])
  if type(l:stop) == v:t_list && !empty(l:stop)
    let l:payload.stop = l:stop
  endif
  let l:body = json_encode(l:payload)

  let l:argv = ['curl', '-s', '-X', 'POST', s:get('endpoint', s:default_endpoint),
        \ '-H', 'Content-Type: application/json',
        \ '-H', 'Authorization: Bearer ' . l:key,
        \ '-d', l:body]

  call s:log('POST body=' . strlen(l:body) . 'B prefix=' . strlen(l:prefix) . ' suffix=' . strlen(l:suffix))
  let s:job_chunks = []
  let s:cur_job = job_start(l:argv, {
        \ 'out_mode': 'raw',
        \ 'out_cb': function('s:on_out'),
        \ 'err_cb': function('s:on_err'),
        \ 'exit_cb': function('s:finish'),
        \ })
endfunction

function! lecodestral#on_change() abort
  if !s:enabled
    return
  endif
  call s:clear_ghost()
  if s:timer_id != -1
    call timer_stop(s:timer_id)
  endif
  let s:timer_id = timer_start(s:get('debounce_ms', 150), function('s:trigger'))
endfunction

function! lecodestral#on_leave() abort
  call s:clear_ghost()
endfunction

function! lecodestral#dismiss() abort
  call s:clear_ghost()
endfunction

function! lecodestral#toggle() abort
  let s:enabled = !s:enabled
  if !s:enabled
    call s:clear_ghost()
  endif
  echo 'LeCodestral ' . (s:enabled ? 'enabled' : 'disabled')
endfunction

function! lecodestral#accept() abort
  if !s:ghost_active
    if pumvisible()
      call feedkeys("\<C-n>", 'n')
    else
      call feedkeys("\<Tab>", 'n')
    endif
    return
  endif
  let l:lines = copy(s:ghost_lines)
  call s:clear_ghost()
  let l:lnum = line('.')
  let l:c = col('.')
  let l:cur = getline(l:lnum)
  let l:before = strpart(l:cur, 0, l:c - 1)
  let l:after = strpart(l:cur, l:c - 1)
  if len(l:lines) == 1
    call setline(l:lnum, l:before . l:lines[0] . l:after)
    call cursor(l:lnum, strlen(l:before . l:lines[0]) + 1)
  else
    call setline(l:lnum, l:before . l:lines[0])
    let l:lines[-1] = l:lines[-1] . l:after
    call append(l:lnum, l:lines[1:])
    let l:endlnum = l:lnum + len(l:lines) - 1
    call cursor(l:endlnum, strlen(l:lines[-1]) - strlen(l:after) + 1)
  endif
endfunction
