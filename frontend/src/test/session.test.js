import { it, expect, vi } from "vitest";
it("coalesces simultaneous CSRF bootstraps and refreshes the token after logout", async () => {
  vi.resetModules();
  let bootstraps = 0;
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url) => {
      if (url.endsWith("/auth/csrf")) {
        bootstraps += 1;
        return {
          ok: true,
          status: 200,
          json: async () => ({ data: { csrf_token: `token-${bootstraps}` } }),
        };
      }
      return {
        ok: true,
        status: url.endsWith("/auth/logout") ? 204 : 200,
        json: async () => ({ data: {} }),
      };
    }),
  );
  const { api, bootstrap } = await import("../api");
  await Promise.all([bootstrap(), bootstrap()]);
  expect(bootstraps).toBe(1);
  await api("/auth/logout", { method: "POST" });
  expect(bootstraps).toBe(2);
  await api("/auth/login", {
    method: "POST",
    body: { email: "demo@example.test" },
  });
  expect(fetch.mock.calls.at(-1)[1].headers["X-CSRF-Token"]).toBe("token-2");
});
