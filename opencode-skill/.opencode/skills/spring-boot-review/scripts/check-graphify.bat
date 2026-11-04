@echo off
REM Check if graphify is installed and has a knowledge graph for the target.
REM Usage: check-graphify.bat <target_directory>
REM Exit codes:
REM   0 - graphify installed, graph exists at <target>\graphify-out\graph.json
REM   1 - graphify installed, but no graph exists yet
REM   2 - graphify is not installed
REM   3 - error (target not found, etc.)

setlocal enabledelayedexpansion

set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=."

REM Validate target directory exists
if not exist "%TARGET%" (
    echo ERROR: Target directory not found: %TARGET% >&2
    exit /b 3
)

REM Resolve to absolute path
pushd "%TARGET%" 2>nul || (
    echo ERROR: Cannot access target directory: %TARGET% >&2
    exit /b 3
)
set "TARGET_ABS=%CD%"
popd

REM Check if graphify CLI is available via 'where'
where graphify >nul 2>&1
if %ERRORLEVEL% neq 0 (
    REM graphify binary not found on PATH. Try python module directly.
    goto :check_python_module
)

REM graphify binary found. Verify the Python module is importable.
python -c "import graphify" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    goto :check_graph_exists
)

REM Binary exists but module import failed. Try alternate Python paths.
:check_python_module
python -c "import graphify" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    python3 -c "import graphify" >nul 2>&1
    if !ERRORLEVEL! neq 0 (
        py -3 -c "import graphify" >nul 2>&1
        if !ERRORLEVEL! neq 0 (
            echo graphify not installed >&2
            exit /b 2
        )
    )
)

:check_graph_exists
REM graphify is installed. Check if a graph already exists.
if exist "%TARGET_ABS%\graphify-out\graph.json" (
    echo graphify: installed, graph exists at %TARGET_ABS%\graphify-out\graph.json
    exit /b 0
) else (
    echo graphify: installed, no graph found for %TARGET_ABS%
    exit /b 1
)
