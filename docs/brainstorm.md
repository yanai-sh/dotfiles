# Brainstorm: which tool should manage these dotfiles

## Decision

chezmoi, with the source state under `home/` (`.chezmoiroot`). The `dot_` naming was judged a cosmetic cost: files are addressed by their real target path day to day. What decided it is the last section below: four homes share one git config with a different signing program on each, plus ssh modes and WSL-only files. See [design.md](design.md).

The rest of this file is the discussion record, written when the design was real filenames, `deploy.txt`, `setup.ps1`, and `setup.sh`.

## The starting tree

The repo is a home directory. `deploy.txt` copies:

| Path | Where |
|---|---|
| `.gitconfig` | Windows and Linux |
| `.zshenv`, `.config`, `.local`, `.ssh` | Linux. `.ssh` is `700`, `.ssh/config` is `600`, `wsl-ssh-sign` is `755` |
| `Documents/PowerShell` | Windows. The profile points caches at `D:\cache` |

`.config/git/config` is the Linux git file. It keeps `~/` in the repo. `setup.sh` rewrites that to the real home path in the installed copy, because git does not expand `~/` in `gpg.ssh.program` or `credential.helper`. That file also assumes WSL: `wsl-ssh-sign`, and the Windows credential helper under `~/.local/lib/win32`.

Linux is the larger set. Windows is `.gitconfig` and the PowerShell profile. Windows and WSL do not share a home, so each home is installed from its own clone. A Linux clone lives inside the distro, not under `/mnt/c`.

## Tools that were set aside

Stow, chezmoi, yadm, dotbot, and the `.dotfiles` tool (the project documented at <https://doc.dotfiles.io/manual/>, which wraps chezmoi) were compared, along with smaller managers (yui, store, DotState, rcm). Bare git and a hand-written installer were out of scope.

**`.dotfiles` is chezmoi plus a workstation product.** Chezmoi still reads `~/.dotfiles/defaults/`, renders templates, and writes `$HOME`. `dot apply` runs `chezmoi apply --force`. The installer clones their release and applies their shell, gitconfig, and feature flags. Keeping your own files means copying them into `defaults/` and merging `.chezmoidata.toml`, `.chezmoiignore`, and `.chezmoi.toml.tmpl` with theirs. Doctor, themes, fleet, and attestation do not set ssh modes or rewrite the gitconfig path. Their platform matrix lists Windows and WSL as x86_64. Personal use does not need that product. Their own migration guide says plain chezmoi is the smaller surface when you do not want the CLI layer.

**yadm** uses `$HOME` as the work tree and real names, with `##os.Linux` suffixes. The suffixed file still sits in the home on the other OS. Git still cannot store mode `600` or `700`. The gitconfig rewrite needs a template. On Windows the tool runs from Git Bash.

**dotbot and Stow** symlink. The home file and the repo file are the same bytes, so they cannot rewrite `~/` on install. Directory symlinks on Windows need Developer Mode or an admin shell.

**Chezmoi's naming is permanent.** Source names that start with a dot are ignored, so `.gitconfig` is stored as `dot_gitconfig`. `private_` and `executable_` encode modes. There is no setting that turns the spelling off.

## What chezmoi adds over Stow

Stow is enough while a file in git and the file in `$HOME` are the same bytes, and while "Linux only" or "Windows only" is a matter of which directory you link.

Chezmoi keeps a source file and writes a separate file on apply. Two things follow, and they are the ones that matter here:

- The installed bytes can differ from the repo. `.config/git/config` can keep `~/` in git and contain the real home path on disk.
- `private_` reapplies `.ssh` as `700` and `.ssh/config` as `600`. Git records only the executable bit, so Stow cannot put those modes back after a clone. `wsl-ssh-sign` being executable is already covered by git.

A larger pile of ordinary files does not change this. More zsh, git, and `.config` entries are still Stow's job. Age-encrypted secrets, and one path that must render differently per machine, are the point where the copy-and-substitute steps become a second installer.

## When chezmoi is the better tool

Any one of these:

- About three files whose installed content is generated, not copied. One rewrite (the gitconfig tilde) is still a small exception.
- One path must come out different on different machines, and the shared part of that file should be edited once.
- A secret must live in the repo encrypted and land on disk decrypted, mode `600`.
- The Windows side is no longer two paths you can copy from memory.

## These computers

Personal use, two computers, four homes:

| Home | What is already machine-specific |
|---|---|
| This PC, Windows on ARM | PowerShell profile. Caches are `D:\cache`. |
| This PC, WSL | Git signing goes through `wsl-ssh-sign`. The credential helper is the Windows exe under `~/.local/lib/win32`. A user service talks to the WSL ssh agent. |
| Desktop, Windows | The PowerShell profile is right only if that install also has a Dev Drive at `D:`. Signing there would use Windows OpenSSH. |
| Desktop, Linux, bare metal | The zshrc and the shared git preferences still apply. The WSL signing program, the Windows credential helper, and the WSL agent unit do not. |

Dual boot does not share a home. The desktop gets one apply in Windows and one apply in Linux. Architecture barely affects the text files. ARM versus x64 matters when a path points at a binary. Both Linux homes report OS `linux`, so a WSL-only line is chosen from the hostname or from the Microsoft kernel, not from the OS name.

The shared half stays one copy: name and email, delta, rebase, the zshrc, ripgrep, direnv. The PowerShell cache lines can stay a single file if the profile checks that `D:\cache` exists and falls back otherwise. The git config cannot. Signing on each home is one policy and a different `gpg.ssh.program`. Stow would keep a full copy of that file per home, and a change to merge or rebase settings would be repeated in each.

For that layout, each home is `chezmoi init --apply`. Plain files are copied. The git config, the agent socket, and the ssh modes come out for that computer. `.dotfiles` is still the wrong layer on top.
