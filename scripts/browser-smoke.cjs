const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
async function main() {
  const [token, holder] = process.argv.slice(2);
  const browser = await chromium.launch({executablePath: process.env.CHROME_EXECUTABLE, headless:true});
  try {
    const page = await browser.newPage();
    // Isolate the disposable chain from other local projects using port 8545.
    await page.route('http://127.0.0.1:8545/**', async route => {
      const response = await route.fetch({ url: 'http://127.0.0.1:18673/' });
      await route.fulfill({response});
    });
    await page.goto('http://127.0.0.1:18731/');
    await page.getByLabel('Token address').fill(token);
    await page.getByLabel('Holder address').fill(holder);
    await page.getByRole('button',{name:'Inspect holder'}).click();
    await page.waitForFunction(()=>document.querySelector('[role=status]')?.textContent.includes('"balance"'));
    const record=JSON.parse(await page.getByRole('status').innerText());
    if(record.balance!=='100'||record.supply!=='100'||record.cap!=='10000'||record.frozen!==false) throw Error(JSON.stringify(record));
    console.log(JSON.stringify(record));
  } finally {await browser.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1});
