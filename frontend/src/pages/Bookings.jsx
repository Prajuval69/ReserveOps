import { useState } from "react";
import { Link } from "react-router-dom";
import { api, query } from "../api";
import { DateTime } from "luxon";
import { formatDate, formatTime } from "../time";
import {
  Dialog,
  Empty,
  Field,
  Loading,
  Notice,
  Pagination,
  Status,
  useApi,
} from "../ui";
import { BookingForm } from "./ResourceDetail";
export function Bookings() {
  const [status, setStatus] = useState(""),
    [version, setVersion] = useState(0),
    [page, setPage] = useState(1),
    [selected, setSelected] = useState(null),
    [mode, setMode] = useState(""),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  const bookings = useApi(`/bookings?${query({ status, page })}`, version);
  async function cancel(event) {
    event.preventDefault();
    setBusy(true);
    setError("");
    try {
      await api(`/bookings/${selected.id}/cancel`, {
        method: "POST",
        body: { reason: new FormData(event.currentTarget).get("reason") },
      });
      setSelected(null);
      setVersion(version + 1);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <>
      <div className="page-heading">
        <div>
          <span className="eyebrow">YOUR PLANS</span>
          <h1>My bookings</h1>
          <p>Every reservation, from first request to the last detail.</p>
        </div>
        <Link className="primary" to="/resources">
          Reserve a resource
        </Link>
      </div>
      <div className="filters">
        <Field label="Booking status">
          <select
            value={status}
            onChange={(e) => {
              setStatus(e.target.value);
              setPage(1);
            }}
          >
            <option value="">All statuses</option>
            {[
              "confirmed",
              "pending_approval",
              "waitlisted",
              "cancelled",
              "expired",
              "rejected",
              "completed",
            ].map((s) => (
              <option key={s} value={s}>
                {s.replaceAll("_", " ")}
              </option>
            ))}
          </select>
        </Field>
      </div>
      <Notice error>{bookings.error}</Notice>
      {bookings.loading ? (
        <Loading />
      ) : bookings.data?.length ? (
        <div className="booking-list">
          {bookings.data.map((b) => (
            <article className="panel booking-card" key={b.id}>
              <div>
                <span className="small">
                  {b.resource.location.name} · #{b.id}
                </span>
                <h2>{b.resource.name}</h2>
                <p>{b.purpose}</p>
                <strong>
                  {formatDate(b.starts_at)} · {formatTime(b.starts_at)}–
                  {formatTime(b.ends_at)}
                </strong>
                {b.approval_expires_at && b.status === "pending_approval" && (
                  <small className="deadline">
                    Approval expires {formatDate(b.approval_expires_at)} at{" "}
                    {formatTime(b.approval_expires_at)}
                  </small>
                )}
              </div>
              <div className="booking-actions">
                <Status value={b.status} />
                <div>
                  <button
                    onClick={() => {
                      setSelected(b);
                      setMode("timeline");
                      setError("");
                    }}
                  >
                    Timeline
                  </button>
                  {["confirmed", "pending_approval", "waitlisted"].includes(
                    b.status,
                  ) &&
                    new Date(b.starts_at) > new Date() && (
                      <>
                        <button
                          onClick={() => {
                            setSelected(b);
                            setMode("cancel");
                            setError("");
                          }}
                        >
                          Cancel
                        </button>
                        {b.status !== "waitlisted" && (
                          <button
                            onClick={() => {
                              setSelected(b);
                              setMode("reschedule");
                            }}
                          >
                            Reschedule
                          </button>
                        )}
                      </>
                    )}
                </div>
              </div>
            </article>
          ))}
        </div>
      ) : (
        <Empty title="No bookings to show">
          Your reservations and waitlist requests appear here.
        </Empty>
      )}
      <Pagination meta={bookings.meta} page={page} setPage={setPage} />
      {selected && (
        <Dialog
          title={
            mode === "timeline"
              ? "Reservation timeline"
              : mode === "cancel"
                ? "Cancel reservation"
                : "Reschedule reservation"
          }
          onClose={() => setSelected(null)}
        >
          {mode === "timeline" ? (
            <Timeline id={selected.id} />
          ) : mode === "cancel" ? (
            <form onSubmit={cancel}>
              <p>
                Release {selected.resource.name} so the next person can use it.
              </p>
              <Field label="Cancellation reason">
                <textarea name="reason" maxLength="500" />
              </Field>
              <Notice error>{error}</Notice>
              <button disabled={busy} className="danger">
                {busy ? "Cancelling…" : "Confirm cancellation"}
              </button>
            </form>
          ) : (
            <BookingForm
              booking={selected}
              resource={selected.resource}
              initialStart={DateTime.fromISO(selected.starts_at)
                .setZone(selected.resource.location.timezone)
                .toFormat("yyyy-MM-dd'T'HH:mm")}
              initialEnd={DateTime.fromISO(selected.ends_at)
                .setZone(selected.resource.location.timezone)
                .toFormat("yyyy-MM-dd'T'HH:mm")}
              onSuccess={() => {
                setSelected(null);
                setVersion(version + 1);
              }}
            />
          )}
        </Dialog>
      )}
    </>
  );
}
function Timeline({ id }) {
  const booking = useApi(`/bookings/${id}`);
  return (
    <>
      <Notice error>{booking.error}</Notice>
      {booking.loading ? (
        <Loading />
      ) : (
        <ol className="timeline">
          {booking.data?.events.map((e) => (
            <li key={e.id}>
              <strong>{e.action.replaceAll("_", " ")}</strong>
              <Status value={e.to_status} />
              <small>
                {formatDate(e.created_at)} at {formatTime(e.created_at)} ·{" "}
                {e.actor_id ? "User action" : "System"}
              </small>
              {e.metadata.reason && <p>{e.metadata.reason}</p>}
            </li>
          ))}
        </ol>
      )}
    </>
  );
}
export function Approvals() {
  const [version, setVersion] = useState(0),
    [page, setPage] = useState(1),
    [selected, setSelected] = useState(null),
    [action, setAction] = useState(""),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  const approvals = useApi(`/approvals?page=${page}`, version);
  async function decide(event) {
    event.preventDefault();
    setBusy(true);
    try {
      await api(`/bookings/${selected.id}/${action}`, {
        method: "POST",
        body: { reason: new FormData(event.currentTarget).get("reason") },
      });
      setSelected(null);
      setVersion(version + 1);
    } catch (e) {
      setError(e.message);
      setVersion(version + 1);
    } finally {
      setBusy(false);
    }
  }
  return (
    <>
      <div className="page-heading">
        <div>
          <span className="eyebrow">KEEP WORK MOVING</span>
          <h1>Approval inbox</h1>
          <p>
            Requests in your assigned locations. Your own requests are excluded.
          </p>
        </div>
        <button onClick={() => setVersion(version + 1)}>Refresh inbox</button>
      </div>
      <Notice error>{approvals.error}</Notice>
      {approvals.loading ? (
        <Loading />
      ) : approvals.data?.length ? (
        <div className="booking-list">
          {approvals.data.map((b) => (
            <article key={b.id} className="panel booking-card">
              <div>
                <Status value={b.status} />
                <h2>{b.resource.name}</h2>
                <p>
                  {b.purpose} · {b.attendee_count} people
                </p>
                <strong>
                  {formatDate(b.starts_at)} · {formatTime(b.starts_at)}–
                  {formatTime(b.ends_at)}
                </strong>
                <small className="deadline">
                  Decide before {formatDate(b.approval_expires_at)}{" "}
                  {formatTime(b.approval_expires_at)}
                </small>
              </div>
              <div className="action-row">
                <button
                  onClick={() => {
                    setSelected(b);
                    setAction("reject");
                    setError("");
                  }}
                >
                  Reject
                </button>
                <button
                  className="primary"
                  onClick={() => {
                    setSelected(b);
                    setAction("approve");
                    setError("");
                  }}
                >
                  Approve
                </button>
              </div>
            </article>
          ))}
        </div>
      ) : (
        <Empty title="All requests are taken care of">
          New requests from your locations will appear here.
        </Empty>
      )}
      <Pagination meta={approvals.meta} page={page} setPage={setPage} />
      {selected && (
        <Dialog
          title={
            action === "approve" ? "Approve reservation" : "Reject reservation"
          }
          onClose={() => setSelected(null)}
        >
          <form onSubmit={decide}>
            <p>
              {selected.resource.name} · {selected.purpose}
            </p>
            <Field
              label={
                action === "reject"
                  ? "Rejection reason"
                  : "Decision note (optional)"
              }
            >
              <textarea
                name="reason"
                required={action === "reject"}
                maxLength="500"
              />
            </Field>
            <Notice error>{error}</Notice>
            <button disabled={busy} className="primary">
              {busy
                ? "Saving…"
                : action === "approve"
                  ? "Confirm approval"
                  : "Confirm rejection"}
            </button>
          </form>
        </Dialog>
      )}
    </>
  );
}
export function Notifications() {
  const [page, setPage] = useState(1),
    [version, setVersion] = useState(0),
    [error, setError] = useState("");
  const notifications = useApi(`/notifications?page=${page}`, version);
  async function read(id) {
    try {
      await api(`/notifications/${id}/read`, { method: "POST" });
      setVersion(version + 1);
    } catch (e) {
      setError(e.message);
    }
  }
  return (
    <>
      <div className="page-heading">
        <div>
          <span className="eyebrow">STAY IN THE LOOP</span>
          <h1>Notifications</h1>
          <p>Reservation updates, reminders, and your daily plans.</p>
        </div>
        <button onClick={() => setVersion(version + 1)}>Refresh updates</button>
      </div>
      <Notice error>{error || notifications.error}</Notice>
      {notifications.loading ? (
        <Loading />
      ) : notifications.data?.length ? (
        <div className="panel notification-list">
          {notifications.data.map((n) => (
            <article key={n.id} className={n.read_at ? "" : "unread"}>
              <span className={`activity-dot ${n.read_at ? "read" : ""}`} />
              <div>
                <h2>{n.title}</h2>
                <p>{n.body}</p>
                <small>
                  {formatDate(n.created_at)} · {formatTime(n.created_at)}
                </small>
                {n.booking_id && <Link to="/my-bookings">View bookings</Link>}
              </div>
              {!n.read_at && (
                <button onClick={() => read(n.id)}>Mark read</button>
              )}
            </article>
          ))}
        </div>
      ) : (
        <Empty title="You’re all caught up">
          Your next reservation update will appear here.
        </Empty>
      )}
      <Pagination meta={notifications.meta} page={page} setPage={setPage} />
    </>
  );
}
