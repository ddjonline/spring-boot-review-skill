@echo off
setlocal enabledelayedexpansion

REM Spring Boot Review Skill — Installer (Windows)
REM Installs the OpenCode skill and/or Claude Code custom slash command.
REM Default: installs both into the current project directory.
REM
REM Usage:
REM   install.bat                          Install both to current dir
REM   install.bat --opencode-only          Install only OpenCode skill
REM   install.bat --claude-only            Install only Claude Code command
REM   install.bat --target C:\path\to\project
REM   install.bat --global                 Global install
REM   install.bat --help                   Show this help

REM ── Defaults ───────────────────────────────────────────────────────────────

set INSTALL_OPENCODE=true
set INSTALL_CLAUDE=true
set TARGET_DIR=
set GLOBAL=false
set OVERWRITE_ALL=false
set SKIP_ALL=false

set SOURCE_DIR=%~dp0
REM Remove trailing backslash
if "%SOURCE_DIR:~-1%"=="\" set SOURCE_DIR=%SOURCE_DIR:~0,-1%

REM ── Colors / Visual markers ────────────────────────────────────────────────

REM Use ANSI if supported (Windows 10+), else plain text
set "GREEN=[OK]"
set "YELLOW=[SKIP]"
set "RED=[ERROR]"
set "CYAN="
set "BOLD="
set "NC="

REM ── Arg Parsing ────────────────────────────────────────────────────────────

:parse_args
if "%~1"=="" goto :args_done

if /I "%~1"=="--opencode-only" (
    set INSTALL_CLAUDE=false
    shift
    goto :parse_args
)
if /I "%~1"=="--claude-only" (
    set INSTALL_OPENCODE=false
    shift
    goto :parse_args
)
if /I "%~1"=="--target" (
    if "%~2"=="" (
        echo %RED% Error: --target requires a directory argument
        exit /b 1
    )
    set TARGET_DIR=%~2
    shift
    shift
    goto :parse_args
)
if /I "%~1"=="--global" (
    set GLOBAL=true
    shift
    goto :parse_args
)
if /I "%~1"=="--yes" (
    set OVERWRITE_ALL=true
    shift
    goto :parse_args
)
if /I "%~1"=="-y" (
    set OVERWRITE_ALL=true
    shift
    goto :parse_args
)
if /I "%~1"=="--skip-existing" (
    set SKIP_ALL=true
    shift
    goto :parse_args
)
if /I "%~1"=="--help" goto :show_help
if /I "%~1"=="-h" goto :show_help

echo %RED% Error: Unknown option '%~1'. Use --help for usage.
exit /b 1

:args_done

REM ── Help ───────────────────────────────────────────────────────────────────

:show_help
if "%~1"=="" goto :skip_help
echo.
echo Spring Boot Review Skill — Installer
echo.
echo Installs the OpenCode skill and/or Claude Code custom slash command
echo into your project or globally.
echo.
echo Usage:
echo   install.bat [options]
echo.
echo Options:
echo   --opencode-only       Install only the OpenCode skill
echo   --claude-only         Install only the Claude Code slash command
echo   --target ^<dir^>        Install into a specific project directory (default: current dir)
echo   --global              Install globally for all projects
echo   --yes, -y             Skip overwrite prompts — overwrite all existing files
echo   --skip-existing       Skip overwrite prompts — keep all existing files
echo   --help, -h            Show this help message
echo.
echo Examples:
echo   install.bat                              Install both to current directory
echo   install.bat --opencode-only              Install only OpenCode skill
echo   install.bat --target C:\my-spring-app    Install both to a specific project
echo   install.bat --global --claude-only       Global Claude Code command install
echo   install.bat --global                     Global install for both platforms
echo   install.bat --yes                        Install both, overwrite all without asking
exit /b 0

:skip_help

REM ── Resolve target ─────────────────────────────────────────────────────────

if "%GLOBAL%"=="true" (
    set OPENCODE_TARGET=%USERPROFILE%\.config\opencode\skills\spring-boot-review
    set CLAUDE_TARGET=%USERPROFILE%\.claude
) else (
    if "%TARGET_DIR%"=="" set TARGET_DIR=%CD%
    REM Push to resolve full path
    pushd "%TARGET_DIR%" 2>nul
    if errorlevel 1 (
        echo %RED% Error: Target directory not found: %TARGET_DIR%
        exit /b 1
    )
    set TARGET_DIR=%CD%
    popd
    set OPENCODE_TARGET=%TARGET_DIR%\.opencode\skills\spring-boot-review
    set CLAUDE_TARGET=%TARGET_DIR%\.claude
)

REM ── Validation ─────────────────────────────────────────────────────────────

if "%INSTALL_OPENCODE%"=="false" if "%INSTALL_CLAUDE%"=="false" (
    echo %RED% Error: Both --opencode-only and --claude-only specified. Nothing to install.
    exit /b 1
)

REM ── Helper: confirm overwrite ─────────────────────────────────────────────

goto :skip_helpers

:confirm_overwrite
REM %1 = path to check
if "%OVERWRITE_ALL%"=="true" exit /b 0
if "%SKIP_ALL%"=="true" exit /b 1

echo   %YELLOW% File already exists: %~1
choice /C YNAS /N /M "  Overwrite? [Y]es [N]o [A]ll [S]kip all: "
if errorlevel 4 (
    set SKIP_ALL=true
    exit /b 1
)
if errorlevel 3 (
    set OVERWRITE_ALL=true
    exit /b 0
)
if errorlevel 2 exit /b 1
if errorlevel 1 exit /b 0
exit /b 1

