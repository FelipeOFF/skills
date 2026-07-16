/**
 * OpenClaw Markdown to PDF Plugin
 * Main entry point for OpenClaw integration
 */

const { convertToPdf, convertBatch } = require('./converter');

/**
 * Register plugin with OpenClaw
 * @param {Object} context - OpenClaw plugin context
 */
function register(context) {
  // Plugin auto-registers via openclaw.plugin.json
  // Tools are discovered from the manifest
  console.log('[openclaw-md-to-pdf] Plugin registered');
}

/**
 * Activate plugin
 * @param {Object} config - Plugin configuration
 */
function activate(config) {
  try {
    console.log('[openclaw-md-to-pdf] Plugin activated');
  } catch (error) {
    console.error('[openclaw-md-to-pdf] Error during activate:', error.message);
  }
}

/**
 * Convert single Markdown file to PDF
 * @param {Object} params - Conversion parameters
 * @param {string} params.inputFile - Path to input Markdown file
 * @param {string} [params.outputFile] - Path for output PDF
 * @param {string} [params.theme='default'] - Theme name
 * @param {string} [params.header] - Header text
 * @param {string} [params.footer] - Footer text
 * @returns {Promise<Object>} Conversion result
 */
async function md_to_pdf_convert(params) {
  const { inputFile, outputFile, theme = 'default', header, footer } = params;
  
  try {
    const result = await convertToPdf({
      inputFile,
      outputFile,
      theme,
      header,
      footer
    });
    
    return {
      success: true,
      inputFile,
      outputFile: result.outputFile,
      message: `Successfully converted ${inputFile} to PDF`
    };
  } catch (error) {
    return {
      success: false,
      inputFile,
      error: error.message
    };
  }
}

/**
 * Convert multiple Markdown files in batch
 * @param {Object} params - Batch conversion parameters
 * @param {string} params.inputDir - Input directory
 * @param {string} params.outputDir - Output directory
 * @param {string} [params.pattern='*.md'] - File pattern
 * @returns {Promise<Object>} Batch conversion result
 */
async function md_to_pdf_batch(params) {
  const { inputDir, outputDir, pattern = '*.md' } = params;
  
  try {
    const result = await convertBatch({
      inputDir,
      outputDir,
      pattern
    });
    
    return {
      success: true,
      converted: result.converted,
      failed: result.failed,
      message: `Converted ${result.converted.length} files, ${result.failed.length} failed`
    };
  } catch (error) {
    return {
      success: false,
      error: error.message
    };
  }
}

module.exports = {
  register,
  activate,
  md_to_pdf_convert,
  md_to_pdf_batch
};
