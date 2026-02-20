" ChatGPT Menu Functions
" This file handles the interactive menu and code highlighting

" Send highlighted code to ChatGPT
function! chatgpt#menu#send_code(ask, context) abort
    let save_cursor = getcurpos()
    let [current_line, current_col] = getcurpos()[1:2]

    " Save the current yank register and its type
    let save_reg = @@
    let save_regtype = getregtype('@')

    let [line_start, col_start] = getpos("'<")[1:2]
    let [line_end, col_end] = getpos("'>")[1:2]

    " Check if a selection is made
    if (col_end - col_start > 0 || line_end - line_start > 0) &&
       \ (current_line == line_start && current_col == col_start ||
       \  current_line == line_end && current_col == col_end)

        let current_line_start = line_start
        let current_line_end = line_end

        if current_line_start == line_start && current_line_end == line_end
            execute 'normal! ' . line_start . 'G' . col_start . '|v' . line_end . 'G' . col_end . '|y'
            let relative_path = expand('%')
            let file_info = 'File: ' . relative_path . "\n" . 'Lines: ' . line_start . '-' . line_end . "\n\n"
            let yanked_text = file_info . '```' . &syntax . "\n" . @@ . "\n" . '```'
        else
            let yanked_text = ''
        endif
    else
        let yanked_text = ''
    endif

    let prompt = a:context . ' ' . "\n"

    if !empty(yanked_text)
        let prompt .= yanked_text . "\n"
    endif

    echo a:ask
    if has_key(g:prompt_templates, a:ask)
        let prompt = g:prompt_templates[a:ask] . "\n" . prompt
    endif

    call chatgpt#chat(prompt)

    " Restore the original yank register
    let @@ = save_reg
    call setreg('@', save_reg, save_regtype)

    let curpos = getcurpos()
    call setpos("'<", curpos)
    call setpos("'>", curpos)

    " Only restore cursor position if NOT in session mode
    let session_enabled = exists('g:chat_gpt_session_mode') ? g:chat_gpt_session_mode : 1
    if !session_enabled
        call setpos('.', save_cursor)
    endif
endfunction

" Menu sink function
function! s:menu_sink(id, choice) abort
  call popup_hide(a:id)
  let choices = {}

  for index in range(len(g:promptKeys))
    let choices[index+1] = g:promptKeys[index]
  endfor

  if a:choice > 0 && a:choice <= len(g:promptKeys)
    call chatgpt#menu#send_code(choices[a:choice], input('Prompt > '))
  endif
endfunction

" Menu filter function
function! s:menu_filter(id, key) abort
  if a:key > 0 && a:key <= len(g:promptKeys)
    call s:menu_sink(a:id, a:key)
  else
    return popup_filter_menu(a:id, a:key)
  endif
endfunction

" Show ChatGPT menu
function! chatgpt#menu#show() range abort
  let menu_choices = []

  for index in range(len(g:promptKeys))
    call add(menu_choices, string(index + 1) . ". " . g:promptKeys[index])
  endfor

  call popup_menu(menu_choices, #{
        \ pos: 'topleft',
        \ line: 'cursor',
        \ col: 'cursor+2',
        \ title: ' Chat GPT ',
        \ highlight: 'question',
        \ borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ callback: function('s:menu_sink'),
        \ border: [],
        \ cursorline: 1,
        \ padding: [0,1,0,1],
        \ filter: function('s:menu_filter'),
        \ mapping: 0,
        \ })
endfunction
