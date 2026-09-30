import { htmlSafe } from "@ember/template";
import { ICON_PATHS } from "./wbo-icons";

// The same markup WordPress's wbo_icon() emits (inc/icons.php): Phosphor
// Regular, fill-based, coloured by CSS `color`. Decorative by default.
export function wboIcon(name, size, className = "") {
  const inner = ICON_PATHS[name] || "";
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
