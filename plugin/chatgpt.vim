" ChatGPT Vim Plugin - Main Entry Point
" Refactored version with modular structure

" Ensure Python3 is available
if !has('python3')
  echo "Python 3 support is required for ChatGPT plugin"
  finish
endif

" Prevent loading twice
if exists('g:loaded_chatgpt')
  finish
endif
let g:loaded_chatgpt = 1

" Initialize configuration
call chatgpt#config#setup()

" Define commands
command! -nargs=? Ask call chatgpt#chat(<q-args>)
command! GenerateCommit call chatgpt#commit#generate()
command! GptGenerateContext call chatgpt#context#generate()
command! GptGenerateSummary call chatgpt#summary#generate()
command! -nargs=1 GptBe call chatgpt#persona#set(<q-args>)

" Create dynamic commands for prompt templates
for i in range(len(g:promptKeys))
  execute 'command! -range -nargs=? ' . chatgpt#capitalize(g:promptKeys[i]) . " call chatgpt#menu#send_code('" . g:promptKeys[i] . "',<q-args>)"
endfor

" Define mappings
vnoremap <silent> <Plug>(chatgpt-menu) :call chatgpt#menu#show()<CR>

" Compatibility wrapper for old function names
function! DisplayChatGPTResponse(response, finish_reason, chat_gpt_session_id)
  call chatgpt#display_response(a:response, a:finish_reason, a:chat_gpt_session_id)
endfunction

function! ChatGPT(prompt) abort
  call chatgpt#chat(a:prompt)
endfunction

function! SendHighlightedCodeToChatGPT(ask, context) abort
  call chatgpt#menu#send_code(a:ask, a:context)
endfunction

function! GenerateCommitMessage()
  call chatgpt#commit#generate()
endfunction

function! GenerateProjectContext()
  call chatgpt#context#generate()
endfunction

function! GenerateConversationSummary()
  call chatgpt#summary#generate()
endfunction

" Auto-generate context on startup
call chatgpt#context#check_and_generate()
