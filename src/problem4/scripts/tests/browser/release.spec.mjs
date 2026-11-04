import { execFileSync } from "node:child_process";
import { expect, test } from "@playwright/test";

const { RELEASE_A, RELEASE_B, DEPLOY_ARGS } = process.env;

function deploy(...args) {
  execFileSync("bash", [...JSON.parse(DEPLOY_ARGS), ...args], { stdio: "inherit", env: process.env });
}

function watchErrors(page) {
  const errors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") errors.push(msg.text());
  });
  page.on("pageerror", (err) => errors.push(err.message));
  page.on("response", (res) => {
    if (res.status() >= 400) errors.push(`${res.status()} ${res.url()}`);
  });
  return errors;
}

test.describe.configure({ mode: "serial" });

test("the active release renders with its own configuration", async ({ page }) => {
  const errors = watchErrors(page);
  await page.goto("/");
  await expect(page.locator("[data-release]")).toHaveText(`Release ${RELEASE_A}`);
  await expect(page.locator("h1")).toHaveText("Hello, visitor");
  expect(errors).toEqual([]);
});

test("a deep link renders the SPA", async ({ page }) => {
  await page.goto("/details");
  await expect(page.locator("dd").nth(0)).toHaveText(RELEASE_A);
  await expect(page.locator("dd").nth(1)).toHaveText("local");
});

test("an open tab moves to a new activation and back after a rollback", async ({ page }) => {
  const errors = watchErrors(page);
  await page.goto("/");
  await expect(page.locator("[data-release]")).toHaveText(`Release ${RELEASE_A}`);
  deploy("--sha", RELEASE_B, "--artifact", process.env.ARTIFACT_B);
  await expect(page.locator("[data-release]")).toHaveText(`Release ${RELEASE_B}`, { timeout: 10_000 });
  deploy("--sha", RELEASE_A, "--rollback");
  await expect(page.locator("[data-release]")).toHaveText(`Release ${RELEASE_A}`, { timeout: 10_000 });
  expect(errors).toEqual([]);
});

test("a missing chunk reloads the page once and then renders", async ({ page }) => {
  let requests = 0;
  await page.route(/\/assets\/details-.*\.js$/, async (route) => {
    requests += 1;
    if (requests === 1) await route.fulfill({ status: 404, body: "gone" });
    else await route.continue();
  });
  await page.goto("/details");
  await expect(page.locator("dd").nth(0)).toHaveText(RELEASE_A, { timeout: 10_000 });
  expect(requests).toBe(2);
});

test("a chunk that stays missing does not reload forever", async ({ page }) => {
  let requests = 0;
  await page.route(/\/assets\/details-.*\.js$/, async (route) => {
    requests += 1;
    await route.fulfill({ status: 404, body: "gone" });
  });
  await page.goto("/details");
  await page.waitForTimeout(3_000);
  expect(requests).toBe(2);
});
