#!/usr/bin/env python3
"""Convert markdown flyer to PDF with emoji support."""

import markdown
import pdfkit
from pathlib import Path

# Read the markdown file
md_file = Path('AppStore_Marketing_Flyer.md')
html_file = Path('AppStore_Marketing_Flyer.html')
pdf_file = Path('AppStore_Marketing_Flyer.pdf')

# Read markdown content
markdown_text = md_file.read_text()

# Convert markdown to HTML
html = markdown.markdown(markdown_text, extensions=['extra', 'codehilite'])

# Create a complete HTML document with emoji support
html_doc = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ALARM - Professional Theft Detection System</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            line-height: 1.6;
            max-width: 900px;
            margin: 0 auto;
            padding: 20px;
            color: #333;
        }}
        h1, h2, h3 {{ color: #2c3e50; }}
        h1 {{ text-align: center; font-size: 2.5em; }}
        h2 {{ font-size: 2em; border-bottom: 2px solid #3498db; padding-bottom: 10px; }}
        h3 {{ font-size: 1.5em; color: #e74c3c; }}
        table {{ border-collapse: collapse; width: 100%; margin: 20px 0; }}
        th, td {{ border: 1px solid #ddd; padding: 12px; text-align: left; }}
        th {{ background-color: #3498db; color: white; }}
        hr {{ border: none; border-top: 3px solid #eee; margin: 30px 0; }}
        img {{ max-width: 200px; display: block; margin: 0 auto; }}
        ul {{ padding-left: 20px; }}
        em {{ color: #7f8c8d; }}
    </style>
</head>
<body>
{html}
</body>
</html>
"""

# Write HTML file
html_file.write_text(html_doc)

print(f"✓ Created {html_file}")

# Try to convert to PDF using pdfkit
try:
    options = {
        'encoding': 'UTF-8',
        'enable-local-file-access': None,
        'print-media-type': None,
        'no-outline': None,
        'margin-top': '0.75in',
        'margin-right': '0.75in',
        'margin-bottom': '0.75in',
        'margin-left': '0.75in',
    }
    pdfkit.from_file(str(html_file), str(pdf_file), options=options)
    print(f"✓ Created {pdf_file}")
except Exception as e:
    print(f"✗ Could not create PDF with pdfkit: {e}")
    print(f"  However, you can open {html_file} in Chrome/Safari and print to PDF (⌘P)")
