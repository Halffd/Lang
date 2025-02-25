const { build } = require('vite');
const { resolve } = require('path');

async function buildApp() {
  try {
    await build({
      configFile: resolve(__dirname, 'vite.config.ts'),
      root: __dirname,
      build: {
        outDir: '../../dist/apps/web',
        emptyOutDir: true,
      },
    });
    console.log('Build completed successfully!');
  } catch (error) {
    console.error('Build failed:', error);
    process.exit(1);
  }
}

buildApp(); 