"""
Tool execution framework for AI agents

This module provides tool definitions and execution logic for file operations,
git operations, and other system interactions that AI agents can perform.
"""

import os
import subprocess
import re
import vim
from chatgpt.utils import debug_log, get_config

# Session-level cache for approved tools
# Keys: tool_name -> approval status ('always', 'session', 'denied')
_approved_tools = {}


def get_tool_definitions():
    """Define available tools for AI agents"""
    return [
        {
            "name": "get_working_directory",
            "description": "Get the current working directory path. Use this to understand the project root location.",
            "parameters": {"type": "object", "properties": {}, "required": []},
        },
        {
            "name": "list_directory",
            "description": "List files and directories in a specified path. Use this to explore project structure and find relevant files.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "Path to the directory to list (absolute or relative to current directory). Use '.' for current directory.",
                    },
                    "show_hidden": {
                        "type": "boolean",
                        "description": "Whether to show hidden files/directories (those starting with '.'). Default: false",
                        "default": False,
                    },
                },
                "required": ["path"],
            },
        },
        {
            "name": "find_in_file",
            "description": "Search for text pattern in a specific file using grep. Returns matching lines with line numbers.",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Path to the file to search in (absolute or relative to current directory)",
                    },
                    "pattern": {
                        "type": "string",
                        "description": "Text pattern or regex to search for",
                    },
                    "case_sensitive": {
                        "type": "boolean",
                        "description": "Whether the search should be case sensitive (default: false)",
                        "default": False,
                    },
                },
                "required": ["file_path", "pattern"],
            },
        },
        {
            "name": "find_file_in_project",
            "description": "Find files in the current project/directory by name pattern. Returns list of matching file paths.",
            "parameters": {
                "type": "object",
                "properties": {
                    "pattern": {
                        "type": "string",
                        "description": "File name pattern to search for (supports wildcards like *.py, *test*, etc.)",
                    },
                    "max_results": {
                        "type": "integer",
                        "description": "Maximum number of results to return (default: 20)",
                        "default": 20,
                    },
                },
                "required": ["pattern"],
            },
        },
        {
            "name": "read_file",
            "description": "Read the contents of a file. Returns the file contents as text.",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Path to the file to read (absolute or relative to current directory)",
                    },
                    "max_lines": {
                        "type": "integer",
                        "description": "Maximum number of lines to read (default: 100)",
                        "default": 100,
                    },
                },
                "required": ["file_path"],
            },
        },
        {
            "name": "create_file",
            "description": "Create a new file with specified content. Returns success message or error.",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Path where the new file should be created (absolute or relative to current directory)",
                    },
                    "content": {
                        "type": "string",
                        "description": "The content to write to the new file",
                    },
                    "overwrite": {
                        "type": "boolean",
                        "description": "Whether to overwrite if file already exists (default: false)",
                        "default": False,
                    },
                },
                "required": ["file_path", "content"],
            },
        },
        {
            "name": "open_file",
            "description": "Open a file in Vim to show it to the user. The file will be displayed in the editor for the user to view. Use this when you need the user to see the file contents in their editor.",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Path to the file to open in Vim (absolute or relative to current directory)",
                    },
                    "split": {
                        "type": "string",
                        "description": "How to open the file: 'vertical' (default), 'horizontal', or 'current'",
                        "enum": ["current", "horizontal", "vertical"],
                        "default": "vertical",
                    },
                    "line_number": {
                        "type": "integer",
                        "description": "Optional: Line number to jump to after opening the file (1-indexed)",
                    },
                },
                "required": ["file_path"],
            },
        },
        {
            "name": "edit_file",
            "description": "Edit an existing file by replacing specific content. Use this to make precise changes to files.",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Path to the file to edit (absolute or relative to current directory)",
                    },
                    "old_content": {
                        "type": "string",
                        "description": "The exact content to find and replace. Must match exactly including whitespace.",
                    },
                    "new_content": {
                        "type": "string",
                        "description": "The new content to replace the old content with",
                    },
                },
                "required": ["file_path", "old_content", "new_content"],
            },
        },
        {
            "name": "edit_file_lines",
            "description": "Edit specific lines in a file by line number. More efficient for large files. Line numbers are 1-indexed. IMPORTANT: Both start_line and end_line are INCLUSIVE - they specify the exact lines to replace. Example: start_line=5, end_line=7 replaces lines 5, 6, AND 7 (three lines total). To replace a single line, use the same number for both (e.g., start_line=5, end_line=5).",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Path to the file to edit (absolute or relative to current directory)",
                    },
                    "start_line": {
                        "type": "integer",
                        "description": "Starting line number (1-indexed, INCLUSIVE). This line WILL be replaced. Example: start_line=5 means line 5 will be included in the replacement.",
                    },
                    "end_line": {
                        "type": "integer",
                        "description": "Ending line number (1-indexed, INCLUSIVE). This line WILL be replaced. Must be >= start_line. Example: end_line=7 means line 7 will be included in the replacement. To replace only line 5, use start_line=5 and end_line=5.",
                    },
                    "new_content": {
                        "type": "string",
                        "description": "The new content to replace the specified line range. Can be multiple lines separated by newlines. This content will replace ALL lines from start_line to end_line (inclusive).",
                    },
                },
                "required": ["file_path", "start_line", "end_line", "new_content"],
            },
        },
        {
            "name": "git_status",
            "description": "Get the current git repository status. Shows working tree status including staged, unstaged, and untracked files. Also includes recent commit history for context.",
            "parameters": {"type": "object", "properties": {}, "required": []},
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
                        "default": False,
                    },
                    "file_path": {
                        "type": "string",
                        "description": "Optional: specific file path to diff. If not provided, shows all changes.",
                    },
                },
                "required": [],
            },
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
                        "default": 10,
                    },
                    "oneline": {
                        "type": "boolean",
                        "description": "If true, show compact one-line format. If false, show detailed format (default: true)",
                        "default": True,
                    },
                    "file_path": {
                        "type": "string",
                        "description": "Optional: show history for specific file path",
                    },
                },
                "required": [],
            },
        },
        {
            "name": "git_show",
            "description": "Show details of a specific commit including the full diff.",
            "parameters": {
                "type": "object",
                "properties": {
                    "commit": {
                        "type": "string",
                        "description": "Commit hash, branch name, or reference (e.g., 'HEAD', 'HEAD~1', 'abc123')",
                    }
                },
                "required": ["commit"],
            },
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
                        "default": False,
                    }
                },
                "required": [],
            },
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
                        "description": "List of file paths to stage. Use ['.'] to stage all changes.",
                    }
                },
                "required": ["files"],
            },
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
                        "description": "List of file paths to unstage. If empty, unstages all files.",
                    }
                },
                "required": [],
            },
        },
        {
            "name": "git_commit",
            "description": "Create a new commit with staged changes. Only works if there are staged changes.",
            "parameters": {
                "type": "object",
                "properties": {
                    "message": {
                        "type": "string",
                        "description": "Commit message. Should be descriptive and follow conventional commit format if possible.",
                    },
                    "amend": {
                        "type": "boolean",
                        "description": "If true, amend the previous commit instead of creating a new one (default: false)",
                        "default": False,
                    },
                },
                "required": ["message"],
            },
        },
    ]


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
            r"^/etc/",
            r"^/private/etc/",  # macOS: /etc is symlink to /private/etc
            r"^/sys/",
            r"^/proc/",
            r"^/dev/",
            r"^/root/",
            r"^/boot/",
            r"^/bin/",
            r"^/sbin/",
            r"^/lib",
            r"^/usr/bin/",
            r"^/usr/sbin/",
            r"^/usr/lib",
            r"^C:\\Windows\\",
            r"^C:\\Program Files",
            r"^/System/",
            r"^/Library/System",
        ]

        for pattern in blocked_patterns:
            if re.match(pattern, real_path, re.IGNORECASE):
                return (
                    False,
                    f"Security: {operation} denied. Cannot modify system path: {file_path}",
                )

        # Check for suspicious path components (always deny)
        path_parts = os.path.normpath(file_path).split(os.sep)
        if ".." in path_parts:
            return (
                False,
                f"Security: {operation} denied. Path contains '..' traversal: {file_path}",
            )

        # Check if path is within current working directory
        # Use os.path.commonpath to ensure it's truly a subdirectory
        is_within_project = False
        try:
            common = os.path.commonpath([cwd, real_path])
            is_within_project = common == cwd
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

            # Force a redraw to ensure the dialog is visible
            vim.command("redraw")
            vim.command("echo 'Waiting for security approval...'")
            vim.command("redraw")

            # Call Vim's confirm() function
            # Returns: 1=Yes, 2=No
            result_str = vim.eval(f"confirm('{prompt_msg_escaped}', '&Yes\\n&No', 2)")
            # Handle empty string (can happen in test environments)
            if result_str == "" or result_str is None:
                result = 2  # Default to No
            else:
                result = int(result_str)

            if result == 1:
                # User approved
                debug_log(
                    f"INFO: User approved {operation} outside project: {file_path}"
                )
                return (True, None)
            else:
                # User denied
                debug_log(
                    f"WARNING: User denied {operation} outside project: {file_path}"
                )
                return (
                    False,
                    f"Security: {operation} denied by user. Path '{file_path}' is outside project directory.",
                )
        except Exception as e:
            # If we can't prompt (e.g., in non-interactive mode), deny by default
            debug_log(f"ERROR: Failed to prompt user for permission: {str(e)}")
            return (
                False,
                f"Security: {operation} denied. Path '{file_path}' is outside project directory and user confirmation failed.",
            )

    except Exception as e:
        return (False, f"Security: Error validating path: {str(e)}")


