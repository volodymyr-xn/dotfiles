#!/usr/bin/env bash

dconf write \
  /org/gnome/desktop/wm/preferences/focus-mode\
  "'sloppy'"

#!/usr/bin/env bash

########## Gnome settings ####################################################

# Disable Caps Lock and use button for lang switch
# Alt+Shift - language swtich
dconf write \
  /org/gnome/desktop/input-sources/xkb-options \
  "['grp:rctrl_toggle', 'caps:none', 'ctrl:nocaps']"
  # "['grp:rctrl_toggle', 'ctrl:nocaps']"
  # "['grp:caps_toggle']"

dconf write \
  /org/gnome/desktop/wm/keybindings/switch-windows \
  "['<Alt>Tab']"

# Theme
# dconf write /org/gnome/desktop/wm/preferences/theme "'Adwaita-dark'"
# dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'"

# Icon theme
# Temporary disable
# dconf write /org/gnome/desktop/interface/icon-theme "'Numix-Circle'"

# Curson theme
# dconf write /org/gnome/desktop/interface/cursor-theme "'DMZ-Black'"

# Set gnome shell theme
# gsettings set org.gnome.shell.extensions user-theme 'Adwaita-dark'

# dconf write /org/gnome/shell/extensions/dash-to-dock/scroll-action "'cycle-windows'"

#==============================================================================


# Set default monospace font
# dconf write /org/gnome/desktop/interface/monospace-font-name "'Monego Bold 14'"

# Remeber recent files in different apps(evince, for example)
# dconf write /org/gnome/desktop/privacy/remember-recent-files true

# Use new nautilus rendering(requires custom theme support for better look)
# New rendering doent work(end of 2019)
# dconf write /org/gnome/nautilus/preferences/use-experimental-views true
