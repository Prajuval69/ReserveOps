import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { DateTime } from "luxon";
import {
  ArrowLeftIcon,
  ArrowRightIcon,
  ClockIcon,
  UsersIcon,
  MapPinIcon,
} from "@phosphor-icons/react";
import { api, query } from "../api";
import { formatTime, localNow, toUTC, zone } from "../time";
import { Field, Loading, Notice, useApi } from "../ui";

export function BookingForm({
  resource,
  onSuccess,
  initialStart,
  initialEnd,
  booking = null,
}) {
  const tomorrow = localNow().plus({ days: 1 }).toISODate();
  const [start, setStart] = useState(initialStart || `${tomorrow}T10:00`),
    [end, setEnd] = useState(initialEnd || `${tomorrow}T11:00`);
  const [purpose, setPurpose] = useState(booking?.purpose || ""),
    [attendees, setAttendees] = useState(booking?.attendee_count || 1);
  const [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [conflict, setConflict] = useState(false),
    [success, setSuccess] = useState("");
  async function submit(event, waitlist = false) {
    event?.preventDefault();
    setError("");
    setSuccess("");
    setBusy(true);
    try {
      const starts_at = toUTC(start, resource.location.timezone),
        ends_at = toUTC(end, resource.location.timezone);
      if (ends_at <= starts_at) throw new Error("End must be after start.");
      const path = waitlist
        ? "/waitlist"
        : booking
          ? `/bookings/${booking.id}/reschedule`
          : "/bookings";
      const result = await api(path, {
        method: booking ? "PATCH" : "POST",
        body: {
          booking: {
            resource_id: resource.id,
            starts_at,
            ends_at,
            purpose,
            attendee_count: Number(attendees),
          },
        },
      });
      setConflict(false);
      setSuccess(`Reservation ${result.data.status.replaceAll("_", " ")}.`);
      onSuccess?.(result.data);
    } catch (error) {
      setError(error.message);
      setConflict(error.code === "BOOKING_CONFLICT" && !booking);
    } finally {
      setBusy(false);
    }
  }
  return (
    <form onSubmit={submit} className="booking-form">
      <h2>{booking ? "Change your reservation" : "Make it yours"}</h2>
      <p>
        {resource.requires_approval
          ? "Your request holds the slot until manager approval or expiry."
          : "Reserve this resource instantly."}
      </p>
      <Field label="Start time" help={resource.location.timezone}>
        <input
          type="datetime-local"
          required
          step="900"
          value={start}
          onChange={(e) => {
            setStart(e.target.value);
            setConflict(false);
          }}
        />
      </Field>
      <Field label="End time">
        <input
          type="datetime-local"
          required
          step="900"
          value={end}
          onChange={(e) => {
            setEnd(e.target.value);
            setConflict(false);
          }}
        />
      </Field>
      {!booking && (
        <>
          <Field label="People">
            <input
              type="number"
              min="1"
              max={resource.occupants_capacity}
              value={attendees}
              onChange={(e) => setAttendees(e.target.value)}
              required
            />
          </Field>
          <Field label="What’s the plan?">
            <input
              maxLength="250"
              placeholder="e.g. Product planning"
              value={purpose}
              onChange={(e) => setPurpose(e.target.value)}
              required
            />
          </Field>
        </>
      )}
      <Notice error>{error}</Notice>
      <Notice>{success}</Notice>
      <button disabled={busy} className="primary">
        {busy ? "Saving…" : booking ? "Save new times" : "Reserve resource"}
        <ArrowRightIcon />
      </button>
      {conflict && (
        <div className="waitlist-offer">
          <p>
            Want this slot if it opens up? Join the queue in order of arrival.
          </p>
          <button
            type="button"
            disabled={busy}
            onClick={() => submit(null, true)}
          >
            Join waitlist
          </button>
        </div>
      )}
      <small className="booking-note">
        {resource.min_minutes}–{resource.max_minutes} minutes per booking. Up to{" "}
        {resource.advance_days} days ahead.
      </small>
    </form>
  );
}

export function Calendar({ resource, onSelect, revision }) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 60000);
    return () => clearInterval(timer);
  }, []);
  const [date, setDate] = useState(localNow().plus({ days: 1 }).toISODate()),
    [view, setView] = useState("day");
  const base = DateTime.fromISO(date, { zone: resource.location.timezone });
  const first = view === "week" ? base.startOf("week") : base.startOf("day");
  const count = view === "week" ? 7 : 1;
  const days = Array.from({ length: count }, (_, i) => first.plus({ days: i }));
  const availability = useApi(
    `/resources/${resource.id}/availability?${query({ from: first.toUTC().toISO(), to: first.plus({ days: count }).toUTC().toISO() })}`,
    revision,
  );
  const open =
    Number(resource.opens_at.slice(0, 2)) * 60 +
    Number(resource.opens_at.slice(3));
  const close =
    Number(resource.closes_at.slice(0, 2)) * 60 +
    Number(resource.closes_at.slice(3));
  const slots = Array.from(
    { length: Math.ceil((close - open) / 30) },
    (_, i) => open + i * 30,
  );
  const intervals = [
    ...(availability.data?.intervals || []),
    ...(availability.data?.blackouts || []).map((b) => ({
      ...b,
      status: "maintenance",
    })),
  ];
  function move(amount) {
    setDate(base.plus({ days: amount * count }).toISODate());
  }
  return (
    <section className="panel calendar-panel">
      <div className="calendar-toolbar">
        <div>
          <h2>Availability</h2>
          <small>
            {resource.location.timezone} · {resource.opens_at}–
            {resource.closes_at}
          </small>
        </div>
        <div className="calendar-controls">
          <button aria-label="Previous dates" onClick={() => move(-1)}>
            ←
          </button>
          <Field label="Calendar date">
            <input
              aria-label="Calendar date"
              type="date"
              value={date}
              onChange={(e) => setDate(e.target.value)}
            />
          </Field>
          <button aria-label="Next dates" onClick={() => move(1)}>
            →
          </button>
          <div className="segmented">
            <button
              className={view === "day" ? "selected" : ""}
              aria-pressed={view === "day"}
              onClick={() => setView("day")}
            >
              Day
            </button>
            <button
              className={view === "week" ? "selected" : ""}
              aria-pressed={view === "week"}
              onClick={() => setView("week")}
            >
              Week
            </button>
          </div>
        </div>
      </div>
      <div className="legend">
        <span>
          <i className="confirmed" />
          Confirmed
        </span>
        <span>
          <i className="pending_approval" />
          Pending approval
        </span>
        <span>
          <i className="maintenance" />
          Maintenance
        </span>
        <span>Choose a free half-hour to fill the form</span>
      </div>
      <Notice error>{availability.error}</Notice>
      {availability.loading ? (
        <Loading />
      ) : (
        <div className="calendar-scroll">
          <div
            className={`calendar-grid ${view}`}
            style={{
              gridTemplateColumns: `64px repeat(${count}, minmax(${view === "week" ? "95" : "180"}px, 1fr))`,
            }}
          >
            <div className="calendar-corner">Time</div>
            {days.map((day) => (
              <div key={day.toISODate()} className="calendar-day">
                <strong>{day.toFormat("ccc")}</strong>
                <span>{day.toFormat("d LLL")}</span>
              </div>
            ))}
            {slots.map((minutes) => {
              const hour = first
                .startOf("day")
                .plus({ minutes })
                .toFormat("HH:mm");
              return (
                <CalendarRow
                  key={minutes}
                  hour={hour}
                  minutes={minutes}
                  days={days}
                  intervals={intervals}
                  now={now}
                  onSelect={onSelect}
                />
              );
            })}
          </div>
        </div>
      )}
      <small className="calendar-footnote">
        Busy intervals contain no requester information. Availability is
        refreshed after each reservation; the server confirms the final result.
      </small>
    </section>
  );
}
function CalendarRow({ hour, minutes, days, intervals, now, onSelect }) {
  return (
    <>
      <div className="time-label">{hour}</div>
      {days.map((day) => {
        const start = day.startOf("day").plus({ minutes }),
          finish = start.plus({ minutes: 30 });
        const busy = intervals.find(
          (b) =>
            DateTime.fromISO(b.starts_at).toMillis() < finish.toMillis() &&
            DateTime.fromISO(b.ends_at).toMillis() > start.toMillis(),
        );
        const past = start.toMillis() <= now;
        return (
          <button
            key={day.toISODate()}
            disabled={Boolean(busy) || past}
            className={`calendar-slot ${busy?.status || ""}`}
            aria-label={`${start.toFormat("ccc d LLL HH:mm")}, ${busy ? busy.status.replaceAll("_", " ") : past ? "past" : "available"}`}
            onClick={() =>
              onSelect(
                start.toFormat("yyyy-MM-dd'T'HH:mm"),
                finish.toFormat("yyyy-MM-dd'T'HH:mm"),
              )
            }
          >
            {busy ? (
              <>
                <strong>{busy.status.replaceAll("_", " ")}</strong>
                <small>
                  {formatTime(busy.starts_at)}–{formatTime(busy.ends_at)}
                </small>
              </>
            ) : (
              <span>{past ? "—" : "Available"}</span>
            )}
          </button>
        );
      })}
    </>
  );
}
export default function ResourceDetail() {
  const { id } = useParams(),
    resource = useApi(`/resources/${id}`);
  const [revision, setRevision] = useState(0),
    [selection, setSelection] = useState(null);
  if (resource.loading) return <Loading />;
  if (resource.error) return <Notice error>{resource.error}</Notice>;
  const r = resource.data;
  return (
    <>
      <Link className="back-link" to="/resources">
        <ArrowLeftIcon />
        All resources
      </Link>
      <div className="page-heading">
        <div>
          <span className="eyebrow">{r.category.name}</span>
          <h1>{r.name}</h1>
          <p>{r.description}</p>
          <div className="resource-facts">
            <span>
              <MapPinIcon />
              {r.location.name}
            </span>
            <span>
              <UsersIcon />
              {r.occupants_capacity} people
            </span>
            <span>
              <ClockIcon />
              {r.opens_at}–{r.closes_at}
            </span>
          </div>
        </div>
        <span className={`policy ${r.requires_approval ? "approval" : ""}`}>
          {r.requires_approval ? "Approval required" : "Instant booking"}
        </span>
      </div>
      <div className="reservation-layout">
        <Calendar
          resource={r}
          revision={revision}
          onSelect={(start, end) => setSelection({ start, end })}
        />
        <aside className="panel reservation-aside">
          <BookingForm
            key={selection?.start || "default"}
            resource={r}
            initialStart={selection?.start}
            initialEnd={selection?.end}
            onSuccess={() => setRevision(revision + 1)}
          />
          <Link className="text-link" to="/my-bookings">
            See my reservations
            <ArrowRightIcon />
          </Link>
        </aside>
      </div>
      <p className="small">
        Organization display timezone: {zone}. Resource opening hours use{" "}
        {r.location.timezone}. Overnight bookings are unsupported.
      </p>
    </>
  );
}
