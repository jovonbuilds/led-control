# LED Sign

A native macOS app for designing and sending text and pixel art to **CoolLEDX** Bluetooth LED matrix signs: the cheap flexible USB-powered panels sold under many brand names and controlled by the *CoolLED1248* phone app.

No phone app, no cloud, no account. It talks to the sign directly over Bluetooth Low Energy.

## Does it work with my sign?

Probably, if:

- The phone app it shipped with is **CoolLED1248** (or "CoolLEDX").
- In that app, or in a Bluetooth scanner, the sign shows up as **`CoolLEDX`**, sometimes with a suffix like `CoolLEDX-0E09`.
- When you power it on, it briefly shows a 4-character hex code such as **`0E09`**. That's the sign's Bluetooth manufacturer ID.

**Tested on:** a 96×16, 7-color panel (27″×5″, USB 5 V), firmware 6.

The app reads the sign's width, height and color mode from its Bluetooth advertisement, so other CoolLEDX sizes should work as long as the height is a multiple of 8. They haven't been tested. Other CoolLED families (CoolLEDM, CoolLEDU, CoolLEDUX, full-RGB panels) use different protocols and **are not supported**.

## Requirements

- macOS 14 (Sonoma) or later, on a Mac with Bluetooth
- Xcode or the Xcode Command Line Tools (Swift 5.10+) to build it

## Build and run

```sh
git clone https://github.com/jovonbuilds/led-control.git
cd led-control
./build.sh
open LEDSign.app
```

`build.sh` creates a release build and wraps it in `LEDSign.app`. macOS only grants Bluetooth access to a real app bundle with a usage description, so running the bare binary with `swift run` won't connect to the sign. The script also ad-hoc signs the app and registers the `.ledsign` file type, so double-clicking a design in Finder opens it in the app.

The first time it runs, macOS asks for Bluetooth permission. Allow it.

> **Close the CoolLED app on your phone first.** The sign accepts only one Bluetooth connection at a time. If the phone is connected, the Mac can't find the sign.

## Using it

The app finds the sign by itself. When the status dot turns green it shows the sign's name, size and color mode.

- **Text tab:** type a message, then pick a color, font, size and bold. The preview shows exactly which LEDs will light. A dashed line marks the edge of the sign; anything past it scrolls into view.
- **Draw tab:** click or drag to paint individual LEDs. Pick **Off** to erase. **Fill** and **Clear** affect the whole canvas.
- **Mode:** Static, Scroll left/right/up/down, Snowflake, Picture or Laser. Changing it takes effect on the sign immediately.
- **Speed / Brightness:** sent to the sign when you release the slider.
- **Display on:** turns the panel on or off.
- **Send to Sign** (⌘↩): uploads the current design.

### Scroll over a colored background

The sign's built-in scroll moves the whole image, background included, so a colored background leaves black gaps between repeats. When the mode is **Scroll left** and the design's background isn't black, **Send** instead uploads a seamless looping animation: the design is shifted 2 pixels per frame and wraps around, so the background stays still and only the content moves.

- A **Loop speed** slider appears for this mode. Right is faster, and it applies on the next Send.
- The animation upload is much larger than a still image: about a minute for a 96-pixel-wide design, with a progress bar.
- Designs on black use the built-in scroll, which uploads in a couple of seconds and looks the same.

### Saving designs

**Save…** (⌘S) writes a `.ledsign` file and **Open…** (⌘O) reads one back. You can also double-click a `.ledsign` file in Finder. Designs default to `~/Documents/LED Sign Designs`.

A `.ledsign` file is plain, readable JSON. It stores the pixels plus the brightness, speed, mode and loop speed, so opening a design restores how it looked:

```json
{
  "format" : "ledsign",
  "version" : 1,
  "width" : 96,
  "height" : 16,
  "settings" : { "brightness" : 200, "speed" : 128, "mode" : "scrollLeft", "loopDelay" : 150 },
  "colors" : "0 off, 1 red, 2 green, 3 yellow, 4 blue, 5 magenta, 6 cyan, 7 white",
  "rows" : [ "4444444477774444…", "…" ]
}
```

`rows` has one string per LED row, with one digit (0–7) per LED. You can edit it by hand or generate it from a script. `mode` is one of `static`, `scrollLeft`, `scrollRight`, `scrollUp`, `scrollDown`, `snowflake`, `picture` or `laser`.

**Open…** also accepts a PNG that uses one pixel per LED. Each red, green and blue channel above 50% turns that LED color on. `tools/png_to_ledsign.py` converts a PNG to a `.ledsign` file.

## Project layout

```
Sources/LEDSignCore/   Protocol, pixel frames, text rendering, .ledsign format. No Bluetooth; unit-tested.
Sources/LEDSign/       SwiftUI app and CoreBluetooth connection.
Tests/                 Protocol tests checked byte-for-byte against the Python reference driver.
tools/                 Python helpers (PNG → .ledsign, seamless-scroll GIF builder, patch for the Python driver).
build.sh               Builds LEDSign.app.
```

Run the tests with `swift test`.

## How the protocol works

This is a summary for anyone writing their own client. See `Sources/LEDSignCore/CoolLEDProtocol.swift` for the details.

- **BLE:** service `FFF0`, characteristic `FFF1`. Write **without response**; the sign replies with notifications on the same characteristic.
- **Advertisement:** the manufacturer data after the company ID `0x0E09` holds 6 address bytes, then height, width (16-bit, big-endian), color mode and firmware version.
- **Framing:** every packet is `0x01`, then the escaped `[length16][payload]`, then `0x03`. Inside a packet, bytes `0x01`–`0x03` are escaped as `0x02, byte+4`.
- **Commands:** text `0x02`, image `0x03`, animation `0x04`, mode `0x06`, speed `0x07`, brightness `0x08`, power `0x09`.
- **Bulk data** (images, animations) is sent in 128-byte chunks: `[cmd][00][total length16][chunk index16][chunk length][data][XOR checksum]`. The sign acknowledges each chunk. The app waits for each acknowledgement before sending the next chunk.
- **Pixels** are three 1-bit planes (red, green, blue), each column-major with 8 rows per byte and the top row in the most significant bit. That gives 7 colors plus off.
- **Animations** are up to 255 frames, each exactly the sign's width, plus a per-frame delay (larger is slower).

## Credits

The CoolLEDX protocol was reverse-engineered by others. This app's protocol code is a Swift port of [coolledx-driver](https://github.com/UpDryTwist/coolledx-driver) by Greg Tatham (MIT; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)), which builds on earlier reverse-engineering of CoolLED LED face shields. The tests compare the Swift port's output byte-for-byte against that driver.

`tools/coolledx-driver-fixes.patch` fixes several problems in coolledx-driver (at commit `ba24137`) that stopped it from driving this sign, including swapped width and height, which scrambled the display.

## Disclaimer

This is an independent hobby project. It isn't affiliated with or endorsed by CoolLED or any sign manufacturer. Use it at your own risk.
