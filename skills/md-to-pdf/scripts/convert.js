#!/usr/bin/env node

/**
 * CLI Script for Markdown to PDF Conversion
 * Can be used standalone or via OpenClaw
 */

const { program } = require('commander');
const { convertToPdf } = require('../src/converter');
const path = require('path');

program
  .name('openclaw-md-to-pdf')
  .description('Convert Markdown files to PDF')
  .version('1.0.0');

program
  .argument('<input>', 'Input Markdown file or directory')
  .option('-o, --output <file>', 'Output PDF file path')
  .option('-t, --theme <name>', 'Theme (default, github, latex)', 'default')
  .option('-h, --header <text>', 'Header text for all pages')
  .option('-f, --footer <text>', 'Footer text for all pages')
  .action(async (input, options) => {
    try {
      console.log(`📝 Converting ${input} to PDF...`);
      
      const result = await convertToPdf({
        inputFile: path.resolve(input),
        outputFile: options.output ? path.resolve(options.output) : undefined,
        theme: options.theme,
        header: options.header,
        footer: options.footer
      });
      
      console.log(`✅ Success! PDF saved to: ${result.outputFile}`);
      process.exit(0);
    } catch (error) {
      console.error(`❌ Error: ${error.message}`);
      process.exit(1);
    }
  });

program.parse();
