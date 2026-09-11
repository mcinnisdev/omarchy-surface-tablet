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
  local hg = hl.plugin.hyprgrass

  hl.config({
    plugin = {
      hyprgrass = {
        sensitivity = 4.0,
        long_press_delay = 400,
        resize_on_border_long_press = true,
        edge_margin = 20,
      },
    },
    gestures = {
      workspace_swipe_cancel_ratio = 0.15,
    },
  })

  -- Swipe up from the bottom edge: toggle the on-screen keyboard.
  hg.bind({ pattern = { kind = "edge", origin = "down", direction = "up" }, action = hl.dsp.exec_cmd("tablet-keyboard toggle") })

  -- Swipe down from the top edge: Omarchy menu.
  hg.bind({ pattern = { kind = "edge", origin = "up", direction = "down" }, action = hl.dsp.exec_cmd("omarchy-menu toggle") })

  -- Three fingers sideways: switch workspace, following your fingers.
  hg.gesture({ pattern = { kind = "swipe", fingers = 3, direction = "horizontal" }, action = "workspace" })

  -- Three fingers down: close window. Three fingers up: scratchpad.
  hg.gesture({ pattern = { kind = "swipe", fingers = 3, direction = "down" }, action = "close" })
  hg.bind({ pattern = { kind = "swipe", fingers = 3, direction = "up" }, action = hl.dsp.workspace.toggle_special("scratchpad") })

  -- Hold two fingers on a window, then drag to move it.
  hg.bind({ pattern = { kind = "longpress", fingers = 2 }, action = hl.dsp.window.drag(), mouse = true })

  -- Four-finger tap: toggle rotation lock.
  hg.bind({ pattern = { kind = "tap", fingers = 4 }, action = hl.dsp.exec_cmd("tablet-autorotate lock") })
end
