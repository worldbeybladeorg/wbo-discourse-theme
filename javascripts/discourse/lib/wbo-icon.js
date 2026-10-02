import { htmlSafe } from "@ember/template";
import { ICON_PATHS } from "./wbo-icons";

// Phosphor icons the forum uses that WordPress's set (wbo-icons.js, generated
// -- don't add them there) doesn't have. Same 256 viewBox, fill-based.
const FORUM_ICON_PATHS = {
  // Bold, so it reads as the "+" in the "+ New topic" button label.
  "plus-bold":
    '<path d="M228,128a12,12,0,0,1-12,12H140v76a12,12,0,0,1-24,0V140H40a12,12,0,0,1,0-24h76V40a12,12,0,0,1,24,0v76h76A12,12,0,0,1,228,128Z"/>',
};

// The same markup WordPress's wbo_icon() emits (inc/icons.php): Phosphor
// Regular, fill-based, coloured by CSS `color`. Decorative by default.
export function wboIcon(name, size, className = "") {
  const inner = ICON_PATHS[name] || FORUM_ICON_PATHS[name] || "";
  const dim = size ? ` width="${size}" height="${size}"` : "";
  return htmlSafe(
    `<svg class="wbo-icon ${className}"${dim} viewBox="0 0 256 256" ` +
      `fill="currentColor" aria-hidden="true" focusable="false">${inner}</svg>`
  );
}

// WordPress's base URL, from the theme setting (no trailing slash).
export function wpBase() {
  return (settings.wp_base_url || "https://worldbeyblade.org").replace(
    /\/+$/,
    ""
  );
}
