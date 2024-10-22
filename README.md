# ChatGPT Vim Plugin

This Vim plugin brings the power of OpenAI's ChatGPT API into your Vim editor, enabling you to request code explanations or improvements directly within Vim. With this plugin, you can effortlessly highlight code snippets and ask ChatGPT to explain, review, or rewrite them, with the option to include additional context for better results.

## Prerequisites

1) Vim with Python3 support.
1) A ChatGPT API key from OpenAI.

## Installation
Add your ChatGPT API key to your environment:
https://platform.openai.com/account/api-keys

### Setup your environment
To set up your environment, you can export the OPENAI_API_KEY variable in your terminal:
```bash
export OPENAI_API_KEY='your-api-key-here'
```
And more useful env is proxy:
```bash
export OPENAI_PROXY="http://localhost:1087"     # with proxy
# or
export OPENAI_API_BASE='https://openai.xxx.cloud/v1'        # refer: https://github.com/egoist/openai-proxy
```

Alternatively, you can add the following lines to your `.vimrc` file to set up the chatgpt plugin for Vim:
```vim
let g:openai_api_key='your-api-key-here'
```

To install the chatgpt plugin, simply copy the `chatgpt.vim` file to your Vim plugin directory. If you're using [vim-pathogen](https://github.com/tpope/vim-pathogen), you can simply add the `chatgpt` directory to your `bundle` directory.

Finally, to install the `openai` Python module, you can use pip:
```bash
pip install openai
```
[Detailed Direction For Installation](https://github.com/CoderCookE/vim-chatgpt/issues/4#issuecomment-1704607737)

Additionally, for Azure gpt user:
```
let g:api_type = 'azure'
let g:chat_gpt_key = 'your_azure_chatgpt_api'
let g:azure_endpoint = 'your_azure_endpoint'
let g:azure_deployment = 'your_azure_deployment'
let g:azure_api_version = '2023-03-15-preview'
```

## Customization
In your `.vimrc` file you set the following options

```vim
let g:chat_gpt_max_tokens=2000
let g:chat_gpt_model='gpt-4o'
let g:chat_gpt_session_mode=0
let g:chat_gpt_temperature = 0.7
let g:chat_gpt_lang = 'Chinese'
let g:chat_gpt_split_direction = 'vertical'
let g:split_ratio=4
```

 - g:chat_gpt_max_tokens: This option allows you to set the maximum number of tokens (words or characters) that the ChatGPT API will return in its response. By default, it is set to 2000 tokens. You can adjust this value based on your needs and preferences.
 - g:chat_gpt_model: This option allows you to specify the ChatGPT model you'd like to use. By default, it is set to 'gpt-4o' with a token limit of 4097, If you prefer to use a different model, such as {"gpt-3.5-turbo-16k": 16385, "gpt-4": 8192, "gpt-4-32k": 32768}, simply change the value to the desired model name. Note that using a different model may affect the quality of the results and API usage costs.
 - g:chat_gpt_session_mode: The customization allows you to maintain a persistent session with GPT, enabling a more interactive and coherent conversation with the AI model. By default, it is set to 1 which is on,
 - g:chat_gpt_temperature: Controls the randomness of the AI's responses. A higher temperature value (close to 1.0) will be more random, lower 0.1 will be less random,
 - g:chat_gpt_lang: Answer in certain langusage, such as Chinese,
 - g:chat_gpt_split_direction: Controls how to open splits, 'vertical' or 'horizontal'. Plugin opens horizontal splits by default.
By customizing these options, you can tailor the ChatGPT Vim Plugin to better suit your specific needs and preferences.
 - g:split_ratio: Control the split window size. If set 4, the window size will be 1/4.
 - g:chat_gpt_stop: Stop sequence to send to the ChatGPT API.  Use the stop sequence to only return tokens leading up to the specified stop sequence.  Specifying "World" will cause the API to only return "Hellow" if the output would have been "Hello World!"  The default is to not set a stop sequence.

## Usage

The plugin provides several commands to interact with ChatGPT:

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

## Notes
This plugin is not affiliated with or endorsed by OpenAI. You are responsible for managing your API usage and any associated costs when using this plugin.

# Keywords
- Vim plugin
- Chat GPT
- ChatGPT
- Code assistance
- Programming help
- Code explanations
- Code review
- Code documentation
- Code rewrites
- Test generation
- Code fixes
- Commit messages
- OpenAI
- ChatGPT API
- Python module
- Vim integration
