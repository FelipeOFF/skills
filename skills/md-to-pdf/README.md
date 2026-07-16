# OpenClaw Markdown to PDF

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js Version](https://img.shields.io/badge/node-%3E%3D18.0.0-brightgreen)](https://nodejs.org/)
[![OpenClaw Plugin](https://img.shields.io/badge/OpenClaw-Plugin-blue)](https://docs.openclaw.ai)

Convert Markdown files to PDF with ease. An **OpenClaw Plugin + CLI Tool** powered by [md-to-pdf](https://github.com/simonhaenisch/md-to-pdf).

## 🎯 Features

- ✅ **Simple conversion** - One command to convert Markdown to PDF
- ✅ **Customizable themes** - Default, GitHub, LaTeX styles
- ✅ **Headers & Footers** - Add page numbers and custom text
- ✅ **Batch processing** - Convert multiple files at once
- ✅ **OpenClaw integration** - Use as native tool or CLI

## 🚀 Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/FelipeOFF/openclaw-md-to-pdf.git

# Install dependencies
cd openclaw-md-to-pdf
npm install

# Install globally (optional)
npm install -g @felipeoff/openclaw-md-to-pdf
```

### Basic Usage

```bash
# Convert a single file
node scripts/convert.js document.md

# Convert with custom output
node scripts/convert.js document.md --output report.pdf

# Use a theme
node scripts/convert.js document.md --theme github
```

## 🔌 OpenClaw Integration

### As Plugin

Add to your `openclaw.json`:

```json
{
  "plugins": {
    "load": {
      "paths": [
        "/path/to/openclaw-md-to-pdf"
      ]
    },
    "entries": {
      "openclaw-md-to-pdf": {
        "enabled": true,
        "config": {
          "defaultOutputDir": "./pdfs",
          "defaultTheme": "github"
        }
      }
    }
  }
}
```

### Available Tools

#### `md_to_pdf_convert`

```javascript
// Convert single file
md_to_pdf_convert({
  inputFile: "/path/to/document.md",
  outputFile: "/path/to/output.pdf",
  theme: "github",
  header: "Company Report",
  footer: "Page {page} of {pages}"
})
```

#### `md_to_pdf_batch`

```javascript
// Batch conversion
md_to_pdf_batch({
  inputDir: "./documents",
  outputDir: "./pdfs",
  pattern: "*.md"
})
```

## 📋 CLI Options

```bash
Usage: openclaw-md-to-pdf [options] <input>

Options:
  -o, --output <file>     Output PDF file path
  -t, --theme <name>     Theme: default, github, latex (default: default)
  -h, --header <text>    Header text for all pages
  -f, --footer <text>    Footer text for all pages
  --help                  Display help
```

## 🎨 Themes

| Theme | Description |
|-------|-------------|
| `default` | Clean, minimal styling |
| `github` | GitHub-flavored Markdown look |
| `latex` | Academic/LaTeX styling |

## 🛠️ Requirements

- Node.js >= 18.0.0
- **Chrome or Chromium browser** (required by Puppeteer)
- OpenClaw >= 1.0.0 (for plugin mode)

### Installing Chrome/Chromium

This tool requires a Chrome/Chromium installation. Puppeteer will try to download it automatically, but you may need to install it manually:

**Option 1: Automatic (via Puppeteer)**
```bash
npx puppeteer browsers install chrome
```

**Option 2: System Package Manager**
```bash
# Ubuntu/Debian
sudo apt-get install chromium-browser

# macOS
brew install chromium

# Or download manually from:
# https://www.chromium.org/getting-involved/download-chromium
```

**Option 3: Environment Variable**
If Chrome is installed in a non-standard location:
```bash
export PUPPETEER_EXECUTABLE_PATH=/path/to/chrome
```

## 🔧 Troubleshooting

### Error: "Cannot find module 'commander'"
```bash
npm install commander glob --save
```

### Error: "Failed to launch browser" or "No usable sandbox"
Chrome may not be installed. Install it using one of the methods in the Requirements section above.

### Error: "Chrome executable not found"
Set the Chrome path explicitly:
```bash
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
```

### Puppeteer download fails
If Puppeteer fails to download Chrome, skip it and install manually:
```bash
PUPPETEER_SKIP_DOWNLOAD=true npm install
# Then install Chrome manually (see Requirements section)
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for [OpenClaw](https://github.com/openclaw/openclaw)
- Powered by [md-to-pdf](https://github.com/simonhaenisch/md-to-pdf)
- Thanks to the OpenClaw community for feedback and support

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/FelipeOFF/openclaw-md-to-pdf/issues)
- **Discussions:** [GitHub Discussions](https://github.com/FelipeOFF/openclaw-md-to-pdf/discussions)
- **OpenClaw Docs:** https://docs.openclaw.ai

---

**Made with ❤️ for the OpenClaw community**
