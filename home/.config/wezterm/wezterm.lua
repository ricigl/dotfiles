local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.enable_wayland = false
config.color_scheme = "rose-pine-moon"
config.font = wezterm.font("Hack Nerd Font")
config.font_size = 12.0

config.window_background_opacity = 1
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

-- Run Zsh as the default shell inside WSL.
config.default_prog = { "zsh", "-l" }

-- Dim unfocused windows so that the focused window is obvious.
local UNFOCUSED_FOREGROUND_TEXT_HSB = {
  hue = 1.0,
  saturation = 0.25,
  brightness = 0.45,
}

local UNFOCUSED_WINDOW_BACKGROUND_OPACITY = 0.62

local function same_text_hsb(actual, expected)
  if actual == nil or expected == nil then
    return actual == expected
  end

  return actual.hue == expected.hue
    and actual.saturation == expected.saturation
    and actual.brightness == expected.brightness
end

wezterm.on("window-focus-changed", function(window)
  local overrides = window:get_config_overrides() or {}
  local text_hsb
  local opacity

  if not window:is_focused() then
    text_hsb = UNFOCUSED_FOREGROUND_TEXT_HSB
    opacity = UNFOCUSED_WINDOW_BACKGROUND_OPACITY
  end

  if same_text_hsb(overrides.foreground_text_hsb, text_hsb)
    and overrides.window_background_opacity == opacity
  then
    return
  end

  overrides.foreground_text_hsb = text_hsb
  overrides.window_background_opacity = opacity

  window:set_config_overrides(overrides)
end)

return config




