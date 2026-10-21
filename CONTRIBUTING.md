# Contributing

Thanks for wanting to make Get Caffeinated better. Bug reports, ideas and pull
requests are all welcome.

## Reporting a bug

[Open an issue](https://github.com/MartijnMul/get-caffeinated/issues/new/choose)
and pick the bug report. It asks for:

- your macOS version and Mac model (Apple silicon or Intel, laptop or desktop);
- what you did, what you expected, and what happened instead;
- for a session that ended too early or not at all, the output of
  `pmset -g assertions | grep "Get Caffeinated"` while it should be running.

Running it on a macOS other than the current one? The macOS version report
takes a minute and helps, also when everything works. A security problem
goes through [SECURITY.md](SECURITY.md) instead, not a public issue.

## Building

You need Swift 6: Xcode 16 or later, or its command-line tools.

```sh
swift test                  # runs the tests
./scripts/build-app.sh      # builds "build/Get Caffeinated.app"
open "build/Get Caffeinated.app"
```

The tests cover the logic that does not need a running Mac: the "Until"
times and what "Until I leave" does when the network changes. CI runs them
on every push and pull request, and builds the app for both architectures.

`./scripts/release.sh` builds for both Apple silicon and Intel and packs
`build/Get-Caffeinated.dmg`. Attach it to a GitHub release tagged with the
version from `Resources/Info.plist` (such as `v1.0.0`). Keep the file name:
`install.sh` downloads exactly that name from the latest release.

`swift run` works too, but shows SF Symbols instead of the coffee icons, and
"Launch at login" needs the app bundle. Quit a running copy before you open a
new build.

## How the code is laid out

| File | What it does |
|---|---|
| `GetCaffeinatedApp.swift` | The menu: the items, the status line, the toggles. |
| `AwakeKeeper.swift` | Holds the power assertion and decides when a session ends. |
| `UntilTimes.swift` | The end times offered in the "Until" submenu. |
| `PowerSource.swift` | Power adapter or battery, and change notifications ("Until unplugged"). |
| `NetworkSignature.swift` | Recognises the current network by its router ("Until I leave"). |
| `NetworkCheck.swift` | Decides whether a network change ends an "Until I leave" session. |
| `MenuOpening.swift` | Rebuilds the menu each time it opens, so times and states are fresh. |
| `MenuBarIcon.swift` | The bean and cup icons, outline or filled to match the menu bar. |
| `LoginItem.swift` | "Launch at login", through `SMAppService`. |

Tests live in `Tests/GetCaffeinatedTests`, written with Swift Testing.

## Ground rules

These keep the app small and trustworthy. A pull request that breaks one of
them needs a good reason in its description.

- **Talk to IOKit directly.** Keep the Mac awake with
  `IOPMAssertionCreateWithName`; never run `caffeinate` or other shell
  commands.
- **No permissions.** The app asks for nothing: no Location Services, no
  Accessibility, no network access. That is why "Until I leave" reads the
  router instead of the Wi-Fi name.
- **No dependencies.** System frameworks only.
- **macOS 13 and Swift 6 language mode.** Code that needs a newer macOS goes
  behind `if #available`, with a fallback.
- **Comments explain why,** not what. Look at the existing doc comments for
  the tone.

## Pull requests

- One change per pull request; small is easier to review.
- Commit messages in the imperative, as in the history: "Add …", "Fix …",
  "End timed sessions on time after the Mac sleeps". Explain the reason in
  the body when it is not obvious.
- Add or update tests for logic that can run without the system, and keep
  `swift test` passing.
- Describe how you tested it in the app: what you clicked and on which macOS
  version. Keeping a Mac awake cannot be tested automatically, so for
  anything that does, check `pmset -g assertions` before and after. The pull
  request template has a checklist.
- For a larger change or a new keep-awake mode, open an issue first, so we
  can agree on the approach before you spend time on it.

## License

Get Caffeinated is licensed under the [Mozilla Public License 2.0](LICENSE). By
opening a pull request you agree that your contribution is licensed under it
too.
