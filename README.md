# Setup

```bash_profile
export CHAT_GPT_KEY='sk-asdjklfdsajkladfsjkladfsjkladfsjkl'
```

```bash
python3 -m venv vim_venv
source vim_venv/bin/activate
pip install openai
```

```vimrc
let g:python3_host_prog = '.vim/vim_venv/bin/python'
let g:chatgpt_venv_path = '.vim/vim_venv/lib/python3.7/site-packages'
```

# Install Plugin:
https://github.com/tpope/vim-pathogen


# Commands
## Open
 Commands to interact with ChatGPT
command! -nargs=1 Ask call ChatGPT(<q-args>)
```
:Ask <prompt>
```

## Highlight
## Visually Select Text:

command! -range Explain call SendHighlightedCodeToChatGPT('explain', <line1>, <line2>)
```
:<> Explain
```

command! -range Rewrite SendHighlightedCodeToChatGPT('rewrite', <line1>, <line2>)
```
:<> Rewrite
```

command! -range Review call SendHighlightedCodeToChatGPT('review', <line1>, <line2>)
```
:<> Review
```
