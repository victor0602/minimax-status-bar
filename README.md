# MiniMax Status Bar

A macOS menu bar app for monitoring MiniMax API token usage in real-time.

## Requirements

- **macOS 13.0 or later**
  - Liquid Glass UI on macOS 26+
  - Fallback design on macOS 13–25

## Features

- Real-time API usage monitoring
- Support for multiple model categories (Text, Speech, Video, Music, Image)
- Liquid Glass UI design on macOS 26+, native fallback on older versions
- Automatic refresh with live countdown
- Color-coded status indicators (green/yellow/red)
- One-click console access
- Auto-update from GitHub Releases

## Installation

### Prerequisites

1. **macOS 13.0+**
2. **MiniMax API Key** — Set as environment variable

### Download Release

1. Download the `.dmg` file from [GitHub Releases](https://github.com/victor0602/minimax-status-bar/releases)
2. Open the DMG and drag **MiniMax Status Bar** into **Applications**
3. On first launch, if you see a security warning, go to **System Settings → Privacy & Security → Still Open**

If installation shows "file damaged":
```bash
xattr -cr "/Applications/MiniMax Status Bar.app"
```
Then re-open the app.

### Configure API Key

The app automatically resolves the API key from multiple sources (in priority order):

1. Environment variable `MINIMAX_API_KEY`
2. `~/.openclaw/.env` — looks for `MINIMAX_API_KEY=sk-...`
3. `~/.openclaw/openclaw.json` — looks for `models.providers.minimax.apiKey` or `env.MINIMAX_API_KEY`

**OpenClaw users:** Configure MiniMax in OpenClaw and launch the app — no extra setup needed.

**Other users:** Set the environment variable permanently:
```bash
echo 'export MINIMAX_API_KEY="your_key_here"' >> ~/.zshrc
source ~/.zshrc
```

Or create `~/.openclaw/.env`:
```bash
mkdir -p ~/.openclaw
echo 'MINIMAX_API_KEY=your_key_here' > ~/.openclaw/.env
```

If no key is found, the app displays a friendly error with setup instructions.

### Build from Source

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation. After any project file changes, run `xcodegen generate` to regenerate the `.xcodeproj`.

```bash
git clone https://github.com/victor0602/minimax-status-bar.git
cd minimax-status-bar
xcodegen generate
xcodebuild -project minimax-status-bar.xcodeproj -scheme minimax-status-bar -configuration Debug build
```

Or open `minimax-status-bar.xcodeproj` in Xcode and run.

### Environment Variables

| Variable | Description |
|----------|-------------|
| `MINIMAX_API_KEY` | Your MiniMax API key. Also read from `~/.openclaw/.env` and `~/.openclaw/openclaw.json` |

## Usage

1. Launch the app
2. Click the menu bar icon to view API usage
3. Click refresh button or press `Cmd+R` to manually refresh
4. View remaining quota and reset time for each model
5. Click "Update" button when a new version is available — the app will download, install, and restart automatically

## API Endpoint

- **CN Region**: `https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains`
- **Console**: `https://platform.minimaxi.com/user-center/payment/token-plan`

## Architecture

- **SwiftUI** — UI framework with Liquid Glass design (macOS 26+)
- **NSPopover** — Menu bar popover for displaying content
- **ObservableObject** — State management (compatible with macOS 13+)

## License

MIT License
