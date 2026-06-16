import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { createReadStream, existsSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const root = path.resolve('build/web');
const outDir = path.resolve('.tmp/audit');
mkdirSync(outDir, { recursive: true });

const mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
};

const server = createServer(async (req, res) => {
  const urlPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  const clean = urlPath === '/' ? '/index.html' : urlPath;
  let filePath = path.join(root, clean);
  if (!filePath.startsWith(root) || !existsSync(filePath)) {
    filePath = path.join(root, 'index.html');
  }
  res.setHeader('Content-Type', mime[path.extname(filePath)] ?? 'application/octet-stream');
  createReadStream(filePath).pipe(res);
});

function listen(port) {
  return new Promise((resolve) => server.listen(port, '127.0.0.1', resolve));
}

async function waitAndShot(page, name) {
  await page.waitForTimeout(1200);
  await page.screenshot({ path: path.join(outDir, `${name}.png`), fullPage: true });
}

async function tapText(page, text, options = {}) {
  const locator = page.getByText(text, { exact: options.exact ?? true }).first();
  await locator.waitFor({ timeout: options.timeout ?? 7000 });
  await locator.click();
}

async function main() {
  const port = 5139;
  await listen(port);
  const browser = await chromium.launch({
    headless: true,
    executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
  });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 });
  const consoleMessages = [];
  page.on('console', (msg) => consoleMessages.push(`${msg.type()}: ${msg.text()}`));
  page.on('pageerror', (error) => consoleMessages.push(`pageerror: ${error.message}`));

  const report = {
    url: `http://127.0.0.1:${port}`,
    screens: [],
    observations: [],
    consoleMessages,
  };

  await page.goto(report.url, { waitUntil: 'networkidle' });
  await waitAndShot(page, '01-first-load');
  report.screens.push('01-first-load.png');

  const coordinateSteps = [
    { name: '02-after-skip', x: 317, y: 100 },
    { name: '03-auth-scrolled', wheel: 520 },
    { name: '04-after-guest-tap', x: 195, y: 735 },
    { name: '05-after-profile-name-field', x: 195, y: 505, text: 'Codex Denetim' },
    { name: '06-after-profile-submit', x: 195, y: 570 },
    { name: '07-after-scroll-home', wheel: 620 },
    { name: '08-after-join-tap', x: 284, y: 430 },
    { name: '08-after-escape', key: 'Escape' },
    { name: '09-after-create-room', x: 104, y: 430 },
  ];

  for (const step of coordinateSteps) {
    try {
      if (step.wheel) {
        await page.mouse.wheel(0, step.wheel);
      } else if (step.key) {
        await page.keyboard.press(step.key);
      } else {
        await page.mouse.click(step.x, step.y);
        if (step.text) await page.keyboard.type(step.text);
      }
      await waitAndShot(page, step.name);
      report.screens.push(`${step.name}.png`);
    } catch (error) {
      report.observations.push({ step: step.name, error: error.message });
    }
  }

  try {
    await page.setViewportSize({ width: 844, height: 390 });
    await waitAndShot(page, '10-landscape-current');
    report.screens.push('10-landscape-current.png');
  } catch (error) {
    report.observations.push({ step: 'landscape', error: error.message });
  }

  await readFile(path.join(outDir, 'noop')).catch(() => undefined);
  console.log(JSON.stringify(report, null, 2));
  await browser.close();
  server.close();
}

main().catch((error) => {
  console.error(error);
  server.close();
  process.exit(1);
});
