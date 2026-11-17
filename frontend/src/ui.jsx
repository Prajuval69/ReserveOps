import { cloneElement, useEffect, useId, useRef, useState } from "react";
import { api } from "./api";
export function useApi(path, version = 0) {
  const key = `${path}:${version}`;
  const [state, setState] = useState({ key: null });
  useEffect(() => {
    const controller = new AbortController();
    api(path, { signal: controller.signal })
      .then((result) => {
        if (!controller.signal.aborted)
          setState({ ...result, key, loading: false, error: "" });
      })
      .catch((error) => {
        if (error.name !== "AbortError")
          setState({ key, loading: false, data: null, error: error.message });
      });
    return () => controller.abort();
  }, [path, version, key]);
  return state.key === key ? state : { loading: true, data: null, error: "" };
}
export function Notice({ children, error = false }) {
  return children ? (
    <div
      className={`notice ${error ? "error" : ""}`}
      role={error ? "alert" : "status"}
    >
      {children}
    </div>
  ) : null;
}
export function Loading() {
  return (
    <div role="status" aria-label="Loading" className="skeleton">
      <div />
      <div />
      <div />
    </div>
  );
}
export function Empty({ title = "Nothing here yet", children }) {
  return (
    <div className="empty">
      <h3>{title}</h3>
      <p>{children}</p>
    </div>
  );
}
export function Status({ value }) {
  return (
    <span className={`status ${value}`}>{value.replaceAll("_", " ")}</span>
  );
}
export function Field({ label, children, help }) {
  const generatedId = useId();
  const id = children.props.id || generatedId;
  return (
    <div className="field">
      <label htmlFor={id}>{label}</label>
      {cloneElement(children, {
        id,
        "aria-describedby": help ? `${id}-help` : undefined,
      })}
      {help && <small id={`${id}-help`}>{help}</small>}
    </div>
  );
}
export function Pagination({ meta, page, setPage }) {
  return meta?.total > meta?.per_page ? (
    <div className="pagination">
      <button disabled={page <= 1} onClick={() => setPage(page - 1)}>
        Previous
      </button>
      <span>
        Page {page} of {Math.ceil(meta.total / meta.per_page)}
      </span>
      <button
        disabled={page * meta.per_page >= meta.total}
        onClick={() => setPage(page + 1)}
      >
        Next
      </button>
    </div>
  ) : null;
}
export function Dialog({ title, onClose, children }) {
  const ref = useRef(null);
  useEffect(() => {
    const element = ref.current;
    element.showModal();
    return () => element.close();
  }, []);
  return (
    <dialog ref={ref} onCancel={onClose} aria-label={title}>
      <div className="dialog-head">
        <h2>{title}</h2>
        <button
          className="icon-button"
          aria-label="Close dialog"
          onClick={onClose}
        >
          ×
        </button>
      </div>
      {children}
    </dialog>
  );
}
