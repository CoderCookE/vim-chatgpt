# ChatGPT Vim Plugin

This Vim plugin brings the power of AI language models into your Vim editor, enabling you to request code explanations or improvements directly within Vim. With this plugin, you can effortlessly highlight code snippets and ask AI to explain, review, or rewrite them, with the option to include additional context for better results.

**Supported Providers:**
- OpenAI (ChatGPT, GPT-4, etc.)
- Anthropic (Claude)
- Google (Gemini)
- Ollama (local models)
- OpenRouter (unified API for multiple providers)

## Prerequisites

1) Vim with Python3 support.
2) An API key from your chosen provider (OpenAI, Anthropic, Google, or OpenRouter).

## Installation

### 1. Install Python Dependencies

The plugin requires only the `requests` library:
```bash
pip install requests
```

**Important:** Vim must be able to import `requests` from its Python interpreter. If you get a `ModuleNotFoundError: No module named 'requests'` error, see the [Troubleshooting](#troubleshooting) section below.

### 2. Install the Plugin

Copy the `chatgpt.vim` file to your Vim plugin directory. If you're using [vim-pathogen](https://github.com/tpope/vim-pathogen), add the `chatgpt` directory to your `bundle` directory.

### 3. Choose Your AI Provider

The plugin defaults to OpenAI for backward compatibility, but you can use any supported provider:

#### OpenAI (Default)

Get your API key from: https://platform.openai.com/account/api-keys

```bash
export OPENAI_API_KEY='sk-...'
```

Or in your `.vimrc`:
```vim
let g:openai_api_key='sk-...'
let g:chat_gpt_model='gpt-4o'  " Optional: specify model
```

**With Proxy:**
```bash
export OPENAI_PROXY="http://localhost:1087"
# or
export OPENAI_API_BASE='https://openai.xxx.cloud/v1'
```

**Azure OpenAI:**
```vim
let g:api_type = 'azure'
let g:chat_gpt_key = 'your_azure_chatgpt_api'
let g:azure_endpoint = 'your_azure_endpoint'
let g:azure_deployment = 'your_azure_deployment'
let g:azure_api_version = '2023-03-15-preview'
```

#### Anthropic (Claude)

Get your API key from: https://console.anthropic.com/

```bash
export ANTHROPIC_API_KEY='sk-ant-...'
```

Or in your `.vimrc`:
```vim
let g:chat_gpt_provider = 'anthropic'
let g:anthropic_api_key = 'sk-ant-...'
let g:anthropic_model = 'claude-sonnet-4-5-20250929'  " Optional
```

#### Google (Gemini)

Get your API key from: https://makersuite.google.com/app/apikey

```bash
export GOOGLE_API_KEY='...'
```

Or in your `.vimrc`:
```vim
let g:chat_gpt_provider = 'google'
let g:google_api_key = '...'
let g:google_model = 'gemini-2.0-flash-exp'  " Optional
```

#### Ollama (Local Models)

Install Ollama from: https://ollama.ai

```vim
let g:chat_gpt_provider = 'ollama'
let g:ollama_model = 'llama3.2'  " or codellama, mistral, etc.
let g:ollama_base_url = 'http://localhost:11434'  " Optional
```

#### OpenRouter (Multi-Provider)

Get your API key from: https://openrouter.ai/keys

```bash
export OPENROUTER_API_KEY='sk-or-...'
```

Or in your `.vimrc`:
```vim
let g:chat_gpt_provider = 'openrouter'
let g:openrouter_api_key = 'sk-or-...'
let g:openrouter_model = 'anthropic/claude-3.5-sonnet'  " Choose any available model
```

## Customization

### Provider Configuration

```vim
" Select your AI provider (default: 'openai')
let g:chat_gpt_provider = 'openai'  " Options: 'openai', 'anthropic', 'google', 'ollama', 'openrouter'

" Provider-specific models (optional - defaults shown)
let g:chat_gpt_model = 'gpt-4o'                           " For OpenAI
let g:anthropic_model = 'claude-sonnet-4-5-20250929'      " For Anthropic
let g:google_model = 'gemini-2.0-flash-exp'               " For Google
let g:ollama_model = 'llama3.2'                           " For Ollama
let g:openrouter_model = 'anthropic/claude-3.5-sonnet'    " For OpenRouter
```

### General Options

```vim
let g:chat_gpt_max_tokens=2000
let g:chat_gpt_session_mode=1
let g:chat_gpt_temperature = 0.7
let g:chat_gpt_lang = 'Chinese'
let g:chat_gpt_split_direction = 'vertical'
let g:split_ratio=4
let g:chat_gpt_enable_tools=1
```

**Option Details:**

 - **g:chat_gpt_provider**: Select which AI provider to use. Options: `'openai'`, `'anthropic'`, `'google'`, `'ollama'`, `'openrouter'`. Default: `'openai'`
 - **g:chat_gpt_max_tokens**: Maximum number of tokens in the AI response. Default: 2000
 - **g:chat_gpt_model**: Model name for OpenAI (e.g., `'gpt-4o'`, `'gpt-3.5-turbo'`, `'o1'`). Note: When using other providers, use their respective model variables instead.
 - **g:chat_gpt_session_mode**: Maintain persistent conversation history. Default: 1 (on)
 - **g:chat_gpt_temperature**: Controls response randomness (0.0-1.0). Higher = more creative, lower = more focused. Default: 0.7
 - **g:chat_gpt_lang**: Request responses in a specific language (e.g., `'Chinese'`, `'Spanish'`)
 - **g:chat_gpt_split_direction**: Window split direction: `'vertical'` or `'horizontal'`. Default: `'horizontal'`
 - **g:split_ratio**: Split window size ratio. If set to 4, the window will be 1/4 of the screen. Default: 3
 - **g:chat_gpt_enable_tools**: Enable AI tool/function calling capabilities (allows AI to search files, read files, etc.). Default: 1 (enabled). Supported by OpenAI and Anthropic providers.
 - **g:chat_gpt_require_plan_approval**: Require user approval before executing tool-based plans. When enabled, the AI will present a plan first, wait for approval, then execute tools in batches of 3 iterations with review points. Default: 1 (enabled).
 - **g:chat_gpt_summary_compaction_size**: Trigger summary regeneration after this many bytes of new conversation since last summary. Default: 51200 (50KB). This implements automatic conversation compaction.
 - **g:chat_gpt_recent_history_size**: Keep this many bytes of recent conversation uncompressed. Older content gets compressed into summary. Default: 20480 (20KB). Controls the sliding window size.

## AI Tools & Function Calling

The plugin includes a powerful tools framework that allows AI agents to interact with your codebase. When enabled, the AI can autonomously use tools to search files, read code, and find information to better answer your questions.

### Adaptive Planning Workflow

When `g:chat_gpt_require_plan_approval` is enabled (default), the AI follows an **adaptive planning workflow** that adjusts based on results:

1. **Initial Plan Creation**: The AI analyzes your request and creates a step-by-step plan
2. **User Approval**: You review and approve the initial plan
3. **Execution & Reflection**: The AI executes tools one step at a time, evaluating results
4. **Adaptive Revision**: If results are unexpected or require a different approach:
   - AI presents a **REVISED PLAN** explaining what changed and why
   - You approve or reject the revision
   - Execution continues with the new plan
5. **Natural Completion**: The AI decides when the task is complete and summarizes results

**Key Benefits:**
- **Adaptive**: Plans can change based on what the AI discovers
- **Transparent**: You see and approve any plan changes
- **Efficient**: No artificial batch limits - AI works until done
- **Flexible**: Handles unexpected situations (missing files, different structure, etc.)

**Disable plan approval** (tools execute immediately without confirmation):
```vim
let g:chat_gpt_require_plan_approval = 0
```

### Available Tools

**Project Exploration Tools:**
- **get_working_directory**: Get the current working directory path
- **list_directory**: List files and directories in a specified path

**Read-Only Tools:**
- **find_in_file**: Search for text patterns in a specific file using grep
- **find_file_in_project**: Find files by name pattern in the current project
- **read_file**: Read the contents of a file (up to specified line limit)

**File Modification Tools:**
- **create_file**: Create a new file with specified content
- **open_file**: Open a file in the current Vim buffer (supports splits)
- **edit_file**: Edit an existing file by replacing specific content
- **edit_file_lines**: Edit specific line ranges in a file (efficient for large files)

### How It Works

When you ask the AI a question or give it a task, it can automatically:
1. **Get the working directory** using `get_working_directory`
2. **Explore project structure** using `list_directory`
3. **Search for relevant files** using `find_file_in_project`
4. **Read file contents** using `read_file`
5. **Find specific patterns** in code using `find_in_file`
6. **Create new files** using `create_file`
7. **Open files in Vim** using `open_file`
8. **Edit existing files** using `edit_file` or `edit_file_lines`
9. Use that information to provide accurate answers or complete tasks

### Example Usage

**Exploring the Project:**
```vim
:Ask "What is the structure of this project?"
```

The AI might:
1. Use `get_working_directory` to see the project root
2. Use `list_directory` to explore the top-level structure
3. Use `list_directory` on subdirectories to understand organization
4. Provide a summary of the project layout and key directories

**Finding Information:**
```vim
:Ask "Where is the user authentication logic implemented?"
```

The AI might:
1. Use `find_file_in_project` to locate files matching `*auth*`
2. Use `read_file` to examine relevant files
3. Use `find_in_file` to search for specific functions
4. Provide an answer based on the actual code

**Creating Files:**
```vim
:Ask "Create a new test file for the authentication module"
```

The AI might:
1. Use `find_file_in_project` to locate the authentication module
2. Use `read_file` to understand the code structure
3. Use `create_file` to create a new test file with appropriate test cases
4. Use `open_file` to open the new test file in Vim

**Editing Files:**
```vim
:Ask "Add error handling to the login function in auth.py"
```

The AI might:
1. Use `find_file_in_project` to locate `auth.py`
2. Use `read_file` to read the current implementation
3. Use `edit_file` to add try/catch blocks and error handling
4. Confirm the changes were made successfully

**Editing Large Files by Line Number:**
```vim
:Ask "Replace lines 45-60 in config.py with updated settings"
```

The AI might:
1. Use `read_file` to view the current content and line numbers
2. Use `edit_file_lines` to efficiently replace the specific line range
3. Confirm the changes without reading the entire file into memory

**Adaptive Planning Example:**
```vim
:Ask "Refactor the authentication module to use JWT tokens"
```

With `g:chat_gpt_require_plan_approval` enabled, the workflow adapts to discoveries:

1. **AI presents initial plan:**
   ```
   I'll refactor the authentication to use JWT tokens:
   1. find_file_in_project to locate auth files
   2. read_file to understand current implementation
   3. create_file to add JWT utility functions
   4. edit_file to update login/logout functions
   5. edit_file to update middleware
   ============================================================
   INITIAL PLAN FOR APPROVAL:
   ============================================================
   ```

2. **You approve:** `Approve plan? [y]es to proceed, [n]o to cancel: y`

3. **AI executes and discovers something unexpected:**
   - Finds auth files in unexpected location
   - Reads current implementation
   - Discovers auth is split across multiple modules

4. **AI presents revised plan:**
   ```
   === REVISED PLAN ===

   I discovered the auth system is split across 3 modules:
   - auth/session.py (session management)
   - auth/tokens.py (already has basic token support!)
   - middleware/auth.py (request validation)

   Revised approach:
   1. Extend existing auth/tokens.py with JWT functions
   2. Update session.py to use JWT instead of sessions
   3. Update middleware to validate JWT tokens

   ============================================================
   REVISED PLAN FOR APPROVAL:
   ============================================================
   ```

5. **You approve revision:** `Approve revised plan? [y]es to proceed, [n]o to cancel: y`

6. **AI continues with adapted approach** until complete

7. **AI summarizes:** "Successfully refactored auth to use JWT tokens. Modified 3 files..."

### Supported Providers

Tools are currently supported by:
- **OpenAI** (GPT-4, GPT-4o, etc.)
- **Anthropic** (Claude Sonnet, Claude Opus)

### Disabling Tools

If you prefer the AI to not access your files, disable tools:
```vim
let g:chat_gpt_enable_tools = 0
```

## Usage

The plugin provides several commands to interact with AI:

- `Ask`: Ask a question
- `Rewrite`: Ask the model to rewrite a code snippet more idiomatically
- `Review`: Request a code review
- `Document`: Request documentation for a code snippet
- `Explain`: Ask the model to explain how a code snippet works
- `Test`: Ask the model to write a test for a code snippet
- `Fix`: Ask the model to fix an error in a code snippet

Each command takes a context as an argument, which can be any text describing the problem or question more specifically.

## Example

To ask the model to review a code snippet, visually select the code and execute the `Review` command:

```vim
:'<,'>Review 'Can you review this code for me?'
```

The model's response will be displayed in a new buffer.

You can also use `GenerateCommit` command to generate a commit message for the current buffer.

## Conversation History

When `g:chat_gpt_session_mode` is enabled (default), the plugin maintains conversation history to provide context across multiple interactions.

### Storage Location

Conversation history is automatically saved to `.vim-chatgpt/history.txt` in your project directory. This allows:
- **Persistent conversations** across Vim sessions
- **Project-specific history** - each project has its own conversation log
- **Easy review** - you can view or edit the history file directly

### How It Works

1. When you start a conversation, the plugin loads previous history from `.vim-chatgpt/history.txt`
2. As you interact with the AI, responses are automatically appended to the history file
3. The AI has access to previous conversation context (up to token limits)
4. History is displayed in a Vim buffer and simultaneously saved to disk

### Managing History

**View history file:**
```vim
:e .vim-chatgpt/history.txt
```

**Clear history:**
```bash
rm .vim-chatgpt/history.txt
```

**Disable session mode** (no history saved):
```vim
let g:chat_gpt_session_mode = 0
```

## Conversation Summary & Preferences

The plugin uses a **conversation compaction strategy** to maintain context while keeping token usage bounded. As conversations grow, older messages are compressed into a summary, while recent messages remain fully accessible.

### How Compaction Works

**The Strategy:**
1. **System Message = Context + Summary + Recent History**
   - Project context (always loaded)
   - Conversation summary (compressed older conversation)
   - Last ~20KB of recent uncompressed conversation

2. **Automatic Compaction:**
   - When conversation grows by 50KB (configurable), the summary is regenerated
   - Content from the last cutoff point to current position (minus recent window) gets compressed into the summary
   - A cutoff marker is stored in the summary metadata
   - Only messages after the cutoff are loaded as full history

3. **Result:**
   - Bounded token usage (summary + recent history is fixed size)
   - Full context preserved (older parts compressed in summary)
   - Automatic sliding window as conversations grow

### Manual Summary Generation

While summaries are generated automatically through compaction, you can manually trigger an update:

```vim
:GptGenerateSummary
```

The AI will:
1. Read the conversation history from `.vim-chatgpt/history.txt`
2. Compress content from last cutoff to current position (minus recent window)
3. Identify key topics, decisions, and user preferences
4. Merge with existing summary if present
5. Update `.vim-chatgpt/summary.md` with new cutoff metadata

### Summary File Format

The summary file (`.vim-chatgpt/summary.md`) contains:

**Metadata Header:**
```markdown
<!-- SUMMARY_METADATA
cutoff_byte: 51200
last_updated: 2024-01-15
-->
```

**Summary Content:**
- **Key Topics Discussed**: Main subjects and decisions made
- **Important Information to Remember**: Critical details and context
- **User Preferences**: Inferred preferences such as:
  - Coding style preferences (e.g., "prefers functional programming")
  - Tool or technology preferences (e.g., "uses TypeScript over JavaScript")
  - Communication preferences (e.g., "prefers concise explanations")
  - Project-specific conventions
- **Action Items**: Pending tasks or future work

The `cutoff_byte` metadata tracks which portion of history has been compressed, enabling the sliding window strategy.

### Configuration

**Configure compaction behavior:**
```vim
" Trigger summary update after this many bytes of new conversation
let g:chat_gpt_summary_compaction_size = 51200  " Default: 50KB

" Keep this much recent history uncompressed
let g:chat_gpt_recent_history_size = 20480  " Default: 20KB
```

### How It Works

**Automatic Compaction:**
1. New conversation gets written to `.vim-chatgpt/history.txt`
2. When new content since last summary exceeds `g:chat_gpt_summary_compaction_size`:
   - AI reads existing summary + new content to compact
   - Generates updated summary including key topics, decisions, and preferences
   - Stores cutoff position in summary metadata
3. On next conversation:
   - Summary loaded into system message (compressed older content)
   - Only recent history after cutoff loaded as full messages
   - Token usage stays bounded

**Manual Updates:**
- Run `:GptGenerateSummary` anytime to manually trigger compaction
- Edit `.vim-chatgpt/summary.md` to manually adjust preferences
- The summary is automatically loaded into every conversation's system message

### Benefits

- **Bounded Token Usage**: Summary + recent history keeps context size predictable
- **Full Context Preserved**: Older conversations compressed, not lost
- **Remembers Preferences**: AI learns and retains your coding style, tool preferences, and communication style
- **Automatic Maintenance**: Compaction happens automatically as conversations grow
- **Long-Running Conversations**: Have extended discussions without hitting token limits

**Example:**
As you work on a project over days/weeks:
1. Day 1: Discuss architecture, make decisions (saved in history)
2. Day 3: History grows, gets compacted into summary
3. Day 7: AI still remembers Day 1 decisions (from summary) + recent conversation (full history)
4. Your preferences (e.g., "prefers TypeScript", "uses Jest") persist across all sessions

## Project Context

The plugin can maintain project context to make the AI smarter about your specific codebase. This context is automatically loaded into every conversation.

### Generating Project Context

Run this command to have the AI analyze your project and create a context file:

```vim
:GptGenerateContext
```

The AI will:
1. Explore your project using available tools (list directories, read README, package files, etc.)
2. Analyze the project structure and technology stack
3. Create a context summary at `.vim-chatgpt/context.md`

### Context File Structure

The generated context file contains:
- **Project Name**: Identified from the directory or metadata
- **Type**: Kind of project (web app, library, CLI tool, etc.)
- **Purpose**: What the project does
- **Tech Stack**: Technologies, frameworks, and key dependencies
- **Structure**: Overview of directory layout
- **Key Files**: Important entry points and configuration

### Manual Editing

You can manually edit `.vim-chatgpt/context.md` to:
- Add specific details the AI should know
- Highlight important patterns or conventions
- Document architectural decisions
- Note areas that need work

### Example Context File

```markdown
# Project: vim-chatgpt

## Type
Vim plugin

## Purpose
Brings AI language model capabilities into Vim editor for code assistance

## Tech Stack
- VimScript
- Python 3
- Multiple AI providers (OpenAI, Anthropic, Google, Ollama, OpenRouter)

## Structure
- plugin/chatgpt.vim - Main plugin file with VimScript and embedded Python
- README.md - Documentation

## Key Files
- chatgpt.vim - Contains all functionality including provider abstraction and tool framework
```

### How It Works

When you start any AI conversation:
1. Plugin checks for `.vim-chatgpt/context.md` in the current working directory
2. If found, the context is loaded into the system message
3. The AI has this context for every request in that project

This means when you ask "What is this project?", the AI already knows!

## .vim-chatgpt Directory Structure

All plugin files are stored in the `.vim-chatgpt/` directory in your project root:

```
.vim-chatgpt/
├── context.md     # Project context (auto-generated or manual)
├── summary.md     # Conversation summary & user preferences
└── history.txt    # Full conversation history
```

**Files are automatically loaded:**
- `context.md` - Loaded into every conversation's system message
- `summary.md` - Loaded into every conversation's system message
- `history.txt` - Loaded for conversation continuity (respects token limits)

**Manual management:**
```bash
# View files
ls .vim-chatgpt/

# Edit context or summary
vi .vim-chatgpt/context.md
vi .vim-chatgpt/summary.md

# Clear history
rm .vim-chatgpt/history.txt

# Start fresh (removes all plugin data)
rm -rf .vim-chatgpt/
```

## Customization

### Custom Personas

To introduce custom personas into the system context, simply define them in your `vimrc` file:

```vim
let g:chat_gpt_custom_persona = {'neptune': 'You are an expert in all things Graph databases'}
```

With the custom persona defined, you can switch to it using the following command:

```vim
:GptBe neptune
```

If you try to switch to a non-existent persona, the plugin will default to the preconfigured `default` persona.

You can also set a persona to be loaded by default when Vim starts, by setting it in your `vimrc`:

```vim
let g:chat_persona='neptune'
```

### Commands

You can add custom prompt templates using the `chat_gpt_custom_prompts` variable. This should be a dictionary mapping prompt keys to prompt templates.

For example, to add a 'debug' prompt, you could do:

```vim
let g:chat_gpt_custom_prompts = {'debug': 'Can you help me debug this code?'}
```

Afterwards, you can use the `Debug` command like any other command:

```vim
:'<,'>Debug 'I am encountering an issue where...'
```

## Mappings

This plugin exposes a binding to open a menu for options on a visual selecition. You can map it like this:
```
vmap <silent> <leader>0 <Plug>(chatgpt-menu)
```

### Example usage:
1) Enter visual mode by pressing V.
1) Select the lines of code you want to explain, review, or rewrite.
1) Type `:Explain`, `:Review`, or `:Rewrite`, `:Fix`, `:Test` and press Enter.

