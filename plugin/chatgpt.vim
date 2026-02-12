" ChatGPT Vim Plugin
"
" Ensure Python3 is available
if !has('python3')
  echo "Python 3 support is required for ChatGPT plugin"
  finish
endif

" Function to check if context file exists and auto-generate if not or if old
function! s:check_and_generate_context()
    " Use directory of the file being edited, or current directory if no file
    let current_file = expand('%:p')
    if empty(current_file) || !filereadable(current_file)
        " No file being edited, use current working directory
        let project_dir = getcwd()
    else
        " Get directory of the file being edited
        let project_dir = expand('%:p:h')
    endif

    let home = expand('~')

    " Skip if we're in home directory, parent of home, or root
    if project_dir ==# home || project_dir ==# '/' || len(project_dir) <= len(home)
        return
    endif

    " Also skip if we're in a common system directory
    if project_dir =~# '^\(/tmp\|/var\|/etc\|/usr\|/bin\|/sbin\|/opt\)'
        return
    endif

    let context_file = project_dir . '/.vim-chatgpt/context.md'
    let should_generate = 0

    if !filereadable(context_file)
        " Auto-generate context file if it doesn't exist
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
        let save_suppress_display = exists('g:chat_gpt_suppress_display') ? g:chat_gpt_suppress_display : 0

        " Change to project directory for context generation
        execute 'cd ' . fnameescape(project_dir)

        " Disable session mode, plan approval, and suppress display for auto-generation
        let g:chat_gpt_session_mode = 0
        let g:chat_gpt_require_plan_approval = 0
        let g:chat_gpt_suppress_display = 1

        call GenerateProjectContext()

        " Restore settings and directory
        let g:chat_gpt_session_mode = save_session_mode
        let g:chat_gpt_require_plan_approval = save_plan_approval
        let g:chat_gpt_suppress_display = save_suppress_display
        execute 'cd ' . fnameescape(save_cwd)
    endif
endfunction

" Function to extract cutoff byte position from summary metadata
function! s:get_summary_cutoff()
    let summary_file = getcwd() . '/.vim-chatgpt/summary.md'

    if !filereadable(summary_file)
        return 0
    endif

    " Read first few lines looking for metadata
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

" Function to check if summary needs updating based on history size
function! s:check_and_update_summary()
    " Use directory of the file being edited, or current directory if no file
    let current_file = expand('%:p')
    if empty(current_file) || !filereadable(current_file)
        " No file being edited, use current working directory
        let project_dir = getcwd()
    else
        " Get directory of the file being edited
        let project_dir = expand('%:p:h')
    endif

    let home = expand('~')

    " Skip if we're in home directory, parent of home, or root
    if project_dir ==# home || project_dir ==# '/' || len(project_dir) <= len(home)
        return
    endif

    " Also skip if we're in a common system directory
    if project_dir =~# '^\(/tmp\|/var\|/etc\|/usr\|/bin\|/sbin\|/opt\)'
        return
    endif

    let history_file = project_dir . '/.vim-chatgpt/history.txt'
    let summary_file = project_dir . '/.vim-chatgpt/summary.md'

    " Only check if history file exists
    if !filereadable(history_file)
        return
    endif

    " Get history file size
    let file_size = getfsize(history_file)
    let cutoff_byte = s:get_summary_cutoff()
    let compaction_size = g:chat_gpt_summary_compaction_size
    let new_content_size = file_size - cutoff_byte

    " Check if we should update:
    " 1. New content since last summary exceeds compaction size
    " 2. OR summary doesn't exist yet and history has content
    if new_content_size > compaction_size
        echo "Conversation grew by " . float2nr(new_content_size / 1024) . "KB. Compacting into summary..."

        " Save current settings and directory
        let save_cwd = getcwd()
        let save_session_mode = exists('g:chat_gpt_session_mode') ? g:chat_gpt_session_mode : 1
        let save_plan_approval = exists('g:chat_gpt_require_plan_approval') ? g:chat_gpt_require_plan_approval : 1
        let save_suppress_display = exists('g:chat_gpt_suppress_display') ? g:chat_gpt_suppress_display : 0

        " Change to project directory for summary generation
        execute 'cd ' . fnameescape(project_dir)

        " Disable session mode, plan approval, and suppress display for auto-generation
        let g:chat_gpt_session_mode = 0
        let g:chat_gpt_require_plan_approval = 0
        let g:chat_gpt_suppress_display = 1

        call GenerateConversationSummary()

        " Restore settings and directory
        let g:chat_gpt_session_mode = save_session_mode
        let g:chat_gpt_require_plan_approval = save_plan_approval
        let g:chat_gpt_suppress_display = save_suppress_display
        execute 'cd ' . fnameescape(save_cwd)
    elseif !filereadable(summary_file) && file_size > 1024
        echo "No conversation summary found. Generating from history..."

        " Save current settings and directory
        let save_cwd = getcwd()
        let save_session_mode = exists('g:chat_gpt_session_mode') ? g:chat_gpt_session_mode : 1
        let save_plan_approval = exists('g:chat_gpt_require_plan_approval') ? g:chat_gpt_require_plan_approval : 1
        let save_suppress_display = exists('g:chat_gpt_suppress_display') ? g:chat_gpt_suppress_display : 0

        " Change to project directory for summary generation
        execute 'cd ' . fnameescape(project_dir)

        " Disable session mode, plan approval, and suppress display for auto-generation
        let g:chat_gpt_session_mode = 0
        let g:chat_gpt_require_plan_approval = 0
        let g:chat_gpt_suppress_display = 1

        call GenerateConversationSummary()

        " Restore settings and directory
        let g:chat_gpt_session_mode = save_session_mode
        let g:chat_gpt_require_plan_approval = save_plan_approval
        let g:chat_gpt_suppress_display = save_suppress_display
        execute 'cd ' . fnameescape(save_cwd)
    endif
endfunction

" Set default values for Vim variables if they don't exist
if !exists("g:chat_gpt_max_tokens")
  let g:chat_gpt_max_tokens = 2000
endif

if !exists("g:chat_gpt_temperature")
  let g:chat_gpt_temperature = 0.7
endif

if !exists("g:chat_gpt_model")
  let g:chat_gpt_model = 'gpt-4o'
endif

if !exists("g:chat_gpt_lang")
  let g:chat_gpt_lang = v:none
endif

if !exists("g:chat_gpt_split_direction")
  let g:chat_gpt_split_direction = 'horizontal'
endif

if !exists("g:split_ratio")
  let g:split_ratio = 3
endif

if !exists("g:chat_persona")
  let g:chat_persona = 'default'
endif

" Enable tools/function calling (default: enabled for supported providers)
if !exists("g:chat_gpt_enable_tools")
  let g:chat_gpt_enable_tools = 1
endif

" Require plan approval before tool execution (default: enabled when tools are enabled)
if !exists("g:chat_gpt_require_plan_approval")
  let g:chat_gpt_require_plan_approval = 1
endif

" Conversation history compaction settings
if !exists("g:chat_gpt_summary_compaction_size")
  let g:chat_gpt_summary_compaction_size = 51200  " 50KB - trigger summary update
endif

if !exists("g:chat_gpt_recent_history_size")
  let g:chat_gpt_recent_history_size = 20480  " 20KB - keep this much recent history uncompressed
endif

" Provider selection (default to openai for backward compatibility)
if !exists("g:chat_gpt_provider")
  let g:chat_gpt_provider = 'openai'
endif

" Anthropic (Claude) configuration
if !exists("g:anthropic_api_key")
  let g:anthropic_api_key = ''
endif

if !exists("g:anthropic_model")
  let g:anthropic_model = 'claude-sonnet-4-5-20250929'
endif

if !exists("g:anthropic_base_url")
  let g:anthropic_base_url = 'https://api.anthropic.com/v1'
endif

" Gemini (Google) configuration
if !exists("g:gemini_api_key")
  let g:gemini_api_key = ''
endif

if !exists("g:gemini_model")
  let g:gemini_model = 'gemini-2.5-flash'
endif

