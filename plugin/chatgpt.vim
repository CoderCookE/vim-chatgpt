" ChatGPT Vim Plugin
"
" Ensure Python3 is available
if !has('python3')
  echo "Python 3 support is required for ChatGPT plugin"
  finish
endif

" Function to check if context file exists and auto-generate if not or if old
function! s:check_and_generate_context()
    " Skip if Vim was opened with a specific file (not a directory)
    if argc() > 0
        let first_arg = argv(0)
        " If the argument is a file (not a directory), skip context generation
        if filereadable(first_arg) && !isdirectory(first_arg)
            return
        endif
    endif

    " Always use current working directory as project root
    " (assuming user opened vim from the project root)
    let project_dir = getcwd()

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
function! s:get_summary_cutoff(project_dir)
    let summary_file = a:project_dir . '/.vim-chatgpt/summary.md'

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
    " Always use current working directory as project root
    " (assuming user opened vim from the project root)
    let project_dir = getcwd()

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
    let cutoff_byte = s:get_summary_cutoff(project_dir)
    let compaction_size = g:chat_gpt_summary_compaction_size
    let new_content_size = file_size - cutoff_byte

    " Check if we should update:
    " 1. New content since last summary exceeds compaction size
    " 2. OR summary doesn't exist yet and history has content
    if new_content_size > compaction_size
        echo "Conversation grew by " . float2nr(new_content_size / 1024) . "KB. Compacting into summary..."
        echo "Reading summary from: " . summary_file . " (cutoff_byte: " . cutoff_byte . ")"

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
  let g:chat_gpt_split_direction = 'vertical'
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
  let g:chat_gpt_summary_compaction_size = 76800  " 76KB - trigger summary update
endif

if !exists("g:chat_gpt_recent_history_size")
  let g:chat_gpt_recent_history_size = 30480  " 30KB - keep this much recent history uncompressed
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

" Debug logging level (0=off, 1=basic, 2=verbose)
if !exists("g:chat_gpt_log_level")
  let g:chat_gpt_log_level = 0
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

  " Switch to chat window and scroll to bottom
  let chat_winnr = bufwinnr(chat_gpt_session_id)
  if chat_winnr != -1
    let current_win = winnr()
    execute chat_winnr . 'wincmd w'

    " Move the viewport to the bottom of the buffer
    normal! G
    call cursor('$', 1)

    " Force the window to update the scroll position
    execute "normal! \<C-E>\<C-Y>"

    redraw
    " Stay in chat window to preserve scroll position
    " (Don't return to original window here - let caller handle it)
  endif

  " Save to history file if this is a persistent session
  if chat_gpt_session_id ==# 'gpt-persistent-session' && response != ''
    python3 << EOF
import vim
response = vim.eval('a:response')
save_to_history(response)
EOF
  endif

endfunction

" Function to interact with ChatGPT
function! ChatGPT(prompt) abort
  " Ensure suppress_display is off for normal chat operations
  " (It gets set to 1 only during automatic context/summary generation)
  if !exists('g:chat_gpt_suppress_display')
    let g:chat_gpt_suppress_display = 0
  endif

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

# Log level constants
LOG_LEVEL_DEBUG = 0
LOG_LEVEL_INFO = 1
LOG_LEVEL_WARNING = 2
LOG_LEVEL_ERROR = 3

# Map string prefixes to log levels
LOG_LEVEL_MAP = {
    'DEBUG:': LOG_LEVEL_DEBUG,
    'INFO:': LOG_LEVEL_INFO,
    'WARNING:': LOG_LEVEL_WARNING,
    'ERROR:': LOG_LEVEL_ERROR,
}

def debug_log(msg):
    """
    Write debug messages to a log file for troubleshooting.
    
    Messages can be prefixed with a log level:
    - DEBUG: Detailed debugging information (level 0)
    - INFO: General informational messages (level 1)
    - WARNING: Warning messages (level 2)
    - ERROR: Error messages (level 3)
    
    If no prefix is provided, the message is treated as DEBUG level.
    
    The g:chat_gpt_log_level setting controls which messages are logged:
    - 0: Disabled (no logging)
    - 1: DEBUG and above (all messages)
    - 2: INFO and above
    - 3: WARNING and above
    - 4: ERROR only
    """
    try:
        import vim
        configured_level = int(vim.eval('exists("g:chat_gpt_log_level") ? g:chat_gpt_log_level : 0'))
        
        # If logging is disabled (0), don't log anything
        if configured_level == 0:
            return
        
        # Parse log level from message
        message_level = LOG_LEVEL_DEBUG  # Default to DEBUG
        clean_msg = msg
        
        for prefix, level in LOG_LEVEL_MAP.items():
            if msg.startswith(prefix):
                message_level = level
                clean_msg = msg[len(prefix):].strip()
                break
        
        # Filter: only log if message level >= (configured_level - 1)
        # configured_level 1 = DEBUG (0) and above
        # configured_level 2 = INFO (1) and above
        # configured_level 3 = WARNING (2) and above
        # configured_level 4 = ERROR (3) only
        if message_level < (configured_level - 1):
            return
        
        log_file = '/tmp/vim-chatgpt-debug.log'
        
        from datetime import datetime
        timestamp = datetime.now().strftime('%H:%M:%S.%f')[:-3]
        level_name = [k for k, v in LOG_LEVEL_MAP.items() if v == message_level]
        level_str = level_name[0].rstrip(':') if level_name else 'DEBUG'
        
        with open(log_file, 'a') as f:
            f.write(f'[{timestamp}] [{level_str}] {clean_msg}\n')
    except Exception as e:
        # Silently fail - don't interrupt the plugin
        pass


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


# Formatting helpers for better chat display
def format_box(title, content="", width=60):
    """Create a formatted box with title and optional content"""
    top = "╔" + "═" * (width - 2) + "╗"
    bottom = "╚" + "═" * (width - 2) + "╝"
    
    lines = [top]
    
    # Add title
    if title:
        title_padded = f" {title} ".center(width - 2, " ")
        lines.append(f"║{title_padded}║")
        if content:
            lines.append("║" + " " * (width - 2) + "║")
    
    # Add content
    if content:
        for line in content.split('\n'):
            # Wrap long lines
            while len(line) > width - 6:
                lines.append(f"║  {line[:width-6]}  ║")
                line = line[width-6:]
            if line:
                line_padded = f"  {line}".ljust(width - 2)
                lines.append(f"║{line_padded}║")
    
    lines.append(bottom)
    return "\n".join(lines)


def format_separator(char="─", width=60):
    """Create a horizontal separator"""
    return char * width


def format_tool_call(tool_name, tool_args, status="executing"):
    """Format a tool call with status indicator"""
    if status == "executing":
        icon = "🔧"
        status_text = "Executing"
    elif status == "success":
        icon = "✓"
        status_text = "Success"
    elif status == "error":
        icon = "✗"
        status_text = "Error"
    else:
        icon = "→"
        status_text = status
    
    # Format arguments nicely
    args_str = ", ".join(f"{k}={repr(v)[:40]}" for k, v in tool_args.items())
    if len(args_str) > 60:
        args_str = args_str[:57] + "..."
    
    return f"{icon} {status_text}: {tool_name}({args_str})"


def format_tool_result(tool_name, tool_args, result, max_lines=20):
    """Format tool execution result with header"""
    header = format_separator("─", 60)
    tool_call_str = format_tool_call(tool_name, tool_args, "success")
    
    # Truncate long results
    result_lines = result.split('\n')
    if len(result_lines) > max_lines:
        result_lines = result_lines[:max_lines]
        result_lines.append(f"... (truncated, {len(result.split(chr(10))) - max_lines} more lines)")
    
    result_formatted = '\n'.join(f"  {line}" for line in result_lines)
    
    return f"\n{header}\n{tool_call_str}\n\nOutput:\n{result_formatted}\n{header}\n"