def clear_tool_approvals():
    """
    Clear all tool approvals for the current session.
    Useful for resetting permissions if you want to re-approve tools.
    """
    global _approved_tools
    _approved_tools.clear()
    debug_log("INFO: All tool approvals cleared")


def get_approved_tools():
    """
    Get list of currently approved tools.

    Returns:
        dict: Dictionary of tool_name -> approval_status
    """
    return _approved_tools.copy()


def check_tool_approval(tool_name, arguments):
    """
    Check if tool is approved for execution. Prompts user on first use.

    Returns:
        tuple: (is_approved: bool, message: str or None)
    """
    global _approved_tools

    # Check if tool approval is enabled (enabled by default for security)
    require_approval = get_config("require_tool_approval", "1")
    if require_approval == "0":
        return (True, None)

    # Check if tool is already approved
    if tool_name in _approved_tools:
        status = _approved_tools[tool_name]
        if status == "denied":
            return (False, f"Tool '{tool_name}' was denied by user")
        # 'always' or 'session' - both mean approved
        return (True, None)

    # First time using this tool - prompt user
    try:
        # Format arguments for display (truncate if too long)
        args_str = str(arguments)
        if len(args_str) > 100:
            args_str = args_str[:100] + "..."

        # Build prompt as a list for inputlist()
        # Escape single quotes for Vim string literals
        tool_name_escaped = tool_name.replace("'", "''")
        args_str_escaped = args_str.replace("'", "''")

        # Force a redraw to ensure visibility
        vim.command("redraw")

        # Use inputlist() which is more reliable for terminal input
        # Returns the selected number (1, 2, 3) or 0 for cancel
        vim_cmd = f"inputlist(['AI wants to use tool: {tool_name_escaped}', 'Arguments: {args_str_escaped}', '', 'Select an option:', '1. Allow Once', '2. Always Allow', '3. Deny', '', 'Enter number (1-3): '])"
        result_str = vim.eval(vim_cmd)
        # Handle empty string (can happen in test environments)
        if result_str == "" or result_str is None:
            result = 0
        else:
            result = int(result_str)

        if result == 1:
            # Allow once - don't add to cache
            debug_log(f"INFO: Tool '{tool_name}' allowed once by user")
            return (True, None)
        elif result == 2:
            # Always allow - add to cache
            _approved_tools[tool_name] = "always"
            debug_log(f"INFO: Tool '{tool_name}' always allowed by user")
            return (True, None)
        else:  # result == 3 or any other value (including escape)
            # Deny - add to cache
            _approved_tools[tool_name] = "denied"
            debug_log(f"WARNING: Tool '{tool_name}' denied by user")
            return (False, f"Tool '{tool_name}' denied by user")

    except Exception as e:
        # If we can't prompt (e.g., in non-interactive mode), deny by default
        debug_log(f"ERROR: Failed to prompt user for tool approval: {str(e)}")
        return (False, f"Tool approval failed: {str(e)}")


