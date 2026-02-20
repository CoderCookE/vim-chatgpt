# Migration Guide: vim-chatgpt → vim-llm-agent

## Overview

This plugin has been renamed from `vim-chatgpt` to `vim-llm-agent` to better reflect its capabilities as a full-featured LLM agent supporting multiple providers (OpenAI, Anthropic, Google, Ollama, OpenRouter).

**Full backwards compatibility is maintained** - all old configuration variables and directory names continue to work.

## What Changed

### Repository Name
- **Old:** `vim-chatgpt`
- **New:** `vim-llm-agent`

### Configuration Variables
All configuration variables now use the `g:llm_agent_` prefix, but **old `g:chat_gpt_` variables still work as fallbacks**.

| Old Variable | New Variable | Description |
|-------------|--------------|-------------|
| `g:chat_gpt_api_key` | `g:llm_agent_api_key` | API key for your provider |
| `g:chat_gpt_model` | `g:llm_agent_model` | Model to use |
| `g:chat_gpt_provider` | `g:llm_agent_provider` | Provider (openai, anthropic, etc.) |
| `g:chat_gpt_max_tokens` | `g:llm_agent_max_tokens` | Max tokens in response |
| `g:chat_gpt_temperature` | `g:llm_agent_temperature` | Sampling temperature |
| `g:chat_gpt_session_mode` | `g:llm_agent_session_mode` | Enable persistent sessions |
| `g:chat_gpt_enable_tools` | `g:llm_agent_enable_tools` | Enable tool execution |
| `g:chat_gpt_require_plan_approval` | `g:llm_agent_require_plan_approval` | Require plan approval |
| `g:chat_gpt_require_tool_approval` | `g:llm_agent_require_tool_approval` | Require tool approval |
| `g:chat_gpt_log_level` | `g:llm_agent_log_level` | Logging verbosity |
| `g:chat_gpt_recent_history_size` | `g:llm_agent_recent_history_size` | Recent history window size |

### Project Directory
- **Old:** `.vim-chatgpt/`
- **New:** `.vim-llm-agent/`
- **Fallback:** If `.vim-chatgpt/` exists, it will be used automatically

### Commands
All commands remain unchanged and continue to work:

| Command | Description |
|---------|-------------|
| `:Ask` | Main chat interface |
| `:GenerateCommit` | Generate git commit message |
| `:GptGenerateContext` | Generate project context |
| `:GptGenerateSummary` | Generate conversation summary |
| `:GptBe` | Set agent persona |

**Note:** The `Gpt` prefix in commands is kept for backwards compatibility and brevity.

## Migration Options

### Option 1: No Changes Required (Recommended)
Your existing configuration continues to work. No action needed.

```vim
" This continues to work indefinitely
let g:chat_gpt_api_key = $OPENAI_API_KEY
let g:chat_gpt_model = 'gpt-4'
```

### Option 2: Gradual Migration
Update variables at your own pace. Mix and match old and new:

```vim
" Mix old and new - both work
let g:llm_agent_api_key = $ANTHROPIC_API_KEY
let g:chat_gpt_model = 'claude-3-5-sonnet-20241022'
```

### Option 3: Full Migration
Update all variables to new names:

```vim
" New configuration style
let g:llm_agent_api_key = $ANTHROPIC_API_KEY
let g:llm_agent_model = 'claude-3-5-sonnet-20241022'
let g:llm_agent_provider = 'anthropic'
let g:llm_agent_max_tokens = 8192
let g:llm_agent_temperature = 0.7
let g:llm_agent_enable_tools = 1
let g:llm_agent_require_plan_approval = 1
```

## Project Directory Migration

### Automatic Migration
The plugin automatically handles directory migration:

1. First checks for `.vim-llm-agent/`
2. Falls back to `.vim-chatgpt/` if it exists
3. Creates `.vim-llm-agent/` for new projects

### Manual Migration (Optional)
To migrate your existing project data:

```bash
# In your project directory
mv .vim-chatgpt .vim-llm-agent
```

Or keep using `.vim-chatgpt/` - it will continue to work.

## Installation

### Update Plugin Manager Config

**vim-plug:**
```vim
" Old
Plug 'username/vim-chatgpt'

" New
Plug 'username/vim-llm-agent'
```

**Vundle:**
```vim
" Old
Plugin 'username/vim-chatgpt'

" New
Plugin 'username/vim-llm-agent'
```

**Pathogen:**
```bash
# Old
cd ~/.vim/bundle
git clone https://github.com/username/vim-chatgpt.git

# New
cd ~/.vim/bundle
mv vim-chatgpt vim-llm-agent
cd vim-llm-agent
git remote set-url origin https://github.com/username/vim-llm-agent.git
```

## Deprecation Timeline

**No deprecation planned.** The old variable names and directory names will continue to work indefinitely to ensure backwards compatibility.

## Questions?

If you have any issues with the migration, please open an issue on GitHub.
