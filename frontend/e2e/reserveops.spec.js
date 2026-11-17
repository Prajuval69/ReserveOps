import { test, expect } from "@playwright/test";
import { DateTime } from "luxon";
import fs from "node:fs";
const password = process.env.DEMO_PASSWORD;
if (!password)
  throw new Error("Set DEMO_PASSWORD to the password used by db:seed.");
const screenshots = "../docs/screenshots";
fs.mkdirSync(screenshots, { recursive: true });
const stamp = Date.now();
async function capture(page, name) {
  await expect(page.getByRole("status", { name: "Loading" })).toHaveCount(0);
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: `${screenshots}/${name}`, fullPage: true });
}
async function login(page, account) {
  await page.goto("/login");
  await page.getByLabel("Email address").fill(`${account}@reserveops.local`);
  await page.getByLabel("Password", { exact: true }).fill(password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page.getByRole("heading", { name: /Hello,/ })).toBeVisible();
}
async function csrf(page) {
  const response = await page.request.get("/api/v1/auth/csrf");
  return (await response.json()).data.csrf_token;
}
async function request(page, path, body, method = "POST") {
  const token = await csrf(page);
  return page.request.fetch(`/api/v1${path}`, {
    method,
    data: body,
    headers: { "X-CSRF-Token": token },
  });
}
function slot(days, hour = 14) {
  const start = DateTime.now()
    .setZone("Asia/Kolkata")
    .plus({ days })
    .startOf("day")
    .set({ hour });
  return {
    starts_at: start.toUTC().toISO(),
    ends_at: start.plus({ hours: 1 }).toUTC().toISO(),
  };
}
async function newResource(page, name, { approval = false } = {}) {
  const categories = (
    await (await page.request.get("/api/v1/categories")).json()
  ).data;
  const locations = (await (await page.request.get("/api/v1/locations")).json())
    .data;
  const res = await request(page, "/resources", {
    resource: {
      name,
      identifier: `E2E-${name}`,
      resource_category_id: categories[0].id,
      location_id: locations.find((l) => l.name === "Hyderabad Hub").id,
      occupants_capacity: 4,
      requires_approval: approval,
      description: "Created by browser acceptance test",
    },
  });
  expect(res.status()).toBe(201);
  return (await res.json()).data;
}
test("employee books, refreshes persisted card, reschedules, and cancels with a timeline", async ({
  page,
}) => {
  await page.goto("/login");
  await expect(
    page.getByRole("heading", { name: "Let’s get you settled." }),
  ).toBeVisible();
  await capture(page, "login.png");
  await login(page, "admin");
  const resource = await newResource(page, `Focus acceptance ${stamp}`);
  await page.getByRole("button", { name: /Ishaan Malhotra/ }).click();
  await expect(page.getByLabel("Email address")).toBeVisible();
  await login(page, "ananya");
  await capture(page, "overview.png");
  await page.goto("/resources");
  await page.getByLabel("Search resources").fill(resource.name);
  await page.getByRole("link", { name: resource.name, exact: true }).click();
  const time = DateTime.now()
    .setZone("Asia/Kolkata")
    .plus({ days: 3 })
    .startOf("day");
  await page
    .getByLabel("Start time")
    .fill(time.set({ hour: 14 }).toFormat("yyyy-MM-dd'T'HH:mm"));
  await page
    .getByLabel("End time")
    .fill(time.set({ hour: 15 }).toFormat("yyyy-MM-dd'T'HH:mm"));
  await page.getByLabel("What’s the plan?").fill(`Browser planning ${stamp}`);
  await page
    .getByRole("button", { name: "Reserve resource", exact: true })
    .click();
  await expect(
    page.getByText("Reservation confirmed.", { exact: true }),
  ).toBeVisible();
  await capture(page, "calendar.png");
  await page.goto("/my-bookings");
  await page.reload();
  let card = page
    .getByRole("article")
    .filter({ hasText: `Browser planning ${stamp}` });
  await expect(card).toBeVisible();
  await card.getByRole("button", { name: "Reschedule" }).click();
  await page
    .getByLabel("Start time")
    .fill(time.set({ hour: 15 }).toFormat("yyyy-MM-dd'T'HH:mm"));
  await page
    .getByLabel("End time")
    .fill(time.set({ hour: 16 }).toFormat("yyyy-MM-dd'T'HH:mm"));
  await page.getByRole("button", { name: "Save new times" }).click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  card = page
    .getByRole("article")
    .filter({ hasText: `Browser planning ${stamp}` });
  await expect(card).toContainText("3:00 PM");
  await card.getByRole("button", { name: "Cancel", exact: true }).click();
  await page.getByLabel("Cancellation reason").fill("Acceptance test complete");
  await page.getByRole("button", { name: "Confirm cancellation" }).click();
  await expect(card.locator(".status")).toHaveText("cancelled");
  await card.getByRole("button", { name: "Timeline" }).click();
  await expect(page.getByRole("dialog")).toContainText(
    "Acceptance test complete",
  );
});
test("409 offers waitlist, cancellation triggers real Sidekiq promotion and notification", async ({
  browser,
  page,
}) => {
  await login(page, "admin");
  const resource = await newResource(page, `Queue acceptance ${stamp}`);
  await page.getByRole("button", { name: /Ishaan Malhotra/ }).click();
  await expect(page.getByLabel("Email address")).toBeVisible();
  await login(page, "ananya");
  const times = slot(4);
  const created = await request(page, "/bookings", {
    booking: {
      ...times,
      resource_id: resource.id,
      purpose: `Queue owner ${stamp}`,
      attendee_count: 1,
    },
  });
  expect(created.status()).toBe(201);
  const owner = (await created.json()).data;
  const context = await browser.newContext();
  const waitingPage = await context.newPage();
  await login(waitingPage, "kabir");
  await waitingPage.goto(`/resources/${resource.id}`);
  const start = DateTime.fromISO(times.starts_at).setZone("Asia/Kolkata");
  await waitingPage
    .getByLabel("Start time")
    .fill(start.toFormat("yyyy-MM-dd'T'HH:mm"));
  await waitingPage
    .getByLabel("End time")
    .fill(start.plus({ hours: 1 }).toFormat("yyyy-MM-dd'T'HH:mm"));
  await waitingPage
    .getByLabel("What’s the plan?")
    .fill(`Queue candidate ${stamp}`);
  await waitingPage
    .getByRole("button", { name: "Reserve resource", exact: true })
    .click();
  await expect(waitingPage.getByRole("alert")).toContainText("unavailable");
  await capture(waitingPage, "conflict.png");
  await waitingPage.getByRole("button", { name: "Join waitlist" }).click();
  await expect(
    waitingPage.getByText("Reservation waitlisted.", { exact: true }),
  ).toBeVisible();
  const cancellation = await request(page, `/bookings/${owner.id}/cancel`, {
    reason: "Release for waiting teammate",
  });
  expect(cancellation.status()).toBe(200);
  await expect
    .poll(
      async () => {
        const result = await waitingPage.request.get(
          "/api/v1/bookings?per_page=100",
        );
        const bookings = (await result.json()).data;
        return bookings.find((b) => b.purpose === `Queue candidate ${stamp}`)
          ?.status;
      },
      { timeout: 20000 },
    )
    .toBe("confirmed");
  await waitingPage.goto("/notifications");
  await expect(
    waitingPage
      .getByRole("article")
      .filter({ hasText: resource.name })
      .getByRole("heading", {
        name: "Booking confirmed",
        exact: true,
      }),
  ).toBeVisible();
  await capture(waitingPage, "notifications.png");
  await context.close();
});
test("scoped manager approves a pending request and requester sees confirmation", async ({
  browser,
  page,
}) => {
  await login(page, "admin");
  const resource = await newResource(page, `Approval acceptance ${stamp}`, {
    approval: true,
  });
  await page.getByRole("button", { name: /Ishaan Malhotra/ }).click();
  await expect(page.getByLabel("Email address")).toBeVisible();
  await login(page, "tara");
  const result = await request(page, "/bookings", {
    booking: {
      ...slot(5),
      resource_id: resource.id,
      purpose: `Manager review ${stamp}`,
      attendee_count: 2,
    },
  });
  expect(result.status()).toBe(201);
  const booking = (await result.json()).data;
  expect(booking.status).toBe("pending_approval");
  const context = await browser.newContext();
  const manager = await context.newPage();
  await login(manager, "manager.hyderabad");
  await manager.goto("/approvals");
  const card = manager
    .getByRole("article")
    .filter({ hasText: `Manager review ${stamp}` });
  await expect(card).toBeVisible();
  await capture(manager, "approvals.png");
  await card.getByRole("button", { name: "Approve", exact: true }).click();
  await manager
    .getByLabel("Decision note (optional)")
    .fill("Approved for team planning");
  await manager.getByRole("button", { name: "Confirm approval" }).click();
  await expect(card).toHaveCount(0);
  await page.goto("/my-bookings");
  await expect(
    page
      .getByRole("article")
      .filter({ hasText: `Manager review ${stamp}` })
      .locator(".status"),
  ).toHaveText("confirmed");
  await context.close();
});
test("admin creates and edits a resource through the form and views actual analytics", async ({
  page,
}) => {
  await login(page, "admin");
  await page.goto("/admin/resources");
  await page.getByRole("button", { name: "Add resource", exact: true }).click();
  const dialog = page.getByRole("dialog");
  const name = `Admin browser ${stamp}`;
  await dialog.getByLabel("Resource name").fill(name);
  await dialog.getByLabel("Identifier", { exact: true }).fill(`ADMIN-${stamp}`);
  await dialog
    .getByLabel("Category", { exact: true })
    .selectOption({ label: "Meeting rooms" });
  await dialog
    .getByLabel("Location", { exact: true })
    .selectOption({ label: "Hyderabad Hub" });
  await dialog
    .getByLabel("Description")
    .fill("A browser-created meeting space.");
  await dialog.getByRole("button", { name: "Save resource" }).click();
  await expect(dialog).toHaveCount(0);
  const row = page.getByRole("row").filter({ hasText: name });
  await expect(row).toBeVisible();
  await row.getByRole("button", { name: "Edit", exact: true }).click();
  await page.getByRole("dialog").getByLabel("Occupant capacity").fill("6");
  await page
    .getByRole("dialog")
    .getByRole("button", { name: "Save resource" })
    .click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await page.goto("/resources");
  await page.getByLabel("Search resources").fill(name);
  await expect(page.getByRole("article")).toContainText("6 people");
  await capture(page, "catalog.png");
  await page.goto("/analytics");
  await expect(
    page.getByRole("heading", { name: "Resource utilization" }),
  ).toBeVisible();
  await expect(page.getByText(name, { exact: true })).toBeVisible();
  await capture(page, "analytics.png");
});
test("360px mobile navigation works and pages fit the viewport", async ({
  page,
}) => {
  await page.setViewportSize({ width: 360, height: 800 });
  await login(page, "ananya");
  await page.getByRole("button", { name: "Toggle navigation" }).click();
  await page
    .getByRole("navigation")
    .getByRole("link", { name: "Resources", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "Resources", exact: true }),
  ).toBeVisible();
  await expect
    .poll(() =>
      page.evaluate(
        () => document.documentElement.scrollWidth <= window.innerWidth,
      ),
    )
    .toBe(true);
  await capture(page, "mobile-catalog.png");
});
