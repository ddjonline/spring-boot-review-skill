@echo off
REM Generate PDF from a Markdown report file.
REM Tries: 1) npx md-to-pdf (zero-install)  2) pandoc (fallback)
REM Usage: generate-pdf.bat <report_markdown_path>
REM Exit codes:
REM   0 - PDF generated successfully
REM   1 - Both converters failed, markdown-only delivery

setlocal enabledelayedexpansion

set "REPORT_MD=%~1"
if "%REPORT_MD%"=="" set "REPORT_MD=spring-boot-review-report.md"

REM Validate report file exists
if not exist "%REPORT_MD%" (
    echo ERROR: Report file not found: %REPORT_MD% >&2
    exit /b 1
)

REM Extract directory, basename, and PDF path
for %%F in ("%REPORT_MD%") do (
    set "REPORT_DIR=%%~dpF"
    set "REPORT_BASENAME=%%~nF"
)
REM Remove trailing backslash from directory
if "%REPORT_DIR:~-1%"=="\" set "REPORT_DIR=%REPORT_DIR:~0,-1%"
set "REPORT_PDF=%REPORT_DIR%\%REPORT_BASENAME%.pdf"

echo Generating PDF from %REPORT_MD% ...

REM Attempt 1: npx md-to-pdf
echo Attempt 1: npx md-to-pdf ...
call npx.cmd --yes md-to-pdf "%REPORT_MD%" --output "%REPORT_PDF%" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    if exist "%REPORT_PDF%" (
        echo PDF generated successfully (md-to-pdf): %REPORT_PDF%
        exit /b 0
    )
)
echo md-to-pdf failed. Attempting fallback...

REM Attempt 2: pandoc with wkhtmltopdf engine
echo Attempt 2: pandoc ...
where pandoc >nul 2>&1
if %ERRORLEVEL% equ 0 (
    pandoc "%REPORT_MD%" -o "%REPORT_PDF%" --pdf-engine=wkhtmltopdf >nul 2>&1
    if exist "%REPORT_PDF%" (
        echo PDF generated successfully (pandoc+wkhtmltopdf): %REPORT_PDF%
        exit /b 0
    )

    REM Try with weasyprint if wkhtmltopdf unavailable
    pandoc "%REPORT_MD%" -o "%REPORT_PDF%" --pdf-engine=weasyprint >nul 2>&1
    if exist "%REPORT_PDF%" (
        echo PDF generated successfully (pandoc+weasyprint): %REPORT_PDF%
        exit /b 0
    )
)
echo pandoc failed or not available.

REM Both failed
echo WARNING: PDF generation failed. Delivering markdown-only report. >&2
echo.
echo To generate PDF manually:
echo   npm install -g md-to-pdf ^&^& md-to-pdf "%REPORT_MD%"
echo   # or
echo   choco install pandoc wkhtmltopdf ^&^& pandoc "%REPORT_MD%" -o "%REPORT_PDF%" --pdf-engine=wkhtmltopdf
exit /b 1
