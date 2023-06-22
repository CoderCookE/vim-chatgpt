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
EOF

" Set default values for Vim variables if they don't exist
if !exists("g:chat_gpt_max_tokens")
  let g:chat_gpt_max_tokens = 2000
endif

if !exists("g:chat_gpt_model")
  let g:chat_gpt_model = 'gpt-3.5-turbo'
endif

" Set API key
python3 << EOF
openai.api_key = os.getenv('CHAT_GPT_KEY') or vim.eval('g:chat_gpt_key')
EOF

" Function to show ChatGPT responses in a new buffer
function! DisplayChatGPTResponse(response, finish_reason, chat_gpt_session_id)
  let response = a:response
  let finish_reason = a:finish_reason
  let chat_gpt_session_id = a:chat_gpt_session_id

  if !bufexists(chat_gpt_session_id)
    let original_syntax = &syntax

    silent execute 'new '. chat_gpt_session_id
    call setbufvar(chat_gpt_session_id, '&buftype', 'nofile')
    call setbufvar(chat_gpt_session_id, '&bufhidden', 'hide')
    call setbufvar(chat_gpt_session_id, '&swapfile', 0)
    setlocal modifiable
    setlocal wrap
    call setbufvar(chat_gpt_session_id, '&syntax', original_syntax)
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
    call setbufvar(chat_gpt_session_id, '&modifiable', 0)
    setlocal nomodifiable
    wincmd p
  endif
endfunction
" Function to interact with ChatGPT
function! ChatGPT(prompt) abort
  python3 << EOF

def chat_gpt(prompt):
  max_tokens = int(vim.eval('g:chat_gpt_max_tokens'))
  model= str(vim.eval('g:chat_gpt_model'))
  systemCtx = {"role": "system", "content": "You are a helpful expert programmer we are working together to solve complex coding challenges, and I need your help. Please make sure to wrap all code blocks in ``` annotate the programming language you are using."}

  try:
    response = openai.ChatCompletion.create(
      model=model,
      messages=[systemCtx, {"role": "user", "content": prompt}],
      max_tokens=max_tokens,
      stop=None,
      temperature=0.7,
      stream=True
    )

    for chunk in response:
      if chunk["choices"][0]["finish_reason"] is not None:
        vim.command("call DisplayChatGPTResponse('', '{}', '{}')".format(chunk["choices"][0]["finish_reason"].replace("'", "''"), chunk["id"]))
      elif "content" in chunk["choices"][0]["delta"]:
        vim.command("call DisplayChatGPTResponse('{}', '', '{}')".format(chunk["choices"][0]["delta"]["content"].replace("'", "''"), chunk["id"]))
        vim.command("redraw")
  except Exception as e:
    print("Error:", str(e))

chat_gpt(vim.eval('a:prompt'))
EOF
endfunction

function! SendHighlightedCodeToChatGPT(ask, line1, line2, context)
  " Save the current yank register
  let save_reg = @@
  let save_regtype = getregtype('@')

  " Yank the lines between line1 and line2 into the unnamed register
  execute 'normal! ' . a:line1 . 'G0v' . a:line2 . 'G$y'

  " Send the yanked text to ChatGPT
  let yanked_text = @@

  let prompt = a:context . ' ' . yanked_text

  if a:ask == 'rewrite'
    let prompt = 'I have the following code snippet, can you rewrite it more idiomatically?\n' . yanked_text
    if len(a:context) > 0
      let prompt = 'I have the following code snippet, can you rewrite to' . a:context . '?\n' . yanked_text
    endif
  elseif a:ask == 'review'
    let prompt = 'I have the following code snippet, can you provide a code review for?\n' . yanked_text
  elseif a:ask == 'explain'
    let prompt = 'I have the following code snippet, can you explain it?\n' . yanked_text
    if len(a:context) > 0
      let prompt = 'I have the following code snippet, can you explain, ' . a:context . '?\n' . yanked_text
    endif
  elseif a:ask == 'test'
    let prompt = 'I have the following code snippet, can you write a test for it?\n' . yanked_text
    if len(a:context) > 0
      let prompt = 'I have the following code snippet, can you write a test for it, ' . a:context . '?\n' . yanked_text
    endif
  elseif a:ask == 'fix'
    let prompt = 'I have the following code snippet, it has an error I need you to fix:\n' . yanked_text
    if len(a:context) > 0
      let prompt = 'I have the following code snippet I would want you to fix, ' . a:context . ':\n' . yanked_text
    endif
  endif

  call ChatGPT(prompt)

  " Restore the original yank register
  let @@ = save_reg
  call setreg('@', save_reg, save_regtype)
endfunction

function! GenerateCommitMessage()
  " Save the current position and yank register
  let save_cursor = getcurpos()
  let save_reg = @@
  let save_regtype = getregtype('@')

  " Yank the entire buffer into the unnamed register
  normal! ggVGy

  " Send the yanked text to ChatGPT
  let yanked_text = @@
  let prompt = 'I have the following code changes, can you write a helpful commit message, including a short title?\n' . yanked_text

  call ChatGPT(prompt)
endfunction

" Menu for ChatGPT
function! s:ChatGPTMenuSink(lineStart, lineEnd, id, choice)
  call popup_hide(a:id)
  let choices = {1:'Ask', 2:'Rewrite', 3:'Explain', 4:'Test', 5:'Review'}
  if a:choice > 0 && a:choice < 6
    call SendHighlightedCodeToChatGPT(choices[a:choice], a:lineStart, a:lineEnd, input('Prompt > '))
  endif
endfunction
function! s:ChatGPTMenuFilter(lineStart, lineEnd, id, key)
  if a:key == '1' || a:key == '2' || a:key == '3' || a:key == '4' || a:key == '5'
    call s:ChatGPTMenuSink(a:lineStart, a:lineEnd, a:id, a:key)
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
        \ callback: function('s:ChatGPTMenuSink', [a:firstline, a:lastline]),
        \ border: [],
        \ cursorline: 1,
        \ padding: [0,1,0,1],
        \ filter: function('s:ChatGPTMenuFilter', [a:firstline, a:lastline]),
        \ mapping: 0,
        \ })
endfunction

" Expose mappings
vnoremap <silent> <Plug>(chatgpt-menu) :call ChatGPTMenu()<CR>

" Commands to interact with ChatGPT
command! -range -nargs=? Ask call SendHighlightedCodeToChatGPT('Ask', <line1>, <line2>, <q-args>)
command! -range -nargs=? Explain call SendHighlightedCodeToChatGPT('explain', <line1>, <line2>, <q-args>)
command! -range Review call SendHighlightedCodeToChatGPT('review', <line1>, <line2>, '')
command! -range -nargs=? Rewrite call SendHighlightedCodeToChatGPT('rewrite', <line1>, <line2>, <q-args>)
command! -range -nargs=? Test call SendHighlightedCodeToChatGPT('test', <line1>, <line2>, <q-args>)
command! -range -nargs=? Fix call SendHighlightedCodeToChatGPT('fix', <line1>, <line2>, <q-args>)
command! GenerateCommit call GenerateCommitMessage()
