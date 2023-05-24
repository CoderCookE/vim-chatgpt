
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
openai.api_key = os.getenv('OPENAI_API_KEY') or vim.eval('g:chat_gpt_key')
openai.proxy = 'http://localhost:1087'
EOF

" Function to show ChatGPT responses in a new buffer
function! DisplayChatGPTResponse(response)
  let original_syntax = &syntax

  new
  setlocal buftype=nofile bufhidden=hide noswapfile nowrap nobuflisted
  setlocal modifiable
  execute 'setlocal syntax='. original_syntax

  call setline(1, split(a:response, '\n'))
  setlocal nomodifiable
  wincmd p
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
    )
    gpt_result = response.choices[0].message.content.strip()
    vim.command("let g:gpt_result = '{}'".format(gpt_result.replace("'", "''")))
  except Exception as e:
    print("Error:", str(e))
    vim.command("let g:gpt_result = ''")

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

  let prompt = 'Do you like my code?\n' . yanked_text

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

  call DisplayChatGPTResponse(g:gpt_result)
  " Restore the original yank register
  let @@ = save_reg
  call setreg('@', save_reg, save_regtype)
endfunction

function! AskChatGPT(prompt)
  " Save the current yank register
  let save_reg = @@
  let save_regtype = getregtype('@')

  call ChatGPT(a:prompt)
  call DisplayChatGPTResponse(g:gpt_result)

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

  " Save the current buffer
  silent! write

  " Insert the response into the new buffer
  call setline(1, split(g:gpt_result, '\n'))
  setlocal modifiable

  " Go back to the original buffer
  wincmd p

  " Restore the original yank register and position
  let @@ = save_reg
  call setreg('@', save_reg, save_regtype)
  call setpos('.', save_cursor)
endfunction
"
" Commands to interact with ChatGPT
command! -nargs=1 Ask call AskChatGPT(<q-args>)
command! -range  -nargs=? Explain call SendHighlightedCodeToChatGPT('explain', <line1>, <line2>, <q-args>)
command! -range Review call SendHighlightedCodeToChatGPT('review', <line1>, <line2>, '')
command! -range -nargs=? Rewrite call SendHighlightedCodeToChatGPT('rewrite', <line1>, <line2>, <q-args>)
command! -range -nargs=? Test call SendHighlightedCodeToChatGPT('test', <line1>, <line2>, <q-args>)
command! -range -nargs=? Fix call SendHighlightedCodeToChatGPT('fix', <line1>, <line2>, <q-args>)
command! GenerateCommit call GenerateCommitMessage()
