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

async function shotAfter(page, action, name) {
  await action();
  await waitAndShot(page, name);
  return `${name}.png`;
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

  try {
    report.screens.push(
      await shotAfter(page, () => page.mouse.click(317, 100), '02-after-skip'),
    );

    report.screens.push(
      await shotAfter(page, () => page.mouse.wheel(0, 560), '03-auth-scrolled'),
    );

    report.screens.push(
      await shotAfter(page, () => page.mouse.click(195, 675), '04-after-guest-tap'),
    );

    report.screens.push(
      await shotAfter(
        page,
        async () => {
          await page.mouse.click(150, 349);
          await page.waitForTimeout(250);
          await page.keyboard.insertText('Codex Denetim');
        },
        '05-after-profile-name-field',
      ),
    );

    report.screens.push(
      await shotAfter(page, () => page.mouse.click(195, 416), '06-after-profile-submit'),
    );

    report.screens.push(
      await shotAfter(page, () => page.mouse.wheel(0, 620), '07-after-scroll-home'),
    );

    report.screens.push(
      await shotAfter(page, () => page.mouse.click(284, 320), '08-after-join-tap'),
    );

    report.screens.push(
      await shotAfter(page, () => page.keyboard.press('Escape'), '08-after-escape'),
    );

    report.screens.push(
      await shotAfter(page, () => page.mouse.click(104, 276), '09-after-create-room'),
    );
  } catch (error) {
    report.observations.push({ step: 'main-flow', error: error.message });
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
