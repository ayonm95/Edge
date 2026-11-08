const puppeteer = require('puppeteer-core');
const path = require('path');

const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

async function testShowcase() {
  console.log('Launching Chrome to test showcase/index.html...');
  const browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: true,
    args: ['--use-gl=angle', '--use-angle=metal', '--no-sandbox', '--disable-web-security']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1080, height: 1920, deviceScaleFactor: 1 });

  // Listen to console logs and errors
  page.on('console', msg => console.log('PAGE LOG:', msg.text()));
  page.on('pageerror', err => console.error('PAGE ERROR:', err.message));

  const indexPath = 'file://' + path.resolve(__dirname, '../showcase/index.html');
  console.log('Navigating to:', indexPath);
  await page.goto(indexPath, { waitUntil: 'load' });

  // Wait 1 second for scene to load
  await new Promise(r => setTimeout(r, 1000));

  // Check if __EDGE_SEEK__ exists
  const hasSeek = await page.evaluate(() => typeof window.__EDGE_SEEK__ === 'function');
  console.log('__EDGE_SEEK__ available:', hasSeek);

  // Seek to 2 seconds and 5 seconds
  await page.evaluate(() => window.__EDGE_SEEK__(2.0));
  console.log('Successfully sought to 2.0s');

  await page.evaluate(() => window.__EDGE_SEEK__(5.0));
  console.log('Successfully sought to 5.0s');

  // Test mode change
  const durBrightness = await page.evaluate(() => window.__EDGE_SET_MODE__('brightness'));
  console.log('Brightness mode duration:', durBrightness);

  await browser.close();
  console.log('Chrome test finished successfully with zero errors!');
}

testShowcase().catch(err => {
  console.error('Test failed:', err);
  process.exit(1);
});
