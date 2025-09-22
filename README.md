# Zero Discipline

A native macOS prototype of the Zero Discipline app management tool, built with Swift and SwiftUI.

**Philosophy**: Simple and automatic. Launch the app and monitoring begins immediately - no configuration needed to get started, no buttons to remember to press.

## Features

- **Always Active**: No start/stop buttons - monitoring begins when launched
- **System Tray Integration**: Runs as a menu bar app with real-time status
- **SwiftUI Configuration UI**: Modern interface with real application icons
- **Native App Icons**: Shows actual application icons, not generic placeholders
- **Clean Interface**: Displays app names only, not full paths
- **File Browser Integration**: Select apps directly from filesystem using native picker
- **Shared Configuration**: Uses the same `config.json` as the Python version
- **Real-time Monitoring**: Live MRU (Most Recently Used) app tracking
- **Visual Status Indicators**: Color-coded status display for each monitored app

## Architecture

- **ConfigurationManager**: Handles reading/writing `config.json`
- **AppMonitor**: Core monitoring logic with MRU tracking and app termination
- **SystemTrayManager**: Menu bar integration with status display
- **ConfigurationView**: SwiftUI interface for app management

## Building and Running

### Prerequisites

- macOS 13.0+ (Ventura)
- Xcode 14.0+ or Swift 5.9+ command line tools

### Quick Start

```bash
cd ZeroDisciplineSwift

# Run setup script (recommended for first time)
./setup.sh

# Or manually:
# cp config.json.example config.json
# nano config.json
# make build

# Run the app
make run

# Or build and run in release mode
make run-release

# Create an app bundle
make app-bundle
make open-app
```

### Development Commands

```bash
# Build the project
make build

# Clean build artifacts  
make clean

# Run tests
make test

# Install system-wide
make install
```

## Configuration

### Setup

1. Copy the example configuration:
   ```bash
   cp config.json.example config.json
   ```

2. Edit `config.json` to match your needs:
   ```json
   {
     "app_paths": [
       "/Applications/WhatsApp.app",
       "/Applications/Firefox.app", 
       "/Applications/Slack.app",
       "/System/Applications/TextEdit.app"
     ],
     "timeout": 10,
     "top_n": 3
   }
   ```

### Parameters

- **app_paths**: List of full paths to applications to monitor (e.g., `/Applications/App.app`)
- **timeout**: Seconds of inactivity before quitting non-protected apps
- **top_n**: Number of most recently used apps to protect

### Grace Period

The app includes a **10-second grace period** when starting to prevent immediately killing applications. During this time, all applications are protected regardless of their activity status.

### Kill Cooldown

After an application is terminated, it enters a **30-second cooldown period**. During this time:
- The app is treated as protected even if it's relaunched
- No new countdown will start
- This prevents immediate re-killing of apps that auto-restart

The cooldown only persists within the same Zero Discipline session.

### Adding Applications

To add an application to monitor:

**Using the Browse button**:
- Click "Browse Applications..." in the configuration interface
- Navigate to `/Applications` (or wherever your app is installed)
- Select the `.app` file you want to monitor
- The application will be immediately added to your monitoring list

**Advantages of path-based monitoring**:
- ✅ **Exact matching**: No name normalization issues
- ✅ **No Unicode problems**: Paths are always clean strings
- ✅ **User-friendly**: See both app name and location
- ✅ **Reliable**: Direct file system references

## Usage

1. **Launch**: Simply run the app - it immediately starts monitoring
2. **System Tray**: Look for the target icon in your menu bar
3. **Configuration**: Click "Configuration..." to manage your apps
4. **Add Apps**: Use "Browse Applications..." to select apps to monitor
5. **Quit**: Close the app to stop monitoring

## Permissions

The app requires permission to:
- Monitor running applications
- Quit applications
- Access application usage data

macOS will prompt for these permissions on first run.

## Status Indicators

- 🛡️ **Protected**: App is in the top N most recently used
- 🔵 **First Run**: Protected during initial startup
- ⏱️ **Countdown**: Shows remaining seconds before quit
- ❌ **Quit**: App was terminated
- ⚪ **Not Running**: App is not currently active

## Comparison with Python Version

**Advantages:**
- Native performance and memory usage
- System-native look and feel
- Better integration with macOS
- No Python runtime dependency

**Current Limitations:**
- macOS only (Python version is cross-platform)
- Fewer advanced features (for now)

This Swift version serves as a proof of concept for a fully native implementation.