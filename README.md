# OpenCode Credit

A tiny macOS menu bar app that shows your **OpenCode Go** usage windows
(rolling / weekly / monthly) and your **OpenCode Zen** available credit, at a
glance, without opening a browser.

It is a native, dependency-free Swift app: no Electron, no Python, no package
manager. The repository only needs the Swift toolchain that ships with Apple's
Command Line Tools.

> **Unofficial project.** Not affiliated with OpenCode or Anomaly. It reads
> your own account's endpoints, one of which is undocumented. See
> [How the data is fetched](#how-the-data-is-fetched).

## Features

- **Rolling usage** — percentage of the 5-hour window, with a reset countdown.
- **Weekly usage** — percentage of the weekly window, with a reset countdown.
- **Monthly usage** — percentage of the monthly window, with a reset countdown.
- **OpenCode Zen credit** — available balance in USD, the monthly usage, and
  the state of the "Extra Usage" (use credit) switch.
- The OpenCode logo in the menu bar next to the rolling percentage,
  colour-coded green / orange / red.
- Automatic refresh every 5 minutes (configurable) and a manual refresh button.
- Optional threshold notifications, launch at login, and a percentage-free
  menu bar.

## Requirements

- **Apple Silicon only (M1 or newer).** Intel Macs are not supported.
- **macOS 13 (Ventura) or newer.**
- To build from source: the Swift toolchain from Apple's Command Line Tools
  (`xcode-select --install`). No Xcode, no Homebrew, no third-party packages.

## Install

### Option 1 — Homebrew (recommended)

```sh
brew install --cask louisvolant/opencode-statusbar/opencode-credit
```

Homebrew resolves the tap automatically, so no separate `brew tap` is needed.
The app is **not notarised** by Apple, so macOS blocks the first launch. On
macOS 15 and later the right-click shortcut is not always enough: open
**System Settings → Privacy & Security** and click **"Open Anyway"**, or run:

```sh
xattr -dr com.apple.quarantine "/Applications/OpenCode Credit.app"
```

Prefer to avoid the Gatekeeper prompt altogether? Install the build-from-source
formula instead: it compiles the app locally, so it is **not quarantined** (it
needs the Command Line Tools). Homebrew 7 requires trusting third-party tap
formulae first:

```sh
brew trust --formula louisvolant/opencode-statusbar/opencode-credit-src
brew install --formula louisvolant/opencode-statusbar/opencode-credit-src
```

The cask and formula are published from the
[`louisvolant/homebrew-opencode-statusbar`](https://github.com/louisvolant/homebrew-opencode-statusbar)
tap and updated automatically from each release.

### Option 2 — Download the app (no toolchain required)

1. Download the latest `OpenCodeCredit-<version>.zip` from the
   [Releases](https://github.com/louisvolant/opencode-credit/releases) page.
2. Unzip it and drag `OpenCode Credit.app` into `/Applications`.
3. Open **System Settings → Privacy & Security** and click **"Open Anyway"**
   (or right-click the app → Open), or run:
   ```sh
   xattr -dr com.apple.quarantine "/Applications/OpenCode Credit.app"
   ```

### Option 3 — Build from source

```sh
git clone git@github.com:louisvolant/opencode-credit.git
cd opencode-credit
make run
```

`make build` produces `build/OpenCode Credit.app`, `make test` runs the unit
tests, and `make release` produces a zip in `dist/`.

You can also let Homebrew do the build for you with the formula above
(`brew install --formula louisvolant/opencode-statusbar/opencode-credit-src`).

## Configuration

Open the app's settings from the menu bar (gear icon) or by right-clicking the
icon.

### Where the app gets your API key

The app needs an OpenCode API key to read your usage. It looks for one in this
order and uses the first match:

1. A key you entered in the app (stored in the macOS Keychain).
2. The `OPENCODE_API_KEY`, `OPENCODE_GO_API_KEY` or `ZEN_API_KEY` environment
   variable. Note that an app launched from Finder does not inherit your shell
   environment, so this mostly helps when launching from a terminal.
3. Your existing OpenCode configuration, if present:
   - `~/.config/opencode/opencode.json`:
     - v2 shape: `providers.<id>.apiKey` (or an entry whose `type` is a known
       provider id such as `opencode-go`),
     - v1 shape: `provider.<id>.options.apiKey`,
   - `$XDG_DATA_HOME/opencode/auth.json` or
     `~/.local/share/opencode/auth.json` (legacy format).

Values may use OpenCode's variable substitution and are resolved by the app
too: `{env:NAME}` reads an environment variable and `{file:path}` reads a file
(relative to the config directory, or an absolute/`~` path). This lets you keep
the key out of `opencode.json`.

If nothing is found, paste a key in Settings. The settings window shows which
source is currently in use.

### Zen credit balance

The credit balance is **not** available through the API key. To show it, the
app opens an embedded login window:

1. In Settings, click **Sign in…** under "OpenCode Zen credit".
2. Sign in with **GitHub** or **Google**.
3. The window detects your workspace automatically and closes.

The app stores the resulting session (cookie + workspace id) in the Keychain
and reads your workspace **Go console page** (`/console/<workspace>/go`), which
shows both the available credit and the **Extra Usage** switch ("Use credit").
It falls back to the billing settings page if needed. If the session expires,
the app asks you to sign in again. The switch is displayed **read-only**.

## How the data is fetched

- **Go usage** uses the official API-key endpoint:
  `GET https://opencode.ai/zen/go/v1/usage` with an `Authorization: Bearer`
  header. This is stable. Note that the endpoint returns **integer**
  percentages (floored) that can lag the web console by up to one point — e.g.
  the app may show 79% while the console shows 80%.
- **Zen credit** is not exposed by the API (`/zen/v1/balance` returns 404), so
  the app reads your workspace console page with the captured browser session:
  the available credit and the state of the **Extra Usage** ("Use credit")
  switch. This part is **best effort**: it may break if OpenCode changes its
  console, in which case the credit is hidden and everything else keeps
  working.

## Privacy

- Your API key and Zen session are stored in the macOS Keychain.
- The app only talks to `opencode.ai`. There is no analytics, no telemetry and
  no third-party server.

## Troubleshooting

- **The percentage never updates.** Check the message in the popover. A "No API
  key configured" message means the app could not find a key; add one in
  Settings. "The API key was rejected" means the key is invalid.
- **"No OpenCode Go subscription found for this key."** The usage endpoint only
  exists for accounts with a Go subscription.
- **The percentage is one point lower than the web console.** The official
  usage endpoint returns floored integers and can lag the console; the app
  shows exactly what the API returns. This is not a refresh or caching issue —
  the tooltip on the menu bar icon shows the last successful refresh time.
- **The balance says "Not connected".** Sign in from Settings.
- **The balance shows "—" or an error.** The billing page format changed. The
  rest of the app is unaffected; please open an issue.
- **"OpenCode Credit.app is damaged" when opening.** Remove the quarantine
  attribute as shown in the install section.
- **Launch at login does not stick.** Move the app to `/Applications` first;
  macOS is stricter about registering apps from other locations.

## Development

```
Sources/Core   # platform-independent logic (parsing, config, API, storage)
Sources/App    # AppKit / WebKit user interface
Tests          # unit tests, including mocked API calls
scripts        # test and packaging helpers
```

The Homebrew cask lives in a dedicated tap repository,
[`louisvolant/homebrew-opencode-statusbar`](https://github.com/louisvolant/homebrew-opencode-statusbar),
which bumps itself from each GitHub release.

The project deliberately has no Xcode project and no third-party dependencies:
everything is compiled with a single `swiftc` call from `build.sh`. The unit
tests use a tiny built-in harness (no XCTest) and a `URLProtocol` mock for the
network.

- `make build` — build the app bundle.
- `make test` — run the unit tests.
- `make release` — build a distributable zip.

## License

[MIT](LICENSE). The OpenCode name and logo belong to their respective owners
and are used here only to identify the service this tool talks to.
