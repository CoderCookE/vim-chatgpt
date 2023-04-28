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

try:
  import openai
except ImportError:
  print("Error: openai module not found. Please install with Pip and ensure equality of the versions given by :!python3 -V, and :python3 import sys; print(sys.version)")
  raise

import vim
import os

try:
  vim.eval('g:chat_gpt_max_tokens')
except:
  vim.command('let g:chat_gpt_max_tokens=2000')
EOF

" Set API key
python3 << EOF
openai.api_key = os.getenv('CHAT_GPT_KEY') or vim.eval('g:chat_gpt_key')
EOF

" Function to show ChatGPT responses in a new buffer
function! DisplayChatGPTResponse(response, finish_reason, chat_gpt_session_id)
  let original_syntax = &syntax

  call setbufvar(a:chat_gpt_session_id, '&buftype', 'nofile')
  call setbufvar(a:chat_gpt_session_id, '&bufhidden', 'hide')
  call setbufvar(a:chat_gpt_session_id, '&swapfile', 0)
  call setbufvar(a:chat_gpt_session_id, '&modifiable', 1)
  call setbufvar(a:chat_gpt_session_id, '&wrap', 1)
  call setbufvar(a:chat_gpt_session_id, '&syntax', original_syntax)
  if !bufexists(a:chat_gpt_session_id)
    silent execute 'new '. a:chat_gpt_session_id
  endif

  if bufwinnr(a:chat_gpt_session_id) == -1
    execute 'split ' .  a:chat_gpt_session_id
  endif

  " Get the last line content
  let last_line = getbufline(a:chat_gpt_session_id, '$')[0]

  " Append the response to the last line content
  let new_line = last_line . a:response

  " Update the last line with the new content
  call setbufline(a:chat_gpt_session_id, '$', split(new_line, '\n'))

  if a:finish_reason != ''
    call setbufvar(a:chat_gpt_session_id, '&modifiable', 0)
    setlocal nomodifiable
    wincmd p
  endif
endfunction

" Function to interact with ChatGPT
function! ChatGPT(prompt) abort
  python3 << EOF

def chat_gpt(prompt):
  max_tokens = int(vim.eval('g:chat_gpt_max_tokens'))

  try:
    response = openai.ChatCompletion.create(
      model="gpt-3.5-turbo",
      messages=[{"role": "user", "content": prompt}],
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
"
" Commands to interact with ChatGPT
command! -range -nargs=? Ask call SendHighlightedCodeToChatGPT('Ask', <line1>, <line2>, <q-args>)
command! -range -nargs=? Explain call SendHighlightedCodeToChatGPT('explain', <line1>, <line2>, <q-args>)
command! -range Review call SendHighlightedCodeToChatGPT('review', <line1>, <line2>, '')
command! -range -nargs=? Rewrite call SendHighlightedCodeToChatGPT('rewrite', <line1>, <line2>, <q-args>)
command! -range -nargs=? Test call SendHighlightedCodeToChatGPT('test', <line1>, <line2>, <q-args>)
command! -range -nargs=? Fix call SendHighlightedCodeToChatGPT('fix', <line1>, <line2>, <q-args>)
command! GenerateCommit call GenerateCommitMessage()
