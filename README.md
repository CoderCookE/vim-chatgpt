# ChatGPT Vim Plugin

This Vim plugin brings the power of OpenAI's ChatGPT API into your Vim editor, enabling you to request code explanations or improvements directly within Vim. With this plugin, you can effortlessly highlight code snippets and ask ChatGPT to explain, review, or rewrite them, with the option to include additional context for better results.

## Prerequisites

1) Vim with Python3 support.
1) A ChatGPT API key from OpenAI.

## Installation
Add your ChatGPT API key to your environment:
https://platform.openai.com/account/api-keys

### Setup your environment
To set up your environment, you can export the CHAT_GPT_KEY variable in your terminal:
```bash
export CHAT_GPT_KEY='your-api-key-here'
```
And more useful env is proxy:
```bash
export OPENAI_PROXY="http://localhost:1087"     # with proxy
# or
export OPENAI_API_BASE='https://openai.xxx.cloud/v1'        # refer: https://github.com/egoist/openai-proxy 
```

Alternatively, you can add the following lines to your `.vimrc` file to set up the chatgpt plugin for Vim:
```vim
let g:chat_gpt_key='your-api-key-here'
```

To install the chatgpt plugin, simply copy the `chatgpt.vim` file to your Vim plugin directory. If you're using [vim-pathogen](https://github.com/tpope/vim-pathogen), you can simply add the `chatgpt` directory to your `bundle` directory.

Finally, to install the `openai` Python module, you can use pip:
```bash
pip install openai
```
## Customization
In your `.vimrc` file you set the following options

```vim
let g:chat_gpt_max_tokens=2000
let g:chat_gpt_model='gpt-4'
let g:chat_gpt_session_mode=1
let g:chat_gpt_temperature = 0.7
let g:chat_gpt_lang = 'in Chinese, '
```

 - g:chat_gpt_max_tokens: This option allows you to set the maximum number of tokens (words or characters) that the ChatGPT API will return in its response. By default, it is set to 2000 tokens. You can adjust this value based on your needs and preferences.
 - g:chat_gpt_model: This option allows you to specify the ChatGPT model you'd like to use. By default, it is set to 'gpt-3.5-turbo', which is a highly capable and versatile model. If you prefer to use a different model, such as 'gpt-4', simply change the value to the desired model name. Note that using a different model may affect the quality of the results and API usage costs.
 - g:chat_gpt_session_mode: The customization allows you to maintain a persistent session with GPT, enabling a more interactive and coherent conversation with the AI model. By default, it is set to 0 which is off,
 - g:chat_gpt_temperature: Controls the randomness of the AI's responses. A higher temperature value (close to 1.0) will be more random, lower 0.1 will be less random
 - g:chat_gpt_lang: Answer in certain langusage, such Chinese
By customizing these options, you can tailor the ChatGPT Vim Plugin to better suit your specific needs and preferences.

## Usage

The plugin offers the following commands for interacting with ChatGPT:

1) `:Ask '<prompt>'` Sends your raw prompt to the ChatGPT API.

To use this command, type :Ask followed by your prompt.

2) `:<>Review` Sends the highlighted code to ChatGPT and requests a review.

To use these commands (:Explain, :Review, or :Rewrite), visually select the lines of code you want to interact with, then type the desired command and press Enter.

4) `:GenerateCommit` Sends entire buffer to ChatGPT and requests a commit messages be generated, then pastes it at the top of the buffer
To use this command type `git commit -v`  then `:GenerateCommit`

5) `:<>Explain '<context>'` Sends the highlighted code to ChatGPT and requests an explanation, with the option to include additional context.
5) `:<>Rewrite '<context>'` Sends the highlighted code to ChatGPT and requests a rewritten version, with the option to include additional context.
5) `:<>Test '<context>'` Sends the highlighted code to ChatGPT and requests it writes a test, with the option to include additional context.
5) `:<>Fix '<context>'` Sends the highlighted code to ChatGPT and that it fixes any errors it may find, with the option to include additional context.
5) `:<>Complete '<context>'` Sends the highlighted code to ChatGPT and that it write codes with instruction, such as `#def quick_sort():`.

To use this command, visually select the lines of code you want to extend, then type :Extend 'context', where context is any additional information you want to provide.

The ChatGPT response will be displayed in a new buffer.

## Mappings

This plugin exposes a binding to open a menu for options on a visual selecition. You can map it like this:
```
vmap <silent> <leader>0 <Plug>(chatgpt-menu)
```

### Example usage:
1) Enter visual mode by pressing V.
1) Select the lines of code you want to explain, review, or rewrite.
1) Type `:Explain`, `:Review`, or `:Rewrite`, `:Fix`, `:Test`, `:Complete` and press Enter.

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
- Code rewrites
- Test generation
- Code fixes
- Commit messages
- OpenAI
- ChatGPT API
- Python module
- Vim integration
