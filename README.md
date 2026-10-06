# Dotfiles

Personal machine config for a **three-root** host: WSL (Linux source), ReFS Dev Drive (Windows apps), NTFS `C:` (host imaging + SDKs + agent stores).

Chezmoi source state and apply templates live here as they grow. Until then, the operating model is documented under [`docs/`](docs/).

## Docs

| Doc | Topic |
|-----|--------|
| [Three roots](docs/three-roots.md) | Where projects live, what never crosses roots |
| [Chezmoi + caches + agents](docs/chezmoi-caches-agents.md) | Dotfiles vs caches vs Cursor/agent state |

## Host facts (SL7)

- Windows 11 ARM64, Asia/Jerusalem.
- WinMint (host imaging) stays on NTFS under `C:\Users\yanai\Projects\winmint` — not on Dev Drive, not in WSL.
- Product repo: [yanai-sh/winmint](https://github.com/yanai-sh/winmint). This repo is personal environment only.
