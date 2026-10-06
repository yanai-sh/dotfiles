# Three roots

Day-to-day work uses **three fixed roots**. Open exactly one root per Cursor window. Do not dual-home the same git clone.

| Root | Filesystem | Purpose | Open with |
|------|------------|---------|-----------|
| `~/src` (WSL ext4) | Linux VHD | Linux-first projects | Cursor Remote-WSL / shell in distro |
| `D:\dev` | ReFS Dev Drive | Windows apps that never DISM / Hyper-V | Cursor on Windows |
| `C:\Users\yanai\Projects\winmint` | NTFS | Host imaging (WinMint) | Cursor on Windows, that folder only |

## Placement rule

Ask in order for a new project:

1. Primary runtime is Linux? → WSL `~/src`
2. Needs DISM, Hyper-V, ISO trees, elevated host servicing? → NTFS `C:` (WinMint-class)
3. Else Windows-native? → Dev Drive `D:\dev`

## Fixed companions (not project roots)

| Path | Role |
|------|------|
| `%ProgramData%\WinMint\Servicing` | DISM mounts + quality cache (NTFS; leave alone) |
| `%ProgramData%\WinMint\work` | Default CLI work dir |
| `C:\Users\yanai\Projects\winmint\.scratch` | Maintainer smoke / apply media + smoke VHDX |
| Source ISO (user-supplied) | Stay on NTFS (e.g. Documents); never commit bytes |
| SDKs, Visual Studio, Windows SDK, pwsh | Stay on `C:` — not on Dev Drive |

## Do not

- Clone WinMint inside WSL or onto the Dev Drive.
- Edit WinMint via `/mnt/c/...` or `\\wsl$\...` as the daily path.
- Put `.scratch`, ISO, or smoke VHDX on ReFS.
- Use a VHDX-backed Dev Drive for Hyper-V-heavy work if a partition is available (nested VHDX cost).
- Junction “clever” trees across the three roots.

## Shell habit

- WSL projects: only distro shell; paths under `$HOME`.
- Dev Drive / WinMint: native ARM64 `pwsh`.
- WinMint Apply / smoke: elevated `pwsh -File` on the host — never “run Just from WSL.”

## Related

- [Chezmoi + caches + agents](chezmoi-caches-agents.md)
- [Microsoft Dev Drive](https://learn.microsoft.com/en-us/windows/dev-drive/)
- DISM mounts require an **NTFS** mount directory; ReFS is unsupported for that path ([DISM supported platforms](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism-supported-platforms)).