def execute_tool(tool_name, arguments):
    """Execute a tool with given arguments"""

    debug_log(f"INFO: Executing tool: {tool_name}")
    debug_log(f"DEBUG: Tool arguments: {arguments}")

    # Check tool approval first
    is_approved, approval_msg = check_tool_approval(tool_name, arguments)
    if not is_approved:
        return f"Tool execution blocked: {approval_msg}"

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
                    items = [item for item in items if not item.startswith(".")]

                # Sort items: directories first, then files
                dirs = sorted(
                    [item for item in items if os.path.isdir(os.path.join(path, item))]
                )
                files = sorted(
                    [item for item in items if os.path.isfile(os.path.join(path, item))]
                )

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
                            size_str = (
                                f"{size:,} bytes"
                                if size < 1024
                                else f"{size/1024:.1f} KB"
                            )
                            result_lines.append(f"  {f} ({size_str})")
                        except:
                            result_lines.append(f"  {f}")

                if not dirs and not files:
                    return f"Directory is empty: {path}"

                total = len(dirs) + len(files)
                result_lines.insert(
                    0,
                    f"Listing {path} ({len(dirs)} directories, {len(files)} files):\n",
                )

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
                if (
                    "invalid" in result.stderr.lower()
                    or "unmatched" in result.stderr.lower()
                ):
                    return f"Invalid regex pattern '{pattern}'. Error: {result.stderr.strip()}"
                return f"Error searching file: {result.stderr.strip()}"

        elif tool_name == "find_file_in_project":
            pattern = arguments.get("pattern")
            max_results = arguments.get("max_results", 20)

            # Get current working directory
            cwd = os.getcwd()

            # Use find command to search for files
            cmd = ["find", ".", "-name", pattern, "-type", "f"]
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=10, cwd=cwd
            )

            if result.returncode == 0:
                files = result.stdout.strip().split("\n")
                files = [f for f in files if f]  # Remove empty strings
                if len(files) > max_results:
                    files = files[:max_results]
                    return (
                        "\n".join(files)
                        + f"\n... ({len(files)} results shown, more available)"
                        + "\n"
                    )
                return (
                    "\n".join(files)
                    if files
                    else f"No files found matching pattern: {pattern}" + "\n"
                )
            else:
                return f"Error finding files: {result.stderr.strip()}"

        elif tool_name == "read_file":
            file_path = arguments.get("file_path")
            max_lines = arguments.get("max_lines", 100)

            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    lines = []
                    for i, line in enumerate(f):
                        if i >= max_lines:
                            lines.append(f"... (truncated at {max_lines} lines)")
                            break
                        lines.append(line.rstrip())
                    return "\n".join(lines) + "\n"
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
                # Check for both old (.vim-chatgpt) and new (.vim-llm-agent) directory names
                # Note: We don't check bare 'summary.md' to avoid path resolution errors
                if file_path.endswith(".vim-chatgpt/summary.md") or file_path.endswith(
                    ".vim-llm-agent/summary.md"
                ):
                    # Calculate metadata values
                    from datetime import datetime
                    from chatgpt.utils import get_config

                    # Get the recent history window size (default 30KB to match config.vim and summary.py)
                    recent_window = int(get_config("recent_history_size", "30480"))

                    # Calculate history file path from the summary file's directory
                    summary_dir = os.path.dirname(file_path)
                    history_file = os.path.join(summary_dir, "history.txt")

                    # Get old cutoff from existing summary
                    old_cutoff = 0
                    if os.path.exists(file_path):
                        with open(file_path, "r", encoding="utf-8") as f:
                            summary_content = f.read()
                            match = re.search(r"cutoff_byte:\s*(\d+)", summary_content)
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
                with open(file_path, "w", encoding="utf-8") as f:
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
                if file_bufnr != "-1":
                    # Buffer exists - check if it's visible in a window
                    winnr = vim.eval(f"bufwinnr({file_bufnr})")
                    if winnr != "-1":
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
            new_content = arguments.get("new_content")

            # Validate file path for security
            is_valid, error_msg = validate_file_path(file_path, "edit file")
            if not is_valid:
                return error_msg

            try:
                # Read the file
                with open(file_path, "r", encoding="utf-8") as f:
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
                with open(file_path, "w", encoding="utf-8") as f:
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

            # Validate file path for security
            is_valid, error_msg = validate_file_path(file_path, "edit file")
            if not is_valid:
                return error_msg

            try:
                # Validate line numbers
                if start_line < 1:
                    return (
                        f"Invalid start_line: {start_line}. Line numbers must be >= 1."
                    )
                if end_line < start_line:
                    return f"Invalid line range: end_line ({end_line}) must be >= start_line ({start_line})."

                # Read all lines from the file
                with open(file_path, "r", encoding="utf-8") as f:
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

                # Log what will be replaced for debugging
                lines_to_replace_count = end_line - start_line + 1
                debug_log(
                    f"edit_file_lines: Replacing {lines_to_replace_count} line(s) from line {start_line} to {end_line} (inclusive) in {file_path}"
                )

                # Prepare new content lines
                # Handle the case where content ends with \n (split creates empty string at end)
                new_lines = new_content.split("\n") if new_content else []
                # Remove trailing empty string if content ended with newline
                if new_lines and new_lines[-1] == "":
                    new_lines = new_lines[:-1]
                    content_had_trailing_newline = True
                else:
                    content_had_trailing_newline = False

                # Build formatted lines with proper newline handling
                new_lines_formatted = []
                for i, line in enumerate(new_lines):
                    is_last_line = i == len(new_lines) - 1

                    if is_last_line:
                        # For the last line, add newline based on context:
                        # 1. If we're replacing lines in the middle of the file, always add newline
                        # 2. If we're replacing the last line(s), match original file's newline behavior
                        # 3. If content had trailing newline, preserve it
                        if end_idx < total_lines - 1:
                            # Replacing lines in the middle - always add newline
                            new_lines_formatted.append(line + "\n")
                        elif content_had_trailing_newline or (
                            end_idx == total_lines - 1 and lines[end_idx].endswith("\n")
                        ):
                            # At end of file, but either content or original had trailing newline
                            new_lines_formatted.append(line + "\n")
                        else:
                            # At end of file, no trailing newline
                            new_lines_formatted.append(line)
                    else:
                        # Not the last line - always add newline
                        new_lines_formatted.append(line + "\n")

                # Build the new file content
                new_file_lines = (
                    lines[:start_idx] + new_lines_formatted + lines[end_idx + 1 :]
                )

                # Write back to the file
                with open(file_path, "w", encoding="utf-8") as f:
                    f.writelines(new_file_lines)

                lines_replaced = end_idx - start_idx + 1
                lines_added = len(new_lines_formatted)
                return f"Successfully edited {file_path}: replaced lines {start_line} through {end_line} inclusive ({lines_replaced} line(s) removed, {lines_added} line(s) added)"
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
                    cwd=os.getcwd(),
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
                        cwd=os.getcwd(),
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
                        cwd=os.getcwd(),
                    )
                    if status_result.returncode == 0:
                        info_parts.append("=== Git Status (short) ===")
                        info_parts.append(
                            status_result.stdout
                            if status_result.stdout.strip()
                            else "No changes"
                        )
                except Exception:
                    pass  # Silently skip if status fails

                # Get the diff
                cmd = ["git", "diff"]
                if staged:
                    cmd.append("--cached")
                if file_path:
                    cmd.append(file_path)

                result = subprocess.run(
                    cmd, capture_output=True, text=True, timeout=30, cwd=os.getcwd()
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
                    cmd, capture_output=True, text=True, timeout=10, cwd=os.getcwd()
                )

                if result.returncode == 0:
                    return (
                        result.stdout if result.stdout.strip() else "No commits found."
                    )
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
                    cwd=os.getcwd(),
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
                    cmd, capture_output=True, text=True, timeout=5, cwd=os.getcwd()
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
                    cmd, capture_output=True, text=True, timeout=30, cwd=os.getcwd()
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
                            cwd=os.getcwd(),
                        )
                        if status_result.returncode == 0:
                            info_parts.append("\n=== Updated Status ===")
                            info_parts.append(
                                status_result.stdout
                                if status_result.stdout.strip()
                                else "No changes"
                            )
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
                    cmd, capture_output=True, text=True, timeout=10, cwd=os.getcwd()
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
                    cwd=os.getcwd(),
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
                    cwd=os.getcwd(),
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
                    cwd=os.getcwd(),
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
                    cmd, capture_output=True, text=True, timeout=30, cwd=os.getcwd()
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
                        info_parts.append(
                            "Error: No changes staged for commit. Use git_add first."
                        )
                    elif "no changes added to commit" in stderr:
                        info_parts.append("\n=== Commit Result ===")
                        info_parts.append(
                            "Error: No changes staged for commit. Use git_add first."
                        )
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