" Ollama configuration
if !exists("g:ollama_base_url")
  let g:ollama_base_url = 'http://localhost:11434'
endif

if !exists("g:ollama_model")
  let g:ollama_model = 'llama3.2'
endif

" OpenRouter configuration
if !exists("g:openrouter_api_key")
  let g:openrouter_api_key = ''
endif

if !exists("g:openrouter_model")
  let g:openrouter_model = 'anthropic/claude-3.5-sonnet'
endif

if !exists("g:openrouter_base_url")
  let g:openrouter_base_url = 'https://openrouter.ai/api/v1'
endif

let code_wrapper_snippet = "Given the following code snippet: "
let g:prompt_templates = {
\ 'ask': '',
\ 'rewrite': 'Can you rewrite this more idiomatically? ' . code_wrapper_snippet,
\ 'review': 'Can you provide a code review? ' . code_wrapper_snippet,
\ 'document': 'Return documentation following language pattern conventions. ' . code_wrapper_snippet,
\ 'explain': 'Can you explain how this works? ' . code_wrapper_snippet,
\ 'test': 'Can you write a test? ' . code_wrapper_snippet,
\ 'fix':  'I have an error I need you to fix. ' . code_wrapper_snippet,
\}

if exists('g:chat_gpt_custom_prompts')
  call extend(g:prompt_templates, g:chat_gpt_custom_prompts)
endif

let g:promptKeys = keys(g:prompt_templates)

let g:gpt_personas = {
\ "default": 'You are a helpful expert programmer we are working together to solve complex coding challenges, and I need your help. Please make sure to wrap all code blocks in ``` annotate the programming language you are using.',
\}

if exists('g:chat_gpt_custom_persona')
  call extend(g:gpt_personas, g:chat_gpt_custom_persona)
endif
"
" Function to show ChatGPT responses in a new buffer
function! DisplayChatGPTResponse(response, finish_reason, chat_gpt_session_id)
  let response = a:response
  let finish_reason = a:finish_reason

  let chat_gpt_session_id = a:chat_gpt_session_id

  if !bufexists(chat_gpt_session_id)
    if g:chat_gpt_split_direction ==# 'vertical'
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
    if g:chat_gpt_split_direction ==# 'vertical'
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

  execute bufwinnr(chat_gpt_session_id) . 'wincmd w'
  " Move the viewport to the bottom of the buffer
  normal! G
  call cursor('$', 1)

  " Save to history file if this is a persistent session
  if chat_gpt_session_id ==# 'gpt-persistent-session' && response != ''
    python3 << EOF
import vim
response = vim.eval('a:response')
save_to_history(response)
EOF
  endif

  if finish_reason != ''
    wincmd p
  endif
endfunction

" Function to interact with ChatGPT
function! ChatGPT(prompt) abort
  python3 << EOF

import sys
import vim
import os

import json

try:
    import requests
except ImportError:
    print("Error: requests module not found. Please install with: pip install requests")
    raise

def safe_vim_eval(expression):
    try:
        return vim.eval(expression)
    except vim.error:
        return None


def save_to_history(content):
    """Save content to history file"""
    try:
        # Only save if session mode is enabled
        session_enabled = int(vim.eval('exists("g:chat_gpt_session_mode") ? g:chat_gpt_session_mode : 1')) == 1
        if not session_enabled:
            return

        vim_chatgpt_dir = os.path.join(os.getcwd(), '.vim-chatgpt')
        history_file = os.path.join(vim_chatgpt_dir, 'history.txt')

        # Ensure directory exists
        if not os.path.exists(vim_chatgpt_dir):
            os.makedirs(vim_chatgpt_dir)

        # Append to history file
        with open(history_file, 'a', encoding='utf-8') as f:
            f.write(content)
    except Exception as e:
        # Silently ignore errors saving history
        pass


# Tools framework for function calling
def get_tool_definitions():
    """Define available tools for AI agents"""
    return [
        {
            "name": "get_working_directory",
            "description": "Get the current working directory path. Use this to understand the project root location.",
            "parameters": {
                "type": "object",
                "properties": {},
                "required": []
            }
        },
        {
            "name": "list_directory",
            "description": "List files and directories in a specified path. Use this to explore project structure and find relevant files.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "Path to the directory to list (absolute or relative to current directory). Use '.' for current directory."
                    },
                    "show_hidden": {
                        "type": "boolean",
                        "description": "Whether to show hidden files/directories (those starting with '.'). Default: false",
                        "default": False
                    }
                },
                "required": ["path"]
            }
        },
        {
            "name": "find_in_file",
            "description": "Search for text pattern in a specific file using grep. Returns matching lines with line numbers.",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Path to the file to search in (absolute or relative to current directory)"
                    },
                    "pattern": {
                        "type": "string",
                        "description": "Text pattern or regex to search for"
                    },
                    "case_sensitive": {
                        "type": "boolean",
                        "description": "Whether the search should be case sensitive (default: false)",
                        "default": False
                    }
                },
                "required": ["file_path", "pattern"]
            }
        },
        {
            "name": "find_file_in_project",
            "description": "Find files in the current project/directory by name pattern. Returns list of matching file paths.",
            "parameters": {
                "type": "object",
                "properties": {
                    "pattern": {
                        "type": "string",
                        "description": "File name pattern to search for (supports wildcards like *.py, *test*, etc.)"
                    },
                    "max_results": {
                        "type": "integer",
                        "description": "Maximum number of results to return (default: 20)",
                        "default": 20
                    }
                },
                "required": ["pattern"]
            }
        },
        {
            "name": "read_file",
            "description": "Read the contents of a file. Returns the file contents as text.",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Path to the file to read (absolute or relative to current directory)"
                    },
                    "max_lines": {
                        "type": "integer",
                        "description": "Maximum number of lines to read (default: 100)",
                        "default": 100
                    }
                },
                "required": ["file_path"]
            }
        },
        {
            "name": "create_file",
            "description": "Create a new file with specified content. Returns success message or error.",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Path where the new file should be created (absolute or relative to current directory)"
                    },
                    "content": {
                        "type": "string",
                        "description": "The content to write to the new file"
                    },
                    "overwrite": {
                        "type": "boolean",
                        "description": "Whether to overwrite if file already exists (default: false)",
                        "default": False
                    }
                },
                "required": ["file_path", "content"]
            }
        },
        {
            "name": "open_file",
            "description": "Open a file in the current Vim buffer. The file will be displayed in the editor.",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Path to the file to open in Vim (absolute or relative to current directory)"
                    },
                    "split": {
                        "type": "string",
                        "description": "How to open the file: 'current' (default), 'horizontal', or 'vertical'",
                        "enum": ["current", "horizontal", "vertical"],
                        "default": "current"
                    }
                },
                "required": ["file_path"]
            }
        },
        {
            "name": "edit_file",
            "description": "Edit an existing file by replacing specific content. Use this to make precise changes to files.",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Path to the file to edit (absolute or relative to current directory)"
                    },
                    "old_content": {
                        "type": "string",
                        "description": "The exact content to find and replace. Must match exactly including whitespace."
                    },
                    "new_content": {
                        "type": "string",
                        "description": "The new content to replace the old content with"
                    }
                },
                "required": ["file_path", "old_content", "new_content"]
            }
        },
        {
            "name": "edit_file_lines",
            "description": "Edit specific lines in a file by line number. More efficient for large files. Line numbers are 1-indexed.",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Path to the file to edit (absolute or relative to current directory)"
                    },
                    "start_line": {
                        "type": "integer",
                        "description": "Starting line number (1-indexed, inclusive)"
                    },
                    "end_line": {
                        "type": "integer",
                        "description": "Ending line number (1-indexed, inclusive). Use same as start_line to replace a single line."
                    },
                    "new_content": {
                        "type": "string",
                        "description": "The new content to replace the specified line range. Can be multiple lines separated by newlines."
                    }
                },
                "required": ["file_path", "start_line", "end_line", "new_content"]
            }
        }
    ]


