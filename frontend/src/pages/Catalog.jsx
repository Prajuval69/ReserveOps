import { useState } from "react";
import { Link } from "react-router-dom";
import {
  ArrowRightIcon,
  BuildingsIcon,
  UsersIcon,
  MapPinIcon,
  CalendarBlankIcon,
  CheckCircleIcon,
} from "@phosphor-icons/react";
import { useAuth } from "../App";
import { query } from "../api";
import { formatDate, formatTime, localNow } from "../time";
import {
  Empty,
  Field,
  Loading,
  Notice,
  Pagination,
  Status,
  useApi,
} from "../ui";
export function ResourceCard({ resource }) {
  const category = resource.category.slug;
  return (
    <article className="resource-card">
      <div className={`resource-visual ${category}`}>
        <BuildingsIcon weight="duotone" size={58} />
        <span>{resource.identifier}</span>
      </div>
      <div className="resource-copy">
        <div className="card-meta">
          <span>{resource.category.name}</span>
          <span
            className={`policy ${resource.requires_approval ? "approval" : ""}`}
          >
            {resource.requires_approval
              ? "Approval required"
              : "Instant booking"}
          </span>
        </div>
        <h3>
          <Link to={`/resources/${resource.id}`}>{resource.name}</Link>
        </h3>
        <p>{resource.description}</p>
        <div className="resource-facts">
          <span>
            <MapPinIcon />
            {resource.location.name}
          </span>
          <span>
            <UsersIcon />
            {resource.occupants_capacity}{" "}
            {resource.occupants_capacity === 1 ? "person" : "people"}
          </span>
        </div>
        <Link className="card-link" to={`/resources/${resource.id}`}>
          View availability
          <ArrowRightIcon />
        </Link>
      </div>
    </article>
  );
}
export function Catalog({ compact = false }) {
  const [search, setSearch] = useState(""),
    [location, setLocation] = useState(""),
    [category, setCategory] = useState(""),
    [page, setPage] = useState(1);
  const resources = useApi(
    `/resources?${query({ q: search, location_id: location, category_id: category, page, per_page: compact ? 3 : 9 })}`,
  );
  const locations = useApi("/locations"),
    categories = useApi("/categories");
  return (
    <section>
      {!compact && (
        <div className="page-heading">
          <div>
            <span className="eyebrow">FIND YOUR SPACE</span>
            <h1>Resources</h1>
            <p>The right place and tools for whatever’s next.</p>
          </div>
          <span className="subtle-tag">
            {resources.meta?.total ?? "…"} resources
          </span>
        </div>
      )}
      {compact ? (
        <div className="section-heading">
          <h2>Find a space that fits</h2>
          <Link to="/resources">
            Explore all resources
            <ArrowRightIcon />
          </Link>
        </div>
      ) : (
        <div className="filters panel">
          <Field label="Search resources">
            <input
              type="search"
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
              placeholder="Room, desk, equipment…"
            />
          </Field>
          <Field label="Location">
            <select
              value={location}
              onChange={(e) => {
                setLocation(e.target.value);
                setPage(1);
              }}
            >
              <option value="">All locations</option>
              {locations.data?.map((l) => (
                <option key={l.id} value={l.id}>
                  {l.name}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Category">
            <select
              value={category}
              onChange={(e) => {
                setCategory(e.target.value);
                setPage(1);
              }}
            >
              <option value="">All categories</option>
              {categories.data?.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </Field>
        </div>
      )}
      <Notice error>
        {resources.error || locations.error || categories.error}
      </Notice>
      {resources.loading ? (
        <Loading />
      ) : resources.data?.length ? (
        <div className="resource-grid">
          {resources.data.map((r) => (
            <ResourceCard key={r.id} resource={r} />
          ))}
        </div>
      ) : (
        <Empty title="No resources found">
          Try a different search or location.
        </Empty>
      )}
      {!compact && (
        <Pagination meta={resources.meta} page={page} setPage={setPage} />
      )}
    </section>
  );
}
export function Dashboard() {
  const { user } = useAuth();
  const bookings = useApi("/dashboard"),
    notifications = useApi("/notifications?per_page=5");
  const upcoming = bookings.data?.upcoming || [];
  const pending = bookings.data?.pending_count ?? 0;
  const waiting = bookings.data?.waitlist_count ?? 0;
  return (
    <>
      <div className="page-heading">
        <div>
          <span className="eyebrow">YOUR WORKDAY, IN SYNC</span>
          <h1>Hello, {user.display_name.split(" ")[0]}.</h1>
          <p>A little planning. A lot of room for good work.</p>
        </div>
        <Link to="/resources" className="primary">
          <span>Reserve a resource</span>
          <ArrowRightIcon />
        </Link>
      </div>
      <div className="overview-banner">
        <div>
          <span className="banner-label">A SPACE FOR WHAT’S NEXT</span>
          <h2>
            Good work starts
            <br />
            with the right space.
          </h2>
          <p>
            Find a room, settle into a desk, or gear up for your next project.
          </p>
          <Link to="/resources">
            Explore your workspace
            <ArrowRightIcon />
          </Link>
        </div>
        <div className="workspace-art" aria-hidden="true">
          <div className="art-wall" />
          <div className="art-window" />
          <div className="art-table" />
          <div className="art-chair one" />
          <div className="art-chair two" />
          <div className="art-plant" />
          <span className="art-label">ROOM TO THINK.</span>
        </div>
      </div>
      <div className="stat-grid">
        <div className="stat">
          <CalendarBlankIcon />
          <span>Upcoming reservations</span>
          <strong>{bookings.loading ? "—" : upcoming.length}</strong>
          <small>Your next plans, all in one place</small>
        </div>
        <div className="stat">
          <CheckCircleIcon />
          <span>Awaiting approval</span>
          <strong>{bookings.loading ? "—" : pending}</strong>
          <small>We’ll notify you when it’s decided</small>
        </div>
        <div className="stat">
          <UsersIcon />
          <span>On the waitlist</span>
          <strong>{bookings.loading ? "—" : waiting}</strong>
          <small>Keeping your place in the queue</small>
        </div>
      </div>
      <Notice error>{bookings.error || notifications.error}</Notice>
      <div className="dashboard-columns">
        <section className="panel">
          <div className="section-heading">
            <h2>Coming up</h2>
            <Link to="/my-bookings">
              View bookings
              <ArrowRightIcon />
            </Link>
          </div>
          {bookings.loading ? (
            <Loading />
          ) : upcoming.length ? (
            upcoming.slice(0, 3).map((b) => (
              <Link to="/my-bookings" className="upcoming-row" key={b.id}>
                <span className="date-tile">
                  <strong>
                    {formatDate(b.starts_at).split(", ")[1]?.split(" ")[0]}
                  </strong>
                  <small>{formatDate(b.starts_at).split(" ").at(-1)}</small>
                </span>
                <div>
                  <strong>{b.resource.name}</strong>
                  <small>
                    {formatDate(b.starts_at)} · {formatTime(b.starts_at)}–
                    {formatTime(b.ends_at)}
                  </small>
                </div>
                <Status value={b.status} />
              </Link>
            ))
          ) : (
            <Empty title="Your next reservation starts here">
              Explore resources and make room for your plans.
            </Empty>
          )}
        </section>
        <section className="panel activity">
          <div className="section-heading">
            <h2>Workspace updates</h2>
            <Link to="/notifications">View all</Link>
          </div>
          {notifications.data?.slice(0, 3).map((n) => (
            <div key={n.id} className="activity-row">
              <span className={`activity-dot ${n.read_at ? "read" : ""}`} />
              <div>
                <strong>{n.title}</strong>
                <p>{n.body}</p>
                <small>{formatDate(n.created_at)}</small>
              </div>
            </div>
          ))}
          {!notifications.loading && !notifications.data?.length && (
            <Empty title="You’re all caught up">
              Updates will appear here as your plans take shape.
            </Empty>
          )}
        </section>
      </div>
      <Catalog compact />
      <div className="workspace-note">
        <CheckCircleIcon size={20} />
        <span>
          Plans changed? Cancel your reservation to free up space for a
          teammate.
        </span>
        <small>{localNow().toFormat("ZZZZ")}</small>
      </div>
    </>
  );
}
