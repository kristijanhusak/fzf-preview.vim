"=============================================================================
" File: autoload/fzf-preview.vim
" Author: yuki-ycino
" Created: 2018-01-25
"=============================================================================

function! s:project_root() abort
  silent !git rev-parse --show-toplevel
  if v:shell_error
    echomsg 'The current directory is not a git project'
    return ''
  endif

  let get_git_root_cmd = system('git rev-parse --show-toplevel')
  return strpart(get_git_root_cmd, 0, strlen(get_git_root_cmd) - 1)
endfunction

function! s:project_files() abort
  silent !git rev-parse --show-toplevel
  if v:shell_error
    echomsg 'The current directory is not a git project'
    return []
  endif

  let file = systemlist(g:fzf_preview_filelist_command)
  return g:fzf_preview_use_dev_icons ? s:prepend_dev_icon(file) : file
endfunction

function! s:git_files() abort
  silent !git rev-parse --show-toplevel
  if v:shell_error
    echomsg 'The current directory is not a git project'
    return []
  endif

  let list = systemlist(g:fzf_preview_gitfiles_command)
  return list
endfunction

function! s:buffer_list() abort
  let list = filter(range(1, bufnr('$')),
  \ "bufexists(v:val) && buflisted(v:val) && filereadable(expand('#' . v:val . ':p'))"
  \ )
  let buffers = map(list, 'bufname(v:val)')
  return g:fzf_preview_use_dev_icons ? s:prepend_dev_icon(buffers) : buffers
endfunction

function! s:oldfile_list() abort
  let copyfiles = deepcopy(v:oldfiles, 1)
  let files = filter(copyfiles, 'filereadable(v:val)')

  let files = map(files, "fnamemodify(v:val, ':~')")
  return g:fzf_preview_use_dev_icons ? s:prepend_dev_icon(files) : files
endfunction

function! s:mrufile_list() abort
  let files = readfile(g:neomru#file_mru_path)
  call remove(files, 0)
  let files = filter(files, 'filereadable(v:val)')

  let files = map(files, "fnamemodify(v:val, ':.')")
  return g:fzf_preview_use_dev_icons ? s:prepend_dev_icon(files) : files
endfunction

function! s:is_project_file(file, project_path) abort
  let file_path_list = split(a:file, '/')

  let is_target = 1
  let project_path_elm = ''

  for project_path_elm in a:project_path
    if match(file_path_list, '^' . project_path_elm . '$') == -1
      let is_target = 0
    endif
  endfor

  return is_target
endfunction

function! s:project_oldfile_list() abort
  let target_files = []
  let readable_filelist = filter(v:oldfiles, 'filereadable(v:val)')
  let project_path_list = split(s:project_root(), '/')

  let readable_file = ''
  for readable_file in readable_filelist
    if s:is_project_file(readable_file, project_path_list)
      let target_files = add(target_files, readable_file)
    endif
  endfor
  let files = map(target_files, "fnamemodify(v:val, ':.')")
  return g:fzf_preview_use_dev_icons ? s:prepend_dev_icon(files) : files
endfunction

function! s:project_mrufile_list() abort
  let files = readfile(g:neomru#file_mru_path)
  call remove(files, 0)
  let target_files = []
  let readable_filelist = filter(files, 'filereadable(v:val)')
  let project_path_list = split(s:project_root(), '/')

  let readable_file = ''
  for readable_file in readable_filelist
    if s:is_project_file(readable_file, project_path_list)
      let target_files = add(target_files, readable_file)
    endif
  endfor
  let files = map(target_files, "fnamemodify(v:val, ':.')")
  return g:fzf_preview_use_dev_icons ? s:prepend_dev_icon(files) : files
endfunction

function! s:prepend_dev_icon(candidates) abort
  let l:result = []
  for l:candidate in a:candidates
    let l:filename = fnamemodify(l:candidate, ':p:t')
    let l:icon = WebDevIconsGetFileTypeSymbol(l:filename, isdirectory(l:filename))
    call add(l:result, printf('%s  %s', l:icon, l:candidate))
  endfor

  return l:result
endfunction

function! s:edit_file(lines) abort
  let cmd = get({'ctrl-x': 'split',
                 \ 'ctrl-v': 'vertical split',
                 \ 'ctrl-t': 'tabedit'}, a:lines[0], 'e')

  for item in a:lines[1:]
    let file_path = g:fzf_preview_use_dev_icons ? item[4:] : item
    execute 'silent '. cmd . ' ' . file_path
  endfor
endfunction

function! s:map_fzf_keys() abort
  if g:fzf_preview_use_floating_window
    return
  endif

  execute 'resize' float2nr(g:fzf_preview_rate * &lines)
  execute 'tnoremap <silent> <buffer> ' . g:fzf_full_preview_toggle_key . ' <C-\><C-n>:<C-u>call <SID>fzf_toggle_full_buffer()<CR>'
endfunction

function! s:fzf_toggle_full_buffer() abort
  let defaultsize = float2nr(g:fzf_preview_rate * &lines)
  if defaultsize == winheight('%')
    tab split
  else
    tabclose
    resize 1
    execute 'resize' float2nr(g:fzf_preview_rate * &lines)
  endif
  normal! i
endfunction

function! s:fzf_command_common_option(console) abort
  return '--reverse --ansi --prompt="' . a:console . '> " --bind '
        \ . g:fzf_preview_default_key_bindings . ' --expect=ctrl-v,ctrl-x,ctrl-t --preview '
endfunction

function! s:fzf_preview_float_or_layout() abort
  return g:fzf_preview_use_floating_window ?
  \ 'call fzf_preview#window#create_centered_floating_window()' :
  \ g:fzf_preview_layout
endfunction

let s:files_prompt     = 'ProjectFiles'
let s:files_buffer     = 'Buffers'
let s:project_oldfiles = 'ProjectOldFiles'
let s:project_mrufiles = 'ProjectMruFiles'
let s:oldfiles         = 'OldFiles'
let s:mrufiles         = 'MruFiles'
let s:project_grep     = 'ProjectGrep'
let s:git_files_prompt = 'GitFiles'

function! fzf_preview#fzf_files() abort
  if s:project_root() ==# ''
    return
  endif

  call fzf#run({
  \ 'source':  s:project_files(),
  \ 'sink*':   function('s:edit_file'),
  \ 'options': '--multi ' . s:fzf_command_common_option(s:files_prompt) . '''[[ "$(file --mime {})" =~ binary ]] && ' . g:fzf_binary_preview_command . ' || ' . g:fzf_preview_command . '''',
  \ 'window':  s:fzf_preview_float_or_layout(),
  \ })
  call s:map_fzf_keys()
