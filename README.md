# OpenCode Credit

A tiny macOS menu bar app that shows your **OpenCode Go** usage windows
(rolling / weekly / monthly) and your **OpenCode Zen** available credit, at a
glance, without opening a browser.

It is a native, dependency-free Swift app: no Electron, no Python, no package
manager. The repository only needs the Swift toolchain that ships with Apple's
Command Line Tools.

> **Unofficial project.** Not affiliated with OpenCode or Anomaly. It reads
> public/undocumented endpoints of your own account.

## What it shows

- **Rolling usage** — percentage of the 5-hour window, with a reset countdown.
- **Weekly usage** — percentage of the weekly window, with a reset countdown.
- **Monthly usage** — percentage of the monthly window, with a reset countdown.
- **OpenCode Zen** — available credit in USD.

In the menu bar, the OpenCode logo is shown next to the rolling percentage,
colour-coded by how close you are to the limit.

## Requirements

- **Apple Silicon only (M1 or newer).** Intel Macs are not supported.
- **macOS 13 (Ventura) or newer.**
- To build from source: the Swift toolchain from Apple's Command Line Tools
  (`xcode-select --install`). No Xcode, no Homebrew, no third-party packages.

## Install

### Option 1 — Download the app (no toolchain required)

1. Download the latest `OpenCodeCredit.zip` from the
   [Releases](https://github.com/louisvolant/opencode-credit/releases) page.
2. Unzip it and drag `OpenCode Credit.app` into `/Applications`.
3. The app is not notarised, so macOS will warn you the first time. Either
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

`make build` produces `build/OpenCode Credit.app`.

### Option 3 — Homebrew

```sh
brew install --cask louisvolant/opencode-credit/opencode-credit
```

## Where the app gets your API key

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

If nothing is found, open the settings from the menu bar and paste a key.

## How the data is fetched

- **Go usage** uses the official API key endpoint:
  `GET https://opencode.ai/zen/go/v1/usage` with an `Authorization: Bearer`
  header.
- **Zen credit** is *not* exposed by the API. The app opens an embedded login
  window, keeps the resulting session locally, and reads the value from your
  workspace billing page. This part is best-effort and may break if OpenCode
  changes its console.

The app refreshes automatically every 5 minutes (configurable) and you can
force a refresh at any time from the popover.

## Privacy

- Your API key and session cookie are stored in the macOS Keychain.
- The app only talks to `opencode.ai`. There is no analytics, no telemetry and
  no third-party server.

## Development

```
Sources/Core   # platform-independent logic (parsing, config, API, storage)
Sources/App    # AppKit / WebKit user interface
Tests          # unit tests for the core logic
scripts        # test and packaging helpers
```

- `make build` — build the app bundle.
- `make test` — run the unit tests.
- `make release` — produce a zip for distribution.

## License

[MIT](LICENSE). The OpenCode name and logo belong to their respective owners
and are used here only to identify the service this tool talks to.
