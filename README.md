# omarchy-surface-tablet

Tablet mode for [Omarchy](https://omarchy.org) on the Microsoft Surface Pro 4,
without switching away from the stock Arch kernel.

- **Touchscreen** via the [linux-surface](https://github.com/linux-surface/linux-surface)
  IPTS driver, packaged as a DKMS module so it rebuilds on every kernel update
- **Floating on-screen keyboard** styled like Omarchy windows, with Super and
  Alt on the main row and **swipe typing**
- **Auto-rotation** of the screen, touch input and keyboard
- **Touch gestures** with [hyprgrass](https://github.com/horriblename/hyprgrass)

## Why not the linux-surface kernel?

The SP4 needs linux-surface's IPTS driver for touch, which isn't in mainline.
At the time of writing the linux-surface kernel lagged at 6.19 while Arch was on
7.2. The driver itself builds unchanged against current kernels, and the stock
kernel already detects the touch controller, so it only needs the driver as a
module. You keep normal kernel updates; if a future kernel ever breaks the
build, only touch stops working until the driver is fixed.

## Multi-touch

In its default mode the SP4 touch firmware reports one finger at a time.
[iptsd](https://github.com/linux-surface/iptsd), installed from the linux-surface
repo, switches it to multi-touch and handles the pen. iptsd 3.1.0's built-in
contact thresholds miss fingertips on the SP4, so `iptsd/90-sp4-contacts.conf`
sets them back to the documented values
([iptsd#210](https://github.com/linux-surface/iptsd/issues/210)).

Touch does not come back by itself after sleep: the driver has no suspend
support and probes before the touch controller is ready. `systemd/ipts-reload`
is installed as a sleep hook that reloads it. If touch is ever dead after a
resume and reloading the driver hangs, the Intel ME is wedged and only a reboot
clears it.

## Install

Requires Omarchy (Hyprland 0.56+ with Lua config) on a Surface Pro 4.

```sh
git clone https://github.com/mcinnisdev/omarchy-surface-tablet
cd omarchy-surface-tablet
./install.sh
```

Then log out and back in.

## Gestures

| Gesture | Action |
|---|---|
| Swipe up from the bottom edge | Show or hide the keyboard |
| Swipe down from the top edge | Omarchy menu |
| Three fingers left or right | Switch workspace |
| Three fingers down | Close window |
| Three fingers up | Scratchpad |
| Hold two fingers, then drag | Move window |
| Long-press a window border | Resize |
| Four-finger tap | Toggle rotation lock |

These are the defaults. To see, add, change or remove gestures, open
**Omarchy menu → Setup → Gestures** (or run `tablet-gestures`). Pick a gesture
type, the fingers or edge, and a direction, then an action from the list or any
shell command. Gestures are stored in `~/.config/hypr/tablet-gestures.json` and
`tablet-gestures list` prints them.

## Keyboard

The keyboard is a fork of [wvkbd](https://github.com/jjsullivan5196/wvkbd),
built from the `tablet` branch of [mcinnisdev/wvkbd](https://github.com/mcinnisdev/wvkbd).
It adds:

- a floating, centered panel with rounded corners and a border
- `LAYOUT=tablet`, with Sup and Alt on the main row (modifiers latch, so tap
  Sup then Space for the Omarchy menu)
- built-in swipe typing: a shape-based decoder that compares your finger's path
  with each word's path across the keys, weighted by word frequency. Backspace
  right after a swiped word deletes the whole word.

`tablet-keyboard` starts it with colors from the current Omarchy theme:

```sh
tablet-keyboard toggle   # show or hide
tablet-keyboard restart  # pick up theme or setting changes
```

Size, transparency, border and font are set at the top of `~/.local/bin/tablet-keyboard`.

### Swipe word list

`install.sh` builds `~/.local/share/tablet-keyboard/swipe-words.tsv` from SCOWL
(Arch's `words` package) ranked by Peter Norvig's
[word counts](https://norvig.com/ngrams/). Raise a word's count to make it win
more often. Neither source is redistributed here; both are fetched at install time.

## Menus

Omarchy's menu covers the whole screen and holds exclusive keyboard focus, so
while a menu is open it hides the on-screen keyboard and Hyprland sends every
touch to the menu instead of the keyboard. Typing to filter a menu therefore
needs a physical keyboard.

`tablet-menu-sync` installs a copy of Omarchy's menu plugin that fixes both
(it stays clear of the keyboard's reserved space and asks for on-demand focus),
but it is **not installed by default**: Omarchy only hands its application
library to first-party plugins, so a cloned menu shows an empty Apps submenu.
Run `tablet-menu-sync` if you want menu typing by touch and can live without
the Apps list; `tablet-menu-sync remove` goes back to the built-in menu.

## Auto-rotation

`tablet-autorotate` follows `iio-sensor-proxy` and rotates the screen, touch
input and keyboard together. The rotation is kept in
`$XDG_RUNTIME_DIR/tablet-rotation`, so it survives Hyprland config reloads.
Toggle rotation lock with a four-finger tap or `tablet-autorotate lock`.

## Known limitations

- Only tested on a Surface Pro 4. Other IPTS Surfaces might work with the same
  driver but are untested.
- The Surface Pen shows up through iptsd but hasn't been tested.
- hyprgrass is still alpha.

## Credits and license

- `driver/ipts`: Intel Precise Touch & Stylus driver from linux-surface,
  © Dorian Stoll and Intel, GPL-2.0-or-later
- wvkbd: © its authors, GPL-3.0
- Everything else in this repo: GPL-3.0, see [LICENSE](LICENSE)
