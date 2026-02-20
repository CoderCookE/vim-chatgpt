"""
Conversation summary generation module

This module handles generating summaries of conversation history to keep
the context window manageable while preserving important information.
"""

import os
import vim
from chatgpt.core import chat_gpt
from chatgpt.utils import debug_log


def get_summary_cutoff(project_dir):
    """
    Extract cutoff byte position from summary metadata.

    Args:
        project_dir: Project directory path

    Returns:
        int: Byte position where last summary ended
    """
    summary_file = os.path.join(project_dir, '.vim-chatgpt', 'summary.md')

    if not os.path.exists(summary_file):
        return 0

    try:
        with open(summary_file, 'r', encoding='utf-8') as f:
            # Read first 10 lines to find metadata
            for _ in range(10):
                line = f.readline()
                if not line:
                    break
                if 'cutoff_byte:' in line:
                    # Extract number after cutoff_byte:
                    import re
                    match = re.search(r'cutoff_byte:\s*(\d+)', line)
                    if match:
                        return int(match.group(1))
    except Exception as e:
        debug_log(f"WARNING: Could not read summary cutoff: {str(e)}")

    return 0


def generate_conversation_summary():
    """
    Generate a summary of the conversation history.

    This matches the original VimScript implementation:
    - Calculates byte positions for compaction
    - Processes in chunks if history is large
    - Uses AI with tools to save the summary file
    - Maintains cutoff_byte metadata
    """
    debug_log("INFO: Starting conversation summary generation")

    # Get project directory and file paths
    project_dir = os.getcwd()
    history_file = os.path.join(project_dir, '.vim-chatgpt', 'history.txt')
    summary_file = os.path.join(project_dir, '.vim-chatgpt', 'summary.md')

    # Check if history exists
    if not os.path.exists(history_file):
        debug_log("WARNING: No history file found")
        return

    # Calculate byte positions
    old_cutoff = get_summary_cutoff(project_dir)
    history_size = os.path.getsize(history_file)

    # Get window size from config (default 30KB)
    from chatgpt.utils import safe_vim_eval
    recent_window = int(safe_vim_eval('g:chat_gpt_recent_history_size') or 30480)

    new_cutoff = max(0, history_size - recent_window)

    # Read old summary if exists
    old_summary = ""
    if os.path.exists(summary_file):
        try:
            with open(summary_file, 'r', encoding='utf-8') as f:
                old_summary = f.read()
        except Exception as e:
            debug_log(f"WARNING: Could not read old summary: {str(e)}")

    # Maximum chunk size (50KB)
    max_chunk_size = 51200

    # Maximum total bytes to summarize (200KB)
    max_compaction_total = 204800

    # Calculate how much needs to be summarized
    bytes_to_summarize = new_cutoff - old_cutoff

    # Cap the amount to avoid processing too many chunks
    if bytes_to_summarize > max_compaction_total:
        debug_log(f"INFO: Large backlog ({bytes_to_summarize//1024}KB), limiting to {max_compaction_total//1024}KB")
        old_cutoff = new_cutoff - max_compaction_total
        bytes_to_summarize = max_compaction_total

    # Read the conversation portion to summarize
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

            # Decode with error handling for UTF-8 boundaries
            new_conversation = chunk_bytes.decode('utf-8', errors='ignore')
    except Exception as e:
        debug_log(f"ERROR: Failed to read history: {str(e)}")
        return

    # Build the prompt
    prompt = ""

    if old_cutoff > 0 and old_summary:
        # Strip metadata from existing summary
        import re
        summary_content = re.sub(r'^<!--.*?-->\n+', '', old_summary, flags=re.DOTALL)

        prompt += "Here is the existing conversation summary:\n\n"
        prompt += f"```markdown\n{summary_content}\n```\n\n"
        prompt += "And here is the new conversation to add to the summary:\n\n"
        prompt += f"```\n{new_conversation}\n```\n\n"
        prompt += "Please extend the existing summary with insights from the new conversation.\n"
        prompt += "Keep all the existing content and only ADD new topics, preferences, and action items.\n"
        prompt += "Do NOT re-summarize or remove existing content."
    else:
        prompt += "Here is a conversation history to summarize:\n\n"
        prompt += f"```\n{new_conversation}\n```\n\n"
        prompt += "Please create a comprehensive summary of this conversation."

    # Add format instructions
    prompt += "\n\nGenerate a summary using this format:"
    prompt += "\n\n# Conversation Summary"
    prompt += "\n\n## Key Topics Discussed"
    prompt += "\n[Bullet points of main topics and decisions made]"
    prompt += "\n\n## Important Information to Remember"
    prompt += "\n[Critical details, decisions, or context that should be retained]"
    prompt += "\n\n## User Preferences"
    prompt += "\n- Coding style preferences"
    prompt += "\n- Tool or technology preferences"
    prompt += "\n- Communication preferences"
    prompt += "\n- Project-specific conventions"
    prompt += "\n\n## Action Items"
    prompt += "\n[Any pending tasks or future work mentioned]"

    # IMPORTANT: Ask the AI to save the file using the create_file tool
    # This ensures the metadata header gets added properly by the tool
    prompt += f"\n\nSave the summary to .vim-chatgpt/summary.md using the create_file tool with overwrite=true."

    debug_log(f"INFO: Generating summary for {bytes_to_summarize} bytes of conversation")

    # Generate the summary using chat_gpt
    # The AI will use the create_file tool to save it with proper metadata
    chat_gpt(prompt)

    debug_log("INFO: Summary generation complete")
