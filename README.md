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
- **OpenCode Zen credit** — available balance in USD, plus the monthly usage.
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

### Option 1 — Download the app (no toolchain required)

1. Download the latest `OpenCodeCredit-<version>.zip` from the
   [Releases](https://github.com/louisvolant/opencode-credit/releases) page.
2. Unzip it and drag `OpenCode Credit.app` into `/Applications`.
3. The app is not notarised, so macOS warns you the first time. Either
   **right-click the app → Open**, or run:
   ```sh
   xattr -dr com.apple.quarantine "/Applications/OpenCode Credit.app"
   ```

### Option 2 — Build from source

```sh
git clone git@github.com:louisvolant/opencode-credit.git
cd opencode-credit
make run
```

`make build` produces `build/OpenCode Credit.app`, `make test` runs the unit
tests, and `make release` produces a zip in `dist/`.

### Option 3 — Homebrew

```sh
brew tap louisvolant/opencode https://github.com/louisvolant/opencode-credit
brew install --cask louisvolant/opencode/opencode-credit
```

The cask's `sha256` must be updated for each release; `make release` prints the
value to paste into `Casks/opencode-credit.rb`.

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
   - `~/.config/opencode/opencode.json` →
     `provider.zen.options.apiKey` (or `provider["opencode-go"]`),
   - `$XDG_DATA_HOME/opencode/auth.json` or
     `~/.local/share/opencode/auth.json` (legacy format).

If nothing is found, paste a key in Settings. The settings window shows which
source is currently in use.

### Zen credit balance

The credit balance is **not** available through the API key. To show it, the
app opens an embedded login window:

1. In Settings, click **Sign in…** under "OpenCode Zen credit".
2. Continue with **GitHub** (Google blocks OAuth inside embedded web views).
3. The window detects your workspace automatically and closes.

The app stores the resulting session (cookie + workspace id) in the Keychain
and reads the value from your workspace billing page. If the session expires,
the app asks you to sign in again.

## How the data is fetched

- **Go usage** uses the official API-key endpoint:
  `GET https://opencode.ai/zen/go/v1/usage` with an `Authorization: Bearer`
  header. This is stable.
- **Zen credit** is not exposed by the API (`/zen/v1/balance` returns 404), so
  the app reads your workspace billing page with the captured browser session.
  This part is **best effort**: it may break if OpenCode changes its console,
  in which case the balance is hidden and everything else keeps working.

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
Casks          # Homebrew cask
```

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
