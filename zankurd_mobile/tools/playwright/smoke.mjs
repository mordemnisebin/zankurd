import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { chromium } from 'playwright';

const targetUrl = process.env.ZANKURD_URL ?? 'http://127.0.0.1:8093';
const expectSocialBackend = process.env.ZANKURD_EXPECT_SOCIAL === '1';
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
// Slogan (onbTagline) kalktı; ilk sayfanın gövde cümlesi (onbLearnBody).
await expectText('Bi pirsên kurt peyvan hîn bibe, çandê nas bike.');
await screenshot('01-onboarding');

const ageGateLabel = 'Ez ji 13 salî mezintir im';
const ageGate = page.getByRole('checkbox', { name: ageGateLabel });
await ageGate.waitFor({ state: 'visible', timeout: 15_000 });
await ageGate.click();
await page.waitForFunction(
  (label) =>
    [...document.querySelectorAll('[role="checkbox"]')].some(
      (node) =>
        node.getAttribute('aria-label') === label &&
        node.getAttribute('aria-checked') === 'true',
    ),
  ageGateLabel,
  { timeout: 15_000 },
);
await clickText('Bidomîne');
await clickText('Dest pê bike');
await expectText('Bi xêr hatî ZanKurdê');
await screenshot('02-sign-in');

await clickText('Wek mêvan bidomîne');
await expectText('Navê te di lîstikê de çi be?');
const nameInput = page.getByRole('textbox');
if ((await nameInput.count()) !== 1) {
  throw new Error('Oyuncu adı alanı tek ve erişilebilir değil.');
}
await nameInput.fill('Rojda');
await clickText('Dest pê bike');
await expectText('Dersa yekem');
await screenshot('03-first-session-home');

// Yeni kullanıcıda önce kısa 5 soruluk başlangıç tamamlanır. Destek kartları
// ancak bundan sonra geri gelir; smoke eski tam ana sayfayı beklememeli.
await clickText('Dest pê bike');
await page.getByRole('button', { name: /^A: / }).waitFor({ timeout: 15_000 });
const tutorialSkip = page.getByRole('button', { name: 'Derbas bike', exact: true });
if (await tutorialSkip.count()) {
  await tutorialSkip.click();
}
for (let i = 0; i < 5; i++) {
  await page.getByRole('button', { name: /^A: / }).click();
  await page.waitForTimeout(400);
  await clickText(i === 4 ? 'Biqedîne' : 'Bidomîne');
  await page.waitForTimeout(700);
}
await expectText('Hînbûn temam bû');
await screenshot('04-first-result');
await clickText('Vegere');
await expectText('Erkê îro');
await screenshot('05-home');

// Konular ana sayfadaki "Mijar" ızgarasındadır (ayrı "Hemû mijar" /
// "Kategorî" ekranı kalktı); yayın dışı konu sızmamalı.
await expectText('Mijar');
await expectContains('Sînema');
await screenshot('06-topics');

// Flutter web NavigationBar hedefleri canvas/semantik birleşiminde metin
// seçicisi sunmuyor. Sabit mobil viewport'ta hedefe dokunup açılan ekranın
// içeriğini doğrulamak, yalnız koordinata tıklayıp geçmekten farklı olarak
// yanlış sekmeye gitmeyi yakalar.
await page.mouse.click(145, 808);
await page.waitForTimeout(1_200);
await expectContains('Pêşbirka bilez');
if (expectSocialBackend) {
  const quickDuel = page.getByRole('button', { name: /Pêşbirka bilez/ });
  await quickDuel.waitFor({ state: 'visible', timeout: 15_000 });
  await quickDuel.click();
  await page.waitForTimeout(900);
  await expectContains('Hevrikiya rasthatî');
  await screenshot('07-matchmaking');
  await page.mouse.click(20, 28);
  await page.waitForTimeout(900);
  await expectContains('Pêşbirka bilez');
} else {
  await expectContains('Pêşkêşkar negihîştbar e');
  const quickDuel = page.getByRole('button', { name: /Pêşbirka bilez/ });
  await quickDuel.waitFor({ state: 'visible', timeout: 15_000 });
  if (await quickDuel.isEnabled()) {
    throw new Error('Çevrimdışı smoke turunda hızlı düello etkin olmamalı.');
  }
  await screenshot('07-play-hub-offline');
}

await page.mouse.click(245, 808);
await page.waitForTimeout(900);
await expectContains('Rêzbendî');
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
