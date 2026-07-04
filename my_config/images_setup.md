# Inline images in Neovim on WezTerm (Windows) + WSL2

How inline image rendering works in this config. Stack: WezTerm (native Windows)
→ WSL2 Neovim → **image.nvim** (kitty backend) for inline rendering +
**img-clip.nvim** for clipboard paste, in markdown notes.

## TL;DR — the one thing that matters

**You must run WezTerm NIGHTLY** (or any build with the ~1.22-era ConPTY or later).
Inline images do NOT work on WezTerm stable `20240203`.

- The blocker was never WezTerm's image decoder — that's the same cross-platform
  code on Windows and Linux. The blocker is **ConPTY**, the Windows pseudo-console
  feeding WSL panes, which on old versions **strips the kitty (APC) and sixel (DCS)
  escape sequences** before WezTerm ever sees them. (iTerm2/OSC 1337 always passed,
  because ConPTY forwards OSC.)
- Fixed by WezTerm nightly bundling a newer ConPTY: WezTerm **#1236** ("conpty
  limitation", closed *fixed-in-nightly*, Feb 2025) and **#6032** ("sixel does not
  work on wezterm but works on wezterm ssh" — proof the decoder works and the
  transport was the wall). Note **#5757** is a *duplicate* of these ConPTY issues,
  NOT a statement that the Windows build can't decode kitty/sixel.
- Verified on this machine: `my_config/scripts/img_protocol_test.sh` renders all
  three roses (sixel, kitty, iTerm2) on nightly.

If you're stuck on stable and can't run nightly, the alternative is a WezTerm
**SSH domain** into WSL's `sshd` (bypasses ConPTY) — see the bottom of this file.

## Prerequisites (WSL side)

```bash
sudo apt-get install -y imagemagick   # provides convert/identify (magick_cli backend)
# curl is already present (image.nvim uses it for remote images)
```

Ubuntu 22.04 ships ImageMagick 6 (`convert`/`identify`) — fine. `magick_cli`
detects the missing v7 `magick` binary and falls back automatically. **No LuaRocks
/ no `magick` LuaRock** — that's the point of `processor = "magick_cli"`.

## WezTerm

`config.enable_kitty_graphics = true` is set (in
`C:/ws/.frequent/terminal/wezterm/wezterm.lua`). It's **off by default** and the
kitty backend needs it. On nightly this finally takes effect (on old stable,
ConPTY stripped the bytes regardless of the flag).

We use the **sixel** backend, NOT kitty — this is essential, not a preference.
image.nvim's kitty backend transmits images by writing a temp file to a **WSL
path** and handing WezTerm that path; WezTerm is a Windows process and can't read
a WSL path, so kitty renders nothing here. (It only inlines/"direct"-transmits
under SSH; no config forces it otherwise.) The sixel backend embeds pixel data
inline — no path — so it works. See the header comment in `image.lua` for detail.

## Neovim plugins (auto-imported via `{ import = 'custom.plugins' }`)

- `lua/custom/plugins/image.lua` — image.nvim; `backend = "sixel"` (kitty can't
  work here — see above), `processor = "magick_cli"`, markdown rendering,
  lazy-loaded on markdown files.
- `lua/custom/plugins/img-clip.lua` — img-clip.nvim; `<leader>p` → `:PasteImage`,
  saves into `./assets/` next to the note, inserts `![]($FILE_PATH)`.

## The WSL clipboard bridge (required for img-clip — non-obvious)

img-clip pastes from the **Windows** clipboard via `powershell.exe` (bare name, via
`PATH`). This machine's `~/.bashrc` **hard-overwrites `PATH`** and omits the Windows
`/mnt/c/...` dirs, so `powershell.exe` isn't found. Fix — one symlink into
`~/.local/bin` (already on `PATH`), instead of re-appending all of Windows' PATH:

```bash
ln -sf /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe \
  ~/.local/bin/powershell.exe
```

Machine-local (not version-controlled) — recreate on a new machine.

## Using it

1. **View**: open a markdown file in a **nightly-WezTerm WSL tab**; `![](path)`
   images render inline automatically (image.nvim, markdown integration).
2. **Paste**: `Win+Shift+S`, then `<leader>p` in a markdown buffer.

Sanity probe any terminal: `bash my_config/scripts/img_protocol_test.sh` (run
directly in the terminal, NOT in tmux, NOT via `:!`).

## Troubleshooting

- **No image / black placeholder** → you're on WezTerm **stable** (ConPTY strips
  the bytes) or not in a WezTerm tab at all (Neovide/VSCode/plain console). Use a
  nightly-WezTerm WSL tab. Confirm with the protocol test script.
- **sixel renders but looks coarse** → expected (color quantization, no alpha);
  fine for note images. kitty would be higher quality but can't work here (WSL-path
  transmission problem — see the WezTerm section).
- **`<leader>p` pastes nothing / "powershell.exe is not installed"** → the clipboard
  bridge above; confirm `command -v powershell.exe` resolves.
- **`:checkhealth img-clip` errors on `wl-clipboard`** → false positive under WSLg,
  ignore (its health check tests `WAYLAND_DISPLAY` before the WSL branch; the actual
  paste path uses `powershell.exe`). Do NOT install `wl-clipboard`.

## Alternative: SSH domain (works on WezTerm STABLE, no nightly)

`wezterm ssh` into WSL's sshd bypasses ConPTY (WezTerm #6032, yazi docs). Steps:
`sudo apt install openssh-server` + enable it; add to `wezterm.lua`:

```lua
config.ssh_domains = config.ssh_domains or {}
table.insert(config.ssh_domains, {
  name = 'wsl-ssh', remote_address = '127.0.0.1', username = 'ws',
  multiplexing = 'WezTerm',
})
```

Open a tab in the `wsl-ssh` domain and run the protocol test. Trap: typing
`ssh 127.0.0.1` inside a normal WSL pane does NOT bypass ConPTY — WezTerm itself
must own the connection via the domain.
