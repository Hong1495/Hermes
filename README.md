# Hermes

Hermes is a native macOS utility for screenshots, OCR, translation, storage cleanup, disk analysis, application management, and system maintenance.

Hermes is **macOS-only** and is built with SwiftUI and AppKit. It uses the native macOS Liquid Glass APIs available on macOS 26 or later.

## Features

- Screenshot capture with rectangle, arrow, text, highlighter, freehand, and numbered annotations
- Undo and redo for annotations, Japanese color presets, border, corner radius, and shadow export options
- On-device OCR with configurable recognition languages
- Native macOS translation with automatic language detection, clipboard actions, and paste-to-translate
- Review-first cleanup for application caches, logs, browser caches, developer artifacts, package-manager caches, Xcode data, AI model caches, installers, and uninstalled application leftovers
- Installer discovery across Downloads, Desktop, Documents, iCloud Drive, Mail Downloads, Homebrew, and Telegram Downloads
- Application management with related files, residual cleanup, and startup item inspection
- Disk explorer and large-file analysis
- Reversible cleanup through the macOS Trash, plus a separate confirmation flow for emptying Trash
- Safe system maintenance for DNS, Quick Look, font, Launch Services, Spotlight, memory, and icon services
- Live CPU, memory, battery, storage, and network status
- Cleanup history and configurable whitelist paths

## Requirements

- macOS 26.2 or later
- Xcode 17 or later for building from source

Hermes does not target iPhone, iPad, Apple TV, Apple Watch, or visionOS.

## Build

```sh
xcodebuild -project Hermes.xcodeproj \
  -scheme Hermes \
  -configuration Release \
  -sdk macosx \
  CODE_SIGNING_ALLOWED=NO
```

To run the test suite:

```sh
xcodebuild -project Hermes.xcodeproj \
  -scheme Hermes \
  -destination 'platform=macOS' \
  test \
  CODE_SIGNING_ALLOWED=NO
```

## Safety

Hermes scans before it changes anything. Cleanup items are reviewed individually and ordinary cleanup moves files to the macOS Trash so they can be restored. Paths are checked again immediately before execution, symbolic links and protected locations are rejected, and whitelist entries are honored.

Emptying Trash is a separate irreversible action and always requires an explicit confirmation.

## Privacy

OCR and translation use macOS services. Hermes does not include an analytics SDK or a remote account system. Cleanup scans operate on local paths selected by the scanners and the user's whitelist settings.

## License

Copyright (c) 2026 Hong1495.

