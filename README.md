# Caffeinated

`caffeinate`, in your macOS menu bar. Keep your Mac awake for 15 minutes,
an hour, three hours, eight hours or indefinitely, with one click.

Caffeinated holds the same power assertion as `caffeinate -d`: the display
does not go to sleep, and neither does the system.

## Requirements

macOS 13 (Ventura) or later.

## Build

```sh
./scripts/build-app.sh
open build/Caffeinated.app
```

To keep it, drag `build/Caffeinated.app` to `/Applications`.

During development you can also run it straight from the package:

```sh
swift run
```

(`swift run` shows SF Symbols instead of the coffee icons, because those are
only copied into the app bundle.)

## Credits

Menu bar icons from [Phosphor Icons](https://phosphoricons.com) (MIT).
