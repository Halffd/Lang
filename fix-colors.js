const fs = require('fs');
const path = require('path');

const colorFilePath = path.resolve('./app/api/node_modules/@colors/colors/index.d.ts');

try {
  // Read the current file
  console.log(`Attempting to fix: ${colorFilePath}`);
  const original = fs.readFileSync(colorFilePath, 'utf8');
  
  // Create backup
  fs.writeFileSync(`${colorFilePath}.bak`, original, 'utf8');
  console.log(`Created backup at: ${colorFilePath}.bak`);

  // Replace all instances of declarations without initializers
  const fixed = original
    .replace(/export const ([a-zA-Z]+): Color;/g, 
             'export const $1: Color = function(text: string): string { return text; };');
  
  console.log('Fixed content:');
  console.log(fixed);
  
  // Write the file
  fs.writeFileSync(colorFilePath, fixed, 'utf8');
  console.log(`Successfully wrote fixed file to: ${colorFilePath}`);
} catch (err) {
  console.error('Error while fixing colors file:', err);
} 