def format_plan_display(plan_type, explanation, tool_calls):
    """Format plan approval display with nice boxes"""
    title = f"{plan_type} FOR APPROVAL"
    
    # Build content
    content_parts = []
    
    if explanation and explanation.strip():
        content_parts.append("Explanation:")
        content_parts.append(explanation.strip())
        content_parts.append("")
    
    content_parts.append("Tools to execute:")
    for i, tc in enumerate(tool_calls, 1):
        args_str = ", ".join(f"{k}={repr(v)[:30]}" for k, v in tc['arguments'].items())
        content_parts.append(f"  {i}. {tc['name']}({args_str})")
    
    content = "\n".join(content_parts)
    
    return "\n\n" + format_box(title, content, width=70) + "\n"


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
            "description": "Open a file in Vim to show it to the user. The file will be displayed in the editor for the user to view. Use this when you need the user to see the file contents in their editor.",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Path to the file to open in Vim (absolute or relative to current directory)"
                    },
                    "split": {
                        "type": "string",
                        "description": "How to open the file: 'vertical' (default), 'horizontal', or 'current'",
                        "enum": ["current", "horizontal", "vertical"],
                        "default": "vertical"
                    },
                    "line_number": {
                        "type": "integer",
                        "description": "Optional: Line number to jump to after opening the file (1-indexed)"
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
        },
        {
            "name": "git_status",
            "description": "Get the current git repository status. Shows working tree status including staged, unstaged, and untracked files. Also includes recent commit history for context.",
            "parameters": {
                "type": "object",
                "properties": {},
                "required": []
            }
        },
        {
            "name": "git_diff",
            "description": "Show changes in the working directory or staging area. Use this to see what has been modified.",
            "parameters": {
                "type": "object",
                "properties": {
                    "staged": {
                        "type": "boolean",
                        "description": "If true, show staged changes (git diff --cached). If false, show unstaged changes (git diff). Default: false",
                        "default": False
                    },
                    "file_path": {
                        "type": "string",
                        "description": "Optional: specific file path to diff. If not provided, shows all changes."
                    }
                },
                "required": []
            }
        },
        {
            "name": "git_log",
            "description": "Show commit history. Useful for understanding recent changes and commit patterns.",
            "parameters": {
                "type": "object",
                "properties": {
                    "max_count": {
                        "type": "integer",
                        "description": "Maximum number of commits to show (default: 10)",
                        "default": 10
                    },
                    "oneline": {
                        "type": "boolean",
                        "description": "If true, show compact one-line format. If false, show detailed format (default: true)",
                        "default": True
                    },
                    "file_path": {
                        "type": "string",
                        "description": "Optional: show history for specific file path"
                    }
                },
                "required": []
            }
        },
        {
            "name": "git_show",
            "description": "Show details of a specific commit including the full diff.",
            "parameters": {
                "type": "object",
                "properties": {
                    "commit": {
                        "type": "string",
                        "description": "Commit hash, branch name, or reference (e.g., 'HEAD', 'HEAD~1', 'abc123')"
                    }
                },
                "required": ["commit"]
            }
        },
        {
            "name": "git_branch",
            "description": "List branches or get current branch information.",
            "parameters": {
                "type": "object",
                "properties": {
                    "list_all": {
                        "type": "boolean",
                        "description": "If true, list all branches. If false, show only current branch (default: false)",
                        "default": False
                    }
                },
                "required": []
            }
        },
        {
            "name": "git_add",
            "description": "Stage files for commit. Use this to add files to the staging area.",
            "parameters": {
                "type": "object",
                "properties": {
                    "files": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "List of file paths to stage. Use ['.'] to stage all changes."
                    }
                },
                "required": ["files"]
            }
        },
        {
            "name": "git_reset",
            "description": "Unstage files from the staging area (does not modify working directory). Safe operation.",
            "parameters": {
                "type": "object",
                "properties": {
                    "files": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "List of file paths to unstage. If empty, unstages all files."
                    }
                },
                "required": []
            }
        },
        {
            "name": "git_commit",
            "description": "Create a new commit with staged changes. Only works if there are staged changes.",
            "parameters": {
                "type": "object",
                "properties": {
                    "message": {
                        "type": "string",
                        "description": "Commit message. Should be descriptive and follow conventional commit format if possible."
                    },
                    "amend": {
                        "type": "boolean",
                        "description": "If true, amend the previous commit instead of creating a new one (default: false)",
                        "default": False
                    }
                },
                "required": ["message"]
            }
        }
    ]

