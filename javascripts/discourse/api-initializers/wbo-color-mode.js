import { apiInitializer } from "discourse/lib/api";

// Keep the forum's light/dark mode on the member's account setting.
//
// Discourse picks the colour stylesheet on the server from, in order, the
// `forced_color_mode` cookie and then the account's interface_color_mode.
// The cookie is per-browser, so once set it would shadow a change made
// anywhere else — on another device, or on WordPress, which mirrors its
// Appearance setting into interface_color_mode (wbo-core
// includes/discourse/user-menu.php). For signed-in members, bring the cookie
// back in line with the account on every load.
const COOKIE = { 1: "auto", 2: "light", 3: "dark" };

function readCookie(name) {
  const m = document.cookie.match(new RegExp(`(?:^|; )${name}=([^;]*)`));
  return m ? decodeURIComponent(m[1]) : null;
}

export default apiInitializer((api) => {
  const user = api.getCurrentUser();
  const want = COOKIE[user?.user_option?.interface_color_mode];
  if (!want || readCookie("forced_color_mode") === want) {
    return;
  }

  const interfaceColor = api.container.lookup("service:interface-color");
  if (want === "light") {
    interfaceColor.forceLightMode();
  } else if (want === "dark") {
    interfaceColor.forceDarkMode();
  } else {
    interfaceColor.useAutoMode();
  }
});
