import { describe, it, expect } from 'jest';
import { chromium } from 'playwright';

describe('App E2E', () => {
  it('renders login page', async () => {
    const browser = await chromium.launch();
    const page = await browser.newPage();
    await page.goto('http://localhost:3000/login');
    await page.fill('[name="email"]', 'admin@test.com');
    await page.fill('[name="password"]', 'admin123');
    await page.click('button[type="submit"]');
    await page.waitForURL('http://localhost:3000/dashboard');
    expect(page.url()).toContain('/dashboard');
    await browser.close();
  });
});
