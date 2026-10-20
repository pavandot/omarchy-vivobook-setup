-- Golden Gate: specular hairline window edges (from colors.toml) plus the glass module.
local active_border_color = { colors = { "rgba(ffffff5c)", "rgba(c9ccff10)" }, angle = 135 }
local inactive_border_color = "rgba(ffffff12)"

hl.config({
  general = {
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },
})

-- Golden Gate theme: macOS 27 Liquid Glass. Frosted blur, a darkened edge shadow,
-- hairline borders and the tighter, uniform window corners of Golden Gate. Installed by extras/install-glass.sh.
-- Remove the matching require line from ~/.config/hypr/hyprland.lua to disable.

hl.config({
  general = {
    border_size = 1,
    -- macOS "Tiled windows have margins": the same 8px between windows as to
    -- the screen edges (gaps_in is per window, so two neighbours sum to 8).
    gaps_in = 4,
    gaps_out = 8,
  },

  decoration = {
    rounding = 12,
    rounding_power = 3.0,

    shadow = {
      enabled = true,
      range = 32,
      render_power = 4,
      color = "rgba(000000a6)",
      color_inactive = "rgba(00000066)",
    },

    -- Frosted, less see-through than Tahoe, slightly vibrant blur behind translucent surfaces only;
    -- opaque app windows are unaffected.
    blur = {
      enabled = true,
      size = 12,
      passes = 3,
      noise = 0.02,
      contrast = 1.0,
      brightness = 0.85,
      vibrancy = 0.3,
      vibrancy_darkness = 0.2,
      new_optimizations = true,
      xray = false,
      popups = true,
      popups_ignorealpha = 0.2,
    },
  },
})

-- Glass shell surfaces. ignore_alpha keeps the faint dim scrim behind menus
-- and the launcher from being blurred, so only the cards frost.
hl.layer_rule({
  match = { namespace = "^omarchy-(bar|menu|clipboard|emojis|notifications|osd|polkit|reminders|keyboard-panel|network-qr)$" },
  blur = true,
  ignore_alpha = 0.3,
})
