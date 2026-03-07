# AppNetworkMonitor Client (macOS)

[![Platform](https://img.shields.io/badge/Platform-macOS%2012.0%2B-blue.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

**AppNetworkMonitor Client** is the desktop companion application for the [AppNetworkMonitor iOS Library](https://github.com/christianalexandre/app-network-monitor).

It acts as a local server, listening for incoming connections from your iOS apps via Bonjour/TCP. It allows you to inspect network traffic, logs, and metrics in real-time on a large screen, without cluttering the device UI.

## Features

- **Zero-Config Discovery:** Uses Bonjour (`_appmonitor._tcp`) to automatically find and connect to iOS devices running the `AppNetworkMonitor` agent.
- **Real-Time Streaming:** Watch requests, responses, and errors appear instantly as they happen on the device.
- **Deep Inspection:** View JSON bodies, HTTP headers, and status codes with syntax highlighting.
- **Multi-Session:** Handles connections from multiple devices/simulators simultaneously.
- **Search & Filter:** Quickly find specific endpoints or failed requests.
- **Mock Responses:** Create custom mock rules to intercept and override API responses on connected devices.

## Installation & Running

Since this application is distributed outside the Mac App Store (and is unsigned), macOS Gatekeeper might block its execution.

### Option A: Homebrew (Recommended)

```bash
brew tap christianalexandre/app-network-monitor-client
brew install --cask app-network-monitor
```

After installation, you need to bypass macOS security once:

```bash
xattr -cr /Applications/AppNetworkMonitor.app
```

Then open the app normally.

### Option B: Building from Source

1. Clone this repository.
2. Open `AppNetworkMonitor.xcodeproj` in Xcode.
3. Select your Mac as the destination.
4. Press **Cmd + R** to build and run.

### Option C: Manual Download

1. Download the latest `.zip` from [Releases](https://github.com/christianalexandre/homebrew-app-network-monitor-client/releases).
2. Unzip and drag `AppNetworkMonitor.app` to your **Applications** folder.
3. Run in Terminal to bypass macOS security:
    ```bash
    xattr -cr /Applications/AppNetworkMonitor.app
    ```
4. Double-click to open.

### macOS Security Note

Since the app is not signed with an Apple Developer certificate, macOS will block execution by default. The `xattr -cr` command removes the quarantine attribute, allowing the app to run. This is safe for apps you trust.

Alternatively, you can:
1. Try to open the app (it will fail)
2. Go to **System Settings → Privacy & Security**
3. Click **Open Anyway** next to the blocked app message

## How to Use

1. **Launch the Mac App:** It will immediately start listening for connections on the local network.
2. **Launch your iOS App:** Ensure your iOS app (instrumented with the AppNetworkMonitor library) is on the same Wi-Fi network.
3. **Automatic Connection:** The iOS app will discover the Mac Client via Bonjour and establish a connection. You should see logs appearing instantly.

## License

This project is licensed under the MIT License - see the LICENSE file for details.