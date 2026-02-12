" ChatGPT Vim Plugin
"
" Ensure Python3 is available
if !has('python3')
  echo "Python 3 support is required for ChatGPT plugin"
  finish
endif

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

" Google (Gemini) configuration
if !exists("g:google_api_key")
  let g:google_api_key = ''
endif

if !exists("g:google_model")
  let g:google_model = 'gemini-2.0-flash-exp'
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


# Tools framework for function calling
def get_tool_definitions():
    """Define available tools for AI agents"""
    return [
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
        }
    ]


def execute_tool(tool_name, arguments):
    """Execute a tool with given arguments"""
    import subprocess
    import glob as glob_module

    try:
        if tool_name == "find_in_file":
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

    def stream_chat(self, messages, model, temperature, max_tokens):
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

        response = requests.post(
            'https://api.anthropic.com/v1/messages',
            headers=headers,
            json=payload,
            stream=True
        )

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
        """Validate Google configuration"""
        if not self.config.get('api_key'):
            raise ValueError("Google API key required. Set GOOGLE_API_KEY or g:google_api_key")

    def get_model(self):
        """Get the model name from config"""
        return self.config.get('model', 'gemini-2.0-flash-exp')

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

    def stream_chat(self, messages, model, temperature, max_tokens):
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

        for line in response.iter_lines():
            if not line:
                continue

            try:
                chunk = json.loads(line)
                if 'candidates' in chunk and chunk['candidates']:
                    candidate = chunk['candidates'][0]
                    if 'content' in candidate and 'parts' in candidate['content']:
                        for part in candidate['content']['parts']:
                            text = part.get('text', '')
                            if text:
                                yield (text, '', None)
                    finish_reason = candidate.get('finishReason', '')
                    if finish_reason and finish_reason != 'STOP':
                        yield ('', finish_reason, None)
                    elif finish_reason == 'STOP':
                        yield ('', 'stop', None)
            except json.JSONDecodeError:
                continue


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

    def stream_chat(self, messages, model, temperature, max_tokens):
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

    def stream_chat(self, messages, model, temperature, max_tokens):
        """Stream chat completion from OpenRouter"""
        url = f"{self.config['base_url']}/chat/completions"

        headers = {
            'Authorization': f'Bearer {self.config["api_key"]}',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://github.com/CoderCookE/vim-chatgpt',
        }

        payload = {
            'model': model,
            'messages': messages,
            'temperature': temperature,
            'max_tokens': max_tokens,
            'stream': True
        }

        response = requests.post(url, headers=headers, json=payload, stream=True)

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
            'model': safe_vim_eval('g:anthropic_model')
        }
        return AnthropicProvider(config)

    elif provider_name == 'google':
        config = {
            'api_key': os.getenv('GOOGLE_API_KEY') or safe_vim_eval('g:google_api_key'),
            'model': safe_vim_eval('g:google_model')
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

  # Get model from provider
  model = provider.get_model()

  # Build system message
  personas = dict(vim.eval('g:gpt_personas'))
  persona = str(vim.eval('g:chat_persona'))
  system_message = f"{personas[persona]} {resp}"

  # Session history management
  history = []
  session_id = 'gpt-persistent-session' if int(vim.eval('exists("g:chat_gpt_session_mode") ? g:chat_gpt_session_mode : 1')) == 1 else None

  # If session id exists and is in vim buffers
  if session_id:
    buffer = []

    for b in vim.buffers:
       # If the buffer name matches the session id
      if session_id in b.name:
        buffer = b[:]
        break

    # Read the lines from the buffer
    history_text = "\n".join(buffer).split('\n\n>>>')
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

  # Display initial prompt in session
  if session_id:
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
    max_tool_iterations = 5  # Prevent infinite loops
    tool_iteration = 0

    while tool_iteration < max_tool_iterations:
      tool_calls_to_process = None

      for content, finish_reason, tool_calls in provider.stream_chat(messages, model, temperature, max_tokens, tools):
        # Display content as it streams
        if content:
          vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(content.replace("'", "''"), chunk_session_id))
          vim.command("redraw")

        # Handle finish
        if finish_reason:
          if tool_calls:
            tool_calls_to_process = tool_calls
          else:
            vim.command("call DisplayChatGPTResponse('', '{0}', '{1}')".format(finish_reason.replace("'", "''"), chunk_session_id))
            vim.command("redraw")

      # If no tool calls, we're done
      if not tool_calls_to_process:
        break

      # Execute tools and add results to messages
      tool_iteration += 1
      vim.command("call DisplayChatGPTResponse('\\n\\n[Using tools...]\\n', '', '{0}')".format(chunk_session_id))
      vim.command("redraw")

      for tool_call in tool_calls_to_process:
        tool_name = tool_call['name']
        tool_args = tool_call['arguments']
        tool_id = tool_call.get('id', 'unknown')

        # Execute the tool
        tool_result = execute_tool(tool_name, tool_args)

        # Display tool usage in session
        tool_display = f"\\n[Tool: {tool_name}({json.dumps(tool_args)})]\\n{tool_result}\\n"
        vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(tool_display.replace("'", "''"), chunk_session_id))
        vim.command("redraw")

        # Add tool call and result to messages for next iteration
        # Format depends on provider
        if provider_name == 'openai':
          # OpenAI format
          if isinstance(messages, list):
            # Add assistant message with tool calls
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
          # Anthropic format
          if isinstance(messages, dict) and 'messages' in messages:
            # Add user message with tool result
            messages['messages'].append({
              "role": "user",
              "content": [{
                "type": "tool_result",
                "tool_use_id": tool_id,
                "content": tool_result
              }]
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
