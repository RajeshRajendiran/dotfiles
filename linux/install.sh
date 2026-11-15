#!/usr/bin/env bash
# Ubuntu counterpart of bootstrap.sh for the parts of this repo that work on Linux:
# WezTerm config, zsh + starship + CLI tools, Hack Nerd Font, and the Claude
# status line + global AGENTS.md. Safe to re-run.
#
#   ./linux/install.sh            # needs sudo for apt
#   chsh -s "$(command -v zsh)"   # once, then log out and back in
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NERD_FONTS_VERSION="v3.4.0"

# 1. Packages
pkgs=(zsh zsh-autosuggestions zsh-syntax-highlighting starship fd-find fzf lazygit jq unzip curl)
if ! dpkg -s "${pkgs[@]}" >/dev/null 2>&1; then
  sudo apt-get install -y "${pkgs[@]}"
fi

# 2. Hack Nerd Font (Ubuntu's fonts-hack has no Nerd Font glyphs)
font_dir="$HOME/.local/share/fonts/HackNerdFont"
if ! fc-list | grep -qi "Hack Nerd Font"; then
  tmp="$(mktemp -d)"
  base="https://github.com/ryanoasis/nerd-fonts/releases/download/$NERD_FONTS_VERSION"
  curl -fsSL -o "$tmp/Hack.zip" "$base/Hack.zip"
  curl -fsSL -o "$tmp/SHA-256.txt" "$base/SHA-256.txt"
  (cd "$tmp" && grep ' Hack.zip$' SHA-256.txt | sha256sum -c -)
  mkdir -p "$font_dir"
  unzip -oq "$tmp/Hack.zip" -d "$font_dir"
  rm -rf "$tmp"
  fc-cache -f "$font_dir" >/dev/null
fi

# 3. Symlinks. An existing real file is moved aside to <name>.bak-<date> first.
link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak-$(date +%Y%m%d-%H%M%S)"
  fi
  ln -sfn "$src" "$dst"
  echo "linked $dst -> $src"
}
link "$REPO/home/.config/wezterm" "$HOME/.config/wezterm"
link "$REPO/linux/zshrc" "$HOME/.zshrc"
link "$REPO/linux/zprofile" "$HOME/.zprofile"
link "$REPO/linux/starship.toml" "$HOME/.config/starship.toml"
link "$REPO/home/AGENTS.md" "$HOME/.claude/CLAUDE.md"

# WezTerm reads ~/.wezterm.lua before ~/.config/wezterm, so move an old one aside.
if [ -f "$HOME/.wezterm.lua" ] && [ ! -L "$HOME/.wezterm.lua" ]; then
  mv "$HOME/.wezterm.lua" "$HOME/.wezterm.lua.bak-$(date +%Y%m%d-%H%M%S)"
  echo "moved old ~/.wezterm.lua aside"
fi

# 4. Claude: merge only the statusLine from home/.claude/settings.json, keeping the
#    local permissions, model and theme.
settings="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
[ -f "$settings" ] || echo '{}' > "$settings"
tmp="$(mktemp)"
jq --slurpfile src "$REPO/home/.claude/settings.json" '.statusLine = $src[0].statusLine' "$settings" > "$tmp"
cp "$settings" "$settings.bak-$(date +%Y%m%d-%H%M%S)"
mv "$tmp" "$settings"
echo "merged statusLine into $settings"

echo
[ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v zsh)" ] \
  || echo "Next: chsh -s $(command -v zsh)   then log out and back in"