def execute_tool(tool_name, arguments):
    """Execute a tool with given arguments"""
    import subprocess
    import re

    def validate_file_path(file_path, operation="file operation"):
        """
        Validate file paths for security.
        Prevents path traversal attacks and requires explicit user permission for
        operations outside the project directory.

        Args:
            file_path: The file path to validate
            operation: Description of the operation (for error messages)

        Returns:
            tuple: (is_valid: bool, error_message: str or None)
        """
        try:
            # Get current working directory (project root)
            cwd = os.getcwd()

            # Resolve to absolute path
            abs_path = os.path.abspath(file_path)

            # Get the real path (resolves symlinks)
            try:
                real_path = os.path.realpath(abs_path)
            except (OSError, ValueError):
                # If realpath fails, use abspath
                real_path = abs_path

            # Blocked patterns - sensitive system paths (always deny, no prompt)
            blocked_patterns = [
                r'^/etc/',
                r'^/sys/',
                r'^/proc/',
                r'^/dev/',
                r'^/root/',
                r'^/boot/',
                r'^/bin/',
                r'^/sbin/',
                r'^/lib',
                r'^/usr/bin/',
                r'^/usr/sbin/',
                r'^/usr/lib',
                r'^C:\\Windows\\',
                r'^C:\\Program Files',
                r'^/System/',
                r'^/Library/System',
            ]

            for pattern in blocked_patterns:
                if re.match(pattern, real_path, re.IGNORECASE):
                    return (False, f"Security: {operation} denied. Cannot modify system path: {file_path}")

            # Check for suspicious path components (always deny)
            path_parts = os.path.normpath(file_path).split(os.sep)
            if '..' in path_parts:
                return (False, f"Security: {operation} denied. Path contains '..' traversal: {file_path}")

            # Check if path is within current working directory
            # Use os.path.commonpath to ensure it's truly a subdirectory
            is_within_project = False
            try:
                common = os.path.commonpath([cwd, real_path])
                is_within_project = (common == cwd)
            except ValueError:
                # Paths are on different drives (Windows) or one is relative
                is_within_project = False

            # If within project directory, allow without prompting
            if is_within_project:
                return (True, None)

            # Outside project directory - require user permission
            # Use Vim's confirm() function to prompt the user
            try:
                prompt_msg = f"AI wants to {operation}:\\n{file_path}\\n\\nThis is OUTSIDE the project directory ({cwd}).\\n\\nAllow this operation?"
                # Escape special characters for Vim string
                prompt_msg_escaped = prompt_msg.replace("'", "''")
                
                # Call Vim's confirm() function
                # Returns: 1=Yes, 2=No
                result = int(vim.eval(f"confirm('{prompt_msg_escaped}', '&Yes\\n&No', 2)"))
                
                if result == 1:
                    # User approved
                    debug_log(f"INFO: User approved {operation} outside project: {file_path}")
                    return (True, None)
                else:
                    # User denied
                    debug_log(f"WARNING: User denied {operation} outside project: {file_path}")
                    return (False, f"Security: {operation} denied by user. Path '{file_path}' is outside project directory.")
            except Exception as e:
                # If we can't prompt (e.g., in non-interactive mode), deny by default
                debug_log(f"ERROR: Failed to prompt user for permission: {str(e)}")
                return (False, f"Security: {operation} denied. Path '{file_path}' is outside project directory and user confirmation failed.")

        except Exception as e:
            return (False, f"Security: Error validating path: {str(e)}")

    debug_log(f"INFO: Executing tool: {tool_name}")
    debug_log(f"DEBUG: Tool arguments: {arguments}")

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
            use_regex = arguments.get("use_regex", False)

            # Build grep command - use extended regex by default, or fixed string if requested
            cmd = ["grep", "-n"]

            if not use_regex:
                # Use fixed string for safety (prevents regex errors)
                cmd.append("-F")
            else:
                # Use extended regex
                cmd.append("-E")

            if not case_sensitive:
                cmd.append("-i")

            cmd.extend([pattern, file_path])

            result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                return result.stdout.strip()
            elif result.returncode == 1:
                return f"No matches found for '{pattern}' in {file_path}"
            else:
                # Check if it's a regex error
                if "invalid" in result.stderr.lower() or "unmatched" in result.stderr.lower():
                    return f"Invalid regex pattern '{pattern}'. Error: {result.stderr.strip()}"
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
                    return '\n'.join(files) + f'\n... ({len(files)} results shown, more available)' + "\n"
                return '\n'.join(files) if files else f"No files found matching pattern: {pattern}" + "\n"
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
                    return '\n'.join(lines) + "\n"
            except FileNotFoundError:
                return f"File not found: {file_path}"
            except PermissionError:
                return f"Permission denied reading file: {file_path}"
            except Exception as e:
                return f"Error reading file: {str(e)}"

        elif tool_name == "create_file":
            file_path = arguments.get("file_path")
            content = arguments.get("content", "")
            
            # Validate file path for security
            # Validate file path for security
            is_valid, error_msg = validate_file_path(file_path, "create file")
            if not is_valid:
                return error_msg

            try:
                # Check if file exists
                if os.path.exists(file_path) and not overwrite:
                    return f"File already exists: {file_path}. Set overwrite=true to replace it."

                # Create directory if it doesn't exist
                directory = os.path.dirname(file_path)
                if directory and not os.path.exists(directory):
                    os.makedirs(directory)

                # Special handling for summary.md - prepend metadata automatically
                if file_path.endswith('.vim-chatgpt/summary.md') or file_path.endswith('summary.md'):
                    # Calculate metadata values
                    import re
                    from datetime import datetime

                    history_file = os.path.join(os.path.dirname(file_path), 'history.txt')
                    recent_window = int(safe_vim_eval('g:chat_gpt_recent_history_size') or 20480)

                    # Get old cutoff from existing summary
                    old_cutoff = 0
                    if os.path.exists(file_path):
                        with open(file_path, 'r', encoding='utf-8') as f:
                            summary_content = f.read()
                            match = re.search(r'cutoff_byte:\s*(\d+)', summary_content)
                            if match:
                                old_cutoff = int(match.group(1))

                    # Calculate new cutoff
                    if os.path.exists(history_file):
                        history_size = os.path.getsize(history_file)
                        new_cutoff = max(0, history_size - recent_window)
                    else:
                        new_cutoff = 0

                    # Generate metadata header
                    metadata = f"""<!-- SUMMARY_METADATA
cutoff_byte: {new_cutoff}
last_updated: {datetime.now().strftime('%Y-%m-%d')}
-->

"""
                    # Prepend metadata to content
                    content = metadata + content

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
            split = arguments.get("split", "vertical")
            line_number = arguments.get("line_number")

            try:
                # Check if file exists
                if not os.path.exists(file_path):
                    return f"File not found: {file_path}"

                # Get absolute path for comparison
                abs_file_path = os.path.abspath(file_path)

                # Check if file is already open in a buffer
                file_bufnr = vim.eval(f"bufnr('{abs_file_path}')")

                # Check if buffer exists and is visible in a window
                if file_bufnr != '-1':
                    # Buffer exists - check if it's visible in a window
                    winnr = vim.eval(f"bufwinnr({file_bufnr})")
                    if winnr != '-1':
                        # File is already visible - switch to that window
                        vim.command(f"{winnr}wincmd w")

                        # Jump to specific line if requested
                        if line_number is not None:
                            try:
                                if line_number < 1:
                                    return f"Switched to existing window with {file_path}\nWarning: Invalid line number {line_number}, must be >= 1"
                                vim.command(f"call cursor({line_number}, 1)")
                                vim.command("normal! zz")
                                vim.command("redraw")
                                return f"Switched to existing window with {file_path} at line {line_number}"
                            except vim.error as e:
                                return f"Switched to existing window with {file_path}\nWarning: Could not jump to line {line_number}: {str(e)}"

                        return f"Switched to existing window with {file_path}"

                # File is not currently visible - proceed with normal open logic
                # Check current buffer
                current_buffer = vim.eval("bufname('%')")
                current_file = vim.eval("expand('%:p')") if current_buffer else ""

                # Determine actual split behavior
                actual_split = split

                # If we're already in the target file, just jump to line (don't create new split)
                if current_file and os.path.abspath(current_file) == abs_file_path:
                    actual_split = "current"
                # If we're in the chat session buffer, always create a split
                elif current_buffer == "gpt-persistent-session":
                    # Keep the requested split type (default: vertical)
                    actual_split = split if split != "current" else "vertical"

                # Build Vim command to open the file
                if actual_split == "horizontal":
                    vim_cmd = f"split {file_path}"
                elif actual_split == "vertical":
                    vim_cmd = f"vsplit {file_path}"
                else:  # current
                    vim_cmd = f"edit {file_path}"

                # Execute the Vim command
                vim.command(vim_cmd)

                # Jump to specific line if requested
                if line_number is not None:
                    try:
                        # Validate line number
                        if line_number < 1:
                            return f"Opened file in Vim: {file_path} (split={split})\nWarning: Invalid line number {line_number}, must be >= 1"

                        # Jump to the line using cursor() for reliability
                        vim.command(f"call cursor({line_number}, 1)")
                        # Center the line in the viewport
                        vim.command("normal! zz")
                        # Force redraw to ensure viewport updates
                        vim.command("redraw")

                        return f"Opened file in Vim: {file_path} at line {line_number} (split={split})"
                    except vim.error as e:
                        return f"Opened file in Vim: {file_path} (split={split})\nWarning: Could not jump to line {line_number}: {str(e)}"

                return f"Opened file in Vim: {file_path} (split={split})"
            except vim.error as e:
                return f"Vim error opening file: {str(e)}"
            except Exception as e:
                return f"Error opening file: {str(e)}"

        elif tool_name == "edit_file":
            file_path = arguments.get("file_path")
            old_content = arguments.get("old_content")
            
            # Validate file path for security
            is_valid, error_msg = validate_file_path(file_path, "edit file")
            if not is_valid:
                return error_msg

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
            
            # Validate file path for security
            is_valid, error_msg = validate_file_path(file_path, "edit file")
            if not is_valid:
                return error_msg
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
                # Handle the case where content ends with \n (split creates empty string at end)
                new_lines = new_content.split('\n') if new_content else []
                # Remove trailing empty string if content ended with newline
                if new_lines and new_lines[-1] == '':
                    new_lines = new_lines[:-1]
                    content_had_trailing_newline = True
                else:
                    content_had_trailing_newline = False

                # Build formatted lines with proper newline handling
                new_lines_formatted = []
                for i, line in enumerate(new_lines):
                    is_last_line = (i == len(new_lines) - 1)

                    if is_last_line:
                        # For the last line, add newline based on context:
                        # 1. If we're replacing lines in the middle of the file, always add newline
                        # 2. If we're replacing the last line(s), match original file's newline behavior
                        # 3. If content had trailing newline, preserve it
                        if end_idx < total_lines - 1:
                            # Replacing lines in the middle - always add newline
                            new_lines_formatted.append(line + '\n')
                        elif content_had_trailing_newline or (end_idx == total_lines - 1 and lines[end_idx].endswith('\n')):
                            # At end of file, but either content or original had trailing newline
                            new_lines_formatted.append(line + '\n')
                        else:
                            # At end of file, no trailing newline
                            new_lines_formatted.append(line)
                    else:
                        # Not the last line - always add newline
                        new_lines_formatted.append(line + '\n')

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

        # Git-specific tools
        elif tool_name == "git_status":
            try:
                info_parts = []

                # Get git status
                result = subprocess.run(
                    ["git", "status"],
                    capture_output=True,
                    text=True,
                    timeout=10,
                    cwd=os.getcwd()
                )
                if result.returncode == 0:
                    info_parts.append("=== Git Status ===")
                    info_parts.append(result.stdout)
                else:
                    return f"Git error: {result.stderr}"

                # Also include recent commit log for context
                try:
                    log_result = subprocess.run(
                        ["git", "log", "-5", "--oneline"],
                        capture_output=True,
                        text=True,
                        timeout=10,
                        cwd=os.getcwd()
                    )
                    if log_result.returncode == 0:
                        info_parts.append("\n=== Recent Commits ===")
                        info_parts.append(log_result.stdout)
                except Exception:
                    pass  # Silently skip if log fails

                return "\n".join(info_parts)
            except Exception as e:
                return f"Error running git status: {str(e)}"

        elif tool_name == "git_diff":
            staged = arguments.get("staged", False)
            file_path = arguments.get("file_path")

            try:
                info_parts = []

                # Include git status for context
                try:
                    status_result = subprocess.run(
                        ["git", "status", "-s"],  # Short format
                        capture_output=True,
                        text=True,
                        timeout=10,
                        cwd=os.getcwd()
                    )
                    if status_result.returncode == 0:
                        info_parts.append("=== Git Status (short) ===")
                        info_parts.append(status_result.stdout if status_result.stdout.strip() else "No changes")
                except Exception:
                    pass  # Silently skip if status fails

                # Get the diff
                cmd = ["git", "diff"]
                if staged:
                    cmd.append("--cached")
                if file_path:
                    cmd.append(file_path)

                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=30,
                    cwd=os.getcwd()
                )

                if result.returncode == 0:
                    diff_type = "Staged Changes" if staged else "Unstaged Changes"
                    file_info = f" ({file_path})" if file_path else ""
                    info_parts.append(f"\n=== {diff_type}{file_info} ===")
                    if result.stdout.strip():
                        info_parts.append(result.stdout)
                    else:
                        info_parts.append("No changes found.")
                    return "\n".join(info_parts)
                else:
                    return f"Git error: {result.stderr}"
            except Exception as e:
                return f"Error running git diff: {str(e)}"

        elif tool_name == "git_log":
            max_count = arguments.get("max_count", 10)
            oneline = arguments.get("oneline", True)
            file_path = arguments.get("file_path")

            try:
                cmd = ["git", "log", f"-{max_count}"]
                if oneline:
                    cmd.append("--oneline")
                if file_path:
                    cmd.append(file_path)

                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=10,
                    cwd=os.getcwd()
                )

                if result.returncode == 0:
                    return result.stdout if result.stdout.strip() else "No commits found."
                else:
                    return f"Git error: {result.stderr}"
            except Exception as e:
                return f"Error running git log: {str(e)}"

        elif tool_name == "git_show":
            commit = arguments.get("commit")

            try:
                result = subprocess.run(
                    ["git", "show", commit],
                    capture_output=True,
                    text=True,
                    timeout=30,
                    cwd=os.getcwd()
                )

                if result.returncode == 0:
                    return result.stdout
                else:
                    return f"Git error: {result.stderr}"
            except Exception as e:
                return f"Error running git show: {str(e)}"

        elif tool_name == "git_branch":
            list_all = arguments.get("list_all", False)

            try:
                if list_all:
                    cmd = ["git", "branch", "-a"]
                else:
                    cmd = ["git", "branch", "--show-current"]

                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=5,
                    cwd=os.getcwd()
                )

                if result.returncode == 0:
                    return result.stdout.strip()
                else:
                    return f"Git error: {result.stderr}"
            except Exception as e:
                return f"Error running git branch: {str(e)}"

        elif tool_name == "git_add":
            files = arguments.get("files", [])

            if not files:
                return "Error: No files specified to add."

            try:
                info_parts = []

                # Run git add
                cmd = ["git", "add"] + files
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=30,
                    cwd=os.getcwd()
                )

                if result.returncode == 0:
                    files_str = ", ".join(files)
                    info_parts.append(f"Successfully staged: {files_str}")

                    # Show updated status after adding
                    try:
                        status_result = subprocess.run(
                            ["git", "status", "-s"],
                            capture_output=True,
                            text=True,
                            timeout=10,
                            cwd=os.getcwd()
                        )
                        if status_result.returncode == 0:
                            info_parts.append("\n=== Updated Status ===")
                            info_parts.append(status_result.stdout if status_result.stdout.strip() else "No changes")
                    except Exception:
                        pass  # Silently skip if status fails

                    return "\n".join(info_parts)
                else:
                    return f"Git error: {result.stderr}"
            except Exception as e:
                return f"Error running git add: {str(e)}"

        elif tool_name == "git_reset":
            files = arguments.get("files", [])

            try:
                if files:
                    cmd = ["git", "reset", "HEAD"] + files
                    files_str = ", ".join(files)
                    success_msg = f"Successfully unstaged: {files_str}"
                else:
                    cmd = ["git", "reset", "HEAD"]
                    success_msg = "Successfully unstaged all files."

                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=10,
                    cwd=os.getcwd()
                )

                if result.returncode == 0:
                    return success_msg
                else:
                    return f"Git error: {result.stderr}"
            except Exception as e:
                return f"Error running git reset: {str(e)}"

        elif tool_name == "git_commit":
            message = arguments.get("message")
            amend = arguments.get("amend", False)

            if not message and not amend:
                return "Error: Commit message is required."

            # First, automatically gather git status and diff information
            info_parts = []

            # Run git status
            try:
                status_result = subprocess.run(
                    ["git", "status"],
                    capture_output=True,
                    text=True,
                    timeout=10,
                    cwd=os.getcwd()
                )
                if status_result.returncode == 0:
                    info_parts.append("=== Git Status ===")
                    info_parts.append(status_result.stdout)
            except Exception as e:
                info_parts.append(f"Warning: Could not get git status: {str(e)}")

            # Run git diff --cached to show what will be committed
            try:
                diff_result = subprocess.run(
                    ["git", "diff", "--cached"],
                    capture_output=True,
                    text=True,
                    timeout=30,
                    cwd=os.getcwd()
                )
                if diff_result.returncode == 0 and diff_result.stdout.strip():
                    info_parts.append("\n=== Staged Changes (will be committed) ===")
                    info_parts.append(diff_result.stdout)
                elif diff_result.returncode == 0:
                    info_parts.append("\n=== Staged Changes ===")
                    info_parts.append("No staged changes found.")
            except Exception as e:
                info_parts.append(f"\nWarning: Could not get staged changes: {str(e)}")

            # Run git log to show recent commits
            try:
                log_result = subprocess.run(
                    ["git", "log", "-5", "--oneline"],
                    capture_output=True,
                    text=True,
                    timeout=10,
                    cwd=os.getcwd()
                )
                if log_result.returncode == 0:
                    info_parts.append("\n=== Recent Commits ===")
                    info_parts.append(log_result.stdout)
            except Exception as e:
                info_parts.append(f"\nWarning: Could not get recent commits: {str(e)}")

            # Now attempt the commit
            try:
                cmd = ["git", "commit"]
                if amend:
                    cmd.append("--amend")
                if message:
                    cmd.extend(["-m", message])

                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=30,
                    cwd=os.getcwd()
                )

                if result.returncode == 0:
                    info_parts.append("\n=== Commit Result ===")
                    info_parts.append(f"Commit successful:\n{result.stdout}")
                    return "\n".join(info_parts)
                else:
                    # Check for common errors
                    stderr = result.stderr
                    if "nothing to commit" in stderr:
                        info_parts.append("\n=== Commit Result ===")
                        info_parts.append("Error: No changes staged for commit. Use git_add first.")
                    elif "no changes added to commit" in stderr:
                        info_parts.append("\n=== Commit Result ===")
                        info_parts.append("Error: No changes staged for commit. Use git_add first.")
                    else:
                        info_parts.append("\n=== Commit Result ===")
                        info_parts.append(f"Git error: {stderr}")
                    return "\n".join(info_parts)
            except Exception as e:
                info_parts.append("\n=== Commit Result ===")
                info_parts.append(f"Error running git commit: {str(e)}")
                return "\n".join(info_parts)

        else:
            # Unknown tool
            result = f"Unknown tool: {tool_name}"
            debug_log(f"ERROR: Unknown tool requested: {tool_name}")
            return result

    except subprocess.TimeoutExpired:
        result = f"Tool execution timed out: {tool_name}"
        debug_log(f"ERROR: {result}")
        return result
    except Exception as e:
        result = f"Error executing tool {tool_name}: {str(e)}"
        debug_log(f"ERROR: {result}")
        return result


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

        response = requests.post(url, headers=headers, json=payload, stream=True, timeout=60)

        # Check for HTTP errors
        if response.status_code != 200:
            error_body = response.text
            raise Exception(f"OpenAI API error (status {response.status_code}): {error_body}")

        # Parse Server-Sent Events stream
        tool_calls_accumulator = {}  # Accumulate tool call chunks by index

        for line in response.iter_lines():
            if not line:
                continue

            line = line.decode('utf-8', errors='replace')
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
        import sys

        # Validate messages format
        if not isinstance(messages, dict):
            raise ValueError(f"messages must be a dict, got {type(messages)}")
        if 'system' not in messages:
            raise ValueError("messages dict must have 'system' key")
        if 'messages' not in messages:
            raise ValueError("messages dict must have 'messages' key")
        if not isinstance(messages['messages'], list):
            raise ValueError(f"messages['messages'] must be a list, got {type(messages['messages'])}")
        if len(messages['messages']) == 0:
            raise ValueError("messages['messages'] cannot be empty")

        debug_log(f"DEBUG: Anthropic stream_chat called with {len(messages['messages'])} messages")

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
            formatted = self.format_tools_for_api(tools)
            payload['tools'] = formatted
            debug_log(f"INFO: Sending {len(formatted)} tools to Anthropic API")
            debug_log(f"DEBUG: Tool names being sent: {[t['name'] for t in formatted]}")
        else:
            debug_log(f"WARNING: No tools being sent to Anthropic API")

        # Construct URL - ensure we have /v1/messages endpoint
        base_url = self.config.get('base_url')
        if not base_url:
            raise ValueError("base_url is required for Anthropic provider")
        base_url = base_url.rstrip('/')
        # Add /v1 if not already present
        if not base_url.endswith('/v1'):
            base_url = f"{base_url}/v1"
        url = f"{base_url}/messages"

        debug_log(f"DEBUG: Making request to Anthropic API: {url}")

        response = requests.post(
            url,
            headers=headers,
            json=payload,
            stream=True,
            timeout=60
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

            line = line.decode('utf-8', errors='replace')
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
                                    # Handle empty input (tools with no parameters)
                                    tool_input = tool_data['input'].strip()
                                    if not tool_input:
                                        arguments = {}
                                    else:
                                        arguments = json.loads(tool_input)

                                    tool_calls.append({
                                        'id': tool_data['id'],
                                        'name': tool_data['name'],
                                        'arguments': arguments
                                    })
                                except json.JSONDecodeError as e:
                                    pass  # Skip malformed tool calls
                        yield ('', finish_reason, tool_calls)
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

        response = requests.post(url, json=payload, stream=True, timeout=60)

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

        response = requests.post(url, json=payload, stream=True, timeout=60)

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

        response = requests.post(url, headers=headers, json=payload, stream=True, timeout=60)

        # Check for HTTP errors
        if response.status_code != 200:
            error_body = response.text
            raise Exception(f"OpenRouter API error (status {response.status_code}): {error_body}")

        # Parse Server-Sent Events stream (OpenAI-compatible)
        for line in response.iter_lines():
            if not line:
                continue

            line = line.decode('utf-8', errors='replace')
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
        base_url = os.getenv('ANTHROPIC_BASE_URL') or safe_vim_eval('g:anthropic_base_url')
        if not base_url:
            # Fallback to default if not set
            base_url = 'https://api.anthropic.com/v1'
        config = {
            'api_key': os.getenv('ANTHROPIC_API_KEY') or safe_vim_eval('g:anthropic_api_key'),
            'model': safe_vim_eval('g:anthropic_model') or 'claude-sonnet-4-5-20250929',
            'base_url': base_url
        }
        debug_log(f"DEBUG: Creating Anthropic provider with base_url={base_url}")
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
  import sys

  # Log minimal info for debugging
  debug_log(f"INFO: chat_gpt called - prompt length: {len(prompt)}")

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

  # Start with tool calling instruction FIRST if tools are enabled
  enable_tools = int(vim.eval('exists("g:chat_gpt_enable_tools") ? g:chat_gpt_enable_tools : 1'))
  if enable_tools and provider.supports_tools():
    system_message = "CRITICAL: You have function/tool calling capability via the API. When you need to use a tool, you MUST use the API's native tool calling feature. NEVER write text that describes or mimics tool usage. The system handles all tool execution automatically.\n\n"
  else:
    system_message = ""

  system_message += f"{personas[persona]} {resp}"

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

  if enable_tools and provider.supports_tools():
    # Add structured workflow instructions
    system_message += "\n\n## TOOL CALLING CAPABILITY\n\nYou have access to function/tool calling via the API. Tools are available through the native tool calling feature.\n\nIMPORTANT: When executing tools:\n- Use the API's tool/function calling feature (NOT text descriptions)\n- Do NOT write text that mimics tool execution like '✓ Success: git_status()'\n- Do NOT output text like '🔧 Tool Execution' or 'Calling tool: X'\n- The system automatically handles and displays tool execution\n- Your job is to CALL the tools via the API, not describe them in text\n\n## AGENT WORKFLOW\n\nYou are an agentic assistant that follows a structured workflow:\n\n### PHASE 1: PLANNING (when you receive a new user request)\n1. Analyze the user's intention - what is their goal?\n2. Create a detailed plan to achieve that goal\n3. Identify which tools (if any) are needed\n4. Present the plan in this EXACT format:\n\n```\n🎯 GOAL: [Clear statement of what we're trying to achieve]\n\n📋 PLAN:\n1. [First step - include tool name if needed, e.g., \"Check repository status (git_status)\"]\n2. [Second step - e.g., \"Review changes (git_diff with staged=false)\"]\n3. [Continue with all steps...]\n\n🛠️ TOOLS REQUIRED: [List tool names: git_status, git_diff, git_commit, etc.]\n\n⏱️ ESTIMATED STEPS: [Number]\n```\n\n5. CRITICAL: Present ONLY the plan text - do NOT call any tools yet\n6. Wait for user approval\n\n### PHASE 2: EXECUTION (after plan approval)\nWhen user approves the plan with a message like \"Plan approved. Please proceed\":\n1. IMMEDIATELY use your tool calling API capability - do NOT write any text or descriptions\n2. DO NOT output ANY text like: \"🔧 Tool Execution\", \"══════\", \"Step 1:\", \"Checking status\", or descriptions of what you're doing\n3. Your response must contain ONLY function/tool calls using the tool calling feature - NO text content\n4. After each tool execution completes and you see the results, evaluate: \"Do the results change the plan?\"\n5. If plan needs revision:\n   - Present a REVISED PLAN using the same format\n   - Mark it with \"🔄 REVISED PLAN\" at the top\n   - Explain what changed and why\n   - Wait for user approval\n6. If plan is on track: make the NEXT tool call (again, ONLY tool calls, NO text)\n7. Continue until all steps complete\n\n### PHASE 3: COMPLETION\n1. Confirm the goal has been achieved\n2. Summarize what was done\n\nCRITICAL EXECUTION RULES:\n- ALWAYS start with PLANNING phase for new requests\n- NEVER execute tools before showing a plan (unless plan approval is disabled)\n- When executing: Your response must be ONLY tool calls, ZERO text content\n- The system automatically displays tool execution progress - you must NOT output any text\n- DO NOT mimic or output text like \"Tool Execution - Step X\" or separator lines\n- After each tool execution, EVALUATE if plan needs adjustment\n- Between tool calls, you can provide brief analysis text, but during the actual tool call, ONLY send the function call\n"

    if not require_plan_approval:
      system_message += "\nNOTE: Plan approval is DISABLED. You should still create plans mentally, but execute tools immediately.\n"

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
      # Use binary mode with explicit decode to handle UTF-8 seek issues
      with open(history_file, 'rb') as f:
        if summary_cutoff_byte > 0:
          f.seek(summary_cutoff_byte)
        history_bytes = f.read()
        # Decode with error handling for potential mid-character seek
        history_content = history_bytes.decode('utf-8', errors='ignore')

      # Parse history (same format as before)
      history_text = history_content.split('\n\n\x01>>>')
      history_text.reverse()

      # Parse all messages from recent history
      parsed_messages = []
      for line in history_text:
        if ':\x01\n' in line:
          role, message = line.split(":\x01\n", 1)
          parsed_messages.append({
              "role": role.lower(),
              "content": message
          })

      # Always include last 4 messages (to maintain conversation context even after compaction)
      # Note: parsed_messages is in reverse chronological order (newest first) due to the reverse() above
      min_messages = 4
      if len(parsed_messages) >= min_messages:
        # Take first 4 messages (newest 4)
        history = parsed_messages[:min_messages]
        history.reverse()  # Reverse to chronological order (oldest first) for API
        remaining_messages = parsed_messages[min_messages:]  # Older messages
      else:
        # Take all messages if less than 3
        history = parsed_messages[:]
        history.reverse()  # Reverse to chronological order (oldest first) for API
        remaining_messages = []

      # Calculate remaining token budget after including last 3 messages
      token_count = token_limits.get(model, 100000) - max_tokens - len(prompt) - len(system_message)
      for msg in history:
        token_count -= len(msg['content'])

      # Add older messages (from recent history window) until token limit
      # remaining_messages is in reverse chronological order (newest first)
      # We iterate through it and insert older messages at the beginning
      for msg in remaining_messages:
        token_count -= len(msg['content'])
        if token_count > 0:
          history.insert(0, msg)  # Insert at beginning to maintain chronological order
        else:
          break
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
    debug_log(f"INFO: Tools enabled - {len(tools)} tools available")
    debug_log(f"DEBUG: Available tools: {[t['name'] for t in tools]}")
  else:
    debug_log(f"WARNING: Tools not enabled - enable_tools={enable_tools}, supports_tools={provider.supports_tools()}")

  # Stream response using provider (with tool calling loop)
  try:
    chunk_session_id = session_id if session_id else 'gpt-response'
    max_tool_iterations = 25  # Maximum total iterations
    tool_iteration = 0
    plan_approved = not require_plan_approval  # Skip approval if not required
    accumulated_content = ""  # Accumulate content for each iteration
    in_planning_phase = require_plan_approval  # Only enter planning phase if approval is required
    plan_loop_count = 0  # Track how many times we've seen a plan without tool execution

    while tool_iteration < max_tool_iterations:
      tool_calls_to_process = None
      accumulated_content = ""  # Reset for each iteration


      chunk_count = 0
      for content, finish_reason, tool_calls in provider.stream_chat(messages, model, temperature, max_tokens, tools):
        chunk_count += 1
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
            debug_log(f"INFO: Model requested {len(tool_calls)} tool call(s)")
            for idx, tc in enumerate(tool_calls):
              debug_log(f"DEBUG: Tool call {idx+1}: {tc['name']} with args: {json.dumps(tc['arguments'])}")
            tool_calls_to_process = tool_calls

          if not suppress_display:
            vim.command("call DisplayChatGPTResponse('', '{0}', '{1}')".format(finish_reason.replace("'", "''"), chunk_session_id))
            vim.command("redraw")


      # If no tool calls, check if this is a planning response
      if not tool_calls_to_process:
        debug_log(f"INFO: No tool calls received from model")
        debug_log(f"DEBUG: Checking for plan presentation...")
        debug_log(f"DEBUG:   accumulated_content length: {len(accumulated_content)}")
        debug_log(f"DEBUG:   require_plan_approval: {require_plan_approval}")
        debug_log(f"DEBUG:   in_planning_phase: {in_planning_phase}")

        # Check if this is a plan presentation (contains goal/plan markers)
        # Fix boolean logic: parenthesize the 'and' condition
        has_emoji_markers = ('🎯 GOAL:' in accumulated_content or '📋 PLAN:' in accumulated_content)
        has_text_markers = ('GOAL:' in accumulated_content and 'PLAN:' in accumulated_content)
        is_plan_presentation = has_emoji_markers or has_text_markers
        debug_log(f"  is_plan_presentation: {is_plan_presentation}")
        debug_log(f"  Content preview: {accumulated_content[:300]}")

        if is_plan_presentation and require_plan_approval and in_planning_phase:
          # Increment loop counter to detect infinite loops
          plan_loop_count += 1
          debug_log(f"INFO: Plan presentation detected (loop count: {plan_loop_count}, in_planning_phase: {in_planning_phase})")
          debug_log(f"INFO: Full content that triggered detection:\n{accumulated_content}")

          # Safeguard against infinite loops
          if plan_loop_count > 2:
            error_msg = "\n\n❌ ERROR: Model keeps presenting plans without executing. Please try rephrasing your request or disable plan approval.\n"
            vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(error_msg.replace("'", "''"), chunk_session_id))
            break

          # Verify this is actually a valid plan before asking for approval
          # A valid plan should have multiple steps
          has_numbered_steps = bool(re.search(r'\d+\.\s+', accumulated_content))
          if not has_numbered_steps:
            debug_log(f"  WARNING: Detected plan markers but no numbered steps found. Treating as regular response.")
            # Not a real plan, just continue
            break

          # IMPORTANT: Add the assistant's plan response to conversation history
          # so the model has context when we send the approval message
          if provider_name == 'anthropic' and isinstance(messages, dict):
            messages['messages'].append({
              "role": "assistant",
              "content": [{"type": "text", "text": accumulated_content}]
            })
          elif isinstance(messages, list):
            messages.append({
              "role": "assistant",
              "content": accumulated_content
            })

          # Ask for approval
          if not suppress_display:
            approval_prompt_msg = "\n\n" + "="*70 + "\n"
            approval_prompt_msg += "📋 Plan presented above. Approve? [y]es to proceed, [n]o to cancel, [r]evise for changes: "
            vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(approval_prompt_msg.replace("'", "''"), chunk_session_id))
            vim.command("redraw!")

            approval = vim.eval("input('')")

            if approval.lower() in ['n', 'no']:
              cancel_msg = "\n\n❌ Plan cancelled by user.\n"
              vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(cancel_msg.replace("'", "''"), chunk_session_id))
              break
            elif approval.lower() in ['r', 'revise']:
              revise_msg = "\n\n🔄 User requested plan revision.\n"
              vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(revise_msg.replace("'", "''"), chunk_session_id))
              revision_request = vim.eval("input('What changes would you like? ')")

              # Exit planning phase - revised plan will be detected separately
              in_planning_phase = False

              # Send revision request back to model - handle all provider formats
              # Note: Assistant message with plan was already added above
              if provider_name == 'anthropic' and isinstance(messages, dict):
                messages['messages'].append({
                  "role": "user",
                  "content": f"Please present a REVISED PLAN based on this feedback: {revision_request}\n\nMark it clearly with '🔄 REVISED PLAN' at the top."
                })
              elif isinstance(messages, list):
                # OpenAI, Gemini, Ollama format
                messages.append({
                  "role": "user",
                  "content": f"Please present a REVISED PLAN based on this feedback: {revision_request}\n\nMark it clearly with '🔄 REVISED PLAN' at the top."
                })

              continue  # Go to next iteration with revision request
            else:
              # Approved - proceed with execution
              plan_approved = True
              in_planning_phase = False
              approval_msg = "\n\n✅ Plan approved! Proceeding with execution...\n\n"
              vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(approval_msg.replace("'", "''"), chunk_session_id))

              # Send approval message to model to trigger execution - handle all provider formats
              approval_instruction = "Plan approved. Execute step 1 now.\n\nCRITICAL INSTRUCTIONS:\n- Your response must contain ONLY the tool/function call for step 1\n- Do NOT write ANY text content in your response\n- Do NOT output headers like '🔧 Tool Execution' or '══════' or 'Step 1:'\n- The system will automatically display the tool execution progress\n- Just make the actual API function call and nothing else\n- After the tool completes, you'll see the results and can proceed to the next step"

              if provider_name == 'anthropic' and isinstance(messages, dict):
                messages['messages'].append({
                  "role": "user",
                  "content": approval_instruction
                })
              elif isinstance(messages, list):
                # OpenAI, Gemini, Ollama format
                messages.append({
                  "role": "user",
                  "content": approval_instruction
                })

              continue  # Go to next iteration to start execution
        else:
          # No tool calls and not a plan - conversation is done
          break

      # Check if model is presenting a revised plan during execution
      # Only check this if we're NOT in planning phase (to avoid double-asking)
      # and if there are tool calls to process (model is actually making changes)
      is_revised_plan = ("🔄 REVISED PLAN" in accumulated_content or
                        "=== REVISED PLAN ===" in accumulated_content or
                        ("REVISED PLAN" in accumulated_content and not in_planning_phase))

      # If revised plan is detected with tool calls, ask for approval
      # Skip if we already asked during planning phase
      if is_revised_plan and require_plan_approval and not suppress_display and tool_calls_to_process and not in_planning_phase:

        # Show the revised plan header
        revised_plan_header = "\n\n" + "="*70 + "\n"
        revised_plan_header += "🔄 The agent has proposed a REVISED PLAN based on the results.\n"
        revised_plan_header += "="*70 + "\n"
        vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(revised_plan_header.replace("'", "''"), chunk_session_id))

        # Ask for approval
        vim.command("redraw!")
        vim.command("sleep 100m")
        vim.command("redraw!")

        approval = vim.eval("input('Approve revised plan? [y]es to proceed, [n]o to cancel: ')")

        if approval.lower() not in ['y', 'yes']:
          cancel_msg = "\n\n❌ Revised plan cancelled by user.\n"
          vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(cancel_msg.replace("'", "''"), chunk_session_id))
          break

        # Approved - continue execution
        approval_msg = "\n\n✅ Revised plan approved! Continuing execution...\n\n"
        vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(approval_msg.replace("'", "''"), chunk_session_id))

      # Execute tools and add results to messages
      tool_iteration += 1
      debug_log(f"INFO: Starting tool execution iteration {tool_iteration}/{max_tool_iterations}")
      debug_log(f"DEBUG: Processing {len(tool_calls_to_process) if tool_calls_to_process else 0} tool calls")

      if not suppress_display:
        # Display iteration header with formatting
        iteration_msg = "\n\n" + format_separator("═", 70) + f"\n🔧 Tool Execution - Iteration {tool_iteration}\n" + format_separator("═", 70) + "\n"
        vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(iteration_msg.replace("'", "''"), chunk_session_id))
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
      # Reset plan loop counter since we're successfully executing tools
      plan_loop_count = 0

      tool_results = []
      for tool_call in tool_calls_to_process:
        tool_name = tool_call['name']
        tool_args = tool_call['arguments']
        tool_id = tool_call.get('id', 'unknown')

        debug_log(f"INFO: About to execute tool: {tool_name} with id: {tool_id}")
        debug_log(f"DEBUG: Tool arguments: {json.dumps(tool_args)}")

        # Execute the tool
        tool_result = execute_tool(tool_name, tool_args)

        # Log the result
        result_preview = tool_result[:200] if len(tool_result) > 200 else tool_result
        debug_log(f"INFO: Tool {tool_name} completed. Result length: {len(tool_result)} chars")
        debug_log(f"DEBUG: Tool result preview: {result_preview}")

        tool_results.append((tool_id, tool_name, tool_args, tool_result))

        # Display tool usage in session
        # Display tool usage with formatting
        if not suppress_display:
          tool_display = format_tool_result(tool_name, tool_args, tool_result, max_lines=15)
          # Escape for VimScript by doubling single quotes
          escaped_display = tool_display.replace("'", "''")
          vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(escaped_display, chunk_session_id))
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
            # Ensure tool_result is never None
            if tool_result is None:
              tool_result = "Error: Tool returned None"
              debug_log(f"WARNING: Tool {tool_name} returned None, using error placeholder")

            tool_result_content.append({
              "type": "tool_result",
              "tool_use_id": tool_id,
              "content": str(tool_result)  # Ensure it's always a string
            })

          if tool_result_content:  # Only append if we have results
            messages['messages'].append({
              "role": "user",
              "content": tool_result_content
            })
          else:
            debug_log("WARNING: No tool results to add to messages")

  except Exception as e:
    import traceback
    error_details = ''.join(traceback.format_exception(type(e), e, e.__traceback__))
    debug_log(f"ERROR: Full traceback:\n{error_details}")
    print(f"Error streaming from {provider_name}: {str(e)}")
    print(f"See /tmp/vim-chatgpt-debug.log for full error details")

