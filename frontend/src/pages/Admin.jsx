import { useState } from "react";
import { api, query } from "../api";
import { localNow, toUTC } from "../time";
import {
  Dialog,
  Empty,
  Field,
  Loading,
  Notice,
  Pagination,
  useApi,
} from "../ui";
export function Admin() {
  const [version, setVersion] = useState(0),
    [page, setPage] = useState(1),
    [edit, setEdit] = useState(null),
    [blackout, setBlackout] = useState(null),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  const resources = useApi(`/resources?all=true&page=${page}`, version),
    categories = useApi("/categories", version),
    locations = useApi("/locations", version),
    users = useApi("/users?per_page=100", version);
  async function saveResource(event) {
    event.preventDefault();
    setBusy(true);
    setError("");
    const form = event.currentTarget,
      body = Object.fromEntries(new FormData(form));
    for (const key of [
      "occupants_capacity",
      "min_minutes",
      "max_minutes",
      "advance_days",
      "location_id",
      "resource_category_id",
    ])
      body[key] = Number(body[key]);
    body.requires_approval = form.elements.requires_approval.checked;
    body.active = form.elements.active.checked;
    try {
      await api(edit.id ? `/resources/${edit.id}` : "/resources", {
        method: edit.id ? "PATCH" : "POST",
        body: { resource: body },
      });
      setEdit(null);
      setVersion(version + 1);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }
  async function saveBlackout(event) {
    event.preventDefault();
    setBusy(true);
    setError("");
    const form = Object.fromEntries(new FormData(event.currentTarget));
    try {
      await api(`/resources/${blackout.id}/blackouts`, {
        method: "POST",
        body: {
          blackout: {
            ...form,
            starts_at: toUTC(form.starts_at, blackout.location.timezone),
            ends_at: toUTC(form.ends_at, blackout.location.timezone),
          },
        },
      });
      setBlackout(null);
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
          <span className="eyebrow">WORKSPACE SETTINGS</span>
          <h1>Manage resources</h1>
          <p>Give your team the spaces, equipment, and rules they need.</p>
        </div>
        <button
          className="primary"
          onClick={() => {
            setEdit({ active: true });
            setError("");
          }}
        >
          Add resource
        </button>
      </div>
      <Notice error>
        {resources.error || categories.error || locations.error || users.error}
      </Notice>
      {resources.loading ? (
        <Loading />
      ) : (
        <div className="panel table-scroll">
          <table>
            <caption className="sr-only">Workspace resources</caption>
            <thead>
              <tr>
                <th>Resource</th>
                <th>Location</th>
                <th>Policy</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {resources.data?.map((r) => (
                <tr key={r.id}>
                  <td>
                    <strong>{r.name}</strong>
                    <small>
                      {r.identifier} · {r.category.name}
                    </small>
                  </td>
                  <td>{r.location.name}</td>
                  <td>
                    {r.requires_approval
                      ? "Approval required"
                      : "Instant booking"}
                  </td>
                  <td>{r.active ? "Active" : "Archived"}</td>
                  <td>
                    <div className="action-row">
                      <button
                        onClick={() => {
                          setEdit(r);
                          setError("");
                        }}
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => {
                          setBlackout(r);
                          setError("");
                        }}
                      >
                        Maintenance
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <Pagination meta={resources.meta} page={page} setPage={setPage} />
      <div className="admin-settings">
        <CatalogSettings
          kind="category"
          values={categories.data || []}
          onSave={() => setVersion(version + 1)}
        />
        <CatalogSettings
          kind="location"
          values={locations.data || []}
          onSave={() => setVersion(version + 1)}
        />
      </div>
      <section className="panel">
        <h2>Manager location assignments</h2>
        <p className="small">
          Managers can review requests and analytics only in their assigned
          locations.
        </p>
        {users.data
          ?.filter((u) => u.role === "manager")
          .map((user) => (
            <ScopeForm
              key={`${user.id}-${version}`}
              user={user}
              locations={locations.data || []}
              onSave={() => setVersion(version + 1)}
            />
          ))}
      </section>
      {edit && (
        <Dialog
          title={edit.id ? "Edit resource" : "Add resource"}
          onClose={() => setEdit(null)}
        >
          <form onSubmit={saveResource}>
            <div className="form-grid">
              <Field label="Resource name">
                <input
                  name="name"
                  required
                  maxLength="150"
                  defaultValue={edit.name}
                />
              </Field>
              <Field label="Identifier">
                <input
                  name="identifier"
                  required
                  maxLength="150"
                  defaultValue={edit.identifier}
                />
              </Field>
              <Field label="Category">
                <select
                  name="resource_category_id"
                  required
                  defaultValue={edit.resource_category_id || ""}
                >
                  <option value="" disabled>
                    Select category
                  </option>
                  {categories.data?.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </Field>
              <Field label="Location">
                <select
                  name="location_id"
                  required
                  defaultValue={edit.location_id || ""}
                >
                  <option value="" disabled>
                    Select location
                  </option>
                  {locations.data?.map((l) => (
                    <option key={l.id} value={l.id}>
                      {l.name}
                    </option>
                  ))}
                </select>
              </Field>
              <Field label="Occupant capacity">
                <input
                  type="number"
                  name="occupants_capacity"
                  min="1"
                  defaultValue={edit.occupants_capacity || 1}
                  required
                />
              </Field>
              <Field label="Advance booking days">
                <input
                  type="number"
                  name="advance_days"
                  min="1"
                  defaultValue={edit.advance_days || 60}
                  required
                />
              </Field>
              <Field label="Minimum minutes">
                <input
                  type="number"
                  name="min_minutes"
                  min="1"
                  defaultValue={edit.min_minutes || 15}
                  required
                />
              </Field>
              <Field label="Maximum minutes">
                <input
                  type="number"
                  name="max_minutes"
                  min="1"
                  defaultValue={edit.max_minutes || 480}
                  required
                />
              </Field>
              <Field label="Opens at (local)">
                <input
                  type="time"
                  name="opens_at"
                  defaultValue={edit.opens_at || "08:00"}
                  required
                />
              </Field>
              <Field label="Closes at (local)">
                <input
                  type="time"
                  name="closes_at"
                  defaultValue={edit.closes_at || "20:00"}
                  required
                />
              </Field>
            </div>
            <Field label="Description">
              <textarea name="description" defaultValue={edit.description} />
            </Field>
            <label className="checkbox">
              <input
                type="checkbox"
                name="requires_approval"
                defaultChecked={edit.requires_approval}
              />
              Manager approval required
            </label>
            <label className="checkbox">
              <input
                type="checkbox"
                name="active"
                defaultChecked={edit.active}
              />
              Active and visible in catalog
            </label>
            <Notice error>{error}</Notice>
            <button className="primary" disabled={busy}>
              {busy ? "Saving…" : "Save resource"}
            </button>
          </form>
        </Dialog>
      )}
      {blackout && (
        <Dialog
          title={`Maintenance · ${blackout.name}`}
          onClose={() => setBlackout(null)}
        >
          <p>
            Existing active reservations must be moved or cancelled before
            maintenance can be added.
          </p>
          <form onSubmit={saveBlackout}>
            <Field label="Maintenance start">
              <input name="starts_at" type="datetime-local" required />
            </Field>
            <Field label="Maintenance end">
              <input name="ends_at" type="datetime-local" required />
            </Field>
            <Field label="Maintenance reason">
              <input name="reason" required maxLength="250" />
            </Field>
            <Notice error>{error}</Notice>
            <button className="primary" disabled={busy}>
              {busy ? "Saving…" : "Add maintenance"}
            </button>
          </form>
          <BlackoutList id={blackout.id} />
        </Dialog>
      )}
    </>
  );
}
function BlackoutList({ id }) {
  const list = useApi(`/resources/${id}/blackouts`);
  return (
    <div className="small">
      <h3>Scheduled maintenance</h3>
      <Notice error>{list.error}</Notice>
      {list.data?.map((b) => (
        <p key={b.id}>
          {b.reason} · {b.starts_at} to {b.ends_at}
        </p>
      ))}
      {list.data?.length === 0 && <p>No maintenance scheduled.</p>}
    </div>
  );
}
function CatalogSettings({ kind, values, onSave }) {
  const [selected, setSelected] = useState(""),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  const item = values.find((v) => String(v.id) === selected) || {};
  async function save(event) {
    event.preventDefault();
    setBusy(true);
    setError("");
    const form = Object.fromEntries(new FormData(event.currentTarget));
    if (kind === "location")
      form.active = event.currentTarget.elements.active.checked;
    const plural = kind === "category" ? "categories" : "locations";
    try {
      await api(`/${plural}${selected ? `/${selected}` : ""}`, {
        method: selected ? "PATCH" : "POST",
        body: { [kind]: form },
      });
      setSelected("");
      event.target.reset();
      onSave();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }
  async function remove() {
    setBusy(true);
    setError("");
    try {
      await api(`/categories/${selected}`, { method: "DELETE" });
      setSelected("");
      onSave();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <section className="panel">
      <h2>{kind === "category" ? "Categories" : "Locations"}</h2>
      <Field label={`Edit existing ${kind}`}>
        <select value={selected} onChange={(e) => setSelected(e.target.value)}>
          <option value="">Create new</option>
          {values.map((v) => (
            <option key={v.id} value={v.id}>
              {v.name}
            </option>
          ))}
        </select>
      </Field>
      <form key={selected} onSubmit={save}>
        <Field label={`${kind === "category" ? "Category" : "Location"} name`}>
          <input name="name" defaultValue={item.name} required />
        </Field>
        {kind === "category" ? (
          <Field label="Category slug">
            <input
              name="slug"
              pattern="[a-z0-9-]+"
              defaultValue={item.slug}
              required
            />
          </Field>
        ) : (
          <Field label="Location timezone">
            <input
              name="timezone"
              defaultValue={item.timezone || "Asia/Kolkata"}
              required
            />
          </Field>
        )}
        {kind === "location" && (
          <label className="checkbox">
            <input
              name="active"
              type="checkbox"
              defaultChecked={item.active ?? true}
            />
            Location active
          </label>
        )}
        <Notice error>{error}</Notice>
        <div className="action-row">
          <button disabled={busy}>{busy ? "Saving…" : `Save ${kind}`}</button>
          {kind === "category" && selected && (
            <button type="button" onClick={remove} disabled={busy}>
              Delete unused category
            </button>
          )}
        </div>
      </form>
    </section>
  );
}
function ScopeForm({ user, locations, onSave }) {
  const [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  async function save(event) {
    event.preventDefault();
    setBusy(true);
    try {
      const ids = new FormData(event.currentTarget).getAll("location_ids");
      await api(`/manager-scopes/${user.id}`, {
        method: "PUT",
        body: { location_ids: ids },
      });
      onSave();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <form className="scope-form" onSubmit={save}>
      <fieldset>
        <legend>
          {user.display_name} ({user.email})
        </legend>
        {locations.map((l) => (
          <label className="checkbox" key={l.id}>
            <input
              type="checkbox"
              name="location_ids"
              value={l.id}
              defaultChecked={user.location_ids.includes(l.id)}
            />
            {l.name}
          </label>
        ))}
      </fieldset>
      <Notice error>{error}</Notice>
      <button disabled={busy}>{busy ? "Saving…" : "Save assignments"}</button>
    </form>
  );
}
export function Analytics() {
  const [from, setFrom] = useState(localNow().minus({ days: 6 }).toISODate()),
    [to, setTo] = useState(localNow().plus({ days: 1 }).toISODate()),
    [location, setLocation] = useState("");
  const locations = useApi("/locations");
  const data = useApi(
    `/analytics/overview?${query({ from: toUTC(`${from}T00:00`), to: toUTC(`${to}T00:00`), location_id: location })}`,
  );
  const report = data.data;
  function csv() {
    const rows = [
      [
        "Resource",
        "Booked minutes",
        "Available minutes",
        "Utilization percent",
      ],
      ...report.resources.map((r) => [
        r.name,
        r.booked_minutes,
        r.available_minutes,
        r.utilization_percent ?? "",
      ]),
    ];
    const blob = new Blob(
      [
        rows
          .map((row) =>
            row
              .map((value) => `"${String(value).replaceAll('"', '""')}"`)
              .join(","),
          )
          .join("\n"),
      ],
      { type: "text/csv" },
    );
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "reserveops-utilization.csv";
    a.click();
    URL.revokeObjectURL(a.href);
  }
  return (
    <>
      <div className="page-heading">
        <div>
          <span className="eyebrow">UNDERSTAND YOUR WORKSPACE</span>
          <h1>Analytics</h1>
          <p>A clear view of how your team uses shared resources.</p>
        </div>
        <button disabled={!report} onClick={csv}>
          Export CSV
        </button>
      </div>
      <div className="filters panel">
        <Field label="From (inclusive)">
          <input
            type="date"
            value={from}
            onChange={(e) => e.target.value && setFrom(e.target.value)}
          />
        </Field>
        <Field label="To (exclusive)">
          <input
            type="date"
            value={to}
            onChange={(e) => e.target.value && setTo(e.target.value)}
          />
        </Field>
        <Field label="Reporting location">
          <select
            value={location}
            onChange={(e) => setLocation(e.target.value)}
          >
            <option value="">All assigned locations</option>
            {locations.data?.map((l) => (
              <option key={l.id} value={l.id}>
                {l.name}
              </option>
            ))}
          </select>
        </Field>
      </div>
      <Notice error>{data.error}</Notice>
      {data.loading ? (
        <Loading />
      ) : (
        report && (
          <>
            <div className="stat-grid">
              <div className="stat">
                <span>Booking volume</span>
                <strong>{report.booking_volume}</strong>
                <small>Direct requests created in this period</small>
              </div>
              <div className="stat">
                <span>Cancellation rate</span>
                <strong>{report.cancellation_rate_percent}%</strong>
                <small>
                  {report.cancelled_count} of {report.booking_volume} direct
                  submissions
                </small>
              </div>
              <div className="stat">
                <span>Approval turnaround</span>
                <strong>
                  {report.approval_turnaround_minutes ?? "—"}
                  <em>
                    {report.approval_turnaround_minutes !== null ? " min" : ""}
                  </em>
                </strong>
                <small>{report.decision_count} decisions in this period</small>
              </div>
            </div>
            <section className="panel utilization">
              <div className="section-heading">
                <h2>Resource utilization</h2>
                <span className="small">Booked / bookable minutes</span>
              </div>
              {report.resources.length ? (
                report.resources.map((r) => (
                  <div className="utilization-row" key={r.id}>
                    <div>
                      <strong>{r.name}</strong>
                      <small>
                        {r.booked_minutes} / {r.available_minutes} minutes
                      </small>
                    </div>
                    <div className="meter">
                      <span
                        style={{ width: `${r.utilization_percent || 0}%` }}
                      />
                    </div>
                    <strong>
                      {r.utilization_percent === null
                        ? "No bookable hours"
                        : `${r.utilization_percent}%`}
                    </strong>
                  </div>
                ))
              ) : (
                <Empty title="No resources in this scope">
                  Assign manager locations or add resources.
                </Empty>
              )}
            </section>
            <section className="panel metric-definitions">
              <h2>How these numbers are calculated</h2>
              {Object.entries(report.definitions).map(([name, text]) => (
                <p key={name}>
                  <strong>{name[0].toUpperCase() + name.slice(1)}: </strong>
                  {text}
                </p>
              ))}
              <p>
                All intervals are half-open: the end boundary is excluded.
                Opening hours are evaluated in each location’s timezone.
              </p>
            </section>
          </>
        )
      )}
    </>
  );
}
