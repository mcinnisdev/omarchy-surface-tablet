-- Surface Pro 4 tablet setup: touch mapping, auto-rotation, on-screen keyboard,
-- and touch gestures. Remove require("hypr.tablet") in hyprland.lua to disable.

local internal = "eDP-1"

-- Auto-rotation. tablet-autorotate writes the transform (0-3) to this file and
-- reloads Hyprland, so the rotation also survives ordinary config reloads.
local transform = 0
local rotation = io.open((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/tablet-rotation", "r")
if rotation then
  transform = tonumber(rotation:read("*l")) or 0
  rotation:close()
end

-- Reuse the scale Omarchy persists in monitors.lua (omarchy hyprland monitor scaling).
local scale = "auto"
local monitors = io.open((os.getenv("HOME") or "") .. "/.config/hypr/monitors.lua", "r")
if monitors then
  scale = tonumber((monitors:read("*a") or ""):match("\nlocal omarchy_monitor_scale = ([%d.]+)")) or scale
  monitors:close()
end

hl.monitor({ output = internal, mode = "preferred", position = "auto", scale = scale, transform = transform })

-- Keep touch and pen on the internal screen, rotated with it.
hl.config({
  input = {
    touchdevice = { output = internal, transform = transform },
    tablet = { output = internal, transform = transform },
  },
})

o.launch_on_start("tablet-autorotate")
o.launch_on_start("tablet-keyboard start")

-- Load hyprgrass, then reload so the gestures below get registered.
o.exec_on_start("bash -c 'hyprpm reload -n && hyprctl reload'")

if hl.plugin.hyprgrass then
  hl.config({
    plugin = {
      hyprgrass = {
        -- One value covers both swipes and pinches: lower means a pinch is
        -- harder to claim a three-finger swipe, and fingers may land further
        -- apart before the swipe is cancelled.
        sensitivity = 3.0,
        long_press_delay = 400,
        resize_on_border_long_press = true,
        edge_margin = 20,
      },
    },
    gestures = {
      -- hyprgrass scales finger travel to the screen width, so the ratio is the
      -- share of the screen width to swipe (0.08 ≈ 2 cm on the SP4).
      workspace_swipe_cancel_ratio = 0.08,
      -- Average speed (per touch update, in the same scaled units) that switches
      -- anyway; the default of 30 is out of reach for a finger on a touchscreen.
      workspace_swipe_min_speed_to_force = 5,
      -- Swipe by workspace number, so empty workspaces aren't skipped and new
      -- ones keep getting created past the last one.
      workspace_swipe_use_r = true,
    },
  })

  -- Gestures are managed with tablet-gestures (Omarchy menu > Setup > Gestures),
  -- which writes them to tablet-gestures.lua.
  local gestures = (os.getenv("HOME") or "") .. "/.config/hypr/tablet-gestures.lua"
  local file = io.open(gestures, "r")
  if file then
    file:close()
    dofile(gestures)
  end
end
