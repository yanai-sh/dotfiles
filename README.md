# Dotfiles

Managed with [chezmoi](https://www.chezmoi.io/). The source state is in `home/`; see [Design](docs/design.md).

The repo is cloned to `~/dotfiles` in every home. On WSL that clone is a real directory inside the distro, not a symlink to `/mnt/c`.

## Existing clone

When `~/dotfiles` is already a git repo, point chezmoi at it, read the diff, then write the home. Chezmoi clones only when the source directory is not a repo, so no URL is needed.

```sh
chezmoi init --source "$HOME/dotfiles"
chezmoi diff
chezmoi apply
```

On Windows, the same commands in PowerShell use `$HOME\dotfiles`.

## Fresh machine

Use this only after this tree is on `origin/main`. Install the prerequisites first: chezmoi renders templates before its setup script runs.

Windows:

```powershell
winget install --id twpayne.chezmoi -e
winget install --id Git.Git -e
chezmoi init --apply --source "$HOME\dotfiles" https://github.com/yanai-sh/dotfiles.git
```

Linux and WSL, from inside the distro:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply --source "$HOME/dotfiles" https://github.com/yanai-sh/dotfiles.git
```

Open a new terminal and run `chezmoi apply` once more, so settings that depend on the newly installed PowerShell render. For signing and ssh, the Windows `ssh-agent` service must be running with the key loaded (`ssh-add`).

On WSL the first apply writes `/etc/wsl.conf` (asks for `sudo`). Run `wsl.exe --shutdown` from Windows, reopen the distro, and run `chezmoi apply` again to start the ssh agent bridge.

## Daily use

```sh
chezmoi edit --apply ~/.config/git/config   # edit a managed file
chezmoi diff                                # preview
chezmoi apply                               # write the home
chezmoi update                              # pull and apply
```
