require'dsych_config.utils'

vim.cmd([[
command! SpringStartDebug call s:start_spring_boot_app_in_debug_mode(1)
command! SpringStart call s:start_spring_boot_app_in_debug_mode(0)

command! -nargs=1 Redir silent call Redir(<f-args>)
]])
