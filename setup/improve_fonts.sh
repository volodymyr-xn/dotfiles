fontconfig="true false hintslight rgb true lcddefault 131 serif Noto Serif sans-serif Noto Sans monospace Hack Helvetica sans-serif Times serif Courier monospace Terminal monospace monospace Symbola"

echo $fontconfig > $HOME/.config/fontconfig/fonts.conf

xconfig="Xft.autohint: 0\n"\
"Xft.antialias: 1\n"\
"Xft.hinting: true\n"\
"Xft.hintstyle: hintslight\n"\
"Xft.dpi: 96\n"\
"Xft.rgba: rgb\n"\
"Xft.lcdfilter: lcddefault\n"

echo $xconfig > $HOME/.Xresources
