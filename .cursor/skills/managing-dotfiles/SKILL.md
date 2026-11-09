---
name: managing-dotfiles
description: >-
  Edit this chezmoi dotfiles repo from the design in docs/design.md. Use when
  changing shell, git, ssh, PowerShell, or env config, the chezmoi templates and
  ignore rules under home/, or the Windows and WSL setup scripts in
  home/.chezmoiscripts. Do not record the live machine as the design, do not
  create ~/src, and do not add product checkout paths.
---

# Managing dotfiles

The design is [docs/design.md](../../../docs/design.md). Read it before changing what lands on which home. This repo is vanilla+: nicer defaults for the stock terminal and git, not a workstation product.

chezmoi manages this repo. `.chezmoiroot` makes `home/` the source state; the repo root (`README.md`, `docs/`, `.cursor/`) is never applied. Source names use chezmoi prefixes (`dot_`, `private_`, `executable_`, `symlink_`, `.tmpl`). There are four homes: this PC's Windows and WSL, and the desktop's Windows and bare-metal Linux. The only computed fact is `.isWSL` in `home/.chezmoi.toml.tmpl`.

## Rules

- Edit the source under `home/`, never the installed copy. Find a live file's source with `chezmoi source-path <target>`.
- Classify each edit: shared, Windows, Linux, or WSL. Gate whole paths in `home/.chezmoiignore` (list both `dir` and `dir/**`); gate lines with `{{ if .isWSL }}` / `{{ if eq .chezmoi.os "windows" }}` in a `.tmpl`.
- Git config is one file, `home/dot_config/git/config.tmpl`. Do not add `~/.gitconfig` or a second data file for name and email. Per-machine settings go in the unmanaged `~/.config/git/config.local`.
- Windows vanilla+ packages live in `home/.chezmoiscripts/run_onchange_before_windows-bootstrap.ps1.tmpl` as command-name to winget id. Do not copy ids off the current machine. The commands are `git`, `rg`, `starship`, `zoxide`, `fzf`, `yazi`, and `delta`. Install only when the command is missing from `PATH`; a failed install aborts apply. CaskaydiaCove NF is part of the look: `home/.chezmoiscripts/run_before_windows-font.ps1.tmpl` ensures scoop, the font, Terminal's default face, and `scoop-completion`. `delta` is an x64 Windows build; that emulation is acceptable because each run is a short process. PowerShell 7 or newer must already be installed; the script does not install it and refuses to run on Windows PowerShell 5.1. Do not add Docker, fnm, gh, direnv, eza-on-Windows, or cache-drive variables. Yazi, zoxide, and fzf stay integrated: `home/dot_config/yazi/init.lua` enables zoxide `update_db`, shells define `y`, and `YAZI_CONFIG_HOME` is `~/.config/yazi` on every home.
- Templates render before any `run_before_` script, so a `lookPath` check sees the machine before ensure-install runs. Do not gate a vanilla+ tool on `lookPath` in git, chezmoi, zsh, or the pwsh profile. Those files call the commands directly, including starship and its transient prompt. Ensure-install belongs in the Windows scripts, not in the shell.
- The repo lives at `~/dotfiles` in every home (`sourceDir`), never `~/src/dotfiles` or `~/.local/share/chezmoi`.
- Do not create `~/src`. Do not add product checkout paths, scratch trees, or a host inventory.
- OneDrive is removed on every Windows home. Documents is `~/Documents`. Do not detect folder redirection or add a fallback profile path.

## Change workflow

1. Inspect: `chezmoi status` and `chezmoi diff`.
2. Edit the source in `home/`. Update `docs/design.md` when the design itself changes.
3. Preview: `chezmoi execute-template < home/<file>.tmpl` for templates, then `chezmoi apply --dry-run --verbose`.
4. Run `chezmoi verify` after larger refactors.
5. Do not run `chezmoi apply` unless the user asked. chezmoi auto-commits source edits made through its own commands; never push unless asked.

Line endings stay LF (`.gitattributes`).
