<picture>
  <source media="(prefers-color-scheme: dark)" srcset="branding/logo-dark.svg">
  <img src="branding/logo-light.svg" alt="Get Caffeinated" width="420">
</picture>

`caffeinate`, in your macOS menu bar. Keep your Mac awake, with one click:

- for 15 minutes, an hour, three hours or eight hours;
- until a time of your choosing, every half hour up to eight hours ahead;
- until you unplug the power adapter, on a Mac with a battery;
- until you leave: the session ends when the Mac moves to another network,
  or after 30 seconds without one;
- or indefinitely, until you stop it.

"Until I leave" recognises the network by its router, so it needs no
Location Services permission and never asks for your location. It works on
Wi-Fi and on a wired connection alike.

Get Caffeinated holds the same power assertion as `caffeinate -d`: the display
does not go to sleep, and neither does the system. Turn off "Keep screen on"
to keep only the system awake and let the display sleep, like
`caffeinate -i`, for downloads and builds.

## Requirements

Developed and tested on the current macOS. The app is built to run on
macOS 13 (Ventura) and later, but versions before the current one have not
been tested yet; if you try one, an issue saying whether it works is very
welcome.

## Install

Paste this into Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/MartijnMul/get-caffeinated/main/install.sh | sh
```

It downloads the latest release, puts Get Caffeinated in your Applications
folder and opens it. Run it again to update. The [script](install.sh) is
short; read it first if you like.

### Or download it yourself

1. Download [`Get-Caffeinated.dmg`](https://github.com/MartijnMul/get-caffeinated/releases/latest/download/Get-Caffeinated.dmg),
   open it and drag Get Caffeinated onto the Applications shortcut.
2. Open Get Caffeinated from Applications. macOS shows *"Get Caffeinated"
   Not Opened*: choose Done.
3. Open System Settings → Privacy & Security, scroll down to *"Get
   Caffeinated" was blocked*, click **Open Anyway** and confirm.

Steps 2 and 3 are needed once, because the app is not notarised by Apple,
which takes a paid developer account. The Terminal install skips them: macOS
only asks about apps downloaded through a browser.

Either way, turn on "Launch at login" from the copy in Applications.

## Build from source

```sh
./scripts/build-app.sh
open "build/Get Caffeinated.app"
```

To keep it, drag `build/Get Caffeinated.app` to `/Applications`, as above.
A build of your own opens without the "Open Anyway" step.

During development you can also run it straight from the package:

```sh
swift run
```

(`swift run` shows SF Symbols instead of the coffee icons, because those are
only copied into the app bundle.)

## License

[Mozilla Public License 2.0](LICENSE). Use it, change it, ship it, also in
your own or commercial software. If you distribute a changed version, the
source of your changes to Get Caffeinated's files has to stay open under the
same license; improvements sent back as a pull request are very welcome.

## Credits

Menu bar icons from [Phosphor Icons](https://phosphoricons.com), with thicker
strokes; MIT license, see [`Resources/Icons/LICENSE`](Resources/Icons/LICENSE).
