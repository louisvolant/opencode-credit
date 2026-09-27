cask "opencode-credit" do
  version "1.0.0"
  sha256 "66e444dc3cf719f67fc253a2a34d95fc0f623e02c9309a3c549bc00f34d9fd17"

  url "https://github.com/louisvolant/opencode-credit/releases/download/v#{version}/OpenCodeCredit-#{version}.zip"
  name "OpenCode Credit"
  desc "Menu bar app showing OpenCode Go usage and Zen credit"
  homepage "https://github.com/louisvolant/opencode-credit"

  depends_on arch: :arm64
  depends_on macos: ">= :ventura"

  app "OpenCode Credit.app"
end
