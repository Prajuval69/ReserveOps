import { describe, it, expect, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import App from "../App";
import { Catalog } from "../pages/Catalog";
import { BookingForm, Calendar } from "../pages/ResourceDetail";
import { Approvals, Bookings, Notifications } from "../pages/Bookings";
import { toUTC, formatTime } from "../time";
const resource = {
  id: 1,
  name: "Focus Room A",
  identifier: "FOCUS-A",
  description: "Quiet collaboration space",
  resource_category_id: 1,
  location_id: 1,
  occupants_capacity: 4,
  min_minutes: 15,
  max_minutes: 480,
  advance_days: 60,
  opens_at: "08:00",
  closes_at: "20:00",
  requires_approval: false,
  location: { id: 1, name: "Hyderabad Hub", timezone: "Asia/Kolkata" },
  category: { id: 1, name: "Meeting rooms", slug: "rooms" },
};
const booking = {
  id: 10,
  resource,
  status: "confirmed",
  purpose: "Planning",
  attendee_count: 2,
  starts_at: "2030-11-03T04:30:00Z",
  ends_at: "2030-11-03T05:30:00Z",
};
function response(data, status = 200) {
  return { ok: status < 400, status, json: async () => data };
}
function mockApi(handler) {
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url, options) => {
      if (url.endsWith("/auth/csrf"))
        return response({ data: { csrf_token: "test-token" } });
      const result = handler(url, options);
      return result || response({ data: [] });
    }),
  );
}
function renderRoute(element) {
  return render(<MemoryRouter>{element}</MemoryRouter>);
}
describe("ReserveOps user workflows", () => {
  it("converts local booking time to UTC and displays India local time", () => {
    expect(toUTC("2026-11-03T10:00")).toBe("2026-11-03T04:30:00.000Z");
    expect(formatTime("2026-11-03T04:30:00Z")).toBe("10:00 AM");
  });
  it("redirects unauthenticated users to accessible login and submits cookies with CSRF", async () => {
    mockApi((url) =>
      url.endsWith("/auth/me")
        ? response({ error: { message: "Sign in" } }, 401)
        : url.endsWith("/auth/login")
          ? response(
              { error: { message: "Email or password is incorrect." } },
              401,
            )
          : null,
    );
    renderRoute(<App />);
    await screen.findByRole("heading", { name: "Let’s get you settled." });
    await userEvent.type(
      screen.getByLabelText("Email address"),
      "wrong@example.test",
    );
    await userEvent.type(screen.getByLabelText("Password"), "wrong-password");
    await userEvent.click(screen.getByRole("button", { name: "Sign in" }));
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Email or password is incorrect.",
    );
    const [, options] = fetch.mock.calls.find(([url]) =>
      url.endsWith("/auth/login"),
    );
    expect(options.credentials).toBe("include");
    expect(options.headers["X-CSRF-Token"]).toBe("test-token");
  });
  it("does not show management navigation to an employee", async () => {
    mockApi((url) =>
      url.endsWith("/auth/me")
        ? response({
            data: {
              display_name: "Ananya Rao",
              role: "employee",
              timezone: "Asia/Kolkata",
            },
          })
        : null,
    );
    renderRoute(<App />);
    await screen.findByRole("heading", { name: "Hello, Ananya." });
    expect(
      screen.queryByRole("link", { name: "Approvals" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("link", { name: "Manage workspace" }),
    ).not.toBeInTheDocument();
  });
  it("filters resource catalog through real query parameters and renders an empty state", async () => {
    mockApi((url) =>
      url.includes("/resources?")
        ? response({
            data: url.includes("q=Missing") ? [] : [resource],
            meta: { page: 1, total: 1, per_page: 9 },
          })
        : null,
    );
    renderRoute(<Catalog />);
    expect(
      await screen.findByRole("link", { name: "Focus Room A" }),
    ).toBeInTheDocument();
    await userEvent.type(screen.getByLabelText("Search resources"), "Missing");
    expect(await screen.findByText("No resources found")).toBeInTheDocument();
    expect(fetch.mock.calls.some(([url]) => url.includes("q=Missing"))).toBe(
      true,
    );
  });
  it("shows pending approval on successful reservation and sends no trusted user/status fields", async () => {
    mockApi((url) =>
      url.endsWith("/bookings")
        ? response({ data: { status: "pending_approval" } }, 201)
        : null,
    );
    render(<BookingForm resource={{ ...resource, requires_approval: true }} />);
    await userEvent.type(
      screen.getByLabelText("What’s the plan?"),
      "Design review",
    );
    await userEvent.click(
      screen.getByRole("button", { name: "Reserve resource" }),
    );
    expect(await screen.findByRole("status")).toHaveTextContent(
      "Reservation pending approval.",
    );
    const [, opts] = fetch.mock.calls.find(([url]) =>
      url.endsWith("/bookings"),
    );
    const body = JSON.parse(opts.body);
    expect(body.booking.purpose).toBe("Design review");
    expect(body.booking.user_id).toBeUndefined();
    expect(body.booking.status).toBeUndefined();
  });
  it("offers explicit waitlist opt-in after a 409, then persists a waiting request", async () => {
    mockApi((url) =>
      url.endsWith("/bookings")
        ? response(
            {
              error: { code: "BOOKING_CONFLICT", message: "Slot unavailable." },
            },
            409,
          )
        : url.endsWith("/waitlist")
          ? response({ data: { status: "waitlisted" } }, 201)
          : null,
    );
    render(<BookingForm resource={resource} />);
    await userEvent.type(screen.getByLabelText("What’s the plan?"), "Planning");
    await userEvent.click(
      screen.getByRole("button", { name: "Reserve resource" }),
    );
    const join = await screen.findByRole("button", { name: "Join waitlist" });
    expect(fetch.mock.calls.some(([url]) => url.endsWith("/waitlist"))).toBe(
      false,
    );
    await userEvent.click(join);
    expect(await screen.findByRole("status")).toHaveTextContent(
      "Reservation waitlisted.",
    );
  });
  it("rejects reversed form intervals before sending a booking request", async () => {
    mockApi(() => null);
    render(
      <BookingForm
        resource={resource}
        initialStart="2030-11-03T12:00"
        initialEnd="2030-11-03T11:00"
      />,
    );
    await userEvent.type(screen.getByLabelText("What’s the plan?"), "Planning");
    await userEvent.click(
      screen.getByRole("button", { name: "Reserve resource" }),
    );
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "End must be after start.",
    );
    expect(fetch.mock.calls.some(([url]) => url.endsWith("/bookings"))).toBe(
      false,
    );
  });
  it("renders a day/week calendar with a timezone and selectable free slots", async () => {
    mockApi(() => response({ data: { intervals: [], blackouts: [] } }));
    const select = vi.fn();
    render(<Calendar resource={resource} onSelect={select} revision={0} />);
    await waitFor(() =>
      expect(screen.queryByLabelText("Loading")).not.toBeInTheDocument(),
    );
    expect(screen.getByText(/Asia\/Kolkata/)).toBeInTheDocument();
    const slots = screen.getAllByRole("button", { name: /available/ });
    await userEvent.click(slots[0]);
    expect(select).toHaveBeenCalledTimes(1);
    await userEvent.click(screen.getByRole("button", { name: "Week" }));
    expect(screen.getByRole("button", { name: "Week" })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
  });
  it("approves a scoped request through a confirmation dialog", async () => {
    mockApi((url, options) =>
      url.includes("/approvals")
        ? response({
            data: [
              {
                ...booking,
                status: "pending_approval",
                approval_expires_at: booking.starts_at,
              },
            ],
            meta: { total: 1 },
          })
        : url.endsWith("/approve") && options.method === "POST"
          ? response({ data: booking })
          : null,
    );
    renderRoute(<Approvals />);
    await userEvent.click(
      await screen.findByRole("button", { name: "Approve" }),
    );
    expect(
      screen.getByRole("dialog", { name: "Approve reservation" }),
    ).toBeInTheDocument();
    await userEvent.click(
      screen.getByRole("button", { name: "Confirm approval" }),
    );
    await waitFor(() =>
      expect(
        fetch.mock.calls.some(([url]) => url.endsWith("/10/approve")),
      ).toBe(true),
    );
  });
  it("cancels a booking with a rationale and refreshes persisted server state", async () => {
    let cancelled = false;
    mockApi((url) => {
      if (url.endsWith("/10/cancel")) {
        cancelled = true;
        return response({ data: { ...booking, status: "cancelled" } });
      }
      if (url.includes("/bookings?"))
        return response({
          data: [{ ...booking, status: cancelled ? "cancelled" : "confirmed" }],
          meta: { total: 1 },
        });
    });
    renderRoute(<Bookings />);
    await userEvent.click(
      await screen.findByRole("button", { name: "Cancel" }),
    );
    await userEvent.type(
      screen.getByLabelText("Cancellation reason"),
      "Plans changed",
    );
    await userEvent.click(
      screen.getByRole("button", { name: "Confirm cancellation" }),
    );
    expect(
      await screen.findByText("cancelled", { selector: "span" }),
    ).toBeInTheDocument();
  });
  it("marks only the selected notification read and refreshes the list", async () => {
    let read = false;
    mockApi((url) => {
      if (url.endsWith("/5/read")) {
        read = true;
        return response({ data: {} });
      }
      if (url.includes("/notifications?"))
        return response({
          data: [
            {
              id: 5,
              title: "Reservation confirmed",
              body: "Focus room reserved",
              created_at: booking.starts_at,
              read_at: read ? booking.starts_at : null,
            },
          ],
        });
    });
    renderRoute(<Notifications />);
    await userEvent.click(
      await screen.findByRole("button", { name: "Mark read" }),
    );
    await waitFor(() =>
      expect(
        screen.queryByRole("button", { name: "Mark read" }),
      ).not.toBeInTheDocument(),
    );
    expect(read).toBe(true);
  });
});
