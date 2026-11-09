# Design

chezmoi manages this repository. `.chezmoiroot` points chezmoi at `home/`, so only `home/` is source state. Everything else at the repo root (`README.md`, `docs/`, `.cursor/`, `.gitattributes`) is about the repo and is never applied.

Source names use chezmoi's prefixes: `dot_config` is `~/.config`, `private_dot_ssh` is `~/.ssh` with mode `700`, `executable_` sets the exec bit, `symlink_` creates a link, and `.tmpl` files are Go templates. Day to day, address files by their real target path (`chezmoi edit ~/.config/git/config`), not by the source name.

## Vanilla+

This is a personal shell and git config. After apply, the default terminal should feel like the stock one with better defaults: same commands, nicer look, less friction. It is not a workstation installer and not a catalogue of every tool on the machine.

**Look:** CaskaydiaCove NF in Windows Terminal, starship prompt, starship's transient prompt in an interactive pwsh.

**Move and read:** zoxide, ripgrep config, delta as the git/chezmoi pager, Yazi as the file manager. `y` is the shell wrapper that cds on quit so zoxide records the last directory. Inside Yazi, `z` is fzf subtree jump and `Z` is zoxide (Yazi defaults). `init.lua` sets `update_db = true` so changing CWD in Yazi writes the same zoxide database the shell uses. `YAZI_CONFIG_HOME` is `~/.config/yazi` on every home (Windows would otherwise use `%AppData%\yazi\config`). On Linux and WSL, zsh also uses `eza`, `fzf`, `fd`, and `bat` (man pager and fzf preview). On Windows, apply installs `fzf` and `yazi` as well so those Yazi keys have a picker.

**Type:** PSReadLine history and completion in pwsh, tab completion for `winget` and `scoop`.

**Identity:** one git config across four homes, ssh commit signing, the WSL agent bridge. That is why chezmoi is here.

The shell calls those commands directly. Windows apply ensures they are present: if the command is already on `PATH`, leave it; if not, install it; if that install fails, the apply fails. Linux and WSL install the same command names with the distro package manager before the first shell.

Do not add language runtimes, Docker, direnv, GitHub CLI, cache-drive redirects, or a font/package manager beyond what the look above needs (scoop for CaskaydiaCove NF and `scoop-completion`).

## The four homes

| Home | What differs |
|------|--------------|
| Windows (this PC, ARM64; the desktop, x64) | Git signs and pushes through Windows OpenSSH. Apply ensures Git and the Windows vanilla+ tools. The font script ensures CaskaydiaCove NF. pwsh profile. |
| WSL (this PC) | Git signs through `wsl-ssh-sign` and the `wsl2-ssh-agent` bridge to the Windows agent. Credentials use the Windows credential manager through `~/.local/lib/win32`. `/etc/wsl.conf` enables systemd. |
| Bare-metal Linux (the desktop) | Git signs with `ssh-keygen` and the native agent. No Windows bridge. |

`home/.chezmoi.toml.tmpl` computes one fact, `isWSL`, from `.chezmoi.kernel.osrelease`. Both Linux homes report OS `linux`, so WSL is detected from the Microsoft kernel, not the OS name. Everything else uses chezmoi's built-ins (`.chezmoi.os`, `.chezmoi.arch`, `.chezmoi.homeDir`).

`home/.chezmoiignore` decides which paths exist on which home:

- Windows only: `Documents/PowerShell/profile.ps1`.
- Linux only: `~/.zshenv`, `~/.config/zsh`, `~/.ssh`, `~/.local`.
- WSL only: the systemd unit, `~/.local/lib/win32`, `wsl-ssh-sign`, `wsl2-ssh-agent`.
- Everywhere: `~/.config/git`, `~/.config/ripgrep`, `~/.config/yazi`.

## Git

One file, `~/.config/git/config`, for every home. There is no `~/.gitconfig`; with only the XDG file present, `git config --global` writes there too. Shared settings are written once. Only the signing program, `core.sshCommand` (Windows), and the credential helper vary. On WSL the credential helper is omitted when `git-credential-manager.exe` is not installed. `~/.config/git/ignore` is the global ignore file. `~/.config/git/config.local` is included last and is never managed: put per-machine settings there, such as a work identity with `includeIf "hasconfig:remote.*.url:..."`. Each email that signs commits, including one set in `config.local`, needs its own line in `~/.config/git/allowed_signers` with the same public key.

## Shell and XDG

`~/.zshenv` sets the XDG base directories and `ZDOTDIR=~/.config/zsh`; nothing else of zsh lives in `$HOME`. `~/.config/zsh/.zshenv` points cargo, rustup, npm, Python history, and node history at XDG paths so those tools do not clutter `$HOME`. `CARGO_HOME` and `RUSTUP_HOME` only work for a rustup installed after they are set. `~/.config/zsh/.zshenv.local` and `.zshrc.local` are unmanaged per-machine hooks, as is `~/.ssh/config.d/*`.

