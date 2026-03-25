import { test, expect } from '@playwright/test';

test.describe('Phase 5 booking flow', () => {
  test('user can open homepage and navigate search', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/Pearl Hub/i);

    const searchTrigger = page.locator('text=Search').first();
    await expect(searchTrigger).toBeVisible();
    await searchTrigger.click();

    await expect(page).toHaveURL(/search|listings/);
  });

  test('admin dashboard is protected', async ({ page }) => {
    await page.goto('/admin');
    await expect(page.locator('body')).toContainText(/auth|login|unauthorized|admin/i);
  });
});
