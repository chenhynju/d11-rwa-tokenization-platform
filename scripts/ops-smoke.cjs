// Drive the operations console through a full issuance/transfer/redemption lifecycle
// against a disposable Anvil chain and verify receipts plus the final ledger.
// Usage: node scripts/ops-smoke.cjs <token> <approval> <ids>
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

function expect(condition, message) {
  if (!condition) throw Error('ops-smoke: ' + message);
}

async function main() {
  const [token, approval, ids] = process.argv.slice(2);
  const browser = await chromium.launch({ executablePath: process.env.CHROME_EXECUTABLE, headless: true });
  try {
    const page = await browser.newPage();
    // Redirect the console's RPC to the isolated disposable chain.
    await page.route('http://127.0.0.1:8545/**', async route => {
      const response = await route.fetch({ url: 'http://127.0.0.1:18673/' });
      await route.fulfill({ response });
    });
    await page.goto('http://127.0.0.1:18731/');

    const log = () => page.getByRole('log').innerText();
    const status = async () => JSON.parse(await page.getByRole('status').innerText());
    const click = name => page.getByRole('button', { name }).click();
    const waitLog = fragment => page.waitForFunction(
      f => document.querySelector('[role=log]')?.textContent.includes(f), fragment, { timeout: 15000 });
    const select = async account => {
      await page.locator('select').selectOption({ label: account });
    };
    const fill = (label, value) => page.getByLabel(label).fill(value);

    await click('Connect local chain');
    await page.waitForFunction(() => document.querySelectorAll('select option').length > 0);
    const accounts = await page.locator('select option').allInnerTexts();
    const [issuer, reviewer, holder, holder2] = accounts;
    console.log('accounts issuer=' + issuer + ' reviewer=' + reviewer + ' holder=' + holder + ' holder2=' + holder2);

    await fill('Token address', token);
    await fill('Approval address', approval);
    await fill('Identity registry', ids);
    await fill('Investor / holder', holder);

    // 1. Issuer attests both holders.
    await select(issuer);
    await fill('Reference label', 'ops-identity');
    await click('Attest identity (issuer)');
    await waitLog('attest');
    // Attest second holder with the same identity claim fields.
    await fill('Investor / holder', holder2);
    await click('Attest identity (issuer)');
    await waitLog('attest ' + holder2.toLowerCase());
    await fill('Investor / holder', holder);

    // 2. Two-party issuance of 400 units to holder.
    await fill('Reference label', 'ops-issue');
    await fill('Units', '400');
    await click('Propose issuance (issuer)');
    await waitLog('propose');
    // Negative: issuer must not self-execute.
    await click('Execute issuance (reviewer)');
    await waitLog('ERROR');
    await select(reviewer);
    await click('Execute issuance (reviewer)');
    await waitLog('execute issuance tx=');
    let snap = await readback(page, fill, click, status, holder);
    expect(snap.balance === '400' && snap.supply === '400', 'after issuance ' + JSON.stringify(snap));

    // 3. Holder transfers 150 to holder2.
    await select(holder);
    await fill('Transfer recipient', holder2);
    await fill('Transfer amount', '150');
    await click('Transfer (holder)');
    await waitLog('transfer 150');
    snap = await readback(page, fill, click, status, holder);
    expect(snap.balance === '250', 'holder after transfer ' + JSON.stringify(snap));
    const snap2 = await readback(page, fill, click, status, holder2);
    expect(snap2.balance === '150', 'holder2 after transfer ' + JSON.stringify(snap2));

    // 4. Holder requests redemption of 200 units; reserved must block overspend.
    await fill('Reference label', 'ops-redeem');
    await fill('Units', '200');
    await click('Request redemption (holder)');
    await waitLog('request redemption');
    snap = await readback(page, fill, click, status, holder);
    expect(snap.reserved === '200' && snap.balance === '250', 'reserved ' + JSON.stringify(snap));
    // Negative: transfer of 100 (free is only 50) must revert in the UI.
    await fill('Transfer amount', '100');
    await click('Transfer (holder)');
    await waitLog('ERROR');
    const before = await log();
    expect(!/transfer 100 to .* tx=/.test(before), 'reserved units were spent');

    // 5. Issuer approves; reviewer settles with the synthetic receipt (minorAmount = units*100).
    await select(issuer);
    await click('Approve redemption (issuer)');
    await waitLog('approve redemption');
    await fill('Simulated payment id', 'ops-payment-001');
    await select(reviewer);
    await click('Settle with synthetic receipt (reviewer)');
    await waitLog('settle 200');
    snap = await readback(page, fill, click, status, holder);
    expect(snap.reserved === '0' && snap.balance === '50' && snap.supply === '200',
      'after settlement ' + JSON.stringify(snap));

    // 6. Replay: the same settlement must revert onchain.
    await click('Settle with synthetic receipt (reviewer)');
    await waitLog('ERROR');
    snap = await readback(page, fill, click, status, holder);
    expect(snap.supply === '200' && snap.balance === '50', 'replay changed ledger ' + JSON.stringify(snap));

    const finalLog = await log();
    const hashes = [...finalLog.matchAll(/tx=(0x[0-9a-f]+)/g)].map(m => m[1]);
    expect(hashes.length >= 7, 'expected at least 7 confirmed transactions, got ' + hashes.length);
    console.log(JSON.stringify({ supply: snap.supply, holder: snap.balance, transactions: hashes }));
    console.log('PASS browser operations: dual issuance, transfer, reservation lock, settlement, replay rejection');
  } finally {
    await browser.close();
  }
}

async function readback(page, fill, click, status, holder) {
  await fill('Investor / holder', holder);
  await click('Inspect holder');
  // The console clears the panel before fetching; wait for the clear, then the fresh JSON.
  await page.waitForFunction(() => {
    const t = document.querySelector('[role=status]')?.textContent || '';
    return t === '' || t === 'No readback yet.';
  }, undefined, { timeout: 15000 });
  await page.waitForFunction(
    () => (document.querySelector('[role=status]')?.textContent || '').includes('"balance"'),
    undefined, { timeout: 15000 });
  return status();
}

main().catch(e => { console.error(e); process.exitCode = 1; });
