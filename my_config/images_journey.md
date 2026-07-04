# Inline images in Neovim (WezTerm + WSL2): the full investigation

A lab-notebook of how we got inline images working, including the dead ends and
one wrong conclusion — so the reasoning isn't lost and mistakes aren't repeated.
For the **operational setup**, see `images_setup.md`. This file is the *story*.

**Final working answer (TL;DR):** WezTerm **nightly** (newer ConPTY) + image.nvim
with the **sixel** backend + `processor="magick_cli"`. img-clip.nvim for paste.

## Goal & environment

- Goal: images rendered **inline** in Neovim markdown notes.
- Windows 11 + native-Windows **WezTerm** → **WSL2 Ubuntu 22.04**, **Neovim
  0.12-dev** in WSL (kickstart + lazy.nvim). We chose WSL-side nvim (not
  Windows-native) so ImageMagick installs trivially via apt.

## Timeline

1. **Installed image.nvim (kitty) + img-clip.nvim.** img-clip paste failed at
   first: it calls `powershell.exe` by bare name, but `~/.bashrc` overwrites PATH
   without `/mnt/c`. Fixed with a symlink `~/.local/bin/powershell.exe`. **Paste
   worked from here on.**

2. **Images rendered as black boxes.** First red herring: the test PNG was
   16-bit; regenerating as 8-bit didn't fix it. So it wasn't the image.

3. **Raw protocol probes (bypassing Neovim entirely)** in a WSL WezTerm pane:
   - kitty (APC): nothing · sixel (DCS): nothing · **iTerm2 (OSC 1337): rendered.**

4. **WRONG CONCLUSION (this session's mistake):** concluded "native-Windows
   WezTerm only decodes the iTerm2 protocol" and cited issue #5757. This was based
   on a **failed WebFetch** of #5757 (the page errored) plus an **AI-generated
   search summary** — a weak source treated as fact. It invented a second wall
   (a decoder limitation) that does not exist. **Lesson: don't harden a
   summary/failed-fetch into a stated fact; verify the primary source.**

5. **Built an iTerm2/OSC-1337 preview hack** (a script emitting the escape,
   invoked from nvim). Discovered nvim's `:!` child has **no controlling
   terminal** (`tpgid=-1`), so `/dev/tty` reads fail; moving the wait to
   `getcharstr()` then made nvim **hang**. Abandoned — and the user wanted true
   inline, not a preview, anyway.

6. **Fresh agent + web research corrected the model** (verified against primary
   sources this session):
   - #5757 is a **duplicate of the ConPTY issues** (#1673 / #1236), not a decoder
     statement. The image decoder is the **same cross-platform code** on Windows.
   - The real wall is **ConPTY** (Windows pseudo-console for WSL panes), which
     **strips APC (kitty) and DCS (sixel)** escapes; OSC (iTerm2) passes — exactly
     matching the step-3 results. (#1236 label: "conpty limitation".)
   - **Fixed in WezTerm nightly** (bundles newer ConPTY; #1236 "fixed-in-nightly",
     Feb 2025). Proof the decoder was never the problem: #6032 = "sixel does not
     work on wezterm but works on **wezterm ssh**" (SSH bypasses ConPTY).
   - Also: `enable_kitty_graphics` is **off by default** in WezTerm — needed for
     kitty, and a contributor to the original kitty probe failing.

7. **Installed WezTerm nightly** (portable, alongside stable). Raw probe:
   **all three roses rendered** (sixel, kitty, iTerm2). The ConPTY wall was down.

8. **image.nvim kitty STILL failed** — the last wall, and image.nvim-specific.
   Its **kitty backend transmits by FILE**: it writes a temp PNG to a **WSL path**
   and hands WezTerm that path. WezTerm is a **Windows** process and can't read a
   WSL path → nothing. (It only inlines under SSH: `is_SSH = SSH_CLIENT/SSH_TTY`;
   no config forces direct.) The **sixel backend embeds pixel data inline** (no
   path) → immune to the mismatch.

9. **Switched image.nvim to `backend = "sixel"`.** **Inline images render.** Done.

## The three walls, in order (all had to fall)

1. **ConPTY** stripped kitty/sixel from WSL panes → fixed by WezTerm **nightly**.
2. **`enable_kitty_graphics`** off by default → set `= true` (matters for kitty;
   sixel doesn't need it, but harmless).
3. **image.nvim kitty file-transmission** sends a WSL path Windows-WezTerm can't
   read → use the **sixel** backend (inline data, no path).

## Lessons

- Verify primary sources; never let a failed fetch or an AI summary become a
  "fact." (Wall-2 mistake cost a whole detour into a preview hack.)
- **Isolate with raw tests.** The bypass-Neovim protocol probes were what actually
  moved the diagnosis forward every time.
- **Transmission medium matters as much as protocol.** Even with the right
  protocol and a capable terminal, file-vs-inline transmission across the
  Windows/WSL boundary was the final blocker.

## Rejected alternatives (and why)

- iTerm2-emitting inline plugin: none exists (image.nvim/snacks/hologram are
  kitty/sixel; the iTerm2 protocol lacks placement IDs for redraw-on-scroll).
- Windows Terminal + sixel: works at the raw layer, unproven end-to-end, and
  means abandoning WezTerm.
- WSLg Linux terminal (real kitty): most "correct" kitty setup but a separate GUI
  window with HiDPI blur; unnecessary once nightly+sixel worked.
- `wezterm ssh` domain into WSL sshd: valid ConPTY bypass for **stable** WezTerm
  (no nightly), at the cost of a permanent sshd + panes living in an SSH domain.
