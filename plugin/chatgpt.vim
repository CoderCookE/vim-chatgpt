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

# Set API key
openai.api_key = os.getenv('CHAT_GPT_KEY') or vim.eval('g:chat_gpt_key')
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

" Function to show ChatGPT responses in a new buffer
function! DisplayChatGPTResponse(response, finish_reason, chat_gpt_session_id)
  call cursor('$', 1)

  let response = a:response
  let finish_reason = a:finish_reason

  let chat_gpt_session_id = a:chat_gpt_session_id

  if !bufexists(chat_gpt_session_id)
    silent execute 'new '. chat_gpt_session_id
    call setbufvar(chat_gpt_session_id, '&buftype', 'nofile')
    call setbufvar(chat_gpt_session_id, '&bufhidden', 'hide')
    call setbufvar(chat_gpt_session_id, '&swapfile', 0)
    setlocal modifiable
    setlocal wrap
    call setbufvar(chat_gpt_session_id, '&ft', 'markdown')
    call setbufvar(chat_gpt_session_id, '&syntax', 'markdown')
  endif

  if bufwinnr(chat_gpt_session_id) == -1
    execute 'split ' . chat_gpt_session_id
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
  call cursor('$', 1)

  if finish_reason != ''
    wincmd p
  endif
endfunction

" Function to interact with ChatGPT
function! ChatGPT(prompt) abort
  python3 << EOF

def chat_gpt(prompt):
  max_tokens = int(vim.eval('g:chat_gpt_max_tokens'))
  model = str(vim.eval('g:chat_gpt_model'))
  lang = str(vim.eval('g:chat_gpt_lang'))
  temperature = float(vim.eval('g:chat_gpt_temperature'))
  systemCtx = {"role": "system", "content": f"You are a helpful expert programmer we are working together to solve complex coding challenges, and I need your help. Please make sure to wrap all code blocks in ``` annotate the programming language you are using. And respond in {lang}"}

  try:
    response = openai.ChatCompletion.create(
      model=model,
      messages=[systemCtx, {"role": "user", "content": prompt}],
      max_tokens=max_tokens,
      stop='',
      temperature=temperature,
      stream=True
    )

    # Check if `g:chat_gpt_session_mode` exists and set session_id accordingly
    session_id = 'gpt-persistent-session' if int(vim.eval('exists("g:chat_gpt_session_mode") && g:chat_gpt_session_mode')) else None

    # Call DisplayChatGPTResponse with the prompt
    if session_id:
      content = '\n\n>>>User:\n' + prompt + '\n\n<<<Assistant:\n'.replace("'", "''")

      vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(content.replace("'", "''"), session_id))
      vim.command("redraw")

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
  " Save the current yank register
  let save_reg = @@
  let save_regtype = getregtype('@')

  let [line_start, col_start] = getpos("'<")[1:2]
  let [line_end, col_end] = getpos("'>")[1:2]

  " Yank the visually selected text into the unnamed register
  execute 'normal! ' . line_start . 'G' . col_start . '|v' . line_end . 'G' . col_end . '|y'

  " Send the yanked text to ChatGPT
  let yanked_text = ''

  if (col_end - col_start > 0) || (line_end - line_start > 0)
    let yanked_text = '```' . "\n" . @@ . "\n" . '```'
  endif

  let prompt = a:context . ' ' . "\n" . yanked_text

  if a:ask == 'rewrite'
    let prompt = 'I have the following code snippet, can you rewrite it more idiomatically?' . "\n" . yanked_text . "\n"
    if len(a:context) > 0
      let prompt = 'I have the following code snippet, can you rewrite to' . a:context . '?' . "\n" . yanked_text . "\n"
    endif
  elseif a:ask == 'review'
    let prompt = 'I have the following code snippet, can you provide a code review for?' . "\n" . yanked_text . "\n"
  elseif a:ask == 'complete'
    let prompt = 'Please write codes with instruction:\n' . yanked_text
  elseif a:ask == 'explain'
    let prompt = 'I have the following code snippet, can you explain it?' . "\n" . yanked_text
    if len(a:context) > 0
      let prompt = 'I have the following code snippet, can you explain, ' . a:context . '?' . "\n" . yanked_text
    endif
  elseif a:ask == 'test'
    let prompt = 'I have the following code snippet, can you write a test for it?' . "\n" . yanked_text
    if len(a:context) > 0
      let prompt = 'I have the following code snippet, can you write a test for it, ' . a:context . '?' . "\n" . yanked_text
    endif
  elseif a:ask == 'fix'
    let prompt = 'I have the following code snippet, it has an error I need you to fix:' . "\n" . yanked_text . "\n"
    if len(a:context) > 0
      let prompt = 'I have the following code snippet I would want you to fix, ' . a:context . ':' . "\n" . yanked_text . "\n"
    endif
  endif

  call ChatGPT(prompt)

  " Restore the original yank register
  let @@ = save_reg
  call setreg('@', save_reg, save_regtype)
  let curpos = getcurpos()
  call setpos("'<", curpos)
  call setpos("'>", curpos)

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
  let prompt = 'I have the following code changes, can you write a helpful commit message, including a short title?' . "\n" .  yanked_text

  call ChatGPT(prompt)
endfunction

" Menu for ChatGPT
function! s:ChatGPTMenuSink(id, choice)
  call popup_hide(a:id)
  let choices = {1:'Ask', 2:'rewrite', 3:'explain', 4:'test', 5:'review'}
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
  call popup_menu([ '1. Ask', '2. Rewrite', '3. Explain', '4. Test', '5. Review', ], #{
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
command! -range -nargs=? Ask call SendHighlightedCodeToChatGPT('Ask',<q-args>)
command! -range -nargs=? Explain call SendHighlightedCodeToChatGPT('explain', <q-args>)
command! -range Review call SendHighlightedCodeToChatGPT('review', '')
command! -range -nargs=? Rewrite call SendHighlightedCodeToChatGPT('rewrite', <q-args>)
command! -range -nargs=? Test call SendHighlightedCodeToChatGPT('test',<q-args>)
command! -range -nargs=? Fix call SendHighlightedCodeToChatGPT('fix', <q-args>)
command! -range -nargs=? Complete call SendHighlightedCodeToChatGPT('complete', <q-args>)

command! GenerateCommit call GenerateCommitMessage()