def execute_tool(tool_name, arguments):
    """Execute a tool with given arguments"""
    import subprocess
    import glob as glob_module

    try:
        if tool_name == "get_working_directory":
            try:
                cwd = os.getcwd()
                return f"Current working directory: {cwd}"
            except Exception as e:
                return f"Error getting working directory: {str(e)}"

        elif tool_name == "list_directory":
            path = arguments.get("path", ".")
            show_hidden = arguments.get("show_hidden", False)

            try:
                # Resolve path
                if not os.path.exists(path):
                    return f"Directory not found: {path}"

                if not os.path.isdir(path):
                    return f"Not a directory: {path}"

                # List directory contents
                items = os.listdir(path)

                # Filter hidden files if needed
                if not show_hidden:
                    items = [item for item in items if not item.startswith('.')]

                # Sort items: directories first, then files
                dirs = sorted([item for item in items if os.path.isdir(os.path.join(path, item))])
                files = sorted([item for item in items if os.path.isfile(os.path.join(path, item))])

                # Format output
                result_lines = []
                if dirs:
                    result_lines.append("Directories:")
                    for d in dirs:
                        result_lines.append(f"  {d}/")

                if files:
                    if dirs:
                        result_lines.append("")  # Empty line separator
                    result_lines.append("Files:")
                    for f in files:
                        file_path = os.path.join(path, f)
                        try:
                            size = os.path.getsize(file_path)
                            size_str = f"{size:,} bytes" if size < 1024 else f"{size/1024:.1f} KB"
                            result_lines.append(f"  {f} ({size_str})")
                        except:
                            result_lines.append(f"  {f}")

                if not dirs and not files:
                    return f"Directory is empty: {path}"

                total = len(dirs) + len(files)
                result_lines.insert(0, f"Listing {path} ({len(dirs)} directories, {len(files)} files):\n")

                return "\n".join(result_lines)
            except PermissionError:
                return f"Permission denied accessing directory: {path}"
            except Exception as e:
                return f"Error listing directory: {str(e)}"

        elif tool_name == "find_in_file":
            file_path = arguments.get("file_path")
            pattern = arguments.get("pattern")
            case_sensitive = arguments.get("case_sensitive", False)

            # Build grep command
            cmd = ["grep", "-n"]
            if not case_sensitive:
                cmd.append("-i")
            cmd.extend([pattern, file_path])

            result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                return result.stdout.strip()
            elif result.returncode == 1:
                return f"No matches found for '{pattern}' in {file_path}"
            else:
                return f"Error searching file: {result.stderr.strip()}"

        elif tool_name == "find_file_in_project":
            pattern = arguments.get("pattern")
            max_results = arguments.get("max_results", 20)

            # Get current working directory
            cwd = os.getcwd()

            # Use find command to search for files
            cmd = ["find", ".", "-name", pattern, "-type", "f"]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10, cwd=cwd)

            if result.returncode == 0:
                files = result.stdout.strip().split('\n')
                files = [f for f in files if f]  # Remove empty strings
                if len(files) > max_results:
                    files = files[:max_results]
                    return '\n'.join(files) + f'\n... ({len(files)} results shown, more available)'
                return '\n'.join(files) if files else f"No files found matching pattern: {pattern}"
            else:
                return f"Error finding files: {result.stderr.strip()}"

        elif tool_name == "read_file":
            file_path = arguments.get("file_path")
            max_lines = arguments.get("max_lines", 100)

            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = []
                    for i, line in enumerate(f):
                        if i >= max_lines:
                            lines.append(f"... (truncated at {max_lines} lines)")
                            break
                        lines.append(line.rstrip())
                    return '\n'.join(lines)
            except FileNotFoundError:
                return f"File not found: {file_path}"
            except PermissionError:
                return f"Permission denied reading file: {file_path}"
            except Exception as e:
                return f"Error reading file: {str(e)}"

        elif tool_name == "create_file":
            file_path = arguments.get("file_path")
            content = arguments.get("content", "")
            overwrite = arguments.get("overwrite", False)

            try:
                # Check if file exists
                if os.path.exists(file_path) and not overwrite:
                    return f"File already exists: {file_path}. Set overwrite=true to replace it."

                # Create directory if it doesn't exist
                directory = os.path.dirname(file_path)
                if directory and not os.path.exists(directory):
                    os.makedirs(directory)

                # Write the file
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)

                return f"Successfully created file: {file_path} ({len(content)} characters)"
            except PermissionError:
                return f"Permission denied creating file: {file_path}"
            except Exception as e:
                return f"Error creating file: {str(e)}"

        elif tool_name == "open_file":
            file_path = arguments.get("file_path")
            split = arguments.get("split", "current")

            try:
                # Check if file exists
                if not os.path.exists(file_path):
                    return f"File not found: {file_path}"

                # Build Vim command to open the file
                if split == "horizontal":
                    vim_cmd = f"split {file_path}"
                elif split == "vertical":
                    vim_cmd = f"vsplit {file_path}"
                else:  # current
                    vim_cmd = f"edit {file_path}"

                # Execute the Vim command
                vim.command(vim_cmd)

                return f"Opened file in Vim: {file_path} (split={split})"
            except vim.error as e:
                return f"Vim error opening file: {str(e)}"
            except Exception as e:
                return f"Error opening file: {str(e)}"

        elif tool_name == "edit_file":
            file_path = arguments.get("file_path")
            old_content = arguments.get("old_content")
            new_content = arguments.get("new_content")

            try:
                # Read the file
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Check if old_content exists in the file
                if old_content not in content:
                    return f"Content not found in {file_path}. The exact content must match including whitespace."

                # Count occurrences
                count = content.count(old_content)
                if count > 1:
                    return f"Found {count} occurrences of the content in {file_path}. Please provide more specific content to replace (include more surrounding context)."

                # Replace the content
                new_file_content = content.replace(old_content, new_content, 1)

                # Write back to the file
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_file_content)

                return f"Successfully edited {file_path}: replaced {len(old_content)} characters with {len(new_content)} characters"
            except FileNotFoundError:
                return f"File not found: {file_path}"
            except PermissionError:
                return f"Permission denied editing file: {file_path}"
            except Exception as e:
                return f"Error editing file: {str(e)}"

        elif tool_name == "edit_file_lines":
            file_path = arguments.get("file_path")
            start_line = arguments.get("start_line")
            end_line = arguments.get("end_line")
            new_content = arguments.get("new_content")

            try:
                # Validate line numbers
                if start_line < 1:
                    return f"Invalid start_line: {start_line}. Line numbers must be >= 1."
                if end_line < start_line:
                    return f"Invalid line range: end_line ({end_line}) must be >= start_line ({start_line})."

                # Read all lines from the file
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()

                total_lines = len(lines)

                # Check if line numbers are within bounds
                if start_line > total_lines:
                    return f"start_line ({start_line}) exceeds file length ({total_lines} lines)."
                if end_line > total_lines:
                    return f"end_line ({end_line}) exceeds file length ({total_lines} lines)."

                # Convert to 0-indexed
                start_idx = start_line - 1
                end_idx = end_line - 1

                # Prepare new content lines
                new_lines = new_content.split('\n') if new_content else []
                # Ensure each line has a newline except possibly the last
                new_lines_formatted = [line + '\n' if not line.endswith('\n') else line for line in new_lines[:-1]]
                if new_lines:
                    # For the last line, add newline only if original last line had one
                    if end_idx < total_lines - 1 or (end_idx == total_lines - 1 and lines[end_idx].endswith('\n')):
                        new_lines_formatted.append(new_lines[-1] + '\n' if not new_lines[-1].endswith('\n') else new_lines[-1])
                    else:
                        new_lines_formatted.append(new_lines[-1])

                # Build the new file content
                new_file_lines = lines[:start_idx] + new_lines_formatted + lines[end_idx + 1:]

                # Write back to the file
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.writelines(new_file_lines)

                lines_replaced = end_idx - start_idx + 1
                lines_added = len(new_lines_formatted)
                return f"Successfully edited {file_path}: replaced lines {start_line}-{end_line} ({lines_replaced} lines) with {lines_added} lines"
            except FileNotFoundError:
                return f"File not found: {file_path}"
            except PermissionError:
                return f"Permission denied editing file: {file_path}"
            except Exception as e:
                return f"Error editing file by lines: {str(e)}"

        else:
            return f"Unknown tool: {tool_name}"

    except subprocess.TimeoutExpired:
        return f"Tool execution timed out: {tool_name}"
    except Exception as e:
        return f"Error executing tool {tool_name}: {str(e)}"


