" ChatGPT Git Commit Generation
" This file handles AI-assisted commit message generation

" Generate a commit message using git integration
function! chatgpt#commit#generate() abort
  let prompt = 'Please help me create a git commit message.'
  let prompt .= "\n\nThe goal is to:"
  let prompt .= "\n- Check the repository status"
  let prompt .= "\n- Review the changes that will be committed"
  let prompt .= "\n- Draft an appropriate commit message following conventional commit format"
  let prompt .= "\n- Create the commit"
  let prompt .= "\n\nIf there are no staged changes, ask if I want to stage files first."

  call chatgpt#chat(prompt)
endfunction
