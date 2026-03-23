" Normal AppArmor file detection
autocmd BufNewFile,BufRead /etc/apparmor.d/*                    set ft=apparmor
autocmd BufNewFile,BufRead /usr/share/apparmor/extra-profiles/* set ft=apparmor
