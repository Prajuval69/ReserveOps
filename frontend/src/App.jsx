import { createContext, useContext, useEffect, useState } from "react";
import {
  Link,
  NavLink,
  Navigate,
  Route,
  Routes,
  useNavigate,
} from "react-router-dom";
import {
  SquaresFourIcon,
  CalendarBlankIcon,
  BuildingsIcon,
  CheckCircleIcon,
  ChartBarIcon,
  BellIcon,
  SignOutIcon,
  ListIcon,
  ArrowUpRightIcon,
} from "@phosphor-icons/react";
import { api, bootstrap } from "./api";
import { localNow } from "./time";
import { Field, Loading, Notice } from "./ui";
import { Catalog, Dashboard } from "./pages/Catalog";
import ResourceDetail from "./pages/ResourceDetail";
import { Bookings, Approvals, Notifications } from "./pages/Bookings";
import { Admin, Analytics } from "./pages/Admin";
const AuthContext = createContext(null);
export const useAuth = () => useContext(AuthContext);

export default function App() {
  const [user, setUser] = useState(null),
    [loading, setLoading] = useState(true),
    [initialError, setInitialError] = useState("");
  useEffect(() => {
    let active = true;
    bootstrap()
      .then(() => api("/auth/me"))
      .then((result) => {
        if (active) setUser(result.data);
      })
      .catch((error) => {
        if (active && error.status !== 401)
          setInitialError(
            "Cannot reach ReserveOps. Check that the Rails API is running.",
          );
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, []);
  if (loading)
    return (
      <main className="boot">
        <Loading />
      </main>
    );
  return (
    <AuthContext.Provider value={{ user, setUser }}>
      <Routes>
        <Route
          path="/login"
          element={
            user ? (
              <Navigate to="/" replace />
            ) : (
              <Login initialError={initialError} />
            )
          }
        />
        <Route
          path="/*"
          element={user ? <Shell /> : <Navigate to="/login" replace />}
        />
      </Routes>
    </AuthContext.Provider>
  );
}
function Login({ initialError }) {
  const { setUser } = useAuth();
  const [error, setError] = useState(initialError),
    [busy, setBusy] = useState(false);
  async function submit(event) {
    event.preventDefault();
    setError("");
    setBusy(true);
    const fields = Object.fromEntries(new FormData(event.currentTarget));
    try {
      const result = await api("/auth/login", { method: "POST", body: fields });
      setUser(result.data);
    } catch (error) {
      setError(error.message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <main className="login-layout">
      <section className="login-story">
        <Link className="brand" to="/">
          <span className="brand-mark">
            <SquaresFourIcon weight="fill" />
          </span>
          ReserveOps
        </Link>
        <div>
          <span className="eyebrow">MAKE ROOM FOR GOOD WORK</span>
          <h1>
            Your workspace.
            <br />
            Your next great idea.
          </h1>
          <p>
            Find a quiet corner, bring the team together, or get the right
            equipment. A better workday starts here.
          </p>
          <div className="story-lines">
            <span>Rooms for collaboration</span>
            <span>Space to focus</span>
            <span>Equipment that’s ready</span>
          </div>
        </div>
        <small>One shared workspace. Everything in its place.</small>
      </section>
      <section className="login-form">
        <div>
          <span className="eyebrow">WELCOME BACK</span>
          <h2>Let’s get you settled.</h2>
          <p>Sign in with your organization account.</p>
          <form onSubmit={submit}>
            <Field label="Email address">
              <input
                name="email"
                type="email"
                autoComplete="username"
                required
                placeholder="you@reserveops.local"
              />
            </Field>
            <Field label="Password">
              <input
                name="password"
                type="password"
                autoComplete="current-password"
                required
              />
            </Field>
            <Notice error>{error}</Notice>
            <button className="primary" disabled={busy}>
              {busy ? "Signing in…" : "Sign in"}
              <ArrowUpRightIcon />
            </button>
          </form>
          <p className="small">
            Local demo accounts and setup instructions are in the project
            README.
          </p>
        </div>
      </section>
    </main>
  );
}
function Shell() {
  const { user, setUser } = useAuth();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false),
    [error, setError] = useState("");
  const manager = ["admin", "manager"].includes(user.role);
  const links = [
    ["/", "Overview", SquaresFourIcon],
    ["/resources", "Resources", BuildingsIcon],
    ["/my-bookings", "My bookings", CalendarBlankIcon],
    ...(manager
      ? [
          ["/approvals", "Approvals", CheckCircleIcon],
          ["/analytics", "Analytics", ChartBarIcon],
        ]
      : []),
    ["/notifications", "Notifications", BellIcon],
    ...(user.role === "admin"
      ? [["/admin/resources", "Manage workspace", BuildingsIcon]]
      : []),
  ];
  async function logout() {
    try {
      await api("/auth/logout", { method: "POST" });
      setUser(null);
      navigate("/login");
    } catch (e) {
      setError(e.message);
    }
  }
  return (
    <div className="app-shell">
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <aside className={`sidebar ${open ? "open" : ""}`}>
        <Link className="brand" to="/" onClick={() => setOpen(false)}>
          <span className="brand-mark">
            <SquaresFourIcon weight="fill" />
          </span>
          ReserveOps
        </Link>
        <div className="workspace-label">
          <span className="workspace-dot" />
          Your workspace<small>Internal reservations</small>
        </div>
        <nav aria-label="Main navigation">
          {links.map(([path, label, Icon]) => (
            <NavLink
              key={path}
              to={path}
              end={path === "/"}
              onClick={() => setOpen(false)}
            >
              <Icon size={20} />
              {label}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-bottom">
          <div className="workspace-tip">
            <strong>A little space goes a long way.</strong>
            <p>
              Release a reservation when plans change so someone else can use
              it.
            </p>
          </div>
          <button className="account" onClick={logout}>
            <span className="avatar">
              {user.display_name
                .split(" ")
                .map((n) => n[0])
                .slice(0, 2)
                .join("")}
            </span>
            <span>
              <strong>{user.display_name}</strong>
              <small>{user.role}</small>
            </span>
            <SignOutIcon size={19} />
          </button>
        </div>
      </aside>
      <div className="main-column">
        <header className="topbar">
          <button
            className="mobile-toggle icon-button"
            aria-label="Toggle navigation"
            aria-expanded={open}
            onClick={() => setOpen(!open)}
          >
            <ListIcon size={24} />
          </button>
          <span>
            Workspace / <strong>Reservations</strong>
          </span>
          <div>
            <span className="today-label">
              {localNow().toFormat("ccc, d LLL yyyy")}
            </span>
            <Link
              className="icon-button"
              to="/notifications"
              aria-label="Notifications"
            >
              <BellIcon size={21} />
            </Link>
          </div>
        </header>
        <main id="main" className="main-content">
          <Notice error>{error}</Notice>
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/resources" element={<Catalog />} />
            <Route path="/resources/:id" element={<ResourceDetail />} />
            <Route path="/my-bookings" element={<Bookings />} />
            <Route path="/notifications" element={<Notifications />} />
            <Route
              path="/approvals"
              element={manager ? <Approvals /> : <Navigate to="/" />}
            />
            <Route
              path="/analytics"
              element={manager ? <Analytics /> : <Navigate to="/" />}
            />
            <Route
              path="/admin/resources"
              element={user.role === "admin" ? <Admin /> : <Navigate to="/" />}
            />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </main>
        <footer className="app-footer">
          <span>ReserveOps</span>
          <span>Times displayed in {user.timezone}</span>
        </footer>
      </div>
    </div>
  );
}
