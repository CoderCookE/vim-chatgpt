" ChatGPT Vim Plugin
"
" Ensure Python3 is available
if !has('python3')
  echo "Python 3 support is required for ChatGPT plugin"
  finish
endif

" Add ChatGPT dependencies
python3 << EOF
import sys
import vim
import os

try:
    import openai
except ImportError:
    print("Error: openai module not found. Please install with Pip and ensure equality of the versions given by :!python3 -V, and :python3 import sys; print(sys.version)")
    raise

def safe_vim_eval(expression):
    try:
        return vim.eval(expression)
    except vim.error:
        return None

openai.api_key = os.getenv('OPENAI_API_KEY') or safe_vim_eval('g:chat_gpt_key') or safe_vim_eval('g:openai_api_key')
openai.proxy = os.getenv("OPENAI_PROXY")
EOF

" Set default values for Vim variables if they don't exist
if !exists("g:chat_gpt_max_tokens")
  let g:chat_gpt_max_tokens = 2000
endif

if !exists("g:chat_gpt_temperature")
  let g:chat_gpt_temperature = 0.7
endif

if !exists("g:chat_gpt_model")
  let g:chat_gpt_model = 'gpt-3.5-turbo'
endif

if !exists("g:chat_gpt_lang")
  let g:chat_gpt_lang = ''
endif

if !exists("g:chat_gpt_split_direction")
  let g:chat_gpt_split_direction = 'horizontal'
endif

" Function to show ChatGPT responses in a new buffer
function! DisplayChatGPTResponse(response, finish_reason, chat_gpt_session_id)
  let response = a:response
  let finish_reason = a:finish_reason

  let chat_gpt_session_id = a:chat_gpt_session_id

  if !bufexists(chat_gpt_session_id)
    if g:chat_gpt_split_direction ==# 'vertical'
      silent execute 'vnew '. chat_gpt_session_id
    else
      silent execute 'new '. chat_gpt_session_id
    endif
    call setbufvar(chat_gpt_session_id, '&buftype', 'nofile')
    call setbufvar(chat_gpt_session_id, '&bufhidden', 'hide')
    call setbufvar(chat_gpt_session_id, '&swapfile', 0)
    setlocal modifiable
    setlocal wrap
    call setbufvar(chat_gpt_session_id, '&ft', 'markdown')
    call setbufvar(chat_gpt_session_id, '&syntax', 'markdown')
  endif

  if bufwinnr(chat_gpt_session_id) == -1
    if g:chat_gpt_split_direction ==# 'vertical'
      execute 'vsplit ' . chat_gpt_session_id
    else
      execute 'split ' . chat_gpt_session_id
    endif
  endif

  let last_lines = getbufline(chat_gpt_session_id, '$')
  let last_line = empty(last_lines) ? '' : last_lines[-1]

  let new_lines = substitute(last_line . response, '\n', '\r\n\r', 'g')
  let lines = split(new_lines, '\n')

  let clean_lines = []
  for line in lines
    call add(clean_lines, substitute(line, '\r', '', 'g'))
  endfor

  call setbufline(chat_gpt_session_id, '$', clean_lines)

  execute bufwinnr(chat_gpt_session_id) . 'wincmd w'
  " Move the viewport to the bottom of the buffer
  normal! G
  call cursor('$', 1)

  if finish_reason != ''
    wincmd p
  endif
endfunction

" Function to interact with ChatGPT
function! ChatGPT(prompt) abort
  python3 << EOF

def chat_gpt(prompt):
  token_limits = {
    "gpt-3.5-turbo": 4097,
    "gpt-3.5-turbo-16k": 16385,
    "gpt-3.5-turbo-1106": 16385,
    "gpt-4": 8192,
    "gpt-4-32k": 32768,
    "gpt-4-1106-preview": 128000,
  }

  max_tokens = int(vim.eval('g:chat_gpt_max_tokens'))
  model = str(vim.eval('g:chat_gpt_model'))
  temperature = float(vim.eval('g:chat_gpt_temperature'))
  lang = str(vim.eval('g:chat_gpt_lang'))
  resp = lang and f" And respond in {lang}." or ""

  systemCtx = {"role": "system", "content": f"You are a helpful expert programmer we are working together to solve complex coding challenges, and I need your help. Please make sure to wrap all code blocks in ``` annotate the programming language you are using. {resp}"}
  messages = []
  session_id = 'gpt-persistent-session' if int(vim.eval('exists("g:chat_gpt_session_mode") ? g:chat_gpt_session_mode : 1')) == 1 else None

  # If session id exists and is in vim buffers
  if session_id:
    buffer = []

    for b in vim.buffers:
       # If the buffer name matches the session id
      if session_id in b.name:
        buffer = b[:]
        break

    # Read the lines from the buffer
    history = "\n".join(buffer).split('\n\n>>>')
    history.reverse()

    # Adding messages to history until token limit is reached
    token_count = token_limits.get(model, 4097) - max_tokens - len(prompt) - len(str(systemCtx))

    for line in history:
      if ':\n' in line:
        role, message = line.split(":\n")

        token_count -= len(message)

        if token_count > 0:
            messages.insert(0, {
                "role": role.lower(),
                "content": message
            })

  if session_id:
    content = '\n\n>>>User:\n' + prompt + '\n\n>>>Assistant:\n'.replace("'", "''")

    vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(content.replace("'", "''"), session_id))
    vim.command("redraw")

  messages.append({"role": "user", "content": prompt})
  messages.insert(0, systemCtx)

  try:
    response = openai.ChatCompletion.create(
      model=model,
      messages=messages,
      max_tokens=max_tokens,
      stop='',
      temperature=temperature,
      stream=True
    )

    # Iterate through the response chunks
    for chunk in response:
      chunk_session_id = session_id if session_id else chunk["id"]
      choice = chunk["choices"][0]
      finish_reason = choice.get("finish_reason")
      content = choice.get("delta", {}).get("content")

      # Call DisplayChatGPTResponse with the finish_reason or content
      if finish_reason:
        vim.command("call DisplayChatGPTResponse('', '{0}', '{1}')".format(finish_reason.replace("'", "''"), chunk_session_id))
      elif content:
        vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(content.replace("'", "''"), chunk_session_id))

      vim.command("redraw")

  except Exception as e:
    print("Error:", str(e))

