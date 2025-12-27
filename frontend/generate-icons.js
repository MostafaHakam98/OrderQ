/**
 * Script to generate PWA icons from SVG logo
 * 
 * This script requires sharp to be installed:
 * npm install -D sharp
 * 
 * Run: node generate-icons.js
 */

import sharp from 'sharp';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const sizes = [
  { size: 192, name: 'icon-192x192.png' },
  { size: 512, name: 'icon-512x512.png' },
  { size: 180, name: 'apple-touch-icon.png' }
];

const logoPath = path.join(__dirname, 'public', 'logo.svg');
const outputDir = path.join(__dirname, 'public');

async function generateIcons() {
  try {
    // Check if logo exists
    if (!fs.existsSync(logoPath)) {
      console.error('Logo file not found at:', logoPath);
      console.log('Creating a simple colored icon instead...');
      
      // Create a simple blue icon with "OQ" text
      for (const { size, name } of sizes) {
        const svg = `
          <svg width="${size}" height="${size}" xmlns="http://www.w3.org/2000/svg">
            <rect width="${size}" height="${size}" fill="#2563eb"/>
            <text x="50%" y="50%" font-family="Arial, sans-serif" font-size="${size * 0.4}" 
                  font-weight="bold" fill="white" text-anchor="middle" dominant-baseline="middle">OQ</text>
          </svg>
        `;
        
        await sharp(Buffer.from(svg))
          .png()
          .toFile(path.join(outputDir, name));
        
        console.log(`✓ Generated ${name}`);
      }
      return;
    }

    // Generate icons from logo
    for (const { size, name } of sizes) {
      await sharp(logoPath)
        .resize(size, size, {
          fit: 'contain',
          background: { r: 255, g: 255, b: 255, alpha: 1 }
        })
        .png()
        .toFile(path.join(outputDir, name));
      
      console.log(`✓ Generated ${name}`);
    }
    
    console.log('\n✅ All icons generated successfully!');
  } catch (error) {
    console.error('Error generating icons:', error.message);
    if (error.message.includes('sharp')) {
      console.log('\n💡 Install sharp first: npm install -D sharp');
    }
    process.exit(1);
  }
}

generateIcons();

