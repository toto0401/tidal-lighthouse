#!/bin/zsh
set -e
cd -- "${0:A:h}"
if [[ -x /opt/homebrew/bin/godot ]]; then
  exec /opt/homebrew/bin/godot --path "$PWD"
elif command -v godot >/dev/null 2>&1; then
  exec godot --path "$PWD"
elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  exec /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD"
else
  print '请先安装 Godot 4.7，再双击开始游戏。'
  read -r '?按回车关闭窗口'
fi
