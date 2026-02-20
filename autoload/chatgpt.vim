" ChatGPT Autoload Core Functions
" This file contains the main API functions for the ChatGPT plugin

" Main ChatGPT function - delegates to Python
function! chatgpt#chat(prompt) abort
  " Ensure suppress_display is off for normal chat operations
  if !exists('g:llm_agent_suppress_display') && !exists('g:chat_gpt_suppress_display')
    let g:llm_agent_suppress_display = 0
  endif

  python3 << EOF
import sys
import vim
import os

# Add python3/chatgpt to Python path
plugin_dir = vim.eval('expand("<sfile>:p:h:h")')
python_path = os.path.join(plugin_dir, 'python3')
if python_path not in sys.path:
    sys.path.insert(0, python_path)

# Import and call main chat function
from chatgpt.core import chat_gpt
chat_gpt(vim.eval('a:prompt'))
EOF


  " Check if summary needs updating after AI response completes
  let suppress_display = exists('g:llm_agent_suppress_display') ? g:llm_agent_suppress_display : (exists('g:chat_gpt_suppress_display') ? g:chat_gpt_suppress_display : 0)
  if suppress_display == 0
    call chatgpt#summary#check_and_update()
  endif

  " Ensure we're in the chat window at the bottom
  if suppress_display == 0
    let chat_winnr = bufwinnr('gpt-persistent-session')
    if chat_winnr != -1
      execute chat_winnr . 'wincmd w'
      normal! G
      call cursor('$', 1)
      redraw
    endif
  endif
endfunction

" Display ChatGPT responses in a buffer
function! chatgpt#display_response(response, finish_reason, chat_gpt_session_id)
  let response = a:response
  let finish_reason = a:finish_reason
  let chat_gpt_session_id = a:chat_gpt_session_id
  if !bufexists(chat_gpt_session_id)
    let split_dir = exists('g:llm_agent_split_direction') ? g:llm_agent_split_direction : (exists('g:chat_gpt_split_direction') ? g:chat_gpt_split_direction : 'vertical')
    if split_dir ==# 'vertical'
      silent execute winwidth(0)/g:split_ratio.'vnew '. chat_gpt_session_id
    else
      silent execute winheight(0)/g:split_ratio.'new '. chat_gpt_session_id
    endif
    call setbufvar(chat_gpt_session_id, '&buftype', 'nofile')
    call setbufvar(chat_gpt_session_id, '&bufhidden', 'hide')
    call setbufvar(chat_gpt_session_id, '&swapfile', 0)
    setlocal modifiable
    setlocal wrap
    setlocal linebreak
    call setbufvar(chat_gpt_session_id, '&ft', 'markdown')
    call setbufvar(chat_gpt_session_id, '&syntax', 'markdown')
  endif

  if bufwinnr(chat_gpt_session_id) == -1
    let split_dir = exists('g:llm_agent_split_direction') ? g:llm_agent_split_direction : (exists('g:chat_gpt_split_direction') ? g:chat_gpt_split_direction : 'vertical')
    if split_dir ==# 'vertical'
      execute winwidth(0)/g:split_ratio.'vsplit ' . chat_gpt_session_id
    else
      execute winheight(0)/g:split_ratio.'split ' . chat_gpt_session_id
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

  " Switch to chat window and scroll to bottom
  let chat_winnr = bufwinnr(chat_gpt_session_id)
  if chat_winnr != -1
    let current_win = winnr()
    execute chat_winnr . 'wincmd w'
    normal! G
    call cursor('$', 1)
    execute "normal! \<C-E>\<C-Y>"
    redraw
  endif

  " Save to history file if this is a persistent session
  if chat_gpt_session_id ==# 'gpt-persistent-session' && response != ''
    python3 << EOF
import vim
import sys
import os

plugin_dir = vim.eval('expand("<sfile>:p:h:h")')
python_path = os.path.join(plugin_dir, 'python3')
if python_path not in sys.path:
    sys.path.insert(0, python_path)

from chatgpt.utils import save_to_history
response = vim.eval('a:response')
save_to_history(response)
EOF
  endif
endfunction

" Helper function to capitalize strings
function! chatgpt#capitalize(str)
    return toupper(strpart(a:str, 0, 1)) . tolower(strpart(a:str, 1))
endfunction
