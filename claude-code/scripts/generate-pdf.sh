#!/usr/bin/env bash
# Generate PDF from a Markdown report file.
# Tries: 1) npx md-to-pdf (zero-install)  2) pandoc (fallback)
# Usage: generate-pdf.sh <report_markdown_path>
# Exit codes:
#   0 - PDF generated successfully
#   1 - Both converters failed, markdown-only delivery

set -euo pipefail

REPORT_MD="${1:-spring-boot-review-report.md}"

if [ ! -f "$REPORT_MD" ]; then
    echo "ERROR: Report file not found: $REPORT_MD" >&2
    exit 1
fi

REPORT_DIR="$(dirname "$REPORT_MD")"
REPORT_BASENAME="$(basename "$REPORT_MD" .md)"
REPORT_PDF="${REPORT_DIR}/${REPORT_BASENAME}.pdf"

echo "Generating PDF from $REPORT_MD ..."

# Attempt 1: npx md-to-pdf
echo "Attempt 1: npx md-to-pdf ..."
if npx --yes md-to-pdf "$REPORT_MD" --output "$REPORT_PDF" 2>/dev/null; then
    echo "PDF generated successfully (md-to-pdf): $REPORT_PDF"
    exit 0
fi
echo "md-to-pdf failed or timed out. Attempting fallback..."

# Attempt 2: pandoc with wkhtmltopdf engine
echo "Attempt 2: pandoc ..."
if command -v pandoc &>/dev/null; then
    if pandoc "$REPORT_MD" -o "$REPORT_PDF" --pdf-engine=wkhtmltopdf 2>/dev/null; then
        echo "PDF generated successfully (pandoc): $REPORT_PDF"
        exit 0
    fi
    # Try with weasyprint if wkhtmltopdf unavailable
    if pandoc "$REPORT_MD" -o "$REPORT_PDF" --pdf-engine=weasyprint 2>/dev/null; then
        echo "PDF generated successfully (pandoc+weasyprint): $REPORT_PDF"
        exit 0
    fi
fi
echo "pandoc failed or not available."

# Both failed
echo "WARNING: PDF generation failed. Delivering markdown-only report." >&2
echo "To generate PDF manually:"
echo "  npm install -g md-to-pdf && md-to-pdf $REPORT_MD"
echo "  # or"
echo "  brew install pandoc wkhtmltopdf && pandoc $REPORT_MD -o $REPORT_PDF --pdf-engine=wkhtmltopdf"
exit 1
