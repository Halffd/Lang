#!/usr/bin/env node

const { build } = require('esbuild');
const { copy } = require('fs-extra');
const { resolve, join } = require('path');

const srcDir = __dirname;
const outDir = resolve(__dirname, '../../dist/apps/web');

async function buildApp() {
  try {
    console.log('Building web app...');
    
    // Build the JavaScript bundle
    await build({
      entryPoints: [join(srcDir, 'src/main.tsx')],
      bundle: true,
      minify: true,
      sourcemap: true,
      outfile: join(outDir, 'assets/index.js'),
      loader: {
        '.tsx': 'tsx',
        '.ts': 'ts',
        '.jsx': 'jsx',
        '.js': 'js',
        '.css': 'css',
        '.svg': 'file',
        '.png': 'file',
        '.jpg': 'file',
      },
      define: {
        'process.env.NODE_ENV': '"production"',
      },
      platform: 'browser',
      target: ['es2020', 'chrome80', 'firefox80', 'safari13'],
      external: ['react-native'],
      jsx: 'automatic',
    });
    
    // Copy static files
    await copy(join(srcDir, 'public'), outDir, { overwrite: true });
    await copy(join(srcDir, 'index.html'), join(outDir, 'index.html'), { overwrite: true });
    
    // Update the script path in index.html
    const fs = require('fs');
    const indexPath = join(outDir, 'index.html');
    let indexContent = fs.readFileSync(indexPath, 'utf8');
    indexContent = indexContent.replace(
      /<script type="module" src="\.\/src\/main\.tsx"><\/script>/,
      '<script type="module" src="./assets/index.js"></script>'
    );
    fs.writeFileSync(indexPath, indexContent);
    
    console.log('Build completed successfully!');
  } catch (error) {
    console.error('Build failed:', error);
    process.exit(1);
  }
}

buildApp(); 