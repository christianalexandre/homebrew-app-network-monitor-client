# AppNetworkMonitor Cask for Homebrew
#
# Installation:
#   brew tap christianalexandre/app-network-monitor-client
#   brew install --cask app-network-monitor
#
# Upgrade:
#   brew upgrade --cask app-network-monitor

cask "app-network-monitor" do
  version "4.0.0"
  sha256 "4ef29fcf694908a3dc38f08e07381221b8934726893515211b1b4eb1aec75e51"

  url "https://github.com/christianalexandre/homebrew-app-network-monitor-client/releases/download/#{version}/AppNetworkMonitor-#{version}.zip"
  name "AppNetworkMonitor"
  desc "Desktop companion app for iOS network request debugging"
  homepage "https://github.com/christianalexandre/homebrew-app-network-monitor-client"

  # Requires macOS 13.0 or later (adjust based on your deployment target)
  depends_on macos: ">= :ventura"

  app "AppNetworkMonitor.app"

  zap trash: [
    "~/Library/Preferences/com.christianalexandre.AppNetworkMonitor.plist",
    "~/Library/Application Support/AppNetworkMonitor",
    "~/Library/Caches/com.christianalexandre.AppNetworkMonitor",
  ]
end
