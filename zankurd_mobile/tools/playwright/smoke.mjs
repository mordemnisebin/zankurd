import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { chromium } from 'playwright';

const targetUrl = process.env.ZANKURD_URL ?? 'http://127.0.0.1:8093';
const screenshotDir =
  process.env.ZANKURD_SCREENSHOT_DIR ?? '/private/tmp/zankurd-playwright';

await mkdir(screenshotDir, { recursive: true });

// Sistem Chrome'u kullanır; ayrıca Playwright Chromium indirmesi gerekmez.
const browser = await chromium.launch({ channel: 'chrome', headless: true });
const context = await browser.newContext({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
});
const page = await context.newPage();
const consoleMessages = [];
const pageErrors = [];

page.on('console', (message) => {
  if (['error', 'warning'].includes(message.type())) {
    consoleMessages.push(`[${message.type()}] ${message.text()}`);
  }
});
page.on('pageerror', (error) => pageErrors.push(error.message));

const bodyText = () => page.locator('body').innerText();
const screenshot = (name) =>
  page.screenshot({ path: join(screenshotDir, `${name}.png`) });

async function expectText(value) {
  await page.getByText(value, { exact: true }).last().waitFor({
    state: 'visible',
    timeout: 15_000,
  });
}

async function expectContains(value) {
  await page.waitForFunction(
    (needle) => document.body.innerText.includes(needle),
    value,
    { timeout: 15_000 },
  );
}

async function clickText(value) {
  await expectText(value);
  await page.getByText(value, { exact: true }).last().click();
  await page.waitForTimeout(900);
}

await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 30_000 });
await page.waitForFunction(
  () => document.querySelectorAll('flutter-view').length > 0,
  { timeout: 30_000 },
);
await expectText('Kurmancî hîn bibe, pêş bikeve.');
await screenshot('01-onboarding');

await clickText('Bidomîne');
await expectText('Pêşbirkê bike û bi ser keve');
await screenshot('02-onboarding-play');

await clickText('Dest pê bike');
await expectText('Bi xêr hatî ZanKurdê');
await screenshot('03-sign-in');

await clickText('Wek mêvan bidomîne');
await expectText('Navê te di lîstikê de çi be?');
const nameInput = page.getByRole('textbox');
if ((await nameInput.count()) !== 1) {
  throw new Error('Oyuncu adı alanı tek ve erişilebilir değil.');
}
await nameInput.fill('Rojda');
await clickText('Dest Pê Bike');
await expectText('Rojbaş, Rojda!');
await screenshot('04-home');

// Kategori kartı gerçek rotayı açmalı ve yayın dışı kategori sızmamalı.
await clickText('Mijar hilbijêre. Kategoriyekê hilbijêre û dest pê bike');
await expectText('Kategorî');
if ((await bodyText()).includes('Sînema')) {
  throw new Error('Yayın dışı Sînema kategorisi kategori ekranına sızdı.');
}
await screenshot('05-categories');
await page.mouse.click(52, 72);
await page.waitForTimeout(900);
await expectText('Rojbaş, Rojda!');

// Flutter web NavigationBar hedefleri canvas/semantik birleşiminde metin
// seçicisi sunmuyor. Sabit mobil viewport'ta hedefe dokunup açılan ekranın
// içeriğini doğrulamak, yalnız koordinata tıklayıp geçmekten farklı olarak
// yanlış sekmeye gitmeyi yakalar.
await page.mouse.click(145, 808);
await page.waitForTimeout(1_200);
await expectContains('Pêşbirka bilez');
await page.getByText('Pêşbirka bilez', { exact: false }).first().click();
await page.waitForTimeout(900);
await expectContains('Şerê 1vs1');
if ((await bodyText()).includes('Sînema')) {
  throw new Error('Yayın dışı Sînema kategorisi eşleşme girişine sızdı.');
}
await screenshot('06-matchmaking');
await page.mouse.click(20, 28);
await page.waitForTimeout(900);
await expectContains('Pêşbirka bilez');

await page.mouse.click(245, 808);
await page.waitForTimeout(900);
await expectContains('Tabloya Pêşderiyan');
await screenshot('07-leaderboard');

await page.mouse.click(340, 808);
await page.waitForTimeout(900);
await expectContains('Profîl');
await screenshot('08-profile');

// Aynı oturumda geniş düzeni de doğrula; ikinci debug istemcisi gerekmez.
await page.setViewportSize({ width: 1280, height: 900 });
await expectContains('Profîl');
await screenshot('09-desktop-profile');

await browser.close();

if (pageErrors.length > 0) {
  throw new Error(`Sayfa hataları:\n${pageErrors.join('\n')}`);
}

const seriousConsoleMessages = consoleMessages.filter(
  (message) =>
    !message.includes('Supabase init completed') &&
    !message.includes('WebGL: CONTEXT_LOST_WEBGL') &&
    !message.includes('GL Driver Message') &&
    !message.includes('GPU stall due to ReadPixels'),
);
if (seriousConsoleMessages.length > 0) {
  throw new Error(`Konsol hataları:\n${seriousConsoleMessages.join('\n')}`);
}

console.log(`Playwright smoke passed: ${targetUrl}`);
