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
