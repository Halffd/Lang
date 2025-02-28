const { build } = require('vite');
const { resolve } = require('path');
const fs = require('fs-extra');

async function buildApp() {
  try {
    // Ensure the dist directory exists
    const distDir = resolve(__dirname, '../../dist/apps/web');
    await fs.ensureDir(distDir);

    // Clean the dist directory
    await fs.emptyDir(distDir);

    // Copy public assets
    await fs.copy(
      resolve(__dirname, 'public'),
      resolve(distDir, 'public'),
      { overwrite: true }
    );

    // Build the app
    await build({
      root: __dirname,
      configFile: resolve(__dirname, 'vite.config.ts'),
      mode: 'production',
    });

    console.log('Build completed successfully!');
  } catch (error) {
    console.error('Build failed:', error);
    process.exit(1);
  }
}

buildApp(); 