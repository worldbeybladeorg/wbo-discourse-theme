import { apiInitializer } from "discourse/lib/api";
import { wpBase } from "../lib/wbo-icon";

// Send a member's own Preferences pages to WordPress's Settings page, which
// mirrors them (wbo-core includes/settings/registry.php).
//
// Only the pages listed here move. Everything else stays in Discourse, on
// purpose:
//   • second-factor, security, account, users — WordPress cannot change
//     2FA, passkeys, the password, linked accounts or ignores, and its
//     "Manage" links point at these pages. Redirecting them would loop.
//   • interface, navigation-menu, apps — not mirrored in WordPress.
//   • any page Discourse or a plugin adds later — an unknown page showing
//     natively is harmless; an unknown page nobody can reach is not.
//
// The value is the WordPress tab (/settings/?section=…). "preferences.index"
// is the bare /u/name/preferences link; a direct link to
// /preferences/account is not in the list, so it stays.
const WP_SECTION = {
  "preferences.index": "account",
  "preferences.profile": "profile",
  "preferences.email": "account",
  "preferences.emails": "notifications",
  "preferences.notifications": "notifications",
  "preferences.tracking": "following",
  "preferences.tags": "following",
};

// The username the route is for (/u/:username/…), from the "user" route above
// the preferences page.
function routeUsername(routeInfo) {
  for (let r = routeInfo; r; r = r.parent) {
    if (r.name === "user") {
      return r.params?.username || null;
    }
  }
  return null;
}

export default apiInitializer((api) => {
  if (!settings.redirect_preferences_to_wordpress) {
    return;
  }

  const user = api.getCurrentUser();
  if (!user) {
    return;
  }

  const router = api.container.lookup("service:router");

  // WordPress links here with ?forum=1 for the one thing on a mirrored page
  // it cannot do itself: "Enable Notifications", a browser permission that
  // belongs to the forum's address. That page load stays put (it is the only
  // navigation with nothing before it); any click after it redirects as
  // usual.
  const openedForForum = new URLSearchParams(window.location.search).has(
    "forum"
  );

  router.on("routeWillChange", (transition) => {
    const to = transition.to;
    const section = to && WP_SECTION[to.name];
    if (!section || transition.isAborted) {
      return;
    }
    if (openedForForum && !transition.from) {
      return;
    }

    // Someone else's preferences (staff editing a member) stay in Discourse —
    // the WordPress page only ever edits the signed-in member.
    const username = routeUsername(to);
    if (!username || username.toLowerCase() !== user.username_lower) {
      return;
    }

    // Discourse holds a member on their Profile page until required profile
    // fields are filled in. Leave them there, or they could never finish.
    if (to.name === "preferences.profile" && user.needs_required_fields_check) {
      return;
    }

    const url = `${wpBase()}/settings/?section=${section}`;
    transition.abort();

    if (transition.from) {
      // A click inside the forum: Back returns to the page they were on.
      window.location.assign(url);
    } else {
      // Arrived straight on the preferences URL (typed, bookmarked, from an
      // email): replace it, so Back does not land on it and bounce forward.
      window.location.replace(url);
    }
  });
});
