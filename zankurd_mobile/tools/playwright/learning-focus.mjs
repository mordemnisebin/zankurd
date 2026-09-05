import assert from 'node:assert/strict';
import {mkdir, writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';
import {chromium} from 'playwright';

// Local debug build with the bundled offline repository.
const output=fileURLToPath(new URL('../../docs/audit/learning_focus_2026-09-05/',import.meta.url));
await mkdir(output,{recursive:true});
const browser=await chromium.launch({channel:'chrome',headless:true});
const page=await browser.newPage({viewport:{width:390,height:844}});
const errors=[];
const screenshots=[];
page.on('pageerror',e=>errors.push(e.message));
page.on('console',m=>{if(/RenderFlex overflowed|ErrorWidget render exception/.test(m.text()))errors.push(m.text());});
const body=()=>page.locator('body').innerText();
const click=name=>page.getByRole('button',{name,exact:true}).click();
const shot=async name=>{
 await page.waitForTimeout(350);
 await page.screenshot({path:join(output,`after-${name}.png`)});
 screenshots.push(`after-${name}.png`);
};
try {
 await page.goto(process.env.ZANKURD_URL??'http://127.0.0.1:8876');
 await page.getByText('Kurmancî hîn bibe, pêş bikeve.',{exact:true}).waitFor();
 await shot('onboarding');
 await click('Dest pê bike');
 await page.getByRole('textbox').click();
 await page.getByRole('textbox').pressSequentially('Rojda',{delay:80});
 await page.waitForTimeout(400);
 await click('Dest pê bike');
 await page.getByText('DESTPÊKA BIÇÛK',{exact:true}).waitFor();
 assert(!(await body()).includes('Erkên Rojane'),'New user should see a focused home');
 await shot('home');
 await click('Moda tarî/ronahî');await shot('home-ku-dark');
 await page.setViewportSize({width:320,height:568});await shot('home-ku-dark-narrow');
 await click('Ziman');await shot('home-tr-dark-narrow');
 await page.setViewportSize({width:1280,height:900});await shot('home-tr-dark-wide');
 await click('Karanlık/Aydınlık mod');await shot('home-tr-light-wide');
 await page.setViewportSize({width:390,height:844});
 await click('Dil');
 await click('Dest pê bike');
 await page.getByRole('button',{name:/^A: /}).waitFor();
 const skip=page.getByRole('button',{name:'Derbas bike',exact:true});
 if(await skip.count())await skip.click();
 for(let i=0;i<5;i++) {
  await page.getByRole('button',{name:/^A: /}).click();
  await page.waitForTimeout(400);
  if(i===0) {
   const explanation=page.getByRole('button',{name:/^(Açıklamayı gör|Şîrove bibîne)$/});
   if(await explanation.count()) {
    await explanation.click();
    await page.getByText(/(Açıklama|Şîrove)/).last().waitFor();
    await page.keyboard.press('Escape');
   }
  }
  await click(i===4?'Biqedîne':'Bidomîne');
  await page.waitForTimeout(700);
 }
 await page.getByText('Fêrbûn temam bû',{exact:true}).waitFor();
 await shot('result');
 const resultText=(await body())+' '+(await page.locator('[aria-label]').evaluateAll(es=>es.map(e=>e.getAttribute('aria-label')).join(' ')));
 assert(resultText.includes('5 bersiv'),'Result should summarize all five answers');
 await page.mouse.move(190,630);await page.mouse.wheel(0,500);await shot('result-summary');
 await click('Vegere');
 await page.getByText('ERKÊ ÎRO',{exact:true}).waitFor();
 assert((await body()).includes('Erkên Rojane'),'Support cards should return after completion');
 await shot('completed-home');
 assert.deepEqual(errors,[]);
 const result={checkedAt:new Date().toISOString(),mode:'local debug, offline repository',journey:'onboarding → first 5 questions → result → refreshed home',screenshots,errors};
 await writeFile(join(output,'validation/browser.json'),JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify(result));
} catch(error) {
 await shot('failure');
 console.error(await body());
 throw error;
} finally {await browser.close();}