chat_gpt(vim.eval('a:prompt'))
EOF

  " Check if summary needs updating after AI response completes
  " Skip during background operations (context/summary generation)
  if !exists('g:chat_gpt_suppress_display') || g:chat_gpt_suppress_display == 0
    call s:check_and_update_summary()
  endif

  " After everything completes, ensure we're in the chat window at the bottom
  " This prevents the window from scrolling up when focus changes
  if !exists('g:chat_gpt_suppress_display') || g:chat_gpt_suppress_display == 0
    let chat_winnr = bufwinnr('gpt-persistent-session')
    if chat_winnr != -1
      execute chat_winnr . 'wincmd w'
      normal! G
      call cursor('$', 1)
      redraw
    endif
  endif
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
            let relative_path = expand('%')
            let file_info = 'File: ' . relative_path . "\n" . 'Lines: ' . line_start . '-' . line_end . "\n\n"
            let yanked_text = file_info . '```' . &syntax . "\n" . @@ . "\n" . '```'
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

    " Only restore cursor position if NOT in session mode
    " (In session mode, we want to stay in the chat window)
    let session_enabled = exists('g:chat_gpt_session_mode') ? g:chat_gpt_session_mode : 1
    if !session_enabled
        call setpos('.', save_cursor)
    endif
endfunction