zsh calls `starship`, `zoxide`, `fzf`, `yazi`, `bat`, `fd`, and `eza` directly, and defines `y`. The PowerShell profile calls `starship`, `zoxide`, and `yazi` directly, defines `y`, enables the transient prompt in interactive sessions, and registers winget and scoop tab completion. Git and chezmoi use `delta`. See [README](../README.md).

## Windows

`home/.chezmoiscripts/run_onchange_before_windows-bootstrap.ps1.tmpl` runs before files are written and again whenever its content changes. chezmoi runs it with `pwsh`. PowerShell 7 or newer must already be installed; the script refuses to run on Windows PowerShell 5.1 and does not install PowerShell. For each Windows vanilla+ command (`git`, `rg`, `starship`, `zoxide`, `fzf`, `yazi`, `delta`) it skips the id when that command is already on `PATH`; otherwise it installs the winget id in the README, with no version pin. `delta` is included even though its Windows build is x64; emulation of that short process is negligible. A missing `winget` aborts the apply. A newer copy already on the machine, or an install that finished and asked for a reboot, does not abort the apply. It also sets `RIPGREP_CONFIG_PATH` to the shared ripgrep config and `YAZI_CONFIG_HOME` to `~/.config/yazi`, and warns when the `ssh-agent` service is not running. OneDrive is removed on every Windows home, so Documents is `~/Documents` and the profile path needs no redirection check.

`home/.chezmoiscripts/run_before_windows-font.ps1.tmpl` runs on every apply, still before files are written, also under `pwsh`, and also requires PowerShell 7. If scoop, the nerd-fonts bucket, CaskaydiaCove NF, extras, or `scoop-completion` is missing, it installs that piece. It sets Windows Terminal's default font face to `CaskaydiaCove NF` in each existing `settings.json`. A terminal that has never been opened has no settings file yet; the next apply sets the font after the first launch creates one. Installing scoop sets the current user's execution policy to `RemoteSigned` when that is what the installer requires.

`Documents/PowerShell/profile.ps1` is loaded by every pwsh host. It sets UTF-8 console encoding, `RIPGREP_CONFIG_PATH`, and `YAZI_CONFIG_HOME`, then exits early for agent sessions (`CURSOR_AGENT`, `CLAUDECODE`, `AI_AGENT`) and scripted runs, including a unique prefix such as `-enc`. That early exit skips prompt UI only, including the transient prompt, because starship is not loaded in those sessions. Interactive sessions get PSReadLine bindings, disk-cached init scripts for starship and zoxide (regenerated when the tool's executable or this profile changes), the `y` wrapper, the transient prompt, and tab completion for winget and scoop. Those commands are invoked directly.

## WSL

`home/.chezmoiscripts/run_onchange_after_wsl-setup.sh.tmpl` sets `systemd=true`, `appendWindowsPath=false`, and the current user as default in `/etc/wsl.conf`, and leaves every other line. When those keys change, the previous file is kept once as `/etc/wsl.conf.bak`. After `wsl.exe --shutdown` and another `chezmoi apply`, it enables `wsl2-ssh-agent.service`. `home/.chezmoiexternal.toml` downloads `wsl2-ssh-agent` v0.9.7 for the host architecture and checks its checksum. The `~/.local/lib/win32` symlinks expose `powershell.exe` and, when Git for Windows' credential manager is installed (machine-wide or per user), `git-credential-manager.exe`. The WSL git config sets that helper only when the executable exists.

## Bootstrap

chezmoi renders every template before any `run_before_` script runs, and it runs `.ps1` scripts with `pwsh`. Install chezmoi, Git, and PowerShell 7 first. See [README](../README.md).

The clone is `~/dotfiles` in each home, not chezmoi's default `~/.local/share/chezmoi` and not under `~/src`. `sourceDir` in `home/.chezmoi.toml.tmpl` pins it, so pass the same path to `chezmoi init --source`. A WSL clone lives inside the distro, not under `/mnt/c`.

## Rules

- Edit the source in `home/` (or `chezmoi edit --apply <target>`). The installed copy is output; pull home edits back with `chezmoi re-add` (plain files) or `chezmoi merge` (templates).
- Add a home file with `chezmoi add <target>`. Gate it per home in `.chezmoiignore` or with `{{ if }}` in a template.
- Add a Windows vanilla+ package by adding its command name and winget id to the bootstrap script. Do not copy ids off the machine you are using.
- Do not inventory a machine and write that inventory back into this repo.
- The repo lives at `~/dotfiles`. Do not create `~/src`. Do not add product checkout paths. Do not put project clones in this repo.
- OneDrive is removed on every Windows home. Documents is `~/Documents`. Do not detect folder redirection or add a fallback profile path.
- chezmoi commits source changes automatically (`git.autoCommit`) and never pushes; push deliberately.
- Line endings stay LF (`.gitattributes`).