endfunction

function! fzf_preview#fzf_git_files() abort
  if s:project_root() ==# ''
    return
  endif

  function! s:gitfile_open(lines) abort
    let cmd = get({'ctrl-x': 'split',
                   \ 'ctrl-v': 'vertical split',
                   \ 'ctrl-t': 'tabedit'}, a:lines[0], 'e')

    for item in a:lines[1:]
      execute 'silent '. cmd . ' ' . item[3:]
    endfor
  endfunction

  call fzf#run({
  \ 'source':  s:git_files(),
  \ 'sink*':    function('s:gitfile_open'),
  \ 'options': '--multi ' . s:fzf_command_common_option(s:git_files_prompt) . "--tiebreak=index --preview '[[ $(git diff -- {-1}) != \"\" ]] && git diff --color=always -- {-1} || " . g:fzf_preview_command . "'",
  \ 'window':  s:fzf_preview_float_or_layout(),
  \ })
  call s:map_fzf_keys()
endfunction

function! fzf_preview#fzf_buffers() abort
  call fzf#run({
  \ 'source':  s:buffer_list(),
  \ 'sink*':   function('s:edit_file'),
  \ 'options': s:fzf_command_common_option(s:files_buffer) . '''[[ "$(file --mime {})" =~ binary ]] && ' . g:fzf_binary_preview_command . ' || ' . g:fzf_preview_command . '''',
  \ 'window':  s:fzf_preview_float_or_layout(),
  \ })
  call s:map_fzf_keys()
endfunction

function! fzf_preview#fzf_oldfiles() abort
  call fzf#run({
  \ 'source':  s:oldfile_list(),
  \ 'sink*':   function('s:edit_file'),
  \ 'options': '--multi ' . s:fzf_command_common_option(s:oldfiles) . '''[[ "$(file --mime {})" =~ binary ]] && ' . g:fzf_binary_preview_command . ' || ' . g:fzf_preview_command . '''',
  \ 'window':  s:fzf_preview_float_or_layout(),
  \ })
  call s:map_fzf_keys()
endfunction

function! fzf_preview#fzf_mrufiles() abort
  call fzf#run({
  \ 'source':  s:mrufile_list(),
  \ 'sink*':   function('s:edit_file'),
  \ 'options': '--multi ' . s:fzf_command_common_option(s:mrufiles) . '''[[ "$(file --mime {})" =~ binary ]] && ' . g:fzf_binary_preview_command . ' || ' . g:fzf_preview_command . '''',
  \ 'window':  s:fzf_preview_float_or_layout(),
  \ })
  call s:map_fzf_keys()
endfunction

function! fzf_preview#fzf_project_oldfiles() abort
  if s:project_root() ==# ''
    return
  endif

  call fzf#run({
  \ 'source':  s:project_oldfile_list(),
  \ 'sink*':   function('s:edit_file'),
  \ 'options': '--multi ' . s:fzf_command_common_option(s:project_oldfiles) . '''[[ "$(file --mime {})" =~ binary ]] && ' . g:fzf_binary_preview_command . ' || ' . g:fzf_preview_command . '''',
  \ 'window':  s:fzf_preview_float_or_layout(),
  \ })
  call s:map_fzf_keys()
endfunction

function! fzf_preview#fzf_project_mrufiles() abort
  if s:project_root() ==# ''
    return
  endif

  call fzf#run({
  \ 'source':  s:project_mrufile_list(),
  \ 'sink*':   function('s:edit_file'),
  \ 'options': '--multi ' . s:fzf_command_common_option(s:project_mrufiles) . '''[[ "$(file --mime {})" =~ binary ]] && ' . g:fzf_binary_preview_command . ' || ' . g:fzf_preview_command . '''',
  \ 'window':  s:fzf_preview_float_or_layout(),
  \ })
  call s:map_fzf_keys()
endfunction

function! fzf_preview#fzf_project_grep(...) abort
  if s:project_root() ==# ''
    return
  endif

  if a:0 >= 1
    let grep_command = g:fzf_preview_grep_cmd . ' ' . a:1
  else
    let grep_command = g:fzf_preview_grep_cmd . ' .'
  end

  call fzf#run(fzf#wrap({
  \ 'source':  grep_command,
  \ 'options': '--delimiter : --nth 3.. --multi ' . s:fzf_command_common_option(s:project_grep) . "'" . g:fzf_preview_grep_preview_cmd . " {}'",
  \ 'window':  s:fzf_preview_float_or_layout(),
  \ }))
  call s:map_fzf_keys()
endfunction

" vim:set expandtab shiftwidth=2 softtabstop=2 tabstop=2 foldenable foldmethod=marker:
