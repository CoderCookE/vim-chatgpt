" ChatGPT Summary Management
" This file handles conversation summary generation and compaction

" Extract cutoff byte position from summary metadata
function! s:get_summary_cutoff(project_dir) abort
    " Use new directory name, but check for old one for backwards compatibility
    let vim_dir = a:project_dir . '/.vim-llm-agent'
    if !isdirectory(vim_dir)
        let old_dir = a:project_dir . '/.vim-chatgpt'
        if isdirectory(old_dir)
            let vim_dir = old_dir
        endif
    endif
    let summary_file = vim_dir . '/summary.md'

    if !filereadable(summary_file)
        return 0
    endif

    let lines = readfile(summary_file, '', 10)
    for line in lines
        if line =~ 'cutoff_byte:'
            let match = matchstr(line, 'cutoff_byte:\s*\zs\d\+')
            if match != ''
                return str2nr(match)
            endif
        endif
    endfor

    return 0
endfunction

" Check if summary needs updating based on history size
function! chatgpt#summary#check_and_update() abort
    let project_dir = getcwd()
    let home = expand('~')

    " Skip if we're in home directory or system directory
    if project_dir ==# home || project_dir ==# '/' || len(project_dir) <= len(home)
        return
    endif

    if project_dir =~# '^\(/tmp\|/var\|/etc\|/usr\|/bin\|/sbin\|/opt\)'
        return
    endif

    " Use new directory name, but check for old one for backwards compatibility
    let vim_dir = project_dir . '/.vim-llm-agent'
    if !isdirectory(vim_dir)
        let old_dir = project_dir . '/.vim-chatgpt'
        if isdirectory(old_dir)
            let vim_dir = old_dir
        endif
    endif

    let history_file = vim_dir . '/history.txt'
    let summary_file = vim_dir . '/summary.md'

    if !filereadable(history_file)
        return
    endif

    let file_size = getfsize(history_file)
    let cutoff_byte = s:get_summary_cutoff(project_dir)
    let compaction_size = g:chat_gpt_summary_compaction_size
    let new_content_size = file_size - cutoff_byte

    if new_content_size > compaction_size
        echo "Conversation grew by " . float2nr(new_content_size / 1024) . "KB. Compacting into summary..."

        let save_cwd = getcwd()
        let save_session_mode = exists('g:chat_gpt_session_mode') ? g:chat_gpt_session_mode : 1
        let save_plan_approval = exists('g:chat_gpt_require_plan_approval') ? g:chat_gpt_require_plan_approval : 1
        let save_tool_approval = exists('g:chat_gpt_require_tool_approval') ? g:chat_gpt_require_tool_approval : 0
        let save_suppress_display = exists('g:chat_gpt_suppress_display') ? g:chat_gpt_suppress_display : 0

        execute 'cd ' . fnameescape(project_dir)

        let g:chat_gpt_session_mode = 0
        let g:chat_gpt_require_plan_approval = 0
        let g:chat_gpt_require_tool_approval = 0
        let g:chat_gpt_suppress_display = 1

        call chatgpt#summary#generate()

        let g:chat_gpt_session_mode = save_session_mode
        let g:chat_gpt_require_plan_approval = save_plan_approval
        let g:chat_gpt_require_tool_approval = save_tool_approval
        let g:chat_gpt_suppress_display = save_suppress_display
        execute 'cd ' . fnameescape(save_cwd)
    elseif !filereadable(summary_file) && file_size > 1024
        echo "No conversation summary found. Generating from history..."

        let save_cwd = getcwd()
        let save_session_mode = exists('g:chat_gpt_session_mode') ? g:chat_gpt_session_mode : 1
        let save_plan_approval = exists('g:chat_gpt_require_plan_approval') ? g:chat_gpt_require_plan_approval : 1
        let save_tool_approval = exists('g:chat_gpt_require_tool_approval') ? g:chat_gpt_require_tool_approval : 0
        let save_suppress_display = exists('g:chat_gpt_suppress_display') ? g:chat_gpt_suppress_display : 0

        execute 'cd ' . fnameescape(project_dir)

        let g:chat_gpt_session_mode = 0
        let g:chat_gpt_require_plan_approval = 0
        let g:chat_gpt_require_tool_approval = 0
        let g:chat_gpt_suppress_display = 1

        call chatgpt#summary#generate()

        let g:chat_gpt_session_mode = save_session_mode
        let g:chat_gpt_require_plan_approval = save_plan_approval
        let g:chat_gpt_require_tool_approval = save_tool_approval
        let g:chat_gpt_suppress_display = save_suppress_display
        execute 'cd ' . fnameescape(save_cwd)
    endif
endfunction

" Generate conversation summary
function! chatgpt#summary#generate() abort
  " Determine which directory to use (new .vim-llm-agent or old .vim-chatgpt for backwards compatibility)
  let project_dir = getcwd()
  let vim_dir = project_dir . '/.vim-llm-agent'
  let dir_name = '.vim-llm-agent'
  if !isdirectory(vim_dir)
    let old_dir = project_dir . '/.vim-chatgpt'
    if isdirectory(old_dir)
      let dir_name = '.vim-chatgpt'
    endif
  endif

  " This function is complex and calls Python code
  " For now, delegate to the main chat function with appropriate prompt
  python3 << EOF
import vim
import sys
import os

plugin_dir = vim.eval('expand("<sfile>:p:h:h:h")')
python_path = os.path.join(plugin_dir, 'python3')
if python_path not in sys.path:
    sys.path.insert(0, python_path)

# Import the summary generation logic
from chatgpt.summary import generate_conversation_summary
generate_conversation_summary()
EOF

  echo "\nConversation summary generated at " . dir_name . "/summary.md"
  echo "You can edit this file to add or modify preferences."
endfunction
