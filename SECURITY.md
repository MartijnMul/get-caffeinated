# Security

Get Caffeinated asks for no permissions and makes no network connections. It
holds a power assertion and reads the network signature macOS already keeps
for the router you are connected to; that signature never leaves your Mac.

## Reporting a vulnerability

Please do not open a public issue. Report it privately through
[GitHub's vulnerability reporting](https://github.com/MartijnMul/get-caffeinated/security/advisories/new)
instead, with what you found and how to reproduce it. You will get an answer
within a week.

Only the latest release gets fixes. Releases from 1.0.1 on are signed with a
Developer ID and notarised by Apple: `codesign -dv "/Applications/Get
Caffeinated.app"` should show the team `JSR6PF58J7`. Get yours from this
repository's
[releases](https://github.com/MartijnMul/get-caffeinated/releases) or from
`install.sh`.
