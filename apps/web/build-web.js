#!/usr/bin/env node

const { execSync } = require('child_process');
const path = require('path');

// Get the root directory of the project
const rootDir = path.resolve(__dirname, '../..');

// Run the build command
try {
  console.log('Building web app...');
  
  // Clean the output directory first
  execSync('rm -rf ../../dist/apps/web', { 
    cwd: __dirname,
    stdio: 'inherit'
  });
  
  // Run the build using nx
  execSync('npx nx build web --skip-nx-cache', {
    cwd: rootDir,
    stdio: 'inherit'
  });
  
  console.log('Build completed successfully!');
} catch (error) {
  console.error('Build failed:', error.message);
  process.exit(1);
} 