# Provider abstraction layer for multi-provider support
class BaseProvider:
    """Base interface for all LLM providers"""

    def __init__(self, config):
        self.config = config
        self.validate_config()

    def validate_config(self):
        """Validate required configuration"""
        raise NotImplementedError("Subclasses must implement validate_config()")

    def get_model(self):
        """Get the model name from config"""
        raise NotImplementedError("Subclasses must implement get_model()")

    def create_messages(self, system_message, history, user_message):
        """Format messages for provider's API"""
        raise NotImplementedError("Subclasses must implement create_messages()")

    def stream_chat(self, messages, model, temperature, max_tokens, tools=None):
        """
        Stream chat completion chunks
        Yields: (content_delta, finish_reason, tool_calls)
        tool_calls format: [{"id": "...", "name": "...", "arguments": {...}}] or None
        """
        raise NotImplementedError("Subclasses must implement stream_chat()")

    def supports_tools(self):
        """Whether this provider supports function/tool calling"""
        return False

    def format_tools_for_api(self, tools):
        """Format tool definitions for this provider's API"""
        return tools


class OpenAIProvider(BaseProvider):
    """OpenAI and Azure OpenAI provider using HTTP requests"""

    def validate_config(self):
        """Validate OpenAI configuration"""
        if not self.config.get('api_key'):
            raise ValueError("OpenAI API key required. Set OPENAI_API_KEY or g:openai_api_key")

        # Validate Azure-specific config if using Azure
        if self.config.get('api_type') == 'azure':
            if not self.config.get('azure_endpoint'):
                raise ValueError("Azure endpoint required. Set g:azure_endpoint")
            if not self.config.get('azure_deployment'):
                raise ValueError("Azure deployment required. Set g:azure_deployment")
            if not self.config.get('azure_api_version'):
                raise ValueError("Azure API version required. Set g:azure_api_version")

    def get_model(self):
        """Get the model name from config"""
        return self.config.get('model', 'gpt-4o')

    def create_messages(self, system_message, history, user_message):
        """Create messages in OpenAI format"""
        messages = [{"role": "system", "content": system_message}]
        messages.extend(history)
        messages.append({"role": "user", "content": user_message})
        return messages

    def supports_tools(self):
        """OpenAI supports function calling"""
        return True

    def format_tools_for_api(self, tools):
        """Format tools for OpenAI API"""
        return [
            {
                "type": "function",
                "function": {
                    "name": tool["name"],
                    "description": tool["description"],
                    "parameters": tool["parameters"]
                }
            }
            for tool in tools
        ]

    def stream_chat(self, messages, model, temperature, max_tokens, tools=None):
        """Stream chat completion from OpenAI via HTTP"""
        # Determine if using Azure or standard OpenAI
        api_type = self.config.get('api_type')

        if api_type == 'azure':
            # Azure OpenAI endpoint format
            azure_endpoint = self.config['azure_endpoint'].rstrip('/')
            azure_deployment = self.config['azure_deployment']
            azure_api_version = self.config['azure_api_version']
            url = f"{azure_endpoint}/openai/deployments/{azure_deployment}/chat/completions?api-version={azure_api_version}"

            headers = {
                'api-key': self.config['api_key'],
                'Content-Type': 'application/json'
            }
        else:
            # Standard OpenAI endpoint
            base_url = self.config.get('base_url') or 'https://api.openai.com/v1'
            base_url = base_url.rstrip('/')
            url = f"{base_url}/chat/completions"

            headers = {
                'Authorization': f'Bearer {self.config["api_key"]}',
                'Content-Type': 'application/json'
            }

        # Build payload
        payload = {
            'model': model,
            'messages': messages,
            'stream': True
        }

        # Add tools if provided
        if tools:
            payload['tools'] = self.format_tools_for_api(tools)
            payload['tool_choice'] = 'auto'

        # Handle different model parameter requirements
        if model.startswith('gpt-'):
            payload['temperature'] = temperature
            payload['max_tokens'] = max_tokens
        else:
            # O-series models use different parameters
            payload['max_completion_tokens'] = max_tokens

        response = requests.post(url, headers=headers, json=payload, stream=True)

        # Check for HTTP errors
        if response.status_code != 200:
            error_body = response.text
            raise Exception(f"OpenAI API error (status {response.status_code}): {error_body}")

        # Parse Server-Sent Events stream
        tool_calls_accumulator = {}  # Accumulate tool call chunks by index

        for line in response.iter_lines():
            if not line:
                continue

            line = line.decode('utf-8')
            if not line.startswith('data: '):
                continue

            data = line[6:]  # Remove 'data: ' prefix
            if data == '[DONE]':
                break

            try:
                chunk = json.loads(data)
                if 'choices' in chunk and chunk['choices']:
                    choice = chunk['choices'][0]
                    delta = choice.get('delta', {})
                    content = delta.get('content', '')
                    finish_reason = choice.get('finish_reason', '')

                    # Handle tool calls (streamed in chunks)
                    if 'tool_calls' in delta:
                        for tool_call_chunk in delta['tool_calls']:
                            idx = tool_call_chunk.get('index', 0)
                            if idx not in tool_calls_accumulator:
                                tool_calls_accumulator[idx] = {
                                    'id': '',
                                    'name': '',
                                    'arguments': ''
                                }

                            if 'id' in tool_call_chunk:
                                tool_calls_accumulator[idx]['id'] = tool_call_chunk['id']
                            if 'function' in tool_call_chunk:
                                func = tool_call_chunk['function']
                                if 'name' in func:
                                    tool_calls_accumulator[idx]['name'] = func['name']
                                if 'arguments' in func:
                                    tool_calls_accumulator[idx]['arguments'] += func['arguments']

                    # Yield content if present
                    if content:
                        yield (content, '', None)

                    # On finish, yield tool calls if any
                    if finish_reason:
                        tool_calls = None
                        if tool_calls_accumulator:
                            tool_calls = []
                            for tool_data in tool_calls_accumulator.values():
                                try:
                                    tool_calls.append({
                                        'id': tool_data['id'],
                                        'name': tool_data['name'],
                                        'arguments': json.loads(tool_data['arguments'])
                                    })
                                except json.JSONDecodeError:
                                    pass  # Skip malformed tool calls
                        yield ('', finish_reason, tool_calls)
            except json.JSONDecodeError:
                continue