" Function to generate a commit message using git integration
function! GenerateCommitMessage()
  " Create a prompt that lets the new workflow handle it
  let prompt = 'Please help me create a git commit message.'
  let prompt .= "\n\nThe goal is to:"
  let prompt .= "\n- Check the repository status"
  let prompt .= "\n- Review the changes that will be committed"
  let prompt .= "\n- Draft an appropriate commit message following conventional commit format"
  let prompt .= "\n- Create the commit"
  let prompt .= "\n\nIf there are no staged changes, ask if I want to stage files first."

  " Call ChatGPT with session mode and plan approval enabled
  " This allows the AI to use tools and get user approval
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
  let project_dir = getcwd()
  let history_file = project_dir . '/.vim-chatgpt/history.txt'
  let summary_file = project_dir . '/.vim-chatgpt/summary.md'
  let temp_chunks_dir = project_dir . '/.vim-chatgpt/temp_chunks'

  let old_cutoff = s:get_summary_cutoff(project_dir)
  let history_size = getfsize(history_file)
  let recent_window = g:chat_gpt_recent_history_size
  let new_cutoff = max([0, history_size - recent_window])

  " Read the old summary if it exists
  let old_summary = ""
  if filereadable(summary_file)
    let old_summary = join(readfile(summary_file), "\n")
  endif

  " Maximum chunk size to process at once (in bytes)
  " Roughly 50KB of conversation = ~12-15K tokens, leaving room for summary and prompt
  let max_chunk_size = 51200

  " Maximum total bytes to summarize in one compaction (200KB = ~4 chunks max)
  " If there's a huge backlog, we skip old content and only summarize recent
  let max_compaction_total = 204800

  " Calculate how much new content needs to be summarized
  let bytes_to_summarize = new_cutoff - old_cutoff

  " Cap the amount to avoid processing too many chunks at once
  if bytes_to_summarize > max_compaction_total
    echo "Large backlog detected (" . float2nr(bytes_to_summarize / 1024) . "KB new content)."
    echo "Summarizing most recent " . float2nr(max_compaction_total / 1024) . "KB only..."
    " Move old_cutoff forward to only summarize recent content
    let old_cutoff = new_cutoff - max_compaction_total
    let bytes_to_summarize = max_compaction_total
  endif

  " Read the new conversation portion from history
  let new_conversation = ""
  if filereadable(history_file)
    " If the amount to summarize is larger than max_chunk_size, chunk it
    if bytes_to_summarize > max_chunk_size
      " Process in chunks, creating intermediate summaries
      let chunk_count = float2nr(ceil(bytes_to_summarize * 1.0 / max_chunk_size))

      echo "Large history detected. Processing " . chunk_count . " chunks..."

      " Create temp directory for chunk summaries
      if !isdirectory(temp_chunks_dir)
        call mkdir(temp_chunks_dir, 'p')
      endif

      " Process each chunk and save intermediate summaries
      for chunk_idx in range(chunk_count)
        let chunk_start = old_cutoff + (chunk_idx * max_chunk_size)
        let chunk_end = min([chunk_start + max_chunk_size, new_cutoff])
        let chunk_size = chunk_end - chunk_start

        if chunk_size <= 0
          break
        endif

        " Use Python to safely extract chunk without splitting UTF-8 characters
        python3 << EOF
