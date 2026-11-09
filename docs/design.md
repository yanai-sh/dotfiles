# Design

chezmoi manages this repository. `.chezmoiroot` points chezmoi at `home/`, so only `home/` is source state. Everything else at the repo root (`README.md`, `docs/`, `.cursor/`, `.gitattributes`) is about the repo and is never applied.

Source names use chezmoi's prefixes: `dot_config` is `~/.config`, `private_dot_ssh` is `~/.ssh` with mode `700`, `executable_` sets the exec bit, `symlink_` creates a link, and `.tmpl` files are Go templates. Day to day, address files by their real target path (`chezmoi edit ~/.config/git/config`), not by the source name.

## The four homes

| Home | What differs |
|------|--------------|
| Windows (this PC, ARM64; the desktop, x64) | Git signs and pushes through Windows OpenSSH. The bootstrap script installs packages. The cache script sets user env vars. pwsh profile. |
| WSL (this PC) | Git signs through `wsl-ssh-sign` and the `wsl2-ssh-agent` bridge to the Windows agent. Credentials use the Windows credential manager through `~/.local/lib/win32`. `/etc/wsl.conf` enables systemd. |
| Bare-metal Linux (the desktop) | Git signs with `ssh-keygen` and the native agent. No Windows bridge. |

`home/.chezmoi.toml.tmpl` computes one fact, `isWSL`, from `.chezmoi.kernel.osrelease`. Both Linux homes report OS `linux`, so WSL is detected from the Microsoft kernel, not the OS name. Everything else uses chezmoi's built-ins (`.chezmoi.os`, `.chezmoi.arch`, `.chezmoi.homeDir`).

`home/.chezmoiignore` decides which paths exist on which home:

- Windows only: `Documents/PowerShell/profile.ps1`.
- Linux only: `~/.zshenv`, `~/.config/zsh`, `~/.ssh`, `~/.local`.
- WSL only: the systemd unit, `~/.local/lib/win32`, `wsl-ssh-sign`, `wsl2-ssh-agent`.
- Everywhere: `~/.config/git`, `~/.config/ripgrep`, `~/.config/direnv`.

## Git

One file, `~/.config/git/config`, for every home. There is no `~/.gitconfig`; with only the XDG file present, `git config --global` writes there too. Shared settings are written once. Only the signing program, `core.sshCommand` (Windows), and the credential helper vary. On WSL the credential helper is omitted when `git-credential-manager.exe` is not installed. `~/.config/git/ignore` is the global ignore file. `~/.config/git/config.local` is included last and is never managed: put per-machine settings there, such as a work identity with `includeIf "hasconfig:remote.*.url:..."`.

## Shell and XDG

`~/.zshenv` sets the XDG base directories and `ZDOTDIR=~/.config/zsh`; nothing else of zsh lives in `$HOME`. `~/.config/zsh/.zshenv` points cargo, rustup, npm, Python history, and node history at XDG paths. `CARGO_HOME` and `RUSTUP_HOME` only work for a rustup installed after they are set. `~/.config/zsh/.zshenv.local` and `.zshrc.local` are unmanaged per-machine hooks, as is `~/.ssh/config.d/*`.

## Windows

`home/.chezmoiscripts/run_onchange_before_windows-bootstrap.ps1.tmpl` runs before files are written and again whenever its content changes. It stays Windows PowerShell 5.1 compatible because pwsh may not exist yet. It installs the winget ids listed in the script (Git, PowerShell) with no version pin, so each run asks winget for the current package. A newer copy already on the machine, or an install that finished and asked for a reboot, does not abort the apply. It also sets `RIPGREP_CONFIG_PATH` to the shared ripgrep config, and warns when the `ssh-agent` service is not running or Documents is redirected (OneDrive), since pwsh would then not find the profile.

`home/.chezmoiscripts/run_before_windows-caches.ps1.tmpl` runs on every apply, still before files are written, and stays PowerShell 5.1 compatible. If `D:\` exists, it creates `D:\cache\{nuget,npm,cargo,pip}` and sets `NUGET_PACKAGES`, `npm_config_cache`, `CARGO_HOME`, and `PIP_CACHE_DIR` as persistent user variables, so every program sees them, not only pwsh. Any `D:` counts. If `D:\` is missing, it removes those variables only when their value is under `D:\cache\`. It does not create `D:\dev`.

`Documents/PowerShell/profile.ps1` is loaded by every pwsh host. It sets UTF-8 console encoding, then exits early for agent sessions (`CURSOR_AGENT`, `CLAUDECODE`, `AI_AGENT`) and scripted runs after putting fnm's Node on `PATH`. Interactive sessions get PSReadLine bindings, disk-cached init scripts for starship, zoxide, gh, and docker (regenerated when the tool's executable changes), fnm with `--use-on-cd`, and winget completion. fnm picks the Node architecture from its own binary, so install the native build for each machine.

## WSL

`home/.chezmoiscripts/run_onchange_after_wsl-setup.sh.tmpl` writes `/etc/wsl.conf` with `sudo` when it differs (systemd on, Windows `PATH` not appended, the current user as default). The first previous file is kept as `/etc/wsl.conf.bak`; later runs do not replace that backup. After `wsl.exe --shutdown` and another `chezmoi apply`, it enables `wsl2-ssh-agent.service`. `home/.chezmoiexternal.toml` downloads the latest `wsl2-ssh-agent` for the host architecture and refreshes it weekly. The `~/.local/lib/win32` symlinks expose `powershell.exe` and, when Git for Windows' credential manager is installed (machine-wide or per user), `git-credential-manager.exe`. The WSL git config sets that helper only when the executable exists.

## Bootstrap

chezmoi renders every template before any `run_before_` script runs, so install chezmoi and Git first. See [README](../README.md).

The clone is `~/dotfiles` in each home, not chezmoi's default `~/.local/share/chezmoi` and not under `~/src`. `sourceDir` in `home/.chezmoi.toml.tmpl` pins it, so pass the same path to `chezmoi init --source`. A WSL clone lives inside the distro, not under `/mnt/c`.

## Rules

- Edit the source in `home/` (or `chezmoi edit --apply <target>`). The installed copy is output; pull home edits back with `chezmoi re-add` (plain files) or `chezmoi merge` (templates).
- Add a home file with `chezmoi add <target>`. Gate it per home in `.chezmoiignore` or with `{{ if }}` in a template.
- Add a Windows package by adding its winget id to the bootstrap script. Do not copy ids off the machine you are using.
- Do not inventory a machine and write that inventory back into this repo.
- The repo lives at `~/dotfiles`. Do not create `~/src`. Do not add product checkout paths. Do not put project clones in this repo.
- chezmoi commits source changes automatically (`git.autoCommit`) and never pushes; push deliberately.
- Line endings stay LF (`.gitattributes`).
