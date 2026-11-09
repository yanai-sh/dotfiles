# Dotfiles

A personal shell and git config for four homes: Windows and WSL on this PC, Windows and Linux on the desktop. [chezmoi](https://www.chezmoi.io/) writes it. The source is `home/`. This README, `docs/`, and `.cursor/` stay in the repo and are never applied.

The clone is `~/dotfiles` in every home. On WSL that clone is a real directory inside the distro. The longer rationale is [docs/design.md](docs/design.md).

## Tools

| Tool | Role |
|------|------|
| chezmoi | Installs and updates the home from `home/` |
| git, OpenSSH | One config, ssh commit signing. WSL signs through the Windows agent |
| delta | Pager for git and chezmoi |
| starship | Prompt. Interactive pwsh also uses the transient prompt |
| zoxide, fzf | Directory jump, and the picker for zoxide and Yazi |
| yazi | File manager. `y` quits back into the shell; `q` keeps the directory, `Q` does not. Inside Yazi, `z` is fzf and `Z` is zoxide |
| ripgrep | Shared config at `~/.config/ripgrep/config` |
| pwsh | Windows shell: PSReadLine, winget and scoop completion |
| zsh, eza, fd, bat | Linux and WSL shell, listing, find, and preview |

## Dependencies

Install these before the first `chezmoi apply`. Apply renders templates before its setup scripts run.

**Windows:** [chezmoi](https://www.chezmoi.io/) (`twpayne.chezmoi`), Git (`Git.Git`), PowerShell 7 (`Microsoft.PowerShell`), and `winget`. The scripts refuse Windows PowerShell 5.1 and do not install PowerShell.

**Linux and WSL:** chezmoi, then the packages below from the distro. The command must be `fd`, not Debian's `fdfind`. Install them before the first shell that loads this config. zsh calls them directly.

| Command | Windows winget id, installed only when missing | Linux and WSL |
|---------|--------------------------------------------------|---------------|
| `git` | `Git.Git` | distro |
| `rg` | `BurntSushi.ripgrep.MSVC` | distro |
| `starship` | `Starship.Starship` | distro |
| `zoxide` | `ajeetdsouza.zoxide` | distro |
| `fzf` | `junegunn.fzf` | distro |
| `yazi` | `sxyazi.yazi` | distro |
| `delta` | `dandavison.delta` | distro |
| `bat`, `eza`, `fd` | | distro |

`delta` on Windows is an x64 build. Each run is a short process.

Windows apply also installs [scoop](https://scoop.sh/) if it is missing, then the `nerd-fonts` package `CascadiaCode-NF` and `scoop-completion` from the extras bucket. It sets Windows Terminal's default face to `CaskaydiaCove NF`. Open Terminal once if it has no `settings.json` yet, then apply again.

A failed winget or scoop install aborts apply. A package already present, including a newer one, does not.

## Layout

chezmoi names in `home/`: `dot_` is a leading dot, `private_` is mode `600` (`700` on the directory), `executable_` sets the exec bit, `symlink_` is a link, `.tmpl` is a Go template.

```
~/dotfiles/
  README.md
  docs/design.md
  home/                          source state
    .chezmoi.toml.tmpl           sourceDir is ~/dotfiles; .isWSL
    .chezmoiignore               which paths exist on which home
    .chezmoiscripts/             Windows install and font; WSL /etc/wsl.conf
    .chezmoiexternal.toml        WSL: wsl2-ssh-agent v0.9.7
    dot_config/git/              every home
    dot_config/ripgrep/
    dot_config/yazi/
    Documents/PowerShell/        Windows
    dot_zshenv                   Linux and WSL
    dot_config/zsh/
    private_dot_ssh/
    dot_local/                   WSL
    dot_config/systemd/user/
```

After apply:

```
~/.config/git/config             every home. No ~/.gitconfig
~/.config/git/ignore
~/.config/git/allowed_signers
~/.config/ripgrep/config
~/.config/yazi/init.lua

~/Documents/PowerShell/profile.ps1    Windows

~/.zshenv                             Linux and WSL
~/.config/zsh/.zshenv
~/.config/zsh/.zshrc
~/.ssh/config

~/.local/bin/wsl-ssh-sign             WSL
~/.local/bin/wsl2-ssh-agent
~/.local/lib/win32/powershell.exe
~/.local/lib/win32/git-credential-manager.exe
~/.config/systemd/user/wsl2-ssh-agent.service
```

These files are yours. chezmoi does not write them:

```
~/.config/git/config.local       per-machine git, included last
~/.config/zsh/.zshenv.local
~/.config/zsh/.zshrc.local
~/.ssh/config.d/*
```

Each signing email, including one set in `config.local`, needs a line in `~/.config/git/allowed_signers`.

## Install

**This tree is already at `~/dotfiles`:**

```sh
chezmoi init --source "$HOME/dotfiles"
chezmoi diff
chezmoi apply
```

On Windows, use `$HOME\dotfiles` in PowerShell.

**Fresh machine**, after this tree is on `origin/main`:

```powershell
winget install --id twpayne.chezmoi -e
winget install --id Git.Git -e
winget install --id Microsoft.PowerShell -e
chezmoi init --apply --source "$HOME\dotfiles" https://github.com/yanai-sh/dotfiles.git
```

Linux and WSL, from inside the distro:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply --source "$HOME/dotfiles" https://github.com/yanai-sh/dotfiles.git
```

Open a new terminal after apply so an upgraded Git is on `PATH`. Windows git signing needs the `ssh-agent` service running and the key loaded (`ssh-add`).

On WSL the first apply writes `/etc/wsl.conf` and asks for `sudo`. From Windows run `wsl.exe --shutdown`, reopen the distro, and `chezmoi apply` again to start the ssh agent bridge.

## Edit

Edit `home/`, or the target path. The copy in the home directory is output.

```sh
chezmoi status
chezmoi diff
chezmoi edit --apply ~/.config/git/config
chezmoi execute-template < home/dot_config/git/config.tmpl
chezmoi apply --dry-run --verbose
chezmoi apply
chezmoi update
```

`chezmoi source-path <target>` prints the file in `home/` for a live path.

**Change a file you already applied.** Plain files: `chezmoi re-add <target>`. Templates: `chezmoi merge <target>`.

**Add a file.** Put it in the home, then `chezmoi add <target>`. That copies it into `home/` with the chezmoi name. Gate a whole path in `home/.chezmoiignore` (list both `dir` and `dir/**`). Gate lines with `{{ if .isWSL }}` or `{{ if eq .chezmoi.os "windows" }}` in a `.tmpl`.

**Add a Windows package.** Add its command name and winget id to `home/.chezmoiscripts/run_onchange_before_windows-bootstrap.ps1.tmpl`. Pick the id from winget, not from whatever happens to be installed on this machine. The shell calls these commands directly. Install checks belong in that script.

chezmoi commits source edits it makes and does not push. Line endings stay LF (`.gitattributes`).
