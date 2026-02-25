" ChatGPT Context Generation
" This file handles automatic project context generation

" Check if context file exists and auto-generate if not or if old
function! chatgpt#context#check_and_generate() abort
    " Skip if Vim was opened with a specific file (not a directory)
    if argc() > 0
        let first_arg = argv(0)
        if filereadable(first_arg) && !isdirectory(first_arg)
            return
        endif
    endif

    let project_dir = getcwd()
    let home = expand('~')

    " Skip if we're in home directory, parent of home, or root
    if project_dir ==# home || project_dir ==# '/' || len(project_dir) <= len(home)
        return
    endif

    " Skip if we're in a common system directory
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
    let context_file = vim_dir . '/context.md'
    let should_generate = 0

    if !filereadable(context_file)
        echo "No project context found. Generating automatically..."
        let should_generate = 1
    else
        " Check if file is older than 24 hours
        let file_time = getftime(context_file)
        let current_time = localtime()
        let age_in_hours = (current_time - file_time) / 3600

        if age_in_hours > 24
            echo "Project context is " . float2nr(age_in_hours) . " hours old. Regenerating..."
            let should_generate = 1
        endif
    endif

    if should_generate
        " Save current directory
        let save_cwd = getcwd()
        execute 'cd ' . fnameescape(project_dir)

        " Use silent generation for auto-generation (no output, runs in background)
        call chatgpt#context#generate_silent()

        " Restore directory
        execute 'cd ' . fnameescape(save_cwd)
    endif
endfunction

" Generate project context (silent mode for auto-generation)
function! chatgpt#context#generate_silent() abort
  " Call Python context generation directly
  python3 << EOF
import vim
import sys
import os

# Add python3/chatgpt to Python path
plugin_dir = vim.eval('expand("<sfile>:p:h:h")')
python_path = os.path.join(plugin_dir, 'python3')
if python_path not in sys.path:
    sys.path.insert(0, python_path)

from chatgpt.context import generate_project_context

# Generate context (will save to .vim-llm-agent/context.md automatically)
generate_project_context()
EOF
endfunction

" Generate project context (interactive mode with messages)
function! chatgpt#context#generate() abort
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

  echo "Generating project context... (this will use AI tools to explore your project)"

  " Call Python context generation directly
  python3 << EOF
import vim
import sys
import os

# Add python3/chatgpt to Python path
plugin_dir = vim.eval('expand("<sfile>:p:h:h")')
python_path = os.path.join(plugin_dir, 'python3')
if python_path not in sys.path:
    sys.path.insert(0, python_path)

from chatgpt.context import generate_project_context

# Generate context (will save to .vim-llm-agent/context.md automatically)
generate_project_context()
EOF

  echo "\nProject context generated at " . dir_name . "/context.md"
  echo "You can edit this file to customize the project context."
endfunction