class AnthropicProvider(BaseProvider):
    """Anthropic Claude provider using HTTP requests"""

    def validate_config(self):
        """Validate Anthropic configuration"""
        if not self.config.get('api_key'):
            raise ValueError("Anthropic API key required. Set ANTHROPIC_API_KEY or g:anthropic_api_key")

    def get_model(self):
        """Get the model name from config"""
        return self.config.get('model', 'claude-sonnet-4-5-20250929')

    def create_messages(self, system_message, history, user_message):
        """Create messages in Anthropic format"""
        # Anthropic separates system message from messages array
        messages = []
        for msg in history:
            if msg.get('role') != 'system':
                messages.append(msg)
        messages.append({"role": "user", "content": user_message})

        return {
            'system': system_message,
            'messages': messages
        }

    def supports_tools(self):
        """Anthropic supports tool use"""
        return True

    def format_tools_for_api(self, tools):
        """Format tools for Anthropic API"""
        return [
            {
                "name": tool["name"],
                "description": tool["description"],
                "input_schema": tool["parameters"]
            }
            for tool in tools
        ]

    def stream_chat(self, messages, model, temperature, max_tokens, tools=None):
        """Stream chat completion from Anthropic"""
        headers = {
            'x-api-key': self.config['api_key'],
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json'
        }

        payload = {
            'model': model,
            'max_tokens': max_tokens,
            'temperature': temperature,
            'system': messages['system'],
            'messages': messages['messages'],
            'stream': True
        }

        # Add tools if provided
        if tools:
            payload['tools'] = self.format_tools_for_api(tools)

        # Construct URL - ensure we have /v1/messages endpoint
        base_url = self.config['base_url'].rstrip('/')
        # Add /v1 if not already present
        if not base_url.endswith('/v1'):
            base_url = f"{base_url}/v1"
        url = f"{base_url}/messages"

        response = requests.post(
            url,
            headers=headers,
            json=payload,
            stream=True
        )

        # Check for HTTP errors
        if response.status_code != 200:
            error_body = response.text
            raise Exception(f"Anthropic API error (status {response.status_code}) at {url}: {error_body}")

        # Parse Server-Sent Events stream
        tool_use_blocks = {}  # Accumulate tool use blocks

        for line in response.iter_lines():
            if not line:
                continue

            line = line.decode('utf-8')
            if not line.startswith('data: '):
                continue

            data = line[6:]  # Remove 'data: ' prefix
            if data == '[DONE]':
                break

            try:
                chunk = json.loads(data)
                chunk_type = chunk.get('type')

                # Handle text content
                if chunk_type == 'content_block_delta':
                    delta = chunk.get('delta', {})
                    if delta.get('type') == 'text_delta':
                        content = delta.get('text', '')
                        if content:
                            yield (content, '', None)
                    elif delta.get('type') == 'input_json_delta':
                        # Accumulate tool use input
                        idx = chunk.get('index', 0)
                        if idx not in tool_use_blocks:
                            tool_use_blocks[idx] = {'id': '', 'name': '', 'input': ''}
                        tool_use_blocks[idx]['input'] += delta.get('partial_json', '')

                # Handle tool use block start
                elif chunk_type == 'content_block_start':
                    block = chunk.get('content_block', {})
                    if block.get('type') == 'tool_use':
                        idx = chunk.get('index', 0)
                        tool_use_blocks[idx] = {
                            'id': block.get('id', ''),
                            'name': block.get('name', ''),
                            'input': ''
                        }

                # Handle message end
                elif chunk_type == 'message_delta':
                    finish_reason = chunk.get('delta', {}).get('stop_reason', '')
                    if finish_reason:
                        # Convert accumulated tool blocks to tool_calls
                        tool_calls = None
                        if tool_use_blocks:
                            tool_calls = []
                            for tool_data in tool_use_blocks.values():
                                try:
                                    tool_calls.append({
                                        'id': tool_data['id'],
                                        'name': tool_data['name'],
                                        'arguments': json.loads(tool_data['input'])
                                    })
                                except json.JSONDecodeError:
                                    pass  # Skip malformed tool calls
                        yield ('', 'stop', tool_calls)
            except json.JSONDecodeError:
                continue


class GoogleProvider(BaseProvider):
    """Google Gemini provider using HTTP requests"""

    def validate_config(self):
        """Validate Gemini configuration"""
        if not self.config.get('api_key'):
            raise ValueError("Gemini API key required. Set GEMINI_API_KEY or g:gemini_api_key")

    def get_model(self):
        """Get the model name from config"""
        return self.config.get('model', 'gemini-2.5-flash')

    def create_messages(self, system_message, history, user_message):
        """Create messages in Gemini format"""
        # Gemini uses 'model' instead of 'assistant' for AI responses
        contents = []
        for msg in history:
            if msg.get('role') == 'user':
                contents.append({
                    'role': 'user',
                    'parts': [{'text': msg['content']}]
                })
            elif msg.get('role') == 'assistant':
                contents.append({
                    'role': 'model',
                    'parts': [{'text': msg['content']}]
                })

        contents.append({
            'role': 'user',
            'parts': [{'text': user_message}]
        })

        return {
            'system_instruction': {'parts': [{'text': system_message}]},
            'contents': contents
        }

    def stream_chat(self, messages, model, temperature, max_tokens, tools=None):
        """Stream chat completion from Google Gemini"""
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?key={self.config['api_key']}"

        payload = {
            'systemInstruction': messages['system_instruction'],
            'contents': messages['contents'],
            'generationConfig': {
                'temperature': temperature,
                'maxOutputTokens': max_tokens
            }
        }

        response = requests.post(url, json=payload, stream=True)

        # Check for HTTP errors
        if response.status_code != 200:
            error_body = response.text
            raise Exception(f"Gemini API error (status {response.status_code}): {error_body}")

        # Gemini streaming sends JSON array with one element per chunk
        # Read the raw text response
        response_text = response.text

        # Parse as JSON array
        try:
            response_data = json.loads(response_text)

            # Response is an array of chunks
            if isinstance(response_data, list):
                for item in response_data:
                    # Check for errors
                    if 'error' in item:
                        raise Exception(f"Gemini API error: {json.dumps(item['error'])}")

                    if 'candidates' in item and item['candidates']:
                        candidate = item['candidates'][0]
                        if 'content' in candidate and 'parts' in candidate['content']:
                            for part in candidate['content']['parts']:
                                text = part.get('text', '')
                                if text:
                                    # Yield the full text at once
                                    yield (text, '', None)
                        finish_reason = candidate.get('finishReason', '')
                        if finish_reason:
                            if finish_reason == 'STOP':
                                yield ('', 'stop', None)
                            else:
                                yield ('', finish_reason, None)
            elif isinstance(response_data, dict):
                # Single object response
                if 'error' in response_data:
                    raise Exception(f"Gemini API error: {json.dumps(response_data['error'])}")

                if 'candidates' in response_data and response_data['candidates']:
                    candidate = response_data['candidates'][0]
                    if 'content' in candidate and 'parts' in candidate['content']:
                        for part in candidate['content']['parts']:
                            text = part.get('text', '')
                            if text:
                                yield (text, '', None)
                    finish_reason = candidate.get('finishReason', '')
                    if finish_reason:
                        if finish_reason == 'STOP':
                            yield ('', 'stop', None)
                        else:
                            yield ('', finish_reason, None)
        except json.JSONDecodeError as e:
            raise Exception(f"Failed to parse Gemini response: {str(e)}")


class OllamaProvider(BaseProvider):
    """Ollama local provider using HTTP requests"""

    def validate_config(self):
        """Validate Ollama configuration"""
        if not self.config.get('base_url'):
            self.config['base_url'] = 'http://localhost:11434'

    def get_model(self):
        """Get the model name from config"""
        return self.config.get('model', 'llama3.2')

    def create_messages(self, system_message, history, user_message):
        """Create messages in Ollama format (OpenAI-compatible)"""
        messages = [{"role": "system", "content": system_message}]
        messages.extend(history)
        messages.append({"role": "user", "content": user_message})
        return messages

    def stream_chat(self, messages, model, temperature, max_tokens, tools=None):
        """Stream chat completion from Ollama"""
        url = f"{self.config['base_url']}/api/chat"

        payload = {
            'model': model,
            'messages': messages,
            'stream': True,
            'options': {
                'temperature': temperature,
                'num_predict': max_tokens
            }
        }

        response = requests.post(url, json=payload, stream=True)

        # Check for HTTP errors
        if response.status_code != 200:
            error_body = response.text
            raise Exception(f"Ollama API error (status {response.status_code}): {error_body}")

        for line in response.iter_lines():
            if not line:
                continue

            try:
                chunk = json.loads(line)
                content = chunk.get('message', {}).get('content', '')
                done = chunk.get('done', False)

                if content:
                    yield (content, '', None)
                if done:
                    yield ('', 'stop', None)
            except json.JSONDecodeError:
                continue


