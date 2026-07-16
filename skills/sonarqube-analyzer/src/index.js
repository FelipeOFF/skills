/**
 * SonarQube Analyzer - Main Entry Point
 * OpenClaw skill for automated code quality analysis
 */

const api = require('./api');
const rules = require('./rules');
const analyzer = require('./analyzer');
const reporter = require('./reporter');

/**
 * Register plugin with OpenClaw
 * @param {Object} context - OpenClaw plugin context
 */
function register(context) {
  // Plugin auto-registers via openclaw.plugin.json
  // Tools are discovered from the manifest
  console.log('[sonarqube-analyzer] Plugin registered');
}

/**
 * Activate plugin
 * @param {Object} config - Plugin configuration
 */
function activate(config) {
  try {
    console.log('[sonarqube-analyzer] Plugin activated');
  } catch (error) {
    console.error('[sonarqube-analyzer] Error during activate:', error.message);
  }
}

// Export all modules
module.exports = {
  // Plugin lifecycle
  register,
  activate,
  
  // API client
  ...api,
  
  // Rule definitions
  ...rules,
  
  // Analysis engine
  ...analyzer,
  
  // Report generators
  ...reporter
};