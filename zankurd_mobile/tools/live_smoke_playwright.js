const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const errors = [];
  const warnings = [];
  const failed = [];

  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
    if (msg.type() === 'warning') warnings.push(msg.text());
  });
  page.on('pageerror', (err) => errors.push(err.message));
  page.on('requestfailed', (req) => {
    failed.push(`${req.method()} ${req.url()} ${req.failure()?.errorText}`);
  });

  const response = await page.goto('https://zankurd.com', {
    waitUntil: 'networkidle',
    timeout: 60000,
  });
  await page.waitForTimeout(5000);

  const title = await page.title();
  const hasFlutter = await page.evaluate(
    () => Boolean(document.querySelector('flutter-view')) || Boolean(window._flutter),
  );
  await page.screenshot({
    path: 'output/playwright/live-zankurd-deploy-smoke.png',
    fullPage: true,
  });

  console.log(JSON.stringify({
    status: response && response.status(),
    title,
    hasFlutter,
    errors,
    warnings,
    failed: failed.slice(0, 20),
  }, null, 2));

  await browser.close();
})();
