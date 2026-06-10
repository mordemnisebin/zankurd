import { mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const targetUrl = process.env.ZANKURD_URL ?? 'http://127.0.0.1:8093';
const outDir = process.env.ZANKURD_SCREENSHOT_DIR ?? '../../reports';

const screenshotDir = new URL(`${outDir}/`, import.meta.url);
const loginScreenshotPath = fileURLToPath(
  new URL('playwright-login.png', screenshotDir),
);
const homeScreenshotPath = fileURLToPath(
  new URL('playwright-home.png', screenshotDir),
);

await mkdir(screenshotDir, { recursive: true });

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
const consoleMessages = [];
const pageErrors = [];

page.on('console', (message) => {
  if (['error', 'warning'].includes(message.type())) {
    consoleMessages.push(`[${message.type()}] ${message.text()}`);
  }
});
page.on('pageerror', (error) => pageErrors.push(error.message));

await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
await page.waitForFunction(
  () => document.querySelectorAll('flutter-view').length > 0,
  { timeout: 30000 },
);
await page.waitForTimeout(2500);
await page.screenshot({
  path: loginScreenshotPath,
  fullPage: true,
});

// Flutter web paints most text on canvas, so text selectors are unreliable.
// This coordinate targets the guest sign-in button on the fixed smoke viewport.
await page.mouse.click(195, 632);
await page.waitForTimeout(3500);
await page.screenshot({
  path: homeScreenshotPath,
  fullPage: true,
});

await browser.close();

if (pageErrors.length > 0) {
  console.error(pageErrors.join('\n'));
  process.exit(1);
}

const seriousConsoleMessages = consoleMessages.filter(
  (message) =>
    !message.includes('Supabase init completed') &&
    !message.includes('WebGL: CONTEXT_LOST_WEBGL') &&
    !message.includes('GL Driver Message') &&
    !message.includes('GPU stall due to ReadPixels'),
);
if (seriousConsoleMessages.length > 0) {
  console.error(seriousConsoleMessages.join('\n'));
  process.exit(1);
}

console.log(`Playwright smoke passed: ${targetUrl}`);
