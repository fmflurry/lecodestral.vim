vim9script
# LeCodestral — Copilot-style inline autocomplete for classic Vim 9 via Mistral Codestral FIM.
# Renders grey ghost text after the cursor; <Tab> accepts, <C-]> dismisses.

if exists('g:loaded_lecodestral')
  finish
endif
g:loaded_lecodestral = true

if !has('patch-9.0.0067') || !has('textprop') || !has('job')
  echohl WarningMsg
  echom 'LeCodestral: needs Vim 9.0.0067+ with +textprop and +job'
  echohl None
  finish
endif

# ---- config (override via g: before plugin loads) -------------------------
const endpoint = get(g:, 'lecodestral_endpoint', 'https://codestral.mistral.ai/v1/fim/completions')
const model = get(g:, 'lecodestral_model', 'codestral-latest')
const key_env = get(g:, 'lecodestral_api_key_env', 'CODESTRAL_API_KEY')
const debounce_ms = get(g:, 'lecodestral_debounce_ms', 150)
const max_tokens = get(g:, 'lecodestral_max_tokens', 256)
const max_prefix = get(g:, 'lecodestral_max_prefix', 4000)
const max_suffix = get(g:, 'lecodestral_max_suffix', 2000)
const temperature = get(g:, 'lecodestral_temperature', 0.2)
const accept_key = get(g:, 'lecodestral_accept_key', '<Tab>')

# ---- state ----------------------------------------------------------------
var enabled = get(g:, 'lecodestral_enabled', true)
var ghost_lines: list<string> = []
var ghost_active = false
var timer_id = -1
var cur_job: job = null_job
var job_chunks: list<string> = []
var req_lnum = 0
var req_col = 0
var req_buf = 0
var warned_key = false

hi default link LeCodestralGhost Comment
if empty(prop_type_get('lecodestral_ghost'))
  prop_type_add('lecodestral_ghost', {highlight: 'LeCodestralGhost'})
endif

def ApiKey(): string
  return getenv(key_env) ?? ''
enddef

def ClearGhost()
  if ghost_active
    silent! prop_remove({type: 'lecodestral_ghost', all: true}, 1, line('$'))
    ghost_lines = []
    ghost_active = false
  endif
enddef

def RenderGhost(lines: list<string>)
  ClearGhost()
  if empty(lines) || (len(lines) == 1 && lines[0] == '')
    return
  endif
  var lnum = line('.')
  var curlen = strlen(getline(lnum))
  var c = col('.')
  if c > curlen
    prop_add(lnum, 0, {type: 'lecodestral_ghost', text: lines[0], text_align: 'after'})
  else
    prop_add(lnum, c, {type: 'lecodestral_ghost', text: lines[0]})
  endif
  for extra in lines[1 : ]
    prop_add(lnum, 0, {type: 'lecodestral_ghost', text: extra, text_align: 'below'})
  endfor
  ghost_lines = lines
  ghost_active = true
enddef

def OnOut(ch: channel, msg: string)
  add(job_chunks, msg)
enddef

def OnErr(ch: channel, msg: string)
enddef

def Finish(j: job, st: number)
  if bufnr('%') != req_buf || line('.') != req_lnum || col('.') != req_col
    return
  endif
  if mode() !~# '^i'
    return
  endif
  var raw = join(job_chunks, '')
  if raw == ''
    return
  endif
  var data: any
  try
    data = json_decode(raw)
  catch
    return
  endtry
  if type(data) != v:t_dict || !has_key(data, 'choices') || empty(data.choices)
    return
  endif
  var ch0 = data.choices[0]
  var text = ''
  if has_key(ch0, 'message') && type(ch0.message) == v:t_dict && has_key(ch0.message, 'content')
    text = ch0.message.content
  elseif has_key(ch0, 'text')
    text = ch0.text
  endif
  if text == ''
    return
  endif
  RenderGhost(split(text, "\n", true))
enddef

