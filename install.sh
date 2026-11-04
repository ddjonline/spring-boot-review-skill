#!/usr/bin/env bash
# Spring Boot Review Skill — Installer
# Installs the OpenCode skill and/or Claude Code custom slash command.
# Default: installs both globally (~/.config/opencode, ~/.claude).
#
# Usage:
#   ./install.sh                          # Install both globally
#   ./install.sh --opencode-only          # Install only OpenCode skill
#   ./install.sh --claude-only            # Install only Claude Code command
#   ./install.sh --target /path/to/project
#   ./install.sh --local                  # Install locally into project directory
#   ./install.sh --help                   # Show this help

set -euo pipefail

# ── Defaults ────────────────────────────────────────────────────────────────

INSTALL_OPENCODE=true
INSTALL_CLAUDE=true
TARGET_DIR=""
LOCAL=false
OVERWRITE_ALL=false
SKIP_ALL=false

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Colors ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Help ─────────────────────────────────────────────────────────────────────

show_help() {
    cat << EOF
${BOLD}Spring Boot Review Skill — Installer${NC}

Installs the OpenCode skill and/or Claude Code custom slash command
into your project or globally.

${BOLD}Usage:${NC}
  ./install.sh [options]

${BOLD}Options:${NC}
  --opencode-only       Install only the OpenCode skill
  --claude-only         Install only the Claude Code slash command
  --target <dir>        Install into a specific project directory (default: current dir)
  --local               Install locally into a project directory
  --yes, -y             Skip overwrite prompts — overwrite all existing files
  --skip-existing       Skip overwrite prompts — keep all existing files
  --help, -h            Show this help message

${BOLD}Examples:${NC}
  ./install.sh                              # Install both globally (default)
  ./install.sh --opencode-only              # Install only OpenCode skill globally
  ./install.sh --local                      # Install both to current directory
  ./install.sh --local --target ~/my-app    # Install both to a specific project
  ./install.sh --local --claude-only        # Local Claude Code command install
  ./install.sh --yes                        # Install both, overwrite all without asking
EOF
    exit 0
}

# ── Arg Parsing ──────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --opencode-only)
            INSTALL_CLAUDE=false
            ;;
        --claude-only)
            INSTALL_OPENCODE=false
            ;;
        --target)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error: --target requires a directory argument${NC}" >&2
                exit 1
            fi
            TARGET_DIR="$2"
            shift
            ;;
        --local)
            LOCAL=true
            ;;
        --yes|-y)
            OVERWRITE_ALL=true
            ;;
        --skip-existing)
            SKIP_ALL=true
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Error: Unknown option '$1'. Use --help for usage.${NC}" >&2
            exit 1
            ;;
    esac
    shift
done

# ── Resolve target ───────────────────────────────────────────────────────────

if [ "$LOCAL" = true ]; then
    if [ -z "$TARGET_DIR" ]; then
        TARGET_DIR="$(pwd)"
    fi
    # Resolve to absolute path
    TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd || echo "$TARGET_DIR")"
    OPENCODE_TARGET="$TARGET_DIR/.opencode/skills/spring-boot-review"
    CLAUDE_TARGET="$TARGET_DIR/.claude"
else
    OPENCODE_TARGET="$HOME/.config/opencode/skills/spring-boot-review"
    CLAUDE_TARGET="$HOME/.claude"
fi

# ── Validation ───────────────────────────────────────────────────────────────

if [ "$INSTALL_OPENCODE" = false ] && [ "$INSTALL_CLAUDE" = false ]; then
    echo -e "${RED}Error: Both --opencode-only and --claude-only specified. Nothing to install.${NC}" >&2
    exit 1
fi

# ── Helper: confirm overwrite ────────────────────────────────────────────────

confirm_overwrite() {
    local path="$1"
    if [ "$OVERWRITE_ALL" = true ]; then
        return 0
    fi
    if [ "$SKIP_ALL" = true ]; then
        return 1
    fi
    echo -ne "${YELLOW}  File already exists: ${path}${NC}\n  Overwrite? [y/N/s=skip all/a=overwrite all] "
    read -r answer
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        [aA]|[aA][lL][lL]) OVERWRITE_ALL=true; return 0 ;;
        [sS]|[sS][kK][iI][pP]) SKIP_ALL=true; return 1 ;;
        *) return 1 ;;
    esac
}

# ── Helper: copy file ────────────────────────────────────────────────────────

copy_file() {
    local src="$1"
    local dest="$2"
    local desc="${3:-file}"

    mkdir -p "$(dirname "$dest")"

    if [ -f "$dest" ] || [ -d "$dest" ]; then
        if ! confirm_overwrite "$dest"; then
            echo -e "  ${YELLOW}Skipped${NC} ${desc}: ${dest/$HOME/~}"
            return
        fi
    fi

    if [ -d "$src" ]; then
        cp -r "$src" "$dest"
    else
        cp "$src" "$dest"
    fi
    echo -e "  ${GREEN}Installed${NC} ${desc}: ${dest/$HOME/~}"
}

# ── Install OpenCode Skill ───────────────────────────────────────────────────

