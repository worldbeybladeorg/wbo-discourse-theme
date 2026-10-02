import { apiInitializer } from "discourse/lib/api";

// The "See N new or updated topics" pill is sticky under the nav
// (scss/topic-list.scss), so it can be tapped from anywhere down the feed.
// Core's handler only inserts the new topics at the top of the list; it
// doesn't scroll, because in core the notice only exists at the top. Take the
// reader back up so they actually see what they asked for.
export default apiInitializer(() => {
  document.addEventListener("click", (event) => {
    if (!event.target.closest?.("#list-area .show-more .alert.clickable")) {
      return;
    }
    const reduceMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;
    window.scrollTo({ top: 0, behavior: reduceMotion ? "auto" : "smooth" });
  });
});
