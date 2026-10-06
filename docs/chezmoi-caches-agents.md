# Chezmoi, caches, and agents

**Chezmoi owns config.** Caches and project trees stay out of git. Agent durable state stays on NTFS under the user profile.

## Layer map

| Layer | Tool | Where |
|-------|------|--------|
| Dotfiles / shell / env pointers | chezmoi | Applied into Windows home **and** WSL home |
| Package / build caches | env vars only | `D:\cache\...` or WSL `~/.cache` |
| Project source | git clone | See [three roots](three-roots.md) |
| Agent memory / skills | Cursor / Claude defaults | NTFS under profile / `AppData` |

## Chezmoi: one source, two applies

Windows and WSL are different OS identities. One git remote; two installs; two applies:

```text
github.com/yanai-sh/dotfiles
        │
        ├─► chezmoi apply          (Windows)  → C:\Users\yanai\...
        └─► wsl: chezmoi apply     (Linux)    → ~/.config, shell rc, ...
```

- Clone the source state on **NTFS** for the Windows chezmoi (`%USERPROFILE%\.local\share\chezmoi`).
- In WSL, use a **separate** clone under the distro home — do not daily-drive `/mnt/c/.../chezmoi` as the sourceDir.
- Branch templates with `.chezmoi.os` and WSL detection:

```gotemplate
{{ if eq .chezmoi.os "linux" }}
{{   if (.chezmoi.kernel.osrelease | lower | contains "microsoft") }}
# WSL-only
{{   end }}
{{ end }}
```

Ignore wrong-OS paths with a templated `.chezmoiignore`.

### Put in chezmoi

- PowerShell profile, WSL shell rc, starship, gitconfig templates
- Env fragments that only **point** at roots and caches
- A short roots file agents/humans can read (paths + placement rule)
- Windows Terminal profiles that open each root
- Optional portable Cursor **user** settings snippets

### Keep out of chezmoi

- NuGet / npm / cargo / pip cache bodies
- WinMint `.scratch`, `%ProgramData%\WinMint\Servicing`
- Source ISO
- Cursor AgentStores / chat history
- Product `AGENTS.md` / repo skills (owned by each project, e.g. winmint)

## Cache layout

Once a Dev Drive exists at `D:` (prefer a **partition** over a VHDX host file):

```text
D:\
  dev\                 Windows app clones
  cache\
    nuget\
    npm\
    cargo\
    pip\
```

Windows profile (chezmoi-applied, sourced from `$PROFILE`):

```powershell
$env:NUGET_PACKAGES = 'D:\cache\nuget'
$env:npm_config_cache = 'D:\cache\npm'
$env:CARGO_HOME = 'D:\cache\cargo'
```

WSL (ext4 — not `/mnt/d` for Linux builds):

```bash
export npm_config_cache="$HOME/.cache/npm"
export CARGO_HOME="$HOME/.cache/cargo"
# projects live in ~/src
```

WinMint may use `NUGET_PACKAGES` on `D:\` for restore speed. Its **repo**, **`.scratch`**, and **DISM mounts** stay on NTFS.

Skip moving `%TEMP%` / `%TMP%` onto Dev Drive until you explicitly allow the `WinSetupMon` filter and accept side effects.

## Agents

| Thing | Location |
|-------|----------|
| Synced user rules / personal skills | chezmoi → profile paths (`.cursor`, `.claude`, …) |
| Cursor AgentStores | default under `%LOCALAPPDATA%\Cursor\...` (NTFS) |
| Project agent contracts | inside each git root |

Pointer text (user rule or roots file), keep it short:

> Three roots: WSL `~/src` · Dev Drive `D:\dev` · host imaging `C:\Users\yanai\Projects\winmint`. Never open WinMint from WSL or ReFS.

Do not relocate agent stores or `%ProgramData%\WinMint` onto ReFS.

## Bootstrap order

1. Create Dev Drive partition; mkdir `D:\dev`, `D:\cache\...`.
2. `chezmoi init --apply` on Windows from this repo; source under `%USERPROFILE%\.local\share\chezmoi`.
3. Same remote `chezmoi init --apply` inside WSL; ignore Windows-only paths.
4. Apply cache env; optionally migrate NuGet once.
5. Clone Windows apps into `D:\dev\...`; leave WinMint on `C:\Users\yanai\Projects\winmint`.
6. Pin three Cursor / Terminal entry points.
7. For WinMint heavy dirs: use the product’s Defender exclusion recipe (`just exclude-scratch` in winmint). Trust the Dev Drive for `D:\` per Microsoft guidance.

## Anti-patterns

- One apply from WSL that writes into `/mnt/c`, `D:`, and `~/` together.
- Chezmoi source state only on `D:` while Windows profiles must exist before the volume mounts.
- Symlinking AgentStores or WinMint servicing onto ReFS.
- Project clones inside the chezmoi source tree.
- Dual clones of the same repo across roots “for convenience.”
