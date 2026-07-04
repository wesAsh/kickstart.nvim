-- image.nvim — TRUE inline image rendering in the buffer (markdown notes, etc.).
--
-- REQUIRES WEZTERM **NIGHTLY** (ConPTY >= ~1.22). Old stable's ConPTY strips the
-- kitty/sixel escapes from WSL panes (WezTerm #1236 "conpty limitation",
-- fixed-in-nightly; #6032). Confirmed: raw kitty & sixel probes render on nightly.
--
-- BACKEND = SIXEL (deliberately, not kitty). Why:
--   image.nvim's KITTY backend transmits images by FILE by default — it writes a
--   temp file to a WSL path (/tmp/...) and hands WezTerm that path to read. But
--   WezTerm is a *Windows* process and can't read a WSL filesystem path, so
--   nothing renders. (It only switches to inline/"direct" transmission when it
--   detects SSH: is_SSH = SSH_CLIENT/SSH_TTY set — not the case in a plain WSL
--   pane, and there's no config option to force direct.)
--   The SIXEL backend embeds the pixel data INLINE in the escape (magick ...
--   sixel:-), sending no path — so the Windows/WSL path mismatch doesn't apply.
--   It's also image.nvim's officially recommended backend for WezTerm.
--
-- processor = "magick_cli" shells out to ImageMagick's convert (IM6 is fine, and
-- supports sixel:-) — no luarocks / no `magick` LuaRock.
--
-- If you ever run under real Linux kitty / Ghostty, or over `wezterm ssh`, switch
-- backend back to "kitty" for higher quality + caching.
return {
  '3rd/image.nvim',
  ft = { 'markdown' }, -- lazy-load when a markdown note is opened
  opts = {
    backend = 'sixel',
    processor = 'magick_cli',
    integrations = {
      markdown = {
        enabled = true,
        clear_in_insert_mode = false,
        download_remote_images = true,
        only_render_image_at_cursor = false,
        filetypes = { 'markdown' },
      },
    },
    max_width_window_percentage = nil,
    max_height_window_percentage = 50,
    window_overlap_clear_enabled = true, -- hide images when a float/popup overlaps
    editor_only_render_when_focused = false,
    tmux_show_only_in_active_window = true,
  },
}
