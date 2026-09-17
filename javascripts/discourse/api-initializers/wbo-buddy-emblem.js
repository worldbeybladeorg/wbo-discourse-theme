import { apiInitializer } from "discourse/lib/api";

// Buddy Emblem overlay.
//
// WordPress owns each member's chosen "Buddy Emblem"; this theme only renders
// it. Rather than store the choice in a Discourse user custom field (which needs
// a server plugin to register an editable field), we fetch buddy art URLs from a
// public WordPress endpoint by username and overlay them on avatars client-side.
//
// The endpoint (a theme setting) returns { buddies: { "<lower-username>": url } }
// for posters who have a buddy set; everyone else is omitted. Results are cached
// for the page's lifetime and requests are batched, so a topic of many posters
// costs one request.
export default apiInitializer((api) => {
  const endpoint = (settings.buddy_emblem_endpoint || "").trim();
  if (!endpoint) {
    return;
  }

  // lower-username -> url string | null (null = known, no buddy). Absent = unknown.
  const cache = new Map();
  const pending = new Set();
  let flushTimer = null;

  function scheduleFlush() {
    if (!flushTimer) {
      flushTimer = setTimeout(flush, 80);
    }
  }

  async function flush() {
    flushTimer = null;
    const batch = [...pending].filter((u) => !cache.has(u));
    pending.clear();
    if (!batch.length) {
      applyAll();
      return;
    }
    try {
      const sep = endpoint.includes("?") ? "&" : "?";
      const url = `${endpoint}${sep}usernames=${encodeURIComponent(
        batch.join(",")
      )}`;
      const res = await fetch(url, { credentials: "omit" });
      const data = await res.json();
      const buddies = (data && data.buddies) || {};
      batch.forEach((u) =>
        cache.set(
          u,
          Object.prototype.hasOwnProperty.call(buddies, u) ? buddies[u] : null
        )
      );
    } catch {
      // Fail closed: remember "no buddy" so a down endpoint can't storm us.
      // Cleared on the next full page load.
      batch.forEach((u) => {
        if (!cache.has(u)) {
          cache.set(u, null);
        }
      });
    }
    applyAll();
  }

  // Resolve the poster username for an avatar <img>. Discourse wraps post
  // avatars in <a data-user-card="Username" href="/u/username">; fall back to
  // parsing the /u/ link for surfaces without the data attribute.
  function usernameFor(img) {
    const card = img.closest("[data-user-card]");
    const name = card && card.getAttribute("data-user-card");
    if (name) {
      return name;
    }
    const a = img.closest('a[href*="/u/"]');
    const m = a && a.getAttribute("href").match(/\/u\/([^/?#]+)/);
    return m ? decodeURIComponent(m[1]) : null;
  }

  function decorate(img) {
    const name = usernameFor(img);
    if (!name) {
      return;
    }
    const key = name.toLowerCase();
    const url = cache.get(key);
    if (url === undefined) {
      pending.add(key);
      scheduleFlush();
      return;
    }
    if (!url) {
      return; // no buddy for this user
    }
    // The immediate wrapper (the data-user-card anchor for posts) boxes just
    // the avatar, so a %-sized badge resolves against the avatar itself.
    const parent = img.parentElement;
    if (!parent || parent.querySelector(":scope > img.wbo-buddy-emblem")) {
      return;
    }
    parent.classList.add("wbo-buddy-parent");
    const badge = document.createElement("img");
    badge.className = "wbo-buddy-emblem";
    badge.src = url;
    badge.setAttribute("aria-hidden", "true");
    badge.setAttribute("loading", "lazy");
    try {
      parent.appendChild(badge);
    } catch {
      // Ember may be mid-teardown of this subtree; the observer re-runs.
    }
  }

  function applyAll() {
    document.querySelectorAll("img.avatar").forEach(decorate);
  }

  function scan(node) {
    if (node.nodeType !== 1) {
      return;
    }
    if (node.matches && node.matches("img.avatar")) {
      decorate(node);
    }
    if (node.querySelectorAll) {
      node.querySelectorAll("img.avatar").forEach(decorate);
    }
  }

  const observer = new MutationObserver((mutations) => {
    for (const m of mutations) {
      if (m.addedNodes) {
        m.addedNodes.forEach(scan);
      }
    }
  });
  observer.observe(document.body, { childList: true, subtree: true });

  api.onPageChange(() => applyAll());
  applyAll();
});