class OpenRouterProvider(BaseProvider):
    """OpenRouter provider using OpenAI-compatible HTTP API"""

    def validate_config(self):
        """Validate OpenRouter configuration"""
        if not self.config.get('api_key'):
            raise ValueError("OpenRouter API key required. Set OPENROUTER_API_KEY or g:openrouter_api_key")
        if not self.config.get('base_url'):
            self.config['base_url'] = 'https://openrouter.ai/api/v1'

    def get_model(self):
        """Get the model name from config"""
        return self.config.get('model', 'anthropic/claude-3.5-sonnet')

    def create_messages(self, system_message, history, user_message):
        """Create messages in OpenAI format (OpenRouter compatible)"""
        messages = [{"role": "system", "content": system_message}]
        messages.extend(history)
        messages.append({"role": "user", "content": user_message})
        return messages

    def stream_chat(self, messages, model, temperature, max_tokens, tools=None):
        """Stream chat completion from OpenRouter"""
        url = f"{self.config['base_url']}/chat/completions"

        headers = {
            'Authorization': f'Bearer {self.config["api_key"]}',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://github.com/CoderCookE/vim-gpt',
        }

        payload = {
            'model': model,
            'messages': messages,
            'temperature': temperature,
            'max_tokens': max_tokens,
            'stream': True
        }

        response = requests.post(url, headers=headers, json=payload, stream=True)

        # Check for HTTP errors
        if response.status_code != 200:
            error_body = response.text
            raise Exception(f"OpenRouter API error (status {response.status_code}): {error_body}")

        # Parse Server-Sent Events stream (OpenAI-compatible)
        for line in response.iter_lines():
            if not line:
                continue

            line = line.decode('utf-8')
            if not line.startswith('data: '):
                continue

            data = line[6:]  # Remove 'data: ' prefix
            if data == '[DONE]':
                break

            try:
                chunk = json.loads(data)
                if 'choices' in chunk and chunk['choices']:
                    choice = chunk['choices'][0]
                    content = choice.get('delta', {}).get('content', '')
                    finish_reason = choice.get('finish_reason', '')

                    if content:
                        yield (content, '', None)
                    if finish_reason:
                        yield ('', finish_reason, None)
            except json.JSONDecodeError:
                continue


def create_provider(provider_name):
    """Factory function to create the appropriate provider"""

    if provider_name == 'anthropic':
        config = {
            'api_key': os.getenv('ANTHROPIC_API_KEY') or safe_vim_eval('g:anthropic_api_key'),
            'model': safe_vim_eval('g:anthropic_model'),
            'base_url': os.getenv('ANTHROPIC_BASE_URL') or safe_vim_eval('g:anthropic_base_url')
        }
        return AnthropicProvider(config)

    elif provider_name == 'gemini':
        config = {
            'api_key': os.getenv('GEMINI_API_KEY') or safe_vim_eval('g:gemini_api_key'),
            'model': safe_vim_eval('g:gemini_model')
        }
        return GoogleProvider(config)

    elif provider_name == 'ollama':
        config = {
            'base_url': os.getenv('OLLAMA_HOST') or safe_vim_eval('g:ollama_base_url'),
            'model': safe_vim_eval('g:ollama_model')
        }
        return OllamaProvider(config)

    elif provider_name == 'openrouter':
        config = {
            'api_key': os.getenv('OPENROUTER_API_KEY') or safe_vim_eval('g:openrouter_api_key'),
            'base_url': safe_vim_eval('g:openrouter_base_url'),
            'model': safe_vim_eval('g:openrouter_model')
        }
        return OpenRouterProvider(config)

    else:  # Default to openai
        config = {
            'api_type': safe_vim_eval('g:api_type'),
            'api_key': os.getenv('OPENAI_API_KEY') or safe_vim_eval('g:chat_gpt_key') or safe_vim_eval('g:openai_api_key'),
            'base_url': os.getenv('OPENAI_PROXY') or os.getenv('OPENAI_API_BASE') or safe_vim_eval('g:openai_base_url'),
            'model': safe_vim_eval('g:chat_gpt_model'),
            # Azure-specific config
            'azure_endpoint': safe_vim_eval('g:azure_endpoint'),
            'azure_deployment': safe_vim_eval('g:azure_deployment'),
            'azure_api_version': safe_vim_eval('g:azure_api_version')
        }
        return OpenAIProvider(config)


