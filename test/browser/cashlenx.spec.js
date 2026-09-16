import { randomBytes } from 'node:crypto';
import { expect, test } from '@playwright/test';

const appUrl = process.env.APP_URL;
const apiUrl = process.env.API_URL;
const adminUsername = process.env.ADMIN_USERNAME;
const adminPassword = process.env.ADMIN_PASSWORD;
const suffix = randomBytes(5).toString('hex');
const testUser = {
  username: `browser_${suffix}`,
  email: `browser_${suffix}@example.test`,
  password: `Qa-${randomBytes(12).toString('hex')}`,
};

let userAccessToken = '';

async function api(path, { method = 'GET', body, token } = {}) {
  const response = await fetch(`${apiUrl}${path}`, {
    method,
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      'x-request-id': `browser-${suffix}`,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${method} ${path} failed with HTTP ${response.status}`);
  }
  return payload;
}

async function loginApi(username, password) {
  const response = await api('/open/auth/login', {
    method: 'POST',
    body: {
      username,
      password,
      device_id: `browser-${suffix}`,
      device_name: 'Browser Acceptance',
    },
  });
  return response.data;
}

async function enableFlutterSemantics(page, timeout = 2_500) {
  const enableButton = page.getByRole('button', {
    name: 'Enable accessibility',
  });
  try {
    await enableButton.waitFor({ state: 'attached', timeout });
  } catch {
    // Semantics remains enabled across ordinary navigation and reloads.
    return;
  }
  const activations = [
    () => enableButton.click({ force: true }),
    async () => {
      await enableButton.focus();
      await enableButton.press('Enter');
    },
    () => enableButton.evaluate((element) => element.click()),
  ];

  for (const activate of activations) {
    try {
      await activate();
      await expect(enableButton).toHaveCount(0, { timeout: 3_000 });
      await page.waitForTimeout(300);
      return;
    } catch {
      // Headless Chromium can require a different activation path.
    }
  }

  throw new Error('Flutter accessibility semantics did not activate.');
}

async function openLogin(page) {
  await page.addInitScript(() => {
    localStorage.setItem('flutter.has_seen_onboarding', 'true');
  });
  await page.goto(`${appUrl}/#/login`);
  await enableFlutterSemantics(page, 15_000);
  await expect(page.getByRole('button', { name: 'Continue with Demo Mode' })).toBeVisible();
}

async function enterText(page, index, value) {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const textbox = page.getByRole('textbox').nth(index);
    await textbox.focus();
    await textbox.fill(value);
    await page.waitForTimeout(200);
    if (await page.getByRole('textbox').nth(index).inputValue() === value) return;
  }

  throw new Error(`Textbox ${index} did not retain its value.`);
}

async function expectSemanticText(page, text) {
  const pattern = new RegExp(text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
  await expect(
    page.getByText(text, { exact: false }).or(page.getByRole('group', { name: pattern })).first(),
  ).toBeVisible();
}

async function finishFirstLoginSetup(page) {
  const finishSetup = page.getByRole('button', { name: 'Finish Setup' });
  const attempts = [
    () => finishSetup.click(),
    async () => {
      await finishSetup.focus();
      await finishSetup.press('Enter');
    },
    () => finishSetup.evaluate((element) => element.click()),
  ];

  for (const activate of attempts) {
    await activate();
    try {
      await page.waitForURL(/#\/home$/, { timeout: 5_000 });
      return;
    } catch {
      // Flutter's semantics bridge can require a second activation in headless Chromium.
    }
  }

  throw new Error('First-login setup did not complete after semantic activation retries.');
}

async function loginBrowser(page, identifier) {
  await page.getByRole('checkbox').click();
  await enterText(page, 0, identifier);
  await enterText(page, 1, testUser.password);
  const signIn = page.getByRole('button', { name: 'Sign In' });
  await expect(signIn).toBeEnabled({ timeout: 10_000 });
  await signIn.click();
  await expect.poll(() => page.evaluate(() => window.isSecureContext)).toBe(true);
  await page.waitForURL(/#\/setup$/, { timeout: 15_000 });
  await page.getByRole('button', { name: '$ USD US Dollar' }).click();
  await finishFirstLoginSetup(page);
  await expect(page).toHaveURL(/#\/home$/);
  await expectSemanticText(page, 'Total Balance');
}

test.beforeAll(async () => {
  const admin = await loginApi(adminUsername, adminPassword);
  await api('/admin/user', {
    method: 'POST',
    token: admin.access_token,
    body: {
      username: testUser.username,
      password: testUser.password,
      email_address: testUser.email,
      is_email_verified: true,
    },
  });
  const user = await loginApi(testUser.username, testUser.password);
  userAccessToken = user.access_token;
  await api('/category', {
    method: 'POST',
    token: userAccessToken,
    body: { name: 'Browser Expense', type: 'expense', remark: 'acceptance' },
  });
  await api('/cash/expense', {
    method: 'POST',
    token: userAccessToken,
    body: {
      belongs_date: '2026-09-17',
      category_name: 'Browser Expense',
      amount: 19.75,
      description: 'Browser acceptance expense',
    },
  });
});

test.afterAll(async () => {
  if (!userAccessToken) return;
  await api('/user/account', { method: 'DELETE', token: userAccessToken }).catch(
    () => undefined,
  );
});

test('built client completes authenticated and demo journeys', async ({ page }) => {
  await openLogin(page);
  await loginBrowser(page, testUser.username);
  await page.reload();
  await enableFlutterSemantics(page);
  await expect(page).toHaveURL(/#\/home$/);
  await expectSemanticText(page, 'Total Balance');

  for (const destination of [
    ['categories', 'Manage your categories'],
    ['transactions', 'Browser acceptance expense'],
    ['statistics', 'Monthly Comparison'],
    ['budgets', 'Manage your spending limits'],
    ['settings', 'Preferences'],
  ]) {
    await page.goto(`${appUrl}/#/${destination[0]}`);
    await enableFlutterSemantics(page);
    await expectSemanticText(page, destination[1]);
  }

  await page.goto(`${appUrl}/#/unsupported`);
  await enableFlutterSemantics(page);
  await expectSemanticText(page, 'Page not found');
  await page.getByRole('button', { name: 'Return home' }).click();
  await expect(page).toHaveURL(/#\/home$/);

  await page.goto(`${appUrl}/#/login`);
  await enableFlutterSemantics(page);
  await expect(page).toHaveURL(/#\/home$/);

  const demoContext = await page.context().browser().newContext({
    viewport: { width: 390, height: 844 },
  });
  const demoPage = await demoContext.newPage();
  const authenticatedRequests = [];
  demoPage.on('request', (request) => {
    if (/\/(user|cash|category|statistic|budget)(\/|\?|$)/.test(request.url())) {
      authenticatedRequests.push(request.url());
    }
  });
  await openLogin(demoPage);
  await demoPage.getByRole('button', { name: 'Continue with Demo Mode' }).click();
  await expect(demoPage).toHaveURL(/#\/home$/);
  await demoPage.waitForTimeout(750);
  expect(authenticatedRequests).toEqual([]);
  await demoPage.getByRole('button', { name: 'Category' }).click();
  await expect(demoPage).toHaveURL(/#\/categories$/);
  const createCategory = demoPage.getByRole('button', {
    name: 'Create New Category',
  });
  await expect(createCategory).toBeVisible();
  await createCategory.click();
  await demoPage
    .getByRole('textbox', { name: 'Enter category name' })
    .fill('Isolated Demo');
  const create = demoPage.getByRole('button', { name: 'Create' });
  await expect(create).toBeVisible();
  await create.click();
  await expectSemanticText(demoPage, 'Isolated Demo');
  expect(authenticatedRequests).toEqual([]);
  await demoContext.close();
});
