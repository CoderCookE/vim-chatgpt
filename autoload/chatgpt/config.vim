" ChatGPT Configuration Management
" This file handles default configuration values

function! chatgpt#config#setup() abort
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

  " Require plan approval before tool execution
  if !exists("g:chat_gpt_require_plan_approval")
    let g:chat_gpt_require_plan_approval = 1
  endif

  " Require individual tool approval (prompts user for each new tool)
  if !exists("g:chat_gpt_require_tool_approval")
    let g:chat_gpt_require_tool_approval = 1
  endif

  " Session mode (persistent chat history)
  if !exists("g:chat_gpt_session_mode")
    let g:chat_gpt_session_mode = 1
  endif

  " Conversation history compaction settings
  if !exists("g:chat_gpt_summary_compaction_size")
    let g:chat_gpt_summary_compaction_size = 76800  " 76KB
  endif

  if !exists("g:chat_gpt_recent_history_size")
    let g:chat_gpt_recent_history_size = 30480  " 30KB
  endif

  " Provider selection
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

  " Prompt templates
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

  " Personas
  let g:gpt_personas = {
  \ "default": 'You are a helpful expert programmer we are working together to solve complex coding challenges, and I need your help. Please make sure to wrap all code blocks in ``` annotate the programming language you are using.',
  \}

  if exists('g:chat_gpt_custom_persona')
    call extend(g:gpt_personas, g:chat_gpt_custom_persona)
  endif
endfunction
