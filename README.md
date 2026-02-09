# Dotfiles - Claude Code Development Environment

Personal development environment setup for Claude Code with MCP, Gemini CLI, and OMC integration.

## 📁 Contents

- `setup-dev-env.sh` - Automated installation script
- `dev-env-setup.md` - Detailed documentation
- `gemini-fallback.py` - Gemini model fallback system

## 🚀 Quick Start

```bash
# Clone this repository
git clone <repo-url> ~/dotfiles
cd ~/dotfiles

# Run the setup script
bash setup-dev-env.sh

# Follow the instructions to add API keys
source ~/.zshrc
```

## 🛠️ What Gets Installed

1. **Homebrew** - Package manager for macOS
2. **Node.js & npm** - JavaScript runtime and package manager
3. **Python 3** - Python interpreter
4. **Claude Code CLI** - Anthropic's Claude CLI tool
5. **Gemini CLI** - Google's Gemini CLI tool
6. **Gemini MCP Server** - MCP integration for Gemini
7. **Gemini Fallback System** - Automatic model switching for quota handling

## 🔑 Required API Keys

After running the setup, you'll need to add your API keys to `~/.zshrc`:

```bash
# Gemini API Keys
export GEMINI_API_KEY="your-gemini-api-key-here"
export GOOGLE_API_KEY="your-google-api-key-here"
```

Get your API key from: https://aistudio.google.com/app/apikey

## 📖 Documentation

See `dev-env-setup.md` for comprehensive documentation including:
- Detailed installation instructions
- MCP server configuration
- Gemini fallback system usage
- Troubleshooting guide
- Architecture overview

## 🔄 Updates

To update these dotfiles:

```bash
cd ~/dotfiles
git pull origin main
bash setup-dev-env.sh  # Re-run to get any updates
```

## 📝 Version History

- **v2.0** (2026-02-09)
  - Added Gemini CLI integration
  - Added MCP server configuration
  - Added Gemini fallback system
  - Improved documentation

- **v1.0** (Initial)
  - Basic Claude Code + OMC setup

## 📚 References

- [Claude Code](https://claude.ai/download)
- [MCP Protocol](https://modelcontextprotocol.io)
- [OMC Documentation](https://github.com/ueno-ryu/oh-my-claudecode)
- [Gemini API](https://ai.google.dev/gemini-api/docs)

---

**Last Updated:** 2026-02-09
