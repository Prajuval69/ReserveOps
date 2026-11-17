let csrfToken;
let bootstrapPromise;
export class ApiError extends Error {
  constructor(message, status, code, details) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}
export async function api(path, { method = "GET", body, signal } = {}) {
  if (method !== "GET" && !csrfToken) await bootstrap();
  const response = await fetch(`/api/v1${path}`, {
    method,
    credentials: "include",
    signal,
    headers: {
      Accept: "application/json",
      ...(body ? { "Content-Type": "application/json" } : {}),
      ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  if (response.status === 204) {
    if (path === "/auth/logout") {
      csrfToken = undefined;
      await bootstrap();
    }
    return { data: null };
  }
  const content = await response.json().catch(() => ({}));
  if (!response.ok) {
    if (content.error?.code === "INVALID_CSRF") csrfToken = undefined;
    throw new ApiError(
      content.error?.message || "The server could not complete your request.",
      response.status,
      content.error?.code,
      content.error?.details,
    );
  }
  if (content.csrf_token) csrfToken = content.csrf_token;
  return content;
}
export async function bootstrap() {
  if (!bootstrapPromise) {
    bootstrapPromise = api("/auth/csrf")
      .then((result) => {
        csrfToken = result.data.csrf_token;
      })
      .finally(() => {
        bootstrapPromise = undefined;
      });
  }
  return bootstrapPromise;
}
export function query(values) {
  return new URLSearchParams(
    Object.entries(values).filter(
      ([, v]) => v !== "" && v !== null && v !== undefined,
    ),
  ).toString();
}
