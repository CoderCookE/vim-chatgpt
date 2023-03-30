# ChatGPT Vim Plugin

This Vim plugin brings the power of OpenAI's ChatGPT API into your Vim editor, enabling you to request code explanations or improvements directly within Vim. With this plugin, you can effortlessly highlight code snippets and ask ChatGPT to explain, review, or rewrite them, with the option to include additional context for better results.

## Prerequisites

1) Vim with Python3 support.
1) A ChatGPT API key from OpenAI.

## Installation
Add your ChatGPT API key to your environment:
```arduino
export CHAT_GPT_KEY='your-api-key-here'
```

Copy the chatgpt.vim file into your Vim plugin directory (usually ~/.vim/plugin/ or $HOME/vimfiles/plugin/ on Windows). Alternatively, use [vim-pathogen](https://github.com/tpope/vim-pathogen)

Install the openai Python module using pip:
```bash
pip install openai
```

## Usage

The plugin offers the following commands for interacting with ChatGPT:

1) :Ask <prompt>: Sends your raw prompt to the ChatGPT API.

To use this command, type :Ask followed by your prompt.

2) :Explain: Sends the highlighted code to ChatGPT and requests an explanation.
2) :Review: Sends the highlighted code to ChatGPT and requests a review.

To use these commands (:Explain, :Review, or :Rewrite), visually select the lines of code you want to interact with, then type the desired command and press Enter.

4) :Rewrite: Sends the highlighted code to ChatGPT and requests a rewritten version,. with the option to include additional context.

To use this command, visually select the lines of code you want to extend, then type :Extend 'context', where context is any additional information you want to provide.

The ChatGPT response will be displayed in a new buffer.

### Example usage:
1) Enter visual mode by pressing V.
1) Select the lines of code you want to explain, review, or rewrite.
1) Type :Explain, :Review, or :Rewrite and press Enter.

## Notes
This plugin is not affiliated with or endorsed by OpenAI. You are responsible for managing your API usage and any associated costs when using this plugin.
