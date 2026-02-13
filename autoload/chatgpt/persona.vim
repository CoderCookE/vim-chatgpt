" ChatGPT Persona Management
" This file handles switching between different AI personas

" Set the active persona
function! chatgpt#persona#set(persona) abort
    let personas = keys(g:gpt_personas)
    if index(personas, a:persona) != -1
      echo 'Persona set to: ' . a:persona
      let g:chat_persona = a:persona
    else
      let g:chat_persona = 'default'
      echo 'Persona set to default, not found ' . a:persona
    end
endfunction