:skip_helpers

REM ── Helper: copy file/dir ──────────────────────────────────────────────────

goto :skip_copyfile

:copy_file
REM %1 = source, %2 = dest, %3 = description
setlocal
set SRC=%~1
set DEST=%~2
set DESC=%~3

REM Create parent directory
for %%F in ("%DEST%") do set PARENT=%%~dpF
if not exist "%PARENT%" mkdir "%PARENT%" 2>nul

REM Check if destination exists
if exist "%DEST%" (
    call :confirm_overwrite "%DEST%"
    if errorlevel 1 (
        echo   %YELLOW% Skipped %DESC%: %DEST%
        endlocal
        exit /b 0
    )
)

REM Copy (handle both files and directories)
if exist "%SRC%\*" (
    REM It's a directory
    if exist "%DEST%" rmdir /S /Q "%DEST%" 2>nul
    xcopy /E /I /H /Y "%SRC%" "%DEST%" >nul 2>nul
) else (
    REM It's a file
    copy /Y "%SRC%" "%DEST%" >nul 2>nul
)

echo   %GREEN% Installed %DESC%: %DEST%
endlocal
exit /b 0

:skip_copyfile

REM ═══════════════════════════════════════════════════════════════════════════
REM  Install OpenCode Skill
REM ═══════════════════════════════════════════════════════════════════════════

:install_opencode
if "%INSTALL_OPENCODE%"=="false" goto :install_claude

echo.
echo ── Installing OpenCode Skill ──────────────────────────────
echo   Source: %SOURCE_DIR%\.opencode\skills\spring-boot-review\
echo   Target: %OPENCODE_TARGET%
echo.

set OPENCODE_SRC=%SOURCE_DIR%\.opencode\skills\spring-boot-review

if not exist "%OPENCODE_SRC%" (
    echo %RED% Error: OpenCode skill source not found at %OPENCODE_SRC%
    exit /b 1
)

call :copy_file "%OPENCODE_SRC%" "%OPENCODE_TARGET%" "OpenCode skill directory"

REM ═══════════════════════════════════════════════════════════════════════════
REM  Install Claude Code Command
REM ═══════════════════════════════════════════════════════════════════════════

:install_claude
if "%INSTALL_CLAUDE%"=="false" goto :post_install

echo.
echo ── Installing Claude Code Command ──────────────────────────
echo   Source: %SOURCE_DIR%\claude-code\
echo   Target: %CLAUDE_TARGET%
echo.

set CLAUDE_SRC=%SOURCE_DIR%\claude-code

if not exist "%CLAUDE_SRC%" (
    echo %RED% Error: Claude Code source not found at %CLAUDE_SRC%
    exit /b 1
)

REM Slash command
call :copy_file "%CLAUDE_SRC%\.claude\commands\spring-boot-review.md" "%CLAUDE_TARGET%\commands\spring-boot-review.md" "slash command"

REM References
call :copy_file "%CLAUDE_SRC%\references" "%CLAUDE_TARGET%\references\spring-boot-review" "reference files"

REM Templates
call :copy_file "%CLAUDE_SRC%\templates" "%CLAUDE_TARGET%\templates\spring-boot-review" "template files"

REM Scripts
call :copy_file "%CLAUDE_SRC%\scripts" "%CLAUDE_TARGET%\scripts\spring-boot-review" "scripts"

REM ═══════════════════════════════════════════════════════════════════════════
REM  Post-install update .gitignore (project-level only)
REM ═══════════════════════════════════════════════════════════════════════════

:post_install
if "%GLOBAL%"=="true" goto :print_summary
if "%TARGET_DIR%"=="" goto :print_summary

set GITIGNORE=%TARGET_DIR%\.gitignore
if not exist "%GITIGNORE%" goto :print_summary

findstr /C:".claude/scratchpad/" "%GITIGNORE%" >nul 2>nul
if errorlevel 1 (
    echo.>>"%GITIGNORE%"
    echo # Spring Boot Review scratchpad — security-sensitive>>"%GITIGNORE%"
    echo .claude/scratchpad/>>"%GITIGNORE%"
    echo   %GREEN% Updated .gitignore with scratchpad exclusion
)

REM ═══════════════════════════════════════════════════════════════════════════
REM  Summary
REM ═══════════════════════════════════════════════════════════════════════════

:print_summary
echo.
echo ✓ Installation complete!
echo.

if "%INSTALL_OPENCODE%"=="true" (
    echo   OpenCode Skill:
    if "%GLOBAL%"=="true" (
        echo     ^> Available in all projects
    ) else (
        echo     ^> %TARGET_DIR%\.opencode\skills\spring-boot-review\
    )
    echo     ^> Invoke with: @spring-boot-review
    echo.
)

if "%INSTALL_CLAUDE%"=="true" (
    echo   Claude Code Command:
    if "%GLOBAL%"=="true" (
        echo     ^> Available in all projects
    ) else (
        echo     ^> %TARGET_DIR%\.claude\
    )
    echo     ^> Invoke with: /spring-boot-review
    echo.
)

echo   Prerequisites:
echo     OpenCode: requires subagent_depth: 2 in opencode.jsonc
echo     Claude Code: auto-discovers commands under .claude/commands/
echo     PDF generation: Node.js + npx (optional) or pandoc (optional)
echo.

endlocal
exit /b 0