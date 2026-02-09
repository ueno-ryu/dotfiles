#!/bin/bash
# Dev Environment Setup Script
# Claude Code + MCP + OMC 자동화 설치
# Updated: 2026-02-09 - Added Gemini CLI, MCP integration, fallback system

set -e

echo "🚀 Claude Code Development Environment Setup"
echo "=============================================="
echo "Version: 2.0 (with Gemini MCP + Fallback System)"
echo ""

# 색 컬러 확인
if [[ "$TERM_PROGRAM" != "vscode" ]]; then
    echo "⚠️  Warning: This script is designed for VS Code terminal"
    echo "   Some features may not work in other terminals"
    echo ""
fi

# Homebrew 확인
if ! command -v brew &> /dev/null; then
    echo "📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "✅ Homebrew already installed"
fi

# Node.js 확인
if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js..."
    brew install node
else
    echo "✅ Node.js already installed"
fi

# Python3 확인
if ! command -v python3 &> /dev/null; then
    echo "📦 Installing Python 3..."
    brew install python3
else
    echo "✅ Python 3 already installed"
fi

# Claude Code CLI 확인
if ! command -v claude &> /dev/null; then
    echo "📦 Installing Claude Code CLI..."
    npm install -g @anthropic-ai/claude-code
else
    echo "✅ Claude Code CLI already installed"
fi

# Gemini CLI 확인 (NEW)
if ! command -v gemini &> /dev/null; then
    echo "📦 Installing Gemini CLI..."
    npm install -g @google/gemini-cli
else
    echo "✅ Gemini CLI already installed"
fi

# Gemini MCP 서버 확인
if ! command -v gemini-mcp-rust &> /dev/null; then
    echo "📦 Installing Gemini MCP Server..."
    npm install -g gemini-mcp-rust
else
    echo "✅ Gemini MCP Server already installed"
fi

# Gemini Fallback System 설치
if [ ! -f "$HOME/gemini-fallback.py" ]; then
    echo "📦 Installing Gemini Fallback System..."
    cat > "$HOME/gemini-fallback.py" << 'FALLBACK_EOF'
#!/usr/bin/env python3
"""
Gemini Model Fallback Handler
할당량 초과 시 자동으로 다른 모델로 전환하고 인계 시스템
"""
import subprocess
import json
import sys
import time
from typing import List, Dict, Optional

class GeminiModelFallback:
    """Gemini 모델 자동 전환 시스템"""

    MODEL_PRIORITIES = [
        "gemini-2.5-pro",
        "gemini-2.5-flash",
        "gemini-2.5-flash-preview-09-2025",
        "gemini-2.5-flash-lite",
        "gemini-1.5-pro",
        "gemini-1.5-flash",
    ]

    MAX_RETRIES_PER_MODEL = 3
    TOTAL_CYCLE_LIMIT = 3

    def __init__(self, master_mode: bool = False):
        self.master_mode = master_mode
        self.current_model_index = 0
        self.retry_count = 0
        self.cycle_count = 0

    def get_current_model(self) -> str:
        return self.MODEL_PRIORITIES[self.current_model_index]

    def _check_quota_error(self, error_output: str) -> bool:
        quota_indicators = ["quota", "Quota exceeded", "limit", "429", "rate limit"]
        return any(indicator in error_output.lower() for indicator in quota_indicators)

    def _execute_with_model(self, model: str, prompt: str, timeout: int = 60) -> Dict:
        cmd = ["gemini", "--model", model, "-p", prompt]
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
            return {
                "success": result.returncode == 0,
                "model": model,
                "output": result.stdout,
                "error": result.stderr,
                "returncode": result.returncode
            }
        except subprocess.TimeoutExpired:
            return {"success": False, "model": model, "error": f"Timeout after {timeout}s", "returncode": -1}
        except Exception as e:
            return {"success": False, "model": model, "error": str(e), "returncode": -1}

    def execute(self, prompt: str, timeout: int = 60, verbose: bool = True) -> Dict:
        while True:
            current_model = self.get_current_model()
            if verbose:
                print(f"🤖 Attempting model: {current_model}")

            result = self._execute_with_model(current_model, prompt, timeout)

            if result["success"]:
                if verbose:
                    print(f"✅ Success with model: {current_model}")
                return {**result, "fallback_used": self.cycle_count > 0 or self.current_model_index > 0}

            if self._check_quota_error(result.get("error", "")):
                self.retry_count += 1
                if self.retry_count >= self.MAX_RETRIES_PER_MODEL:
                    if self.current_model_index < len(self.MODEL_PRIORITIES) - 1:
                        self.current_model_index += 1
                        self.retry_count = 0
                        continue
                    else:
                        self.cycle_count += 1
                        if self.cycle_count >= self.TOTAL_CYCLE_LIMIT:
                            error_msg = "All Gemini models exhausted after 3 cycles. Master agent (Claude) should handle this task."
                            print(f"\n🔴 {error_msg}\n")
                            return {"success": False, "error": error_msg}
                        self.current_model_index = 0
                        self.retry_count = 0
                        time.sleep(2)
                        continue
                time.sleep(5)
                continue
            else:
                return {"success": False, "error": f"Non-quota error with {current_model}: {result['error']}"}

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Gemini Model Fallback Handler")
    parser.add_argument("prompt", help="Prompt to send to Gemini")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    args = parser.parse_args()

    handler = GeminiModelFallback()
    result = handler.execute(args.prompt, verbose=args.verbose)

    if result["success"]:
        print("\n" + "="*60)
        print("✅ SUCCESS")
        print("="*60)
        print(result["output"])
    else:
        print("\n" + "="*60)
        print("❌ FAILED")
        print("="*60)
        print(f"Error: {result.get('error', 'Unknown error')}")
        sys.exit(1)
