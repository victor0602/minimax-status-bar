# MiniMax Status Bar

A macOS menu bar app for monitoring MiniMax API token usage in real-time.

## Requirements

- **macOS 13.0+** with fallback design
- **macOS 26.0+** for Liquid Glass design
  - When running on macOS 26+, the app uses the native Liquid Glass visual effect
  - On older macOS versions, a standard translucent design is used
  - All functionality remains the same across versions

## Features

- Real-time API usage monitoring
- Support for multiple model categories (Text, Speech, Video, Music, Image)
- macOS native Liquid Glass UI design
- Automatic refresh with live countdown
- Color-coded status indicators (green/yellow/red)
- One-click console access

## Installation

### Prerequisites

1. **macOS 26.0+** - Required for Liquid Glass design
2. **Xcode 26+** - For building from source
3. **MiniMax API Key** - Set as environment variable

### Building from Source

```bash
# Clone the repository
git clone https://github.com/victor0602/minimax-status-bar.git
cd minimax-status-bar

# Set your MiniMax API key
export MINIMAX_API_KEY="your_api_key_here"

# Generate Xcode project
xcodegen generate

# Build
xcodebuild -scheme minimax-status-bar -configuration Debug build

# Run
open /Users/victor/Library/Developer/Xcode/DerivedData/minimax-status-bar-*/Build/Products/Debug/MiniMax\ Status\ Bar.app
```

Or open `minimax-status-bar.xcodeproj` in Xcode and run.

### Environment Variables

| Variable | Description |
|----------|-------------|
| `MINIMAX_API_KEY` | Your MiniMax API key (CN region: api.minimaxi.com) |

## Usage

1. Launch the app
2. Click the menu bar icon to view API usage
3. Click refresh button or press `Cmd+R` to manually refresh
4. View remaining quota and reset time for each model

## API Endpoint

- **CN Region**: `https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains`
- **Console**: `https://platform.minimaxi.com/user-center/payment/token-plan`

## Architecture

- **SwiftUI** - UI framework with Liquid Glass design
- **NSPopover** - Menu bar popover for displaying content
- **SQLite.swift** - Local data persistence
- **ObservableObject** - State management (compatible with macOS 13+)

## License

MIT License
