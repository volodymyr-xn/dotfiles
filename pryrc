require 'rb-readline'
require 'readline'

# Search in pry history with fzf(https://github.com/junegunn/fzf)

def fzf_installed?
  !`which fzf`&.size.zero?
end

if fzf_installed?
  def RbReadline.rl_reverse_search_history(_sign, _key)
    rl_insert_text(`cat ~/.pry_history | fzf --tac |  tr '\n' ' '`)
  end
end
