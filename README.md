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

Edit them in `~/.config/hypr/tablet.lua`.

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

Omarchy's menu covers the whole screen, which hides the keyboard when you want
to type to filter (the keybindings list, app launcher, and so on).
`tablet-menu-sync` installs a copy of the menu that is identical except that it
stays clear of the space the keyboard reserves, so the menu sits above it.

The copy is rebuilt from the current Omarchy menu by a post-update hook, so menu
improvements keep coming through. `tablet-menu-sync remove` goes back to the
built-in menu.

## Auto-rotation

`tablet-autorotate` follows `iio-sensor-proxy` and rotates the screen, touch
input and keyboard together. The rotation is kept in
`$XDG_RUNTIME_DIR/tablet-rotation`, so it survives Hyprland config reloads.
Toggle rotation lock with a four-finger tap or `tablet-autorotate lock`.

## Known limitations

- Only tested on a Surface Pro 4. Other IPTS Surfaces might work with the same
  driver but are untested.
- The Surface Pen isn't set up yet.
- hyprgrass is still alpha.

## Credits and license

- `driver/ipts`: Intel Precise Touch & Stylus driver from linux-surface,
  © Dorian Stoll and Intel, GPL-2.0-or-later
- wvkbd: © its authors, GPL-3.0
- Everything else in this repo: GPL-3.0, see [LICENSE](LICENSE)