def Trigger()
  timer_id = -1
  if !enabled || mode() !~# '^i'
    return
  endif
  var key = ApiKey()
  if key == ''
    if !warned_key
      warned_key = true
      echohl WarningMsg
      echom 'LeCodestral: env ' .. key_env .. ' not set'
      echohl None
    endif
    return
  endif
  if cur_job != null_job && job_status(cur_job) == 'run'
    job_stop(cur_job)
  endif

  var lnum = line('.')
  var c = col('.')
  req_lnum = lnum
  req_col = c
  req_buf = bufnr('%')

  var all = getline(1, '$')
  var cur = all[lnum - 1]
  var before_cur = strpart(cur, 0, c - 1)
  var after_cur = strpart(cur, c - 1)

  var prefix = ''
  if lnum > 1
    prefix = join(all[0 : lnum - 2], "\n") .. "\n"
  endif
  prefix ..= before_cur

  var suffix = after_cur
  if lnum < len(all)
    suffix ..= "\n" .. join(all[lnum : ], "\n")
  endif

  if strlen(prefix) > max_prefix
    prefix = strpart(prefix, strlen(prefix) - max_prefix)
  endif
  if strlen(suffix) > max_suffix
    suffix = strpart(suffix, 0, max_suffix)
  endif

  var body = json_encode({
    model: model,
    prompt: prefix,
    suffix: suffix,
    max_tokens: max_tokens,
    temperature: temperature,
    stream: false,
  })

  var argv = [
    'curl', '-s', '-X', 'POST', endpoint,
    '-H', 'Content-Type: application/json',
    '-H', 'Authorization: Bearer ' .. key,
    '-d', body,
  ]

  job_chunks = []
  cur_job = job_start(argv, {
    out_mode: 'raw',
    out_cb: OnOut,
    err_cb: OnErr,
    exit_cb: Finish,
  })
enddef

def Schedule()
  if !enabled
    return
  endif
  ClearGhost()
  if timer_id != -1
    timer_stop(timer_id)
  endif
  timer_id = timer_start(debounce_ms, (_) => Trigger())
enddef

# ---- map / autocmd facing (global so autocmds resolve them) ---------------
def g:LeCodestral_OnChange()
  Schedule()
enddef

def g:LeCodestral_OnLeave()
  ClearGhost()
enddef

def g:LeCodestral_Dismiss()
  ClearGhost()
enddef

def g:LeCodestral_Toggle()
  enabled = !enabled
  if !enabled
    ClearGhost()
  endif
  echo 'LeCodestral ' .. (enabled ? 'enabled' : 'disabled')
enddef

def g:LeCodestral_Accept()
  if !ghost_active
    if pumvisible()
      feedkeys("\<C-n>", 'n')
    else
      feedkeys("\t", 'n')
    endif
    return
  endif
  var lines = copy(ghost_lines)
  ClearGhost()
  var lnum = line('.')
  var c = col('.')
  var cur = getline(lnum)
  var before = strpart(cur, 0, c - 1)
  var after = strpart(cur, c - 1)
  if len(lines) == 1
    setline(lnum, before .. lines[0] .. after)
    cursor(lnum, strlen(before .. lines[0]) + 1)
  else
    setline(lnum, before .. lines[0])
    lines[-1] = lines[-1] .. after
    append(lnum, lines[1 : ])
    var endlnum = lnum + len(lines) - 1
    cursor(endlnum, strlen(lines[-1]) - strlen(after) + 1)
  endif
enddef

augroup LeCodestral
  autocmd!
  autocmd TextChangedI * call g:LeCodestral_OnChange()
  autocmd InsertLeave,BufLeave * call g:LeCodestral_OnLeave()
augroup END

execute 'inoremap <silent> ' .. accept_key .. ' <Cmd>call g:LeCodestral_Accept()<CR>'
inoremap <silent> <C-]> <Cmd>call g:LeCodestral_Dismiss()<CR>

command! LeCodestralToggle call g:LeCodestral_Toggle()
command! LeCodestralDismiss call g:LeCodestral_Dismiss()
