" The get_browser_command and open_browser functions belong to
" https://github.com/mattn/gist-vim
" Big thank you. Open source ftw
"

function! s:get_browser_command()
  let to_github_browser_command = get(g:, 'to_github_browser_command', '')
  if to_github_browser_command == ''
    if has('win32') || has('win64')
      let to_github_browser_command = '!start rundll32 url.dll,FileProtocolHandler %URL%'
    elseif has('mac') || has('macunix') || has('gui_macvim') || system('uname') =~? '^darwin'
      let to_github_browser_command = 'open %URL%'
    elseif executable('xdg-open')
      let to_github_browser_command = 'xdg-open %URL%'
    elseif executable('firefox')
      let to_github_browser_command = 'firefox %URL% &'
    else
      let to_github_browser_command = ''
    endif
  endif
  return to_github_browser_command
endfunction

function! s:open_browser(url)
  let cmd = s:get_browser_command()
  if len(cmd) == 0
    redraw
    echohl WarningMsg
    echo "It seems that you don't have general web browser. Open URL below."
    echohl None
    echo a:url
    return
  endif
  if cmd =~ '^!'
    let cmd = substitute(cmd, '%URL%', '\=shellescape(a:url)', 'g')
    silent! exec cmd
  elseif cmd =~ '^:[A-Z]'
    let cmd = substitute(cmd, '%URL%', '\=a:url', 'g')
    exec cmd
  else
    let cmd = substitute(cmd, '%URL%', '\=shellescape(a:url)', 'g')
    call system(cmd)
  endif
endfunction

function! s:run(...)
  let command = join(a:000, ' | ')
  return substitute(system(command), "\n", '', '')
endfunction

function! s:copy_to_clipboard(url)
  if exists('g:to_github_clip_command')
    call system(g:to_github_clip_command, a:url)
  elseif has('unix') && !has('clipboard')
    let @" = a:url
  else
    let @+ = a:url
  endif
endfunction

function! ToGithub(range, line1, line2, clipboard, ...)
  if len(a:000) == 0
    let commit = s:run('git rev-parse HEAD')
  else
    let commit = a:000[0] == "." ? s:run('git rev-parse --abbrev-ref HEAD') : a:000[0]
  endif

  let github_url = 'https://github.com'
  let get_remote = 'git remote -v | grep -E "github\.com.*\(fetch\)" | head -n 1'
  let get_username = 'sed -E "s/.*com[:\/](.*)\/.*/\\1/"'
  let get_repo = 'sed -E "s/.*com[:\/].*\/(.*).*/\\1/" | cut -d " " -f 1'
  let optional_ext = 'sed -E "s/\.git//"'

  " Get the username and repo.
  let username = s:run(get_remote, get_username)
  let repo = s:run(get_remote, get_repo, optional_ext)

  let repo_root = s:run('git rev-parse --show-toplevel')
  let file_path = expand('%:p')
  let file_path = substitute(file_path, repo_root . '/', '', 'e')
  let url = join([github_url, username, repo, 'blob', commit, file_path], '/')

  " Finally set the line numbers if necessary.
  if a:range == 0
    let line = ''
  elseif a:range == 1
    let line = '#L' . line('.')
  else
    let line = '#L' . a:line1 . '-L' . a:line2
  endif

  if a:clipboard
    return s:copy_to_clipboard(url . line)
  else
    return s:open_browser(url . line)
  endif
endfunction

command! -nargs=? -range ToGithub          :call ToGithub(<range>, <line1>, <line2>, 0, <f-args>)
command! -nargs=? -range ToGithubClipboard :call ToGithub(<range>, <line1>, <line2>, 1, <f-args>)
