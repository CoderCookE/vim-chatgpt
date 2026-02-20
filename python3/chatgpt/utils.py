"""
Utility functions for the ChatGPT plugin
"""

import os
import vim


def safe_vim_eval(expression):
    """Safely evaluate a Vim expression"""
    try:
        return vim.eval(expression)
    except vim.error:
        return None


# Log level constants
LOG_LEVEL_DEBUG = 0
LOG_LEVEL_INFO = 1
LOG_LEVEL_WARNING = 2
LOG_LEVEL_ERROR = 3

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
    """
    try:
        import vim
        configured_level = int(vim.eval('exists("g:chat_gpt_log_level") ? g:chat_gpt_log_level : 0'))

        if configured_level == 0:
            return

        message_level = LOG_LEVEL_DEBUG
        clean_msg = msg

        for prefix, level in LOG_LEVEL_MAP.items():
            if msg.startswith(prefix):
                message_level = level
                clean_msg = msg[len(prefix):].strip()
                break

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
        pass


def save_to_history(content):
    """Save content to history file"""
    try:
        session_enabled = int(vim.eval('exists("g:chat_gpt_session_mode") ? g:chat_gpt_session_mode : 1')) == 1
        if not session_enabled:
            return

        vim_chatgpt_dir = os.path.join(os.getcwd(), '.vim-chatgpt')
        history_file = os.path.join(vim_chatgpt_dir, 'history.txt')

        if not os.path.exists(vim_chatgpt_dir):
            os.makedirs(vim_chatgpt_dir)

        with open(history_file, 'a', encoding='utf-8') as f:
            f.write(content)
    except Exception as e:
        pass


def save_plan(plan_content):
    """
    Save the approved plan to .vim-chatgpt/plan.md

    This ensures the plan persists across conversation compactions and sessions.

    Args:
        plan_content: The plan text to save
    """
    try:
        session_enabled = int(vim.eval('exists("g:chat_gpt_session_mode") ? g:chat_gpt_session_mode : 1')) == 1
        if not session_enabled:
            debug_log("INFO: Session mode disabled, not saving plan")
            return

        vim_chatgpt_dir = os.path.join(os.getcwd(), '.vim-chatgpt')
        plan_file = os.path.join(vim_chatgpt_dir, 'plan.md')

        if not os.path.exists(vim_chatgpt_dir):
            os.makedirs(vim_chatgpt_dir)

        # Add metadata header
        from datetime import datetime
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        content_with_metadata = f"""<!-- Plan saved at: {timestamp} -->

{plan_content.strip()}
"""

        with open(plan_file, 'w', encoding='utf-8') as f:
            f.write(content_with_metadata)

        debug_log(f"INFO: Plan saved to {plan_file}")
    except Exception as e:
        debug_log(f"ERROR: Failed to save plan: {str(e)}")


def load_plan():
    """
    Load the saved plan from .vim-chatgpt/plan.md

    Returns:
        str: The plan content, or None if no plan exists
    """
    try:
        plan_file = os.path.join(os.getcwd(), '.vim-chatgpt', 'plan.md')

        if not os.path.exists(plan_file):
            return None

        with open(plan_file, 'r', encoding='utf-8') as f:
            content = f.read()

        # Strip metadata comments
        import re
        content = re.sub(r'<!--.*?-->\s*\n', '', content, flags=re.DOTALL)

        debug_log(f"INFO: Loaded plan from {plan_file}")
        return content.strip()
    except Exception as e:
        debug_log(f"WARNING: Failed to load plan: {str(e)}")
        return None


# Formatting helpers for better chat display
def format_box(title, content="", width=60):
    """Create a formatted box with title and optional content"""
    top = "╔" + "═" * (width - 2) + "╗"
    bottom = "╚" + "═" * (width - 2) + "╝"

    lines = [top]

    if title:
        title_padded = f" {title} ".center(width - 2, " ")
        lines.append(f"║{title_padded}║")
        if content:
            lines.append("║" + " " * (width - 2) + "║")

    if content:
        for line in content.split('\n'):
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

    args_str = ", ".join(f"{k}={repr(v)[:40]}" for k, v in tool_args.items())
    if len(args_str) > 60:
        args_str = args_str[:57] + "..."

    return f"{icon} {status_text}: {tool_name}({args_str})"


def format_tool_result(tool_name, tool_args, result, max_lines=20):
    """Format tool execution result with header"""
    header = format_separator("─", 60)
    tool_call_str = format_tool_call(tool_name, tool_args, "success")

    result_lines = result.split('\n')
    if len(result_lines) > max_lines:
        result_lines = result_lines[:max_lines]
        result_lines.append(f"... (truncated, {len(result.split(chr(10))) - max_lines} more lines)")

    result_formatted = '\n'.join(f"  {line}" for line in result_lines)

    return f"\n{header}\n{tool_call_str}\n\nOutput:\n{result_formatted}\n{header}\n"


def format_plan_display(plan_type, explanation, tool_calls):
    """Format plan approval display with nice boxes"""
    title = f"{plan_type} FOR APPROVAL"

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
