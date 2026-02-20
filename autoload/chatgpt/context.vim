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
        " Save current settings and directory
        let save_cwd = getcwd()
        let save_session_mode = exists('g:chat_gpt_session_mode') ? g:chat_gpt_session_mode : 1
        let save_plan_approval = exists('g:chat_gpt_require_plan_approval') ? g:chat_gpt_require_plan_approval : 1
        let save_tool_approval = exists('g:chat_gpt_require_tool_approval') ? g:chat_gpt_require_tool_approval : 0
        let save_suppress_display = exists('g:chat_gpt_suppress_display') ? g:chat_gpt_suppress_display : 0

        execute 'cd ' . fnameescape(project_dir)

        " Disable session mode, plan approval, tool approval, and suppress display for auto-generation
        let g:chat_gpt_session_mode = 0
        let g:chat_gpt_require_plan_approval = 0
        let g:chat_gpt_require_tool_approval = 0
        let g:chat_gpt_suppress_display = 1

        call chatgpt#context#generate()

        " Restore settings and directory
        let g:chat_gpt_session_mode = save_session_mode
        let g:chat_gpt_require_plan_approval = save_plan_approval
        let g:chat_gpt_require_tool_approval = save_tool_approval
        let g:chat_gpt_suppress_display = save_suppress_display
        execute 'cd ' . fnameescape(save_cwd)
    endif
endfunction

" Generate project context
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

  let prompt = 'Please analyze this project and create a concise project context summary. Use the available tools to:'
  let prompt .= "\n\n1. Get the working directory"
  let prompt .= "\n2. List the root directory contents"
  let prompt .= "\n3. Look for README files, package.json, requirements.txt, Cargo.toml, go.mod, pom.xml, or other project metadata files"
  let prompt .= "\n4. Read key configuration/metadata files to understand the project"
  let prompt .= "\n\nThen write a summary in this format:"
  let prompt .= "\n\n# Project: [Name]"
  let prompt .= "\n\n## Type"
  let prompt .= "\n[e.g., Python web application, JavaScript library, Rust CLI tool, etc.]"
  let prompt .= "\n\n## Purpose"
  let prompt .= "\n[Brief description of what this project does]"
  let prompt .= "\n\n## Tech Stack"
  let prompt .= "\n[Key technologies, frameworks, and dependencies]"
  let prompt .= "\n\n## Structure"
  let prompt .= "\n[Brief overview of directory structure and key files]"
  let prompt .= "\n\n## Key Files"
  let prompt .= "\n[List important entry points, config files, etc.]"
  let prompt .= "\n\nSave this context to " . dir_name . "/context.md so I understand this project in future conversations."
  let prompt .= "\n\nImportant: Actually use the create_file tool to save the context to " . dir_name . "/context.md"

  " Use session mode 0 for one-time response
  let save_session_mode = exists('g:chat_gpt_session_mode') ? g:chat_gpt_session_mode : 1
  let save_plan_approval = exists('g:chat_gpt_require_plan_approval') ? g:chat_gpt_require_plan_approval : 1
  let save_tool_approval = exists('g:chat_gpt_require_tool_approval') ? g:chat_gpt_require_tool_approval : 0
  let save_suppress_display = exists('g:chat_gpt_suppress_display') ? g:chat_gpt_suppress_display : 0
  let g:chat_gpt_session_mode = 0
  let g:chat_gpt_require_plan_approval = 0
  let g:chat_gpt_require_tool_approval = 0
  let g:chat_gpt_suppress_display = 1

  echo "Generating project context... (this will use AI tools to explore your project)"
  call chatgpt#chat(prompt)

  " Restore settings
  let g:chat_gpt_session_mode = save_session_mode
  let g:chat_gpt_require_plan_approval = save_plan_approval
  let g:chat_gpt_require_tool_approval = save_tool_approval
  let g:chat_gpt_suppress_display = save_suppress_display

  echo "\nProject context generated at " . dir_name . "/context.md"
  echo "You can edit this file to customize the project context."
endfunction