def chat_gpt(prompt):
  token_limits = {
    "gpt-3.5-turbo": 4097,
    "gpt-3.5-turbo-16k": 16385,
    "gpt-3.5-turbo-1106": 16385,
    "gpt-4": 8192,
    "gpt-4-turbo": 128000,
    "gpt-4-turbo-preview": 128000,
    "gpt-4-32k": 32768,
    "gpt-4o": 128000,
    "gpt-4o-mini": 128000,
    "o1": 200000,
    "o3": 200000,
    "o3-mini": 200000,
    "o4-mini": 200000,
  }

  # Get provider
  provider_name = safe_vim_eval('g:chat_gpt_provider') or 'openai'

  try:
    provider = create_provider(provider_name)
  except Exception as e:
    print(f"Error creating provider '{provider_name}': {str(e)}")
    return

  # Get parameters
  max_tokens = int(vim.eval('g:chat_gpt_max_tokens'))
  temperature = float(vim.eval('g:chat_gpt_temperature'))
  lang = str(vim.eval('g:chat_gpt_lang'))
  resp = f" And respond in {lang}." if lang != 'None' else ""
  suppress_display = int(vim.eval('exists("g:chat_gpt_suppress_display") ? g:chat_gpt_suppress_display : 0'))

  # Get model from provider
  model = provider.get_model()

  # Build system message
  personas = dict(vim.eval('g:gpt_personas'))
  persona = str(vim.eval('g:chat_persona'))
  system_message = f"{personas[persona]} {resp}"

  # Load project context if available
  context_file = os.path.join(os.getcwd(), '.vim-chatgpt', 'context.md')
  if os.path.exists(context_file):
    try:
      with open(context_file, 'r', encoding='utf-8') as f:
        project_context = f.read().strip()
        if project_context:
          system_message += f"\n\n## Project Context\n\n{project_context}"
    except Exception as e:
      # Silently ignore errors reading context file
      pass

  # Load conversation summary if available and extract cutoff position
  summary_file = os.path.join(os.getcwd(), '.vim-chatgpt', 'summary.md')
  summary_cutoff_byte = 0
  if os.path.exists(summary_file):
    try:
      with open(summary_file, 'r', encoding='utf-8') as f:
        conversation_summary = f.read().strip()

        # Extract cutoff_byte from metadata if present
        import re
        cutoff_match = re.search(r'cutoff_byte:\s*(\d+)', conversation_summary)
        if cutoff_match:
          summary_cutoff_byte = int(cutoff_match.group(1))

        if conversation_summary:
          system_message += f"\n\n## Conversation Summary & User Preferences\n\n{conversation_summary}"
    except Exception as e:
      # Silently ignore errors reading summary file
      pass

  # Add planning instruction if tools are enabled and plan approval required
  enable_tools = int(vim.eval('exists("g:chat_gpt_enable_tools") ? g:chat_gpt_enable_tools : 1'))
  require_plan_approval = int(vim.eval('exists("g:chat_gpt_require_plan_approval") ? g:chat_gpt_require_plan_approval : 1'))

  if enable_tools and require_plan_approval and provider.supports_tools():
    system_message += "\n\nWhen you need to use tools, first create a clear, step-by-step plan explaining what you will do and which tools you'll use. Present this plan to the user for approval before proceeding with tool execution.\n\nAfter each tool execution, evaluate the results:\n- If the result is unexpected or requires a different approach, explain why and present a REVISED PLAN for approval\n- If the result is as expected, continue with the next step\n- If the task is complete, summarize what was accomplished\n\nStart any revised plan with '=== REVISED PLAN ===' so it can be clearly identified."

  # Session history management
  history = []
  session_enabled = int(vim.eval('exists("g:chat_gpt_session_mode") ? g:chat_gpt_session_mode : 1')) == 1

  # Create .vim-chatgpt directory if it doesn't exist
  vim_chatgpt_dir = os.path.join(os.getcwd(), '.vim-chatgpt')
  if session_enabled and not os.path.exists(vim_chatgpt_dir):
    try:
      os.makedirs(vim_chatgpt_dir)
    except:
      pass

  # Use file-based history
  history_file = os.path.join(vim_chatgpt_dir, 'history.txt') if session_enabled else None
  session_id = 'gpt-persistent-session' if session_enabled else None

  # Load history from file
  if history_file and os.path.exists(history_file):
    try:
      # Read only from cutoff position onwards (recent uncompressed history)
      with open(history_file, 'r', encoding='utf-8') as f:
        if summary_cutoff_byte > 0:
          f.seek(summary_cutoff_byte)
        history_content = f.read()

      # Parse history (same format as before)
      history_text = history_content.split('\n\n>>>')
      history_text.reverse()

      # Adding messages to history until token limit is reached
      token_count = token_limits.get(model, 100000) - max_tokens - len(prompt) - len(system_message)

      for line in history_text:
        if ':\n' in line:
          role, message = line.split(":\n", 1)

          token_count -= len(message)

          if token_count > 0:
            history.insert(0, {
                "role": role.lower(),
                "content": message
            })
    except Exception as e:
      # Silently ignore errors reading history
      pass

  # Display initial prompt in session
  if session_id and not suppress_display:
    content = '\n\n>>>User:\n' + prompt + '\n\n>>>Assistant:\n'

    vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(content.replace("'", "''"), session_id))
    vim.command("redraw")

  # Create messages using provider
  try:
    messages = provider.create_messages(system_message, history, prompt)
  except Exception as e:
    print(f"Error creating messages: {str(e)}")
    return

  # Get tools if enabled and provider supports them
  tools = None
  enable_tools = int(vim.eval('exists("g:chat_gpt_enable_tools") ? g:chat_gpt_enable_tools : 1'))
  if enable_tools and provider.supports_tools():
    tools = get_tool_definitions()

  # Stream response using provider (with tool calling loop)
  try:
    chunk_session_id = session_id if session_id else 'gpt-response'
    max_tool_iterations = 15  # Maximum total iterations
    tool_iteration = 0
    plan_approved = not require_plan_approval  # Skip approval if not required
    accumulated_content = ""  # Accumulate content for each iteration

    while tool_iteration < max_tool_iterations:
      tool_calls_to_process = None
      accumulated_content = ""  # Reset for each iteration

      for content, finish_reason, tool_calls in provider.stream_chat(messages, model, temperature, max_tokens, tools):
        # Display content as it streams
        if content:
          # Accumulate content to detect plan revisions
          accumulated_content += content

          if not suppress_display:
            vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(content.replace("'", "''"), chunk_session_id))
            vim.command("redraw")

        # Handle finish
        if finish_reason:
          if tool_calls:
            tool_calls_to_process = tool_calls
          else:
            if not suppress_display:
              vim.command("call DisplayChatGPTResponse('', '{0}', '{1}')".format(finish_reason.replace("'", "''"), chunk_session_id))
              vim.command("redraw")

      # If no tool calls, we're done
      if not tool_calls_to_process:
        break

      # Detect revised plan or initial plan
      is_initial_plan = (tool_iteration == 0 and not plan_approved)
      is_revised_plan = ("=== REVISED PLAN ===" in accumulated_content or "REVISED PLAN" in accumulated_content)
      needs_approval = require_plan_approval and (is_initial_plan or is_revised_plan)

      # Request approval for initial or revised plans
      if needs_approval:
        # Show a separator and the plan
        plan_type = "REVISED PLAN" if is_revised_plan else "INITIAL PLAN"
        plan_display = "\\n\\n" + "="*60 + "\\n"
        plan_display += f"{plan_type} FOR APPROVAL:\\n"
        plan_display += "="*60 + "\\n"

        if accumulated_content.strip():
          # Show the plan that was just presented
          plan_display += accumulated_content.strip()
        else:
          # If no plan was provided, list the tools that will be called
          plan_display += "AI wants to use the following tools:\\n"
          for i, tc in enumerate(tool_calls_to_process, 1):
            plan_display += f"{i}. {tc['name']}\\n"

        plan_display += "\\n" + "="*60 + "\\n\\n"

        if not suppress_display:
          vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(plan_display.replace("'", "''"), chunk_session_id))
          vim.command("redraw")

        approval_prompt = "Approve revised plan? [y]es to proceed, [n]o to cancel: " if is_revised_plan else "Approve plan? [y]es to proceed, [n]o to cancel: "
        approval = vim.eval(f"input('{approval_prompt}')")

        if approval.lower() not in ['y', 'yes']:
          if not suppress_display:
            vim.command("call DisplayChatGPTResponse('\\n\\n[Plan cancelled by user]\\n', '', '{0}')".format(chunk_session_id))
            vim.command("redraw")
          break

        plan_approved = True
        if not suppress_display:
          approval_msg = "[Revised plan approved. Continuing...]" if is_revised_plan else "[Plan approved. Executing...]"
          vim.command("call DisplayChatGPTResponse('\\n\\n{0}\\n', '', '{1}')".format(approval_msg, chunk_session_id))
          vim.command("redraw")

      # Execute tools and add results to messages
      tool_iteration += 1
      if not suppress_display:
        vim.command("call DisplayChatGPTResponse('\\n\\n[Using tools... (iteration {0})]\\n', '', '{1}')".format(tool_iteration, chunk_session_id))
        vim.command("redraw")

      # For Anthropic, we need to add the assistant message with ALL tool_use blocks first
      if provider_name == 'anthropic' and isinstance(messages, dict) and 'messages' in messages:
        # Build assistant message with text + all tool_use blocks
        assistant_content = []
        if accumulated_content.strip():
          assistant_content.append({"type": "text", "text": accumulated_content})

        for tool_call in tool_calls_to_process:
          assistant_content.append({
            "type": "tool_use",
            "id": tool_call['id'],
            "name": tool_call['name'],
            "input": tool_call['arguments']
          })

        messages['messages'].append({
          "role": "assistant",
          "content": assistant_content
        })

      # Now execute tools and collect results
      tool_results = []
      for tool_call in tool_calls_to_process:
        tool_name = tool_call['name']
        tool_args = tool_call['arguments']
        tool_id = tool_call.get('id', 'unknown')

        # Execute the tool
        tool_result = execute_tool(tool_name, tool_args)
        tool_results.append((tool_id, tool_name, tool_args, tool_result))

        # Display tool usage in session
        if not suppress_display:
          tool_display = f"\\n[Tool: {tool_name}({json.dumps(tool_args)})]\\n{tool_result}\\n"
          vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(tool_display.replace("'", "''"), chunk_session_id))
          vim.command("redraw")

      # Add tool results to messages - format depends on provider
      if provider_name == 'openai':
        # OpenAI format - add each tool call and result individually
        if isinstance(messages, list):
          for tool_id, tool_name, tool_args, tool_result in tool_results:
            # Add assistant message with tool call
            messages.append({
              "role": "assistant",
              "content": None,
              "tool_calls": [{
                "id": tool_id,
                "type": "function",
                "function": {
                  "name": tool_name,
                  "arguments": json.dumps(tool_args)
                }
              }]
            })
            # Add tool response
            messages.append({
              "role": "tool",
              "tool_call_id": tool_id,
              "content": tool_result
            })
      elif provider_name == 'anthropic':
        # Anthropic format - add ONE user message with ALL tool_result blocks
        if isinstance(messages, dict) and 'messages' in messages:
          tool_result_content = []
          for tool_id, tool_name, tool_args, tool_result in tool_results:
            tool_result_content.append({
              "type": "tool_result",
              "tool_use_id": tool_id,
              "content": tool_result
            })

          messages['messages'].append({
            "role": "user",
            "content": tool_result_content
          })

  except Exception as e:
    print(f"Error streaming from {provider_name}: {str(e)}")

chat_gpt(vim.eval('a:prompt'))
EOF
endfunction

