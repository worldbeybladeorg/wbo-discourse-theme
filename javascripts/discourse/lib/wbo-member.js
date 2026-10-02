import { TrackedMap } from "@ember-compat/tracked-built-ins";
import { wpBase } from "./wbo-icon";

// Public WordPress profile data for any forum member — role pills and the
// WordPress profile URL — from the same endpoint the account panel reads
// (GET /wp-json/wbo/v1/user-menu). Fetched without the WordPress cookie, so
// it is only ever the public tier, whoever is looking.
//
// lower-username -> data object | null (no linked WordPress account, or the
// request failed). Absent = not fetched yet. Tracked, so a template reading
// memberData() re-renders when the fetch lands.
const results = new TrackedMap();
const inflight = new Set();

export function memberData(username) {
  const key = (username || "").toLowerCase();
  if (!key) {
    return null;
  }
  if (!results.has(key) && !inflight.has(key)) {
    inflight.add(key);
    const url = `${wpBase()}/wp-json/wbo/v1/user-menu?username=${encodeURIComponent(key)}`;
    fetch(url, { credentials: "omit" })
      .then((r) => (r.ok ? r.json() : null))
      .catch(() => null)
      .then((data) => {
        inflight.delete(key);
        results.set(key, data?.found ? data : null);
      });
  }
  return results.get(key);
}