FALLBACK_EOF
    chmod +x "$HOME/gemini-fallback.py"
    echo "✅ Gemini Fallback System installed"
else
    echo "✅ Gemini Fallback System already installed"
fi

# MCP 설정 파일 생성/업�데이트
MCP_CONFIG="$HOME/.claude/.mcp.json"
MCP_DIR=$(dirname "$MCP_CONFIG")

if [ ! -d "$MCP_DIR" ]; then
    echo "📁 Creating Claude config directory..."
    mkdir -p "$MCP_DIR"
fi

if [ ! -f "$MCP_CONFIG" ]; then
    echo "📝 Creating MCP configuration..."
    cat > "$MCP_CONFIG" << 'MCP_EOF'
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "HOME_PLACEHOLDER"]
    },
    "gemini": {
      "command": "gemini-mcp-rust",
      "args": []
    }
  }
}
MCP_EOF

    # Replace HOME_PLACEHOLDER with actual home directory
    sed -i.bak "s|HOME_PLACEHOLDER|$HOME|g" "$MCP_CONFIG"
    rm -f "$MCP_CONFIG.bak"

    echo "✅ MCP configuration created at $MCP_CONFIG"
else
    echo "✅ MCP configuration already exists at $MCP_CONFIG"

    # Check if gemini-mcp-rust is configured
    if ! grep -q "gemini-mcp-rust" "$MCP_CONFIG"; then
        echo "⚠️  Adding Gemini MCP server to configuration..."
        # Backup and add gemini server
        cp "$MCP_CONFIG" "$MCP_CONFIG.backup"
        if command -v jq &> /dev/null; then
            jq --arg home "$HOME" '.mcpServers.gemini = {"command": "gemini-mcp-rust", "args": []} |
               .mcpServers.filesystem.args = ["-y", "@modelcontextprotocol/server-filesystem", $home]' \
               "$MCP_CONFIG.backup" > "$MCP_CONFIG"
        fi
    fi
fi

# .zshrc에 API 키 설정 가이드
echo ""
echo "📝 API Key Setup"
echo "=================="
echo ""
echo "Get your API keys from:"
echo "  • Gemini API: https://aistudio.google.com/app/apikey"
echo ""
echo "Add these to your ~/.zshrc:"
echo ""
echo "  # Gemini API Keys"
echo "  export GEMINI_API_KEY=\"your-gemini-api-key-here\""
echo "  export GOOGLE_API_KEY=\"your-google-api-key-here\""
echo ""
echo "Then reload your shell:"
echo "  source ~/.zshrc"
echo ""

# 현재 상태 확인
echo "📊 Installation Status"
echo "======================"
echo ""
echo "Installed Tools:"
echo "  ✅ Homebrew: $(brew --version | head -1 || echo 'Not found')"
echo "  ✅ Node.js: $(node --version || echo 'Not found')"
echo "  ✅ Python: $(python3 --version || echo 'Not found')"
echo "  ✅ Claude Code: $(claude --version 2>/dev/null || echo 'Not found')"
echo "  ✅ Gemini CLI: $(gemini --version 2>/dev/null || echo 'Not found')"
echo "  ✅ Gemini MCP: $(command -v gemini-mcp-rust || echo 'Not found')"
echo "  ✅ Fallback System: $HOME/gemini-fallback.py"
echo ""

echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Get API keys from https://aistudio.google.com/app/apikey"
echo "  2. Add API keys to ~/.zshrc (see above)"
echo "  3. Run: source ~/.zshrc"
echo "  4. Install OMC: claude omc-setup"
echo "  5. Test Gemini: gemini 'Hello, world!'"
echo ""
echo "📚 Documentation available at: ~/dev-env-setup.md"
echo ""