import vim

history_file = vim.eval('history_file')
chunk_start = int(vim.eval('chunk_start'))
chunk_end = int(vim.eval('chunk_end'))

try:
    with open(history_file, 'rb') as f:
        # Seek to start position
        f.seek(chunk_start)
        # Read the chunk
        chunk_bytes = f.read(chunk_end - chunk_start)
        # Decode with error handling for potential mid-character start/end
        # Use 'ignore' to skip invalid bytes at boundaries
        chunk_text = chunk_bytes.decode('utf-8', errors='ignore')
        # Store in a vim variable using vim.vars (safer than repr())
        vim.vars['_chunk_conversation'] = chunk_text
except Exception as e:
    print(f"Error reading chunk: {e}")
    vim.vars['_chunk_conversation'] = ''
EOF
        let chunk_conversation = g:_chunk_conversation

        " Process this chunk and save to temp file
        call s:ProcessSummaryChunk(chunk_conversation, chunk_idx + 1, chunk_count, temp_chunks_dir)

        " Small delay between chunks to avoid rate limiting
        if chunk_idx < chunk_count - 1
          sleep 1
        endif
      endfor

      " Now merge all chunk summaries with the old summary into one concise summary
      echo "Merging all summaries into one concise summary..."
      call s:MergeChunkSummaries(old_summary, temp_chunks_dir, chunk_count)

      " Clean up temp directory
      call delete(temp_chunks_dir, 'rf')

      echo "\nConversation summary generated at .vim-chatgpt/summary.md (processed in " . chunk_count . " chunks)"
      return
    else
      " Small enough to process in one go - use Python to safely extract
      python3 << EOF