" Function to send highlighted code to ChatGPT
function! SendHighlightedCodeToChatGPT(ask, context) abort
    let save_cursor = getcurpos()
    let [current_line, current_col] = getcurpos()[1:2]

    " Save the current yank register and its type
    let save_reg = @@
    let save_regtype = getregtype('@')

    let [line_start, col_start] = getpos("'<")[1:2]
    let [line_end, col_end] = getpos("'>")[1:2]

    " Check if a selection is made and if current position is within the selection
    if (col_end - col_start > 0 || line_end - line_start > 0) &&
       \ (current_line == line_start && current_col == col_start ||
       \  current_line == line_end && current_col == col_end)

        let current_line_start = line_start
        let current_line_end = line_end

        if current_line_start == line_start && current_line_end == line_end
            execute 'normal! ' . line_start . 'G' . col_start . '|v' . line_end . 'G' . col_end . '|y'
            let yanked_text = '```' . &syntax . "\n" . @@ . "\n" . '```'
        else
            let yanked_text = ''
        endif
    else
        let yanked_text = ''
    endif

    let prompt = a:context . ' ' . "\n"

    " Include yanked_text in the prompt if it's not empty
    if !empty(yanked_text)
        let prompt .= yanked_text . "\n"
    endif

    echo a:ask
    if has_key(g:prompt_templates, a:ask)
        let prompt = g:prompt_templates[a:ask] . "\n" . prompt
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

" Function to generate project context
function! GenerateProjectContext()
  " Create a prompt to generate project context
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
  let prompt .= "\n\nSave this context to .vim-chatgpt/context.md so I understand this project in future conversations."
  let prompt .= "\n\nImportant: Actually use the create_file tool to save the context to .vim-chatgpt/context.md"

  " Use session mode 0 for one-time response, disable plan approval and suppress display
  let save_session_mode = exists('g:chat_gpt_session_mode') ? g:chat_gpt_session_mode : 1
  let save_plan_approval = exists('g:chat_gpt_require_plan_approval') ? g:chat_gpt_require_plan_approval : 1
  let save_suppress_display = exists('g:chat_gpt_suppress_display') ? g:chat_gpt_suppress_display : 0
  let g:chat_gpt_session_mode = 0
  let g:chat_gpt_require_plan_approval = 0
  let g:chat_gpt_suppress_display = 1

  echo "Generating project context... (this will use AI tools to explore your project)"
  call ChatGPT(prompt)

  " Restore settings
  let g:chat_gpt_session_mode = save_session_mode
  let g:chat_gpt_require_plan_approval = save_plan_approval
  let g:chat_gpt_suppress_display = save_suppress_display

  echo "\nProject context generated at .vim-chatgpt/context.md"
  echo "You can edit this file to customize the project context."
endfunction

" Function to generate conversation summary
function! GenerateConversationSummary()
  " Calculate byte positions for compaction
  let history_file = getcwd() . '/.vim-chatgpt/history.txt'
  let summary_file = getcwd() . '/.vim-chatgpt/summary.md'

  let old_cutoff = s:get_summary_cutoff()
  let history_size = getfsize(history_file)
  let recent_window = g:chat_gpt_recent_history_size
  let new_cutoff = max([0, history_size - recent_window])

  " Create a prompt to analyze conversation history and generate summary
  let prompt = 'Please analyze our conversation history and create a comprehensive summary.'
  let prompt .= "\n\nIMPORTANT: Use the read_file tool to read .vim-chatgpt/history.txt"

  if old_cutoff > 0
    let prompt .= "\n\nThis is a summary UPDATE (compaction). The current summary covers conversation up to byte " . old_cutoff . "."
    let prompt .= "\nYou need to read and summarize the portion from byte " . old_cutoff . " to byte " . new_cutoff . "."
    let prompt .= "\nFirst use read_file to read the EXISTING summary from .vim-chatgpt/summary.md, then read the NEW content from .vim-chatgpt/history.txt."
    let prompt .= "\nMerge the existing summary with insights from the new content."
  else
    let prompt .= "\n\nThis is the FIRST summary. Read .vim-chatgpt/history.txt and summarize everything up to byte " . new_cutoff . "."
  endif

  let prompt .= "\n\nCreate a summary in this format:"
  let prompt .= "\n\n<!-- SUMMARY_METADATA"
  let prompt .= "\ncutoff_byte: " . new_cutoff
  let prompt .= "\nlast_updated: " . strftime("%Y-%m-%d")
  let prompt .= "\n-->"
  let prompt .= "\n\n# Conversation Summary"
  let prompt .= "\n\n## Key Topics Discussed"
  let prompt .= "\n[Bullet points of main topics and decisions made]"
  let prompt .= "\n\n## Important Information to Remember"
  let prompt .= "\n[Critical details, decisions, or context that should be retained]"
  let prompt .= "\n\n## User Preferences"
  let prompt .= "\n[Any preferences inferred from the conversation, such as:]"
  let prompt .= "\n- Coding style preferences"
  let prompt .= "\n- Tool or technology preferences"
  let prompt .= "\n- Communication preferences"
  let prompt .= "\n- Project-specific conventions"
  let prompt .= "\n\n## Action Items"
  let prompt .= "\n[Any pending tasks or future work mentioned]"
  let prompt .= "\n\nSave this summary to .vim-chatgpt/summary.md (with the metadata header included)."
  let prompt .= "\n\nImportant: Use create_file tool with overwrite=true to save to .vim-chatgpt/summary.md. INCLUDE THE METADATA COMMENT AT THE TOP."

  " Use session mode 0 for one-time response, disable plan approval and suppress display
  let save_session_mode = exists('g:chat_gpt_session_mode') ? g:chat_gpt_session_mode : 1
  let save_plan_approval = exists('g:chat_gpt_require_plan_approval') ? g:chat_gpt_require_plan_approval : 1
  let save_suppress_display = exists('g:chat_gpt_suppress_display') ? g:chat_gpt_suppress_display : 0
  let g:chat_gpt_session_mode = 0
  let g:chat_gpt_require_plan_approval = 0
  let g:chat_gpt_suppress_display = 1

  echo "Generating conversation summary... (this will analyze conversation history)"
  call ChatGPT(prompt)

  " Restore settings
  let g:chat_gpt_session_mode = save_session_mode
  let g:chat_gpt_require_plan_approval = save_plan_approval
  let g:chat_gpt_suppress_display = save_suppress_display

  echo "\nConversation summary generated at .vim-chatgpt/summary.md"
  echo "You can edit this file to add or modify preferences."
endfunction

" Menu for ChatGPT
function! s:ChatGPTMenuSink(id, choice)
  call popup_hide(a:id)
  let choices = {}

  for index in range(len(g:promptKeys))
    let choices[index+1] = g:promptKeys[index]
  endfor

  if a:choice > 0 && a:choice <= len(g:promptKeys)
    call SendHighlightedCodeToChatGPT(choices[a:choice], input('Prompt > '))
  endif
endfunction

function! s:ChatGPTMenuFilter(id, key)

  if a:key > 0 && a:key <= len(g:promptKeys)
    call s:ChatGPTMenuSink(a:id, a:key)
  else " No shortcut, pass to generic filter
    return popup_filter_menu(a:id, a:key)
  endif
endfunction

function! ChatGPTMenu() range
  echo a:firstline. a:lastline
  let menu_choices = []

  for index in range(len(g:promptKeys))
    call add(menu_choices, string(index + 1) . ". " . g:promptKeys[index])
  endfor

  call popup_menu(menu_choices, #{
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

vnoremap <silent> <Plug>(chatgpt-menu) :call ChatGPTMenu()<CR>

function! Capitalize(str)
    return toupper(strpart(a:str, 0, 1)) . tolower(strpart(a:str, 1))
endfunction

for i in range(len(g:promptKeys))
  execute 'command! -range -nargs=? ' . Capitalize(g:promptKeys[i]) . " call SendHighlightedCodeToChatGPT('" . g:promptKeys[i] . "',<q-args>)"
endfor

command! GenerateCommit call GenerateCommitMessage()
command! GptGenerateContext call GenerateProjectContext()
command! GptGenerateSummary call GenerateConversationSummary()

function! SetPersona(persona)
    let personas = keys(g:gpt_personas)
    if index(personas, a:persona) != -1
      echo 'Persona set to: ' . a:persona
      let g:chat_persona = a:persona
    else
      let g:chat_persona = 'default'
      echo 'Persona set to default, not found ' . a:persona
    end
endfunction


command! -nargs=1 GptBe call SetPersona(<q-args>)

" Call the check functions during plugin initialization (after all variables and functions are defined)
call s:check_and_generate_context()
call s:check_and_update_summary()
