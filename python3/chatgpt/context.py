"""
Context generation module

This module handles generating project context files to help the AI
understand projects in future conversations.
"""

import os
import json
import re
from datetime import datetime
from chatgpt.utils import debug_log, get_config, get_project_dir
from chatgpt.providers import create_provider
from chatgpt.tools import get_tool_definitions, execute_tool


def generate_project_context():
    """
    Generate a project context file by having the AI analyze the project.

    This uses AI with tools to explore the project, then saves the generated
    context markdown to .vim-llm-agent/context.md
    """
    debug_log("INFO: Starting project context generation")

    # Get vim directory path (with fallback for backwards compatibility)
    vim_dir = get_project_dir()
    context_file = os.path.join(vim_dir, "context.md")

    # Build the prompt - asking AI to analyze and output markdown
    prompt = """Please analyze this project and create a concise project context summary.

Use the available tools to:
1. Get the working directory
2. List the root directory contents
3. Look for README files, package.json, requirements.txt, Cargo.toml, go.mod, pom.xml, or other project metadata files
4. Read key configuration/metadata files to understand the project

Then output a markdown summary in this format:

# Project: [Name]

## Type
[e.g., Python web application, JavaScript library, Rust CLI tool, etc.]

## Purpose
[Brief description of what this project does]

## Tech Stack
[Key technologies, frameworks, and dependencies]

## Structure
[Brief overview of directory structure and key files]

## Key Files
[List important entry points, config files, etc.]

Important: Output ONLY the markdown summary. Do not include any conversational text before or after the markdown."""

    debug_log(f"DEBUG: Context generation prompt:\n{prompt}")

    # Get provider
    provider_name = get_config("provider", "openai")
    try:
        provider = create_provider(provider_name)
    except Exception as e:
        debug_log(f"ERROR: Failed to create provider '{provider_name}': {str(e)}")
        return

    # Get parameters
    max_tokens = int(get_config("max_tokens", "2000"))
    temperature = float(get_config("temperature", "0.7"))
    model = provider.get_model()

    # System message for context generation
    system_message = "You are a helpful assistant that analyzes projects and creates concise context summaries. Use the available tools to explore the project structure and files."

    # Create messages without any history
    try:
        messages = provider.create_messages(system_message, [], prompt)
    except Exception as e:
        debug_log(f"ERROR: Failed to create messages: {str(e)}")
        return

    # Get tool definitions
    tools = get_tool_definitions()

    # Iterative tool calling loop
    max_iterations = 20
    context_content = ""

    for iteration in range(max_iterations):
        debug_log(f"INFO: Context generation iteration {iteration + 1}/{max_iterations}")

        try:
            response_content = ""
            finish_reason = None
            tool_calls = None

            # Stream the response
            for content, reason, calls in provider.stream_chat(
                messages, model, temperature, max_tokens, tools=tools
            ):
                if content:
                    response_content += content
                if reason:
                    finish_reason = reason
                if calls:
                    tool_calls = calls

            debug_log(f"DEBUG: Iteration {iteration + 1} - finish_reason={finish_reason}, tool_calls={tool_calls is not None}")

            # If we got content, save it
            if response_content:
                context_content = response_content

            # If no tool calls, we're done
            if finish_reason == "stop" or not tool_calls:
                debug_log(f"INFO: Context generation complete ({len(context_content)} chars)")
                break

            # Execute tool calls
            if tool_calls:
                debug_log(f"INFO: Executing {len(tool_calls)} tool calls")

                # For Anthropic, we need to add the assistant message with ALL tool_use blocks first
                if provider_name == "anthropic" and isinstance(messages, dict) and "messages" in messages:
                    # Build assistant message with text + all tool_use blocks
                    assistant_content = []
                    if response_content.strip():
                        assistant_content.append({"type": "text", "text": response_content})

                    for tool_call in tool_calls:
                        assistant_content.append({
                            "type": "tool_use",
                            "id": tool_call["id"],
                            "name": tool_call["name"],
                            "input": tool_call["arguments"]
                        })

                    messages["messages"].append({
                        "role": "assistant",
                        "content": assistant_content
                    })

                # Execute each tool and collect results
                tool_results = []
                for tool_call in tool_calls:
                    # Handle different tool_call formats
                    if "function" in tool_call:
                        # OpenAI format: {"id": ..., "type": "function", "function": {"name": ..., "arguments": "{...}"}}
                        tool_name = tool_call.get("function", {}).get("name", "")
                        tool_args_str = tool_call.get("function", {}).get("arguments", "{}")
                        try:
                            tool_args = json.loads(tool_args_str)
                        except json.JSONDecodeError:
                            tool_args = {}
                    else:
                        # Anthropic format: {"id": ..., "name": ..., "arguments": {...}}
                        tool_name = tool_call.get("name", "")
                        tool_args = tool_call.get("arguments", {})

                    debug_log(f"INFO: Executing tool: {tool_name}")
                    result = execute_tool(tool_name, tool_args)
                    tool_id = tool_call.get("id", "")

                    tool_results.append((tool_id, tool_name, tool_args, result))

                # Add tool results to messages - format depends on provider
                if provider_name == "anthropic":
                    # Anthropic format - add ONE user message with ALL tool_result blocks
                    if isinstance(messages, dict) and "messages" in messages:
                        tool_result_content = []
                        for tool_id, tool_name, tool_args, tool_result in tool_results:
                            tool_result_content.append({
                                "type": "tool_result",
                                "tool_use_id": tool_id,
                                "content": tool_result
                            })

                        messages["messages"].append({
                            "role": "user",
                            "content": tool_result_content
                        })
                else:
                    # OpenAI and other formats - add each tool call and result individually
                    if isinstance(messages, list):
                        for tool_id, tool_name, tool_args, tool_result in tool_results:
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
                            messages.append({
                                "role": "tool",
                                "tool_call_id": tool_id,
                                "content": tool_result
                            })

        except Exception as e:
            debug_log(f"ERROR: Failed during context generation: {str(e)}")
            return

    if not context_content:
        debug_log("ERROR: No context content generated")
        return

    # Clean up the content - remove any conversational wrapper
    # Extract just the markdown if wrapped in ```markdown blocks
    import re
    markdown_match = re.search(r'```markdown\n(.*?)\n```', context_content, re.DOTALL)
    if markdown_match:
        context_content = markdown_match.group(1)

    # Add timestamp metadata
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    metadata = f"<!-- Context generated at: {timestamp} -->\n\n"
    full_context = metadata + context_content.strip()

    # Save the context file
    try:
        # Create directory if it doesn't exist
        os.makedirs(vim_dir, exist_ok=True)

        with open(context_file, "w", encoding="utf-8") as f:
            f.write(full_context)
        debug_log(f"INFO: Context saved to {context_file}")
    except Exception as e:
        debug_log(f"ERROR: Failed to save context: {str(e)}")
        return

    debug_log("INFO: Context generation complete")