import vim

history_file = vim.eval('history_file')
old_cutoff = int(vim.eval('old_cutoff'))
new_cutoff = int(vim.eval('new_cutoff'))
bytes_to_summarize = int(vim.eval('bytes_to_summarize'))

try:
    with open(history_file, 'rb') as f:
        if bytes_to_summarize > 0:
            # Read from old_cutoff to new_cutoff
            f.seek(old_cutoff)
            chunk_bytes = f.read(bytes_to_summarize)
        else:
            # First summary - read everything up to new_cutoff
            f.seek(0)
            chunk_bytes = f.read(new_cutoff)

        # Decode with error handling for potential mid-character boundaries
        new_conversation = chunk_bytes.decode('utf-8', errors='ignore')
        # Store in a vim variable using vim.vars (safer than repr())
        vim.vars['_new_conversation'] = new_conversation
except Exception as e:
    print(f"Error reading conversation: {e}")
    vim.vars['_new_conversation'] = ''
EOF
      let new_conversation = g:_new_conversation
    endif
  endif

  " Create a prompt with the actual content (single chunk case)
  let prompt = ""

  if old_cutoff > 0 && !empty(old_summary)
    " Strip old metadata from existing summary
    let summary_content = substitute(old_summary, '^<!--\_.\{-}-->\n\+', '', '')

    let prompt .= "Here is the existing conversation summary:\n\n"
    let prompt .= "```markdown\n" . summary_content . "\n```\n\n"
    let prompt .= "And here is the new conversation to add to the summary:\n\n"
    let prompt .= "```\n" . new_conversation . "\n```\n\n"
    let prompt .= "Please extend the existing summary with insights from the new conversation.\n"
    let prompt .= "Keep all the existing content and only ADD new topics, preferences, and action items.\n"
    let prompt .= "Do NOT re-summarize or remove existing content."
  else
    let prompt .= "Here is a conversation history to summarize:\n\n"
    let prompt .= "```\n" . new_conversation . "\n```\n\n"
    let prompt .= "Please create a comprehensive summary of this conversation."
  endif

  let prompt .= "\n\nGenerate a summary using this format:"
  let prompt .= "\n\n# Conversation Summary"
  let prompt .= "\n\n## Key Topics Discussed"
  let prompt .= "\n[Bullet points of main topics and decisions made]"
  let prompt .= "\n\n## Important Information to Remember"
  let prompt .= "\n[Critical details, decisions, or context that should be retained]"
  let prompt .= "\n\n## User Preferences"
  let prompt .= "\n- Coding style preferences"
  let prompt .= "\n- Tool or technology preferences"
  let prompt .= "\n- Communication preferences"
  let prompt .= "\n- Project-specific conventions"
  let prompt .= "\n\n## Action Items"
  let prompt .= "\n[Any pending tasks or future work mentioned]"
  let prompt .= "\n\nSave the summary to .vim-chatgpt/summary.md using the create_file tool with overwrite=true."

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

