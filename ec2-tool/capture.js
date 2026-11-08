/**
 * capture.js — Takes real screenshots of the EC2 Deployment Tool
 * for embedding in the Unit 3 PDF report.
 */

const puppeteer = require('puppeteer');
const path = require('path');
const fs   = require('fs');

const BASE    = 'http://localhost:4000';
const OUT_DIR = path.join(__dirname, 'screenshots');
if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });

const W = 1280, H = 900;

async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function shot(page, name, note = '') {
  const file = path.join(OUT_DIR, `${name}.png`);
  await page.screenshot({ path: file, fullPage: false });
  console.log(`  [screenshot] ${name}.png${note ? '  — ' + note : ''}`);
  return file;
}

(async () => {
  console.log('\n  CSA Unit 3 — Screenshot Capture\n');

  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--window-size=1280,900'],
    defaultViewport: { width: W, height: H },
  });

  const page = await browser.newPage();
  await page.setViewport({ width: W, height: H });

  // ── 1. Deploy tab (idle/initial) ─────────────────────────────────────────
  await page.goto(BASE, { waitUntil: 'networkidle0' });
  await sleep(600);
  await shot(page, '01_deploy_tab_initial', 'Deploy tab before deployment');

  // ── 2. Click deploy ──────────────────────────────────────────────────────
  await page.click('#deploy-btn');
  await sleep(800);
  await shot(page, '02_deploy_in_progress', 'Deployment running — steps appearing');

  // Wait for some steps to complete
  await sleep(3500);
  await shot(page, '03_deploy_mid_progress', 'Mid-deployment — several steps done');

  // Wait for full deployment to complete
  await page.waitForFunction(
    () => document.getElementById('state-pill')?.textContent === 'RUNNING',
    { timeout: 20000 }
  );
  await sleep(800);
  await shot(page, '04_deploy_complete', 'Deployment complete — all 11 steps done');

  // ── 3. Instance tab ──────────────────────────────────────────────────────
  await page.click('#nb-instance');
  await sleep(800);
  await shot(page, '05_instance_tab', 'EC2 Instance details — running state');

  // ── 4. Security Groups tab ───────────────────────────────────────────────
  await page.click('#nb-sg');
  await sleep(600);
  await shot(page, '06_security_groups', 'Security Group rules — SSH IP-locked, HTTP public');

  // ── 5. Nginx tab ─────────────────────────────────────────────────────────
  await page.click('#nb-nginx');
  await sleep(600);
  await shot(page, '07_nginx_status', 'Nginx status — active, security headers');

  // ── 6. Web App tab ───────────────────────────────────────────────────────
  await page.click('#nb-webapp');
  await sleep(600);
  await shot(page, '08_webapp_preview', 'Web application preview — live in browser');

  // ── 7. Verify tab ────────────────────────────────────────────────────────
  await page.click('#nb-verify');
  await sleep(600);
  await shot(page, '09_verification', 'Verification checklist — all 6 requirements pass');

  // ── 8. Back to deploy — show full step list ──────────────────────────────
  await page.click('#nb-deploy');
  await sleep(400);
  // Scroll down to show the full step list
  await page.evaluate(() => window.scrollTo(0, 500));
  await sleep(300);
  await shot(page, '10_deploy_steps_full', 'All 11 deployment steps completed');

  await browser.close();

  console.log('\n  All screenshots saved to ec2-tool/screenshots/');
  console.log('  Files:');
  fs.readdirSync(OUT_DIR).filter(f => f.endsWith('.png')).forEach(f => {
    const size = (fs.statSync(path.join(OUT_DIR, f)).size / 1024).toFixed(1);
    console.log(`    ${f}  (${size} KB)`);
  });
  console.log('');
})();
