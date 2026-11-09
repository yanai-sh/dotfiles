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

The design is [docs/design.md](../../../docs/design.md). Read it before changing what lands on which home.

chezmoi manages this repo. `.chezmoiroot` makes `home/` the source state; the repo root (`README.md`, `docs/`, `.cursor/`) is never applied. Source names use chezmoi prefixes (`dot_`, `private_`, `executable_`, `symlink_`, `.tmpl`). There are four homes: this PC's Windows and WSL, and the desktop's Windows and bare-metal Linux. The only computed fact is `.isWSL` in `home/.chezmoi.toml.tmpl`.

## Rules

- Edit the source under `home/`, never the installed copy. Find a live file's source with `chezmoi source-path <target>`.
- Classify each edit: shared, Windows, Linux, or WSL. Gate whole paths in `home/.chezmoiignore` (list both `dir` and `dir/**`); gate lines with `{{ if .isWSL }}` / `{{ if eq .chezmoi.os "windows" }}` in a `.tmpl`.
- Git config is one file, `home/dot_config/git/config.tmpl`. Do not add `~/.gitconfig` or a second data file for name and email. Per-machine settings go in the unmanaged `~/.config/git/config.local`.
- Windows packages are winget ids in `home/.chezmoiscripts/run_onchange_before_windows-bootstrap.ps1.tmpl`. Do not copy ids off the current machine. That script must stay Windows PowerShell 5.1 compatible. It does not set cache variables.
- Templates render before any `run_before_` script, so a `lookPath` check sees the machine before the bootstrap installs anything.
- Cache directories and the user variables that point at them live in `home/.chezmoiscripts/run_before_windows-caches.ps1.tmpl`, which runs on every apply and must stay Windows PowerShell 5.1 compatible. Do not create `D:\dev`. Cache config stores pointers (`D:\cache\...` on Windows, XDG dirs on Linux), not cache bodies.
- The repo lives at `~/dotfiles` in every home (`sourceDir`), never `~/src/dotfiles` or `~/.local/share/chezmoi`.
- Do not create `~/src`. Do not add product checkout paths, scratch trees, or a host inventory.

## Change workflow

1. Inspect: `chezmoi status` and `chezmoi diff`.
2. Edit the source in `home/`. Update `docs/design.md` when the design itself changes.
3. Preview: `chezmoi execute-template < home/<file>.tmpl` for templates, then `chezmoi apply --dry-run --verbose`.
4. Run `chezmoi verify` after larger refactors.
5. Do not run `chezmoi apply` unless the user asked. chezmoi auto-commits source edits made through its own commands; never push unless asked.

Line endings stay LF (`.gitattributes`).