" Helper function to process a single chunk of conversation history
" Saves the chunk summary to a temp file instead of the final summary
function! s:ProcessSummaryChunk(chunk_conversation, chunk_num, total_chunks, temp_dir)
  let prompt = ""

  let prompt .= "Here is chunk " . a:chunk_num . " of " . a:total_chunks . " of conversation history:\n\n"
  let prompt .= "```\n" . a:chunk_conversation . "\n```\n\n"
  let prompt .= "Please create a summary of this conversation chunk. Focus on key topics, decisions, and important information."
  let prompt .= "\n\nGenerate a summary using this format:"
  let prompt .= "\n\n# Chunk " . a:chunk_num . " Summary"
  let prompt .= "\n\n## Key Topics"
  let prompt .= "\n[Bullet points of main topics discussed]"
  let prompt .= "\n\n## Important Details"
  let prompt .= "\n[Critical information to remember]"
  let prompt .= "\n\n## User Preferences"
  let prompt .= "\n[Any preferences or conventions mentioned]"
  let prompt .= "\n\n## Action Items"
  let prompt .= "\n[Tasks or future work mentioned]"

  " Save to a temp file for this chunk
  let chunk_file = a:temp_dir . '/chunk_' . a:chunk_num . '.md'
  let prompt .= "\n\nSave this chunk summary to " . chunk_file . " using the create_file tool with overwrite=true."

  " Use session mode 0 for one-time response, disable plan approval and suppress display
  let save_session_mode = exists('g:chat_gpt_session_mode') ? g:chat_gpt_session_mode : 1
  let save_plan_approval = exists('g:chat_gpt_require_plan_approval') ? g:chat_gpt_require_plan_approval : 1
  let save_suppress_display = exists('g:chat_gpt_suppress_display') ? g:chat_gpt_suppress_display : 0
  let g:chat_gpt_session_mode = 0
  let g:chat_gpt_require_plan_approval = 0
  let g:chat_gpt_suppress_display = 1

  echo "Processing chunk " . a:chunk_num . " of " . a:total_chunks . "..."
  call ChatGPT(prompt)

  " Restore settings
  let g:chat_gpt_session_mode = save_session_mode
  let g:chat_gpt_require_plan_approval = save_plan_approval
  let g:chat_gpt_suppress_display = save_suppress_display
endfunction

" Helper function to merge all chunk summaries into one concise final summary
function! s:MergeChunkSummaries(old_summary, temp_dir, chunk_count)
  " Collect all chunk summaries
  let all_chunk_summaries = ""
  for chunk_idx in range(1, a:chunk_count)
    let chunk_file = a:temp_dir . '/chunk_' . chunk_idx . '.md'
    if filereadable(chunk_file)
      let chunk_content = join(readfile(chunk_file), "\n")
      let all_chunk_summaries .= "\n\n" . chunk_content
    endif
  endfor

  " Strip old metadata from existing summary if present
  let old_summary_content = substitute(a:old_summary, '^<!--\_.\{-}-->\n\+', '', '')

  let prompt = ""

  if !empty(old_summary_content)
    let prompt .= "Here is the existing conversation summary:\n\n"
    let prompt .= "```markdown\n" . old_summary_content . "\n```\n\n"
  endif

  let prompt .= "Here are " . a:chunk_count . " intermediate summaries from recent conversation chunks:\n\n"
  let prompt .= "```markdown" . all_chunk_summaries . "\n```\n\n"
  let prompt .= "Please merge these summaries into ONE CONCISE final summary."
  let prompt .= "\n\nIMPORTANT:"
  let prompt .= "\n- Consolidate duplicate or overlapping information"
  let prompt .= "\n- Remove redundancy across chunks"
  let prompt .= "\n- Keep only the most important details"
  let prompt .= "\n- Maintain chronological context where relevant"
  let prompt .= "\n- The final summary should be clear and concise"

  if !empty(old_summary_content)
    let prompt .= "\n- Integrate new information with existing summary without duplicating"
  endif

  let prompt .= "\n\nGenerate ONE consolidated summary using this format:"
  let prompt .= "\n\n# Conversation Summary"
  let prompt .= "\n\n## Key Topics Discussed"
  let prompt .= "\n[Consolidated bullet points of all main topics]"
  let prompt .= "\n\n## Important Information to Remember"
  let prompt .= "\n[All critical details merged and deduplicated]"
  let prompt .= "\n\n## User Preferences"
  let prompt .= "\n- Coding style preferences"
  let prompt .= "\n- Tool or technology preferences"
  let prompt .= "\n- Communication preferences"
  let prompt .= "\n- Project-specific conventions"
  let prompt .= "\n\n## Action Items"
  let prompt .= "\n[All pending tasks merged]"
  let prompt .= "\n\nSave this consolidated summary to .vim-chatgpt/summary.md using the create_file tool with overwrite=true."

  " Use session mode 0 for one-time response, disable plan approval and suppress display
  let save_session_mode = exists('g:chat_gpt_session_mode') ? g:chat_gpt_session_mode : 1
  let save_plan_approval = exists('g:chat_gpt_require_plan_approval') ? g:chat_gpt_require_plan_approval : 1
  let save_suppress_display = exists('g:chat_gpt_suppress_display') ? g:chat_gpt_suppress_display : 0
  let g:chat_gpt_session_mode = 0
  let g:chat_gpt_require_plan_approval = 0
  let g:chat_gpt_suppress_display = 1

  call ChatGPT(prompt)

  " Restore settings
  let g:chat_gpt_session_mode = save_session_mode
  let g:chat_gpt_require_plan_approval = save_plan_approval
  let g:chat_gpt_suppress_display = save_suppress_display
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
" Note: Summary compaction check is called after AI responses complete (see ChatGPT function)
