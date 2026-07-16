/**
 * PDF Converter Logic
 * Wrapper around md-to-pdf
 */

const { mdToPdf } = require('md-to-pdf');
const path = require('path');
const fs = require('fs').promises;
const glob = require('glob');

// Theme definitions
const themes = {
  default: {},
  github: {
    css: `
      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; line-height: 1.6; color: #24292e; }
      h1, h2, h3 { color: #0366d6; border-bottom: 1px solid #eaecef; padding-bottom: 0.3em; }
      h1 { font-size: 2em; }
      h2 { font-size: 1.5em; }
      h3 { font-size: 1.25em; }
      code { background: #f6f8fa; padding: 0.2em 0.4em; border-radius: 3px; font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace; }
      pre { background: #f6f8fa; padding: 16px; border-radius: 6px; overflow: auto; }
      pre code { background: transparent; padding: 0; }
      table { border-collapse: collapse; width: 100%; margin: 1em 0; }
      th, td { border: 1px solid #dfe2e5; padding: 6px 13px; }
      th { background: #f6f8fa; font-weight: 600; }
      tr:nth-child(2n) { background: #f6f8fa; }
      blockquote { border-left: 0.25em solid #dfe2e5; color: #6a737d; padding: 0 1em; margin: 0; }
      a { color: #0366d6; text-decoration: none; }
      img { max-width: 100%; }
      hr { border: 0; border-top: 1px solid #e1e4e8; margin: 1.5em 0; }
      ul, ol { padding-left: 2em; }
      li { margin: 0.25em 0; }
    `,
    body_class: 'markdown-body'
  },
  latex: {
    css: `
      body { font-family: "Computer Modern", Georgia, serif; line-height: 1.6; font-size: 11pt; }
      h1, h2, h3 { font-family: "Computer Modern", Georgia, serif; }
      h1 { font-size: 1.8em; border-bottom: 2px solid #333; }
      h2 { font-size: 1.5em; border-bottom: 1px solid #666; }
      code { font-family: "Courier New", monospace; background: #f4f4f4; padding: 0.2em 0.4em; }
      pre { background: #f4f4f4; padding: 1em; border-left: 3px solid #333; }
      table { border-collapse: collapse; margin: 1em 0; }
      th, td { border: 1px solid #333; padding: 0.5em; }
      th { background: #e0e0e0; }
    `,
    pdf_options: {
      format: 'A4',
      margin: { top: '2.5cm', right: '2.5cm', bottom: '2.5cm', left: '2.5cm' }
    }
  }
};

/**
 * Convert single Markdown file to PDF
 * @param {Object} options - Conversion options
 * @returns {Promise<Object>} Result with outputFile path
 */
async function convertToPdf(options) {
  const { inputFile, outputFile, theme = 'default', header, footer } = options;
  
  // Validate input file
  try {
    await fs.access(inputFile);
  } catch {
    throw new Error(`Input file not found: ${inputFile}`);
  }
  
  // Determine output file
  const finalOutputFile = outputFile || inputFile.replace(/\.md$/i, '.pdf');
  
  // Build options
  const pdfOptions = {
    dest: finalOutputFile,
    launch_options: {
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    },
    ...themes[theme] || themes.default
  };
  
  // Add header/footer if provided
  if (header || footer) {
    pdfOptions.pdf_options = {
      ...pdfOptions.pdf_options,
      displayHeaderFooter: true,
      headerTemplate: header ? `<div style="font-size: 9px; margin-left: 20px;">${header}</div>` : '',
      footerTemplate: footer ? `<div style="font-size: 9px; margin: 0 auto;">${footer}</div>` : ''
    };
  }
  
  // Convert
  await mdToPdf({ path: inputFile }, pdfOptions);
  
  return {
    inputFile,
    outputFile: finalOutputFile,
    theme
  };
}

/**
 * Convert multiple Markdown files in batch
 * @param {Object} options - Batch options
 * @returns {Promise<Object>} Results with converted and failed arrays
 */
async function convertBatch(options) {
  const { inputDir, outputDir, pattern = '*.md' } = options;
  
  // Ensure output directory exists
  try {
    await fs.mkdir(outputDir, { recursive: true });
  } catch (error) {
    throw new Error(`Cannot create output directory: ${error.message}`);
  }
  
  // Find files
  const files = await new Promise((resolve, reject) => {
    glob(path.join(inputDir, pattern), (err, matches) => {
      if (err) reject(err);
      else resolve(matches);
    });
  });
  
  if (files.length === 0) {
    throw new Error(`No files found matching pattern: ${pattern}`);
  }
  
  // Convert each file
  const converted = [];
  const failed = [];
  
  for (const file of files) {
    try {
      const basename = path.basename(file, '.md');
      const outputFile = path.join(outputDir, `${basename}.pdf`);
      
      await convertToPdf({
        inputFile: file,
        outputFile
      });
      
      converted.push({ input: file, output: outputFile });
    } catch (error) {
      failed.push({ input: file, error: error.message });
    }
  }
  
  return { converted, failed };
}

module.exports = {
  convertToPdf,
  convertBatch
};
