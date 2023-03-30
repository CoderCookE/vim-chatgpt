
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
sys.path.append(vim.eval('expand(g:chatgpt_venv_path)'))
try:
    import openai
except ImportError:
    print("Error: openai module not found. Install with pip.")
    raise
import vim
import os
EOF

" Set API key
python3 << EOF
openai.api_key = os.getenv('CHAT_GPT_KEY')
EOF

" Function to show ChatGPT responses in a new buffer (improved)
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
  try:
    response = openai.ChatCompletion.create(
      model="gpt-3.5-turbo",
      messages=[{"role": "user", "content": prompt}],
      max_tokens=1000,
      stop=None,
      temperature=0.7,
    )
    result = response.choices[0].message.content.strip()
    vim.command("let g:result = '{}'".format(result.replace("'", "''")))
  except Exception as e:
    print("Error:", str(e))
    vim.command("let g:result = ''")

chat_gpt(vim.eval('a:prompt'))
EOF
  call DisplayChatGPTResponse(g:result)
endfunction

function! SendHighlightedCodeToChatGPT(ask, line1, line2, context)
  " Save the current yank register
  let save_reg = @@
  let save_regtype = getregtype('@')

  " Yank the lines between line1 and line2 into the unnamed register
  execute 'normal! ' . a:line1 . 'G0v' . a:line2 . 'G$y'

  " Send the yanked text to ChatGPT
  let yanked_text = @@
  let prompt = 'I have the following code snippet, can you explain it?\n' . yanked_text

  if a:ask == 'rewrite'
    let prompt = 'I have the following code snippet, can you rewrite it more idiomatically?\n' . yanked_text
    if len(a:context) > 0
      let prompt = 'I have the following code snippet, can you rewrite to' . a:context . '?\n' . yanked_text
    endif
  elseif a:ask == 'review'
    let prompt = 'I have the following code snippet, can you provide a code review for?\n' . yanked_text
  endif
  call ChatGPT(prompt)

  " Restore the original yank register
  let @@ = save_reg
  call setreg('@', save_reg, save_regtype)
endfunction


function! GenerateCommit()
  " Save the current position and yank register
  let save_cursor = getcurpos()
  let save_reg = @@
  let save_regtype = getregtype('@')

  " Yank the entire buffer into the unnamed register
  normal! ggVGy

  " Send the yanked text to ChatGPT
  let yanked_text = @@
  let prompt = 'I have the following code changes, can you write a commit message?\n' . yanked_text
  let response = ChatGPT(prompt)

  " Go to the beginning of the buffer and paste the response
  normal! ggP

  " Restore the original yank register and position
  let @@ = save_reg
  call setreg('@', save_reg, save_regtype)
  call setpos('.', save_cursor)
endfunction

"
" Commands to interact with ChatGPT
command! -nargs=1 Ask call ChatGPT(<q-args>)
command! -range Explain call SendHighlightedCodeToChatGPT('explain', <line1>, <line2>, '')
command! -range Review call SendHighlightedCodeToChatGPT('review', <line1>, <line2>, '')
command! -range -nargs=? Rewrite call SendHighlightedCodeToChatGPT('rewrite', <line1>, <line2>, <q-args>)
command! GenerateCommit call GenerateCommit()