install_opencode() {
    echo ""
    echo -e "${BOLD}${CYAN}── Installing OpenCode Skill ──────────────────────────────────${NC}"
    echo -e "  Source: ${SOURCE_DIR/$HOME/~}/opencode-skill/.opencode/skills/spring-boot-review/"
    echo -e "  Target: ${OPENCODE_TARGET/$HOME/~}/"
    echo ""

    local src="$SOURCE_DIR/opencode-skill/.opencode/skills/spring-boot-review"

    if [ ! -d "$src" ]; then
        echo -e "${RED}Error: OpenCode skill source not found at $src${NC}" >&2
        exit 1
    fi

    copy_file "$src" "$OPENCODE_TARGET" "OpenCode skill directory"
}

# ── Install Claude Code Command ──────────────────────────────────────────────

install_claude() {
    echo ""
    echo -e "${BOLD}${CYAN}── Installing Claude Code Command ──────────────────────────────${NC}"
    echo -e "  Source: ${SOURCE_DIR/$HOME/~}/claude-code/"
    echo -e "  Target: ${CLAUDE_TARGET/$HOME/~}/"
    echo ""

    local src="$SOURCE_DIR/claude-code"

    if [ ! -d "$src" ]; then
        echo -e "${RED}Error: Claude Code source not found at $src${NC}" >&2
        exit 1
    fi

    # Slash command
    copy_file \
        "$src/.claude/commands/spring-boot-review.md" \
        "$CLAUDE_TARGET/commands/spring-boot-review.md" \
        "slash command"

    # References
    copy_file \
        "$src/references" \
        "$CLAUDE_TARGET/references/spring-boot-review" \
        "reference files"

    # Templates
    copy_file \
        "$src/templates" \
        "$CLAUDE_TARGET/templates/spring-boot-review" \
        "template files"

    # Scripts
    copy_file \
        "$src/scripts" \
        "$CLAUDE_TARGET/scripts/spring-boot-review" \
        "scripts"

    # Make scripts executable
    if [ -d "$CLAUDE_TARGET/scripts/spring-boot-review" ]; then
        chmod +x "$CLAUDE_TARGET/scripts/spring-boot-review"/*.sh 2>/dev/null || true
    fi
}

# ── Post-install Gitignore ───────────────────────────────────────────────────

update_gitignore() {
    local gitignore_file="$1/.gitignore"
    local marker="# Spring Boot Review scratchpad — security-sensitive"
    local entry=".claude/scratchpad/"

    # Only for project-level installs (not global)
    if [ "$LOCAL" = false ]; then
        return
    fi

    if [ -f "$gitignore_file" ]; then
        if ! grep -qF "$entry" "$gitignore_file" 2>/dev/null; then
            echo "" >> "$gitignore_file"
            echo "$marker" >> "$gitignore_file"
            echo "$entry" >> "$gitignore_file"
            echo -e "  ${GREEN}Updated${NC} .gitignore with scratchpad exclusion"
        fi
    fi
}

# ── Summary ──────────────────────────────────────────────────────────────────

print_summary() {
    echo ""
    echo -e "${BOLD}${GREEN}✓ Installation complete!${NC}"
    echo ""

    if [ "$INSTALL_OPENCODE" = true ]; then
        echo -e "  ${BOLD}OpenCode Skill:${NC}"
        if [ "$LOCAL" = true ]; then
            echo -e "    → ${TARGET_DIR/$HOME/~}/.opencode/skills/spring-boot-review/"
        else
            echo -e "    → Available in all projects"
        fi
        echo -e "    → Invoke with: ${CYAN}@spring-boot-review${NC}"
        echo ""
    fi

    if [ "$INSTALL_CLAUDE" = true ]; then
        echo -e "  ${BOLD}Claude Code Command:${NC}"
        if [ "$LOCAL" = true ]; then
            echo -e "    → ${TARGET_DIR/$HOME/~}/.claude/"
        else
            echo -e "    → Available in all projects"
        fi
        echo -e "    → Invoke with: ${CYAN}/spring-boot-review${NC}"
        echo ""
    fi

    echo -e "  ${BOLD}Prerequisites:${NC}"
    echo -e "    OpenCode: requires ${CYAN}subagent_depth: 2${NC} in opencode.jsonc"
    echo -e "    Claude Code: auto-discovers commands under .claude/commands/"
    echo -e "    PDF generation: Node.js + npx (optional) or pandoc (optional)"
    echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}Spring Boot Review Skill v2.0 — Installer${NC}"
echo ""

if [ "$INSTALL_OPENCODE" = true ]; then
    install_opencode
fi

if [ "$INSTALL_CLAUDE" = true ]; then
    install_claude
fi

if [ "$LOCAL" = true ] && [ -n "$TARGET_DIR" ]; then
    # Update .gitignore for project-level installs
    if [ -f "$TARGET_DIR/.gitignore" ]; then
        if [ "$INSTALL_CLAUDE" = true ]; then
            update_gitignore "$TARGET_DIR"
        fi
    fi
fi

print_summary