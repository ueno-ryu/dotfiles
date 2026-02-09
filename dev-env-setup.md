# Claude Code Development Environment Setup

자동화된 개발 환경 설정 스크립트 (v2.0)

**Last Updated:** 2026-02-09
**Features:** Claude Code + MCP + Gemini CLI + OMC + Fallback System

## 🚀 Quick Start

```bash
# Run automated setup
bash ~/setup-dev-env.sh

# Then add API keys to ~/.zshrc
source ~/.zshrc

# Install OMC (oh-my-claudecode)
claude omc-setup
```

## 🔧 필수 도구 설치

### 1. Homebrew (macOS)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Node.js & npm
```bash
brew install node
```

### 3. Python 3
```bash
brew install python3
```

### 4. Claude Code CLI
```bash
npm install -g @anthropic-ai/claude-code
```

### 5. Gemini CLI (NEW)
```bash
npm install -g @google/gemini-cli
```

## 🤖 MCP 서버 설정

### Gemini MCP 서버
```bash
npm install -g gemini-mcp-rust
```

MCP 설정 파일 (`~/.claude/.mcp.json`):
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/hoon"]
    },
    "gemini": {
      "command": "gemini-mcp-rust",
      "args": []
    }
  }
}
```

**How MCP Integration Works:**
- **Gemini as Subordinate**: Gemini MCP server allows Claude to orchestrate Gemini as a subordinate model
- **Automatic Fallback**: When Gemini quota is exceeded, the fallback system automatically switches to alternative models
- **Master Agent**: Claude remains the primary orchestrator (master agent)

## 🔄 Gemini Fallback System

The `gemini-fallback.py` script provides automatic model switching when quota limits are hit.

### Model Priority Order
1. `gemini-2.5-pro` (highest quality)
2. `gemini-2.5-flash` (balanced)
3. `gemini-2.5-flash-preview-09-2025`
4. `gemini-2.5-flash-lite` (fastest)
5. `gemini-1.5-pro` (legacy)
6. `gemini-1.5-flash` (legacy)

### Usage
```bash
# Basic usage
python3 ~/gemini-fallback.py "Your prompt here"

# Verbose output
python3 ~/gemini-fallback.py -v "Your prompt here"

# The system will:
# - Try each model in order
# - Retry up to 3 times per model
# - Cycle through all models up to 3 times
# - Report to Claude (master agent) if all models fail
```

### Integration with Claude
When all Gemini models are exhausted, the fallback system automatically reports back to Claude, which can then handle the task using its own capabilities.

## 🔑 API 키 설정

### Gemini API
1. Visit: https://aistudio.google.com/app/apikey
2. Create API key
3. Add to `~/.zshrc`:
```bash
# Gemini API Keys
export GEMINI_API_KEY="your-gemini-api-key-here"
export GOOGLE_API_KEY="your-google-api-key-here"
```

### Reload Shell
```bash
source ~/.zshrc
```

## 🛠️ OMC (oh-my-claudecode) 설치

```bash
# OMC 초기화 - 모든 MCP 서버와 설정 자동 구성
claude omc-setup
```

OMC provides:
- Multi-agent orchestration
- Parallel task execution
- Specialized agents (architect, executor, debugger, etc.)
- Workflow automation (autopilot, ralph, ultrawork modes)

## 📦 기타 유용한 CLI 도구

```bash
# Fast 파일 검색
npm install -g ack

# 코드 검색 및 분���
npm install -g ripgrep

# JSON 처리
brew install jq

# HTTP 클라이언트
npm install -g httpie
```

## ✅ 검증

설치 후 다음 명령어로 확인:

```bash
# MCP 서버 확인
cat ~/.claude/.mcp.json

# Gemini CLI 확인
gemini --version

# API 키 확인
echo $GEMINI_API_KEY

# 테스트
gemini "Hello, world!"
```

## 🐛 Troubleshooting

### Issue: Gemini quota exceeded
**Solution:** The fallback system handles this automatically. If all models fail:
1. Wait for daily quota reset (midnight Pacific Time)
2. Check quota at: https://aistudio.google.com/app/apikey
3. Consider upgrading to paid plan

### Issue: MCP server not found
**Solution:**
```bash
# Reinstall MCP server
npm install -g gemini-mcp-rust

# Verify MCP config
cat ~/.claude/.mcp.json

# Restart Claude Code
```

### Issue: API key not working
**Solution:**
```bash
# Verify API key is set
echo $GEMINI_API_KEY

# Test directly
curl -H "x-goog-api-key: $GEMINI_API_KEY" \
  "https://generativelanguage.googleapis.com/v1/models"
```

## 📚 참고 자료

- **Claude Code**: https://claude.ai/download
- **MCP Protocol**: https://modelcontextprotocol.io
- **OMC Documentation**: https://github.com/ueno-ryu/oh-my-claudecode
- **Gemini API**: https://ai.google.dev/gemini-api/docs
- **Gemini CLI**: https://www.npmjs.com/package/@google/gemini-cli

## 📖 Architecture Overview

```
┌─────────────────────────────────────────┐
│         Claude (Master Agent)           │
│  • Orchestration & Decision Making      │
│  • Multi-agent Coordination            │
│  • User Interaction                    │
└──────────────┬──────────────────────────┘
               │
               ├─→ MCP: Filesystem (direct file access)
               │
               └─→ MCP: Gemini (subordinate model)
                       │
                       ├─→ Gemini CLI (direct invocation)
                       │
                       └─→ Fallback System (auto model switching)
                               ├── gemini-2.5-pro
                               ├── gemini-2.5-flash
                               └─→ ... (6 total models)
```

## 🔄 Workflow Examples

### Example 1: Simple Gemini Task
```bash
# Direct Gemini usage
gemini "Explain quantum computing in simple terms"

# With fallback protection
python3 ~/gemini-fallback.py "Explain quantum computing"
```

### Example 2: Code Analysis with Claude
```bash
# Claude orchestrates, Gemini assists when needed
claude "Analyze this codebase for security issues"

# Claude may use Gemini via MCP for parallel processing
```

### Example 3: OMC Multi-Agent Execution
```bash
# Activate ULTRAWORK mode for maximum parallelism
# Claude orchestrates multiple specialist agents
claude "Build a REST API with authentication"

# OMC will:
# - Spawn architect agent (design)
# - Spawn executor agents (implementation)
# - Use Gemini MCP for additional processing
# - Use fallback system if Gemini quota exceeded
```
