import { DateTime } from "luxon";
export const zone = import.meta.env.VITE_APP_TIMEZONE || "Asia/Kolkata";
export const localNow = () => DateTime.now().setZone(zone);
export const formatTime = (value) =>
  DateTime.fromISO(value).setZone(zone).toFormat("h:mm a");
export const formatDate = (value) =>
  DateTime.fromISO(value).setZone(zone).toFormat("ccc, d LLL");
export function toUTC(value, timezone = zone) {
  const date = DateTime.fromISO(value, { zone: timezone });
  if (!date.isValid) throw new Error("Choose a valid date and time.");
  return date.toUTC().toISO();
}
