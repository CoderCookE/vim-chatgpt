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
        Yields: (content_delta, finish_reason)
        """
        raise NotImplementedError("Subclasses must implement stream_chat()")


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

    def stream_chat(self, messages, model, temperature, max_tokens):
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

        # Handle different model parameter requirements
        if model.startswith('gpt-'):
            payload['temperature'] = temperature
            payload['max_tokens'] = max_tokens
        else:
            # O-series models use different parameters
            payload['max_completion_tokens'] = max_tokens

        response = requests.post(url, headers=headers, json=payload, stream=True)

        # Parse Server-Sent Events stream
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
                        yield (content, '')
                    if finish_reason:
                        yield ('', finish_reason)
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

    def stream_chat(self, messages, model, temperature, max_tokens):
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

        response = requests.post(
            'https://api.anthropic.com/v1/messages',
            headers=headers,
            json=payload,
            stream=True
        )

        # Parse Server-Sent Events stream
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
                if chunk.get('type') == 'content_block_delta':
                    content = chunk.get('delta', {}).get('text', '')
                    if content:
                        yield (content, '')
                elif chunk.get('type') == 'message_delta':
                    finish_reason = chunk.get('delta', {}).get('stop_reason', '')
                    if finish_reason:
                        yield ('', 'stop')
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
                                yield (text, '')
                    finish_reason = candidate.get('finishReason', '')
                    if finish_reason and finish_reason != 'STOP':
                        yield ('', finish_reason)
                    elif finish_reason == 'STOP':
                        yield ('', 'stop')
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
                    yield (content, '')
                if done:
                    yield ('', 'stop')
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
                        yield (content, '')
                    if finish_reason:
                        yield ('', finish_reason)
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

  # Stream response using provider
  try:
    chunk_session_id = session_id if session_id else 'gpt-response'

    for content, finish_reason in provider.stream_chat(messages, model, temperature, max_tokens):
      # Call DisplayChatGPTResponse with the finish_reason or content
      if finish_reason:
        vim.command("call DisplayChatGPTResponse('', '{0}', '{1}')".format(finish_reason.replace("'", "''"), chunk_session_id))
      elif content:
        vim.command("call DisplayChatGPTResponse('{0}', '', '{1}')".format(content.replace("'", "''"), chunk_session_id))

      vim.command("redraw")
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
