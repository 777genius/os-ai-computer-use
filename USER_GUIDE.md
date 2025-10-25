# OS AI - User Guide

Welcome to OS AI! This guide will help you get started with the application.

## Quick Start

### 1. Download the Application

Download the latest release for your platform from the [Releases page](https://github.com/777genius/os-ai-computer-use/releases):

- **macOS**: `OS_AI_X.X.X_macOS.zip`
- **Windows**: `OS_AI_X.X.X_Windows.zip`
- **Linux**: `OS_AI_X.X.X_Linux.tar.gz`
- **Web**: Access directly at [your-web-url] (if deployed)

### 2. Install the Application

#### macOS
1. Download `OS_AI_X.X.X_macOS.zip`
2. Extract the ZIP file
3. Move `OS_AI.app` to your Applications folder
4. Right-click and select "Open" (first time only, due to macOS security)

#### Windows
1. Download `OS_AI_X.X.X_Windows.zip`
2. Extract the ZIP file to a folder of your choice
3. Double-click `OS_AI.exe` to run

#### Linux
1. Download `OS_AI_X.X.X_Linux.tar.gz`
2. Extract: `tar -xzf OS_AI_X.X.X_Linux.tar.gz`
3. Run: `./OS_AI`

### 3. Get Your API Key

OS AI uses Anthropic's Claude AI. You need an API key to use the application.

1. Visit [https://console.anthropic.com/](https://console.anthropic.com/)
2. Sign up or log in to your account
3. Navigate to **API Keys** section
4. Click **Create Key**
5. Copy your API key (starts with `sk-ant-...`)

**Note**: Keep your API key secure and never share it publicly!

### 4. First Launch Setup

When you first launch OS AI:

1. A welcome dialog will appear
2. Paste your Anthropic API key into the field
3. Click **"Get Started"**

Your API key is stored securely in your system keychain:
- **macOS**: Keychain
- **Windows**: Credential Manager
- **Linux**: libsecret

## Using OS AI

### Main Chat Interface

After setup, you'll see the main chat interface where you can:

- Type messages to interact with Claude AI
- View AI responses and actions
- See screenshots of AI actions
- Monitor API usage

### System Tray

OS AI runs in your system tray for easy access:

- Click the tray icon to show/hide the window
- Right-click for quick actions

### Settings

Access settings anytime to:

1. Click the **Settings** button (or menu)
2. Update your API keys
3. Change backend connection settings (advanced)
4. Test your connection

## Features

### Computer Use

Claude can interact with your computer:
- Take screenshots
- Click and type
- Navigate applications
- Execute tasks

### Chat History

Your conversations are saved locally and persist between sessions.

### Cost Tracking

Monitor your API usage and estimated costs in real-time.

## Troubleshooting

### "Invalid API Key" Error

- Verify your key starts with `sk-ant-`
- Make sure you copied the entire key
- Generate a new key at [console.anthropic.com](https://console.anthropic.com/)

### Connection Issues

1. Check your internet connection
2. Verify backend is running (should start automatically)
3. Check Settings → Advanced → Backend connection

### Application Won't Start

**macOS**:
- Right-click the app and select "Open"
- Go to System Preferences → Security & Privacy and allow the app

**Windows**:
- Run as Administrator
- Check Windows Defender hasn't blocked it

**Linux**:
- Ensure you have required libraries: `libgtk-3-0`, `libsecret-1-0`
- Install if needed: `sudo apt-get install libgtk-3-0 libsecret-1-0`

### Reset Settings

If you need to start fresh:

1. **macOS**: Delete from Keychain Access
2. **Windows**: Remove from Credential Manager
3. **Linux**: Use `secret-tool` to clear

Then restart the application.

## Privacy & Security

### Data Storage

- **API Keys**: Stored in system keychain (encrypted)
- **Chat History**: Stored locally on your device
- **Screenshots**: Temporary, cleared on exit

### Network

- All API calls go directly to Anthropic's servers
- No data is sent to third parties
- Backend runs locally on your machine

### Updating

The app checks for updates automatically. When a new version is available:

1. You'll see a notification
2. Download from the releases page
3. Replace your existing installation

## Support

### Need Help?

- **Issues**: [GitHub Issues](https://github.com/777genius/os-ai-computer-use/issues)
- **Documentation**: [Full Docs](https://github.com/777genius/os-ai-computer-use/tree/main/docs)

### Feedback

We'd love to hear from you! Please report bugs or suggest features on GitHub.

---

**Version**: 1.0.0
**Last Updated**: 2025-10-25
