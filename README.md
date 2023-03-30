# ChatGPT Vim Plugin

This Vim plugin integrates OpenAI's ChatGPT API into your Vim editor, allowing you to get explanations or suggestions for code improvements directly within Vim. With this plugin, you can easily highlight code snippets and ask ChatGPT to explain or rewrite them.

## Prerequisites


1) Vim with Python3 support.
1) A ChatGPT API key from OpenAI.
## Installation
1) Add  your API to your enviorment

```
export CHAT_GPT_KEY='sk-asdjklfdsajkladfsjkladfsjkladfsjkl'
```

2) Copy the chatgpt.vim file into your Vim plugin directory (usually ~/.vim/plugin/ or $HOME/vimfiles/plugin/ on Windows). Or use https://github.com/tpope/vim-pathoge

2) Install the openai Python module using pip:
``` bash
pip install openai
```


## Usage
The plugin provides four commands for interacting with ChatGPT:
1) Ask '\<prompt\>', sends your raw prompt to the ChatGPT API

To use this commands, type :Ask then enter you prompt

2) :Explain: Sends the highlighted code to ChatGPT and asks for an explanation.
2) :Review: Sends the highlighted code to ChatGPT and asks for a review of it.
2) :Rewrite: Sends the highlighted code to ChatGPT and asks for a rewritten version.

To use these commands, visually select the lines of code you want to interact with, then type :Explain or :Review. The ChatGPT response will be displayed in a new buffer.


### Example usage:

1) Enter visual mode by pressing V.
1) Select the lines of code you want to explain or rewrite.
1) Type :Explain or :Review and press Enter.

## Notes
This plugin is not affiliated with or endorsed by OpenAI. You are responsible for managing your API usage, and any associated costs, when using this plugin.