chat_gpt(vim.eval('a:prompt'))
EOF
endfunction

" Function to send highlighted code to ChatGPT
function! SendHighlightedCodeToChatGPT(ask, context)
  let save_cursor = getcurpos()

  " Save the current yank register
  let save_reg = @@
  let save_regtype = getregtype('@')

  let [line_start, col_start] = getpos("'<")[1:2]
  let [line_end, col_end] = getpos("'>")[1:2]

  " Yank the visually selected text into the unnamed register
  execute 'normal! ' . line_start . 'G' . col_start . '|v' . line_end . 'G' . col_end . '|y'

  " Send the yanked text to ChatGPT
  let yanked_text = ''
  let syntax = &syntax

  if (col_end - col_start > 0) || (line_end - line_start > 0)
    let yanked_text = '```' . syntax . "\n" . @@ . "\n" . '```'
  endif

  let prompt_templates = {
  \ 'rewrite': 'Can you rewrite it more idiomatically?',
  \ 'review': 'Can you provide a code review for?',
  \ 'document': 'Return documentation following language pattern conventions.',
  \ 'explain': 'Can you explain it?',
  \ 'test': 'Can you write a test for it?',
  \ 'fix': 'It has an error I need you to fix.'
  \}

  let prompt = a:context . ' ' . "\n" . yanked_text

  if has_key(prompt_templates, a:ask)
    let template  = "Given the following code snippet ". prompt_templates[a:ask]
    let prompt = template . "\n" . yanked_text . "\n" . a:context
  endif

  call ChatGPT(prompt)

  " Restore the original yank register
  let @@ = save_reg
  call setreg('@', save_reg, save_regtype)
  let curpos = getcurpos()
  call setpos("'<", curpos)
  call setpos("'>", curpos)
  call setpos('.', save_cursor)

endfunction
"
" Function to generate a commit message
function! GenerateCommitMessage()
  " Save the current position and yank register
  let save_cursor = getcurpos()
  let save_reg = @@
  let save_regtype = getregtype('@')

  " Yank the entire buffer into the unnamed register
  normal! ggVGy

  " Send the yanked text to ChatGPT
  let yanked_text = @@
  let prompt = 'I have the following code changes, can you write a helpful commit message, including a short title? Only respond with the commit message' . "\n" .  yanked_text
  let g:chat_gpt_session_mode = 0

  call ChatGPT(prompt)
endfunction

" Menu for ChatGPT
function! s:ChatGPTMenuSink(id, choice)
  call popup_hide(a:id)
  let choices = {1:'Ask', 2:'rewrite', 3:'explain', 4:'test', 5:'review', 6:'document'}
  if a:choice > 0 && a:choice < 6
    call SendHighlightedCodeToChatGPT(choices[a:choice], input('Prompt > '))
  endif
endfunction

function! s:ChatGPTMenuFilter(id, key)
  if a:key == '1' || a:key == '2' || a:key == '3' || a:key == '4' || a:key == '5'
    call s:ChatGPTMenuSink(a:id, a:key)
  else " No shortcut, pass to generic filter
    return popup_filter_menu(a:id, a:key)
  endif
endfunction

function! ChatGPTMenu() range
  echo a:firstline. a:lastline
  call popup_menu([ '1. Ask', '2. Rewrite', '3. Explain', '4. Test', '5. Review', '6. Document'], #{
        \ pos: 'topleft',
        \ line: 'cursor',
        \ col: 'cursor+2',
        \ title: ' Chat GPT ',
        \ highlight: 'question',
        \ borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ callback: function('s:ChatGPTMenuSink'),
        \ border: [],
        \ cursorline: 1,
        \ padding: [0,1,0,1],
        \ filter: function('s:ChatGPTMenuFilter'),
        \ mapping: 0,
        \ })
endfunction

" Expose mappings
vnoremap <silent> <Plug>(chatgpt-menu) :call ChatGPTMenu()<CR>

" Commands to interact with ChatGPT
command! -range -nargs=? Ask call SendHighlightedCodeToChatGPT('ask',<q-args>)
command! -range -nargs=? Explain call SendHighlightedCodeToChatGPT('explain', <q-args>)
command! -range -nargs=? Review call SendHighlightedCodeToChatGPT('review', <q-args>)
command! -range -nargs=? Document call SendHighlightedCodeToChatGPT('document', <q-args>)
command! -range -nargs=? Rewrite call SendHighlightedCodeToChatGPT('rewrite', <q-args>)
command! -range -nargs=? Test call SendHighlightedCodeToChatGPT('test',<q-args>)
command! -range -nargs=? Fix call SendHighlightedCodeToChatGPT('fix', <q-args>)

command! GenerateCommit call GenerateCommitMessage()