## Troubleshooting

### ModuleNotFoundError: No module named 'requests'

If you see this error, it means `requests` is not installed for the Python version that Vim is using. Vim might use a different Python interpreter than your default `python3` command.

**1. Check which Python version Vim uses:**
```bash
vim --version | grep python
```

Look for a line like: `-lpython3.13` or similar. This shows Vim is using Python 3.13.

**2. Install requests for that specific Python version:**

For Python 3.13 (adjust version number as needed):
```bash
python3.13 -m pip install requests
```

**3. If you get an "externally-managed-environment" error:**

On newer macOS/Linux systems, Python prevents global package installation. Use one of these solutions:

```bash
# Option 1: Use --break-system-packages (simpler, but be aware of the implications)
python3.13 -m pip install --break-system-packages requests

# Option 2: Use --user flag (installs to user directory)
python3.13 -m pip install --user requests

# Option 3: Use Homebrew (macOS only, if requests is available)
brew install python-requests
```

**4. Verify installation:**
```bash
python3.13 -c "import requests; print('✓ Success')"
```

### Common Issues

**Q: The plugin doesn't respond when I run commands**
- Check that your API key is set correctly
- Verify you have internet connection (except for Ollama)
- Check Vim's error messages with `:messages`

**Q: Vim says "Python 3 support is required"**
- Your Vim build doesn't include Python 3 support
- Install a version with Python 3: `brew install vim` (macOS) or compile with `--enable-python3interp`

**Q: How do I know which provider/model I'm using?**
- Check `:echo g:chat_gpt_provider` in Vim
- For OpenAI, check `:echo g:chat_gpt_model`
- For other providers, check `:echo g:anthropic_model`, etc.

## Notes
This plugin is not affiliated with or endorsed by OpenAI, Anthropic, Google, or any other AI provider. You are responsible for managing your API usage and any associated costs when using this plugin.

## Migration from OpenAI SDK

**Previous versions** required the `openai` Python package. The plugin now uses HTTP requests for all providers, requiring only the `requests` library.

If you're upgrading from an older version:
1. Uninstall the old dependency (optional): `pip uninstall openai`
2. Install the new dependency: `pip install requests`
3. Your existing OpenAI configuration will continue to work without changes!

# Keywords
- Vim plugin
- AI assistance
- ChatGPT
- Claude
- Anthropic
- Google Gemini
- Ollama
- OpenRouter
- Code assistance
- Programming help
- Code explanations
- Code review
- Code documentation
- Code rewrites
- Test generation
- Code fixes
- Commit messages
- OpenAI API
- Anthropic API
- Multi-provider
- LLM integration
- Python requests
- Vim integration
