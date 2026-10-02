import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { concat } from "@ember/helper";
import bodyClass from "discourse/helpers/body-class";
import icon from "discourse/helpers/d-icon";
import { getOwner } from "@ember/application";
import Composer from "discourse/models/composer";
import WboUserPanel, { loadMenu } from "../../components/wbo-user-panel";
import { wboIcon, wpBase } from "../../lib/wbo-icon";

// Reuse Discourse's own categories section so we get:
//   - unread/new counts wired to TopicTrackingState (live)
//   - the user's own sidebar category picks (or top-N fallback)
//   - category permissions (private categories omitted)
//   - "All categories" link
//   - resilience to categories being added/renamed
// NOTE: these are internal component paths, not a public plugin API. They
// are re-verified for each Discourse upgrade. Currently reads the running
// instance at 2026.4.0-latest.
import UserCategoriesSection from "discourse/components/sidebar/user/categories-section";
import AnonymousCategoriesSection from "discourse/components/sidebar/anonymous/categories-section";

// Fallback used when the `nav_items` theme setting is empty or malformed.
// The setting (settings.yml) holds the same shape as JSON and is the
// source of truth in normal operation -- edit the menu there, no deploy
// needed. Kept in sync as the safety net.
const DEFAULT_NAV_ITEMS = [
  { label: "Tournaments", url: "https://worldbeyblade.org/tournaments/" },
  { label: "Leagues", url: "https://leaderboard.fighting-spirits.org/" },
  { label: "Resources", url: "https://worldbeyblade.org/resources/" },
  { label: "Community", url: "/", active: true, isCommunity: true },
];

export default class WboSiteNav extends Component {
  @service router;
  @service currentUser;
  @service siteSettings;
  @service composer;
  @service topicTrackingState;
  @service header;

  @tracked isDrawerOpen = false;
  @tracked isUserDropdownOpen = false;
  @tracked totalUnread = 0;
  @tracked totalNew = 0;

  constructor() {
    super(...arguments);

    this._refreshCounts();
    this._loadMenuData();
    this._trackingCallbackId = this.topicTrackingState?.onStateChange(() =>
      this._refreshCounts()
    );

    // Close the drawer on any route change — covers taps on category
    // links rendered by Discourse's own CategoriesSection component (we
    // don't own their click handlers) and normal back/forward navigation.
    this.router.on("routeDidChange", this._closeOnRouteChange);

    // Custom user-menu dropdown: close on any click outside the pill, and
    // on Escape. Kept in one place so it's easy to remove if the mount
    // point ever changes. Listeners run in capture phase so we win the
    // race against any other outside-click handler on the page.
    document.addEventListener("click", this._closeUserDropdownOnOutside, true);
    document.addEventListener("keydown", this._closeUserDropdownOnEscape);
  }

  willDestroy() {
    super.willDestroy?.(...arguments);
    if (this._trackingCallbackId) {
      this.topicTrackingState?.offStateChange(this._trackingCallbackId);
    }
    this.router.off("routeDidChange", this._closeOnRouteChange);
    document.removeEventListener(
      "click",
      this._closeUserDropdownOnOutside,
      true
    );
    document.removeEventListener("keydown", this._closeUserDropdownOnEscape);
  }

  // Outside click closes the account panel and is swallowed, as on
  // WordPress — on phones the dimmed page around the bottom sheet is the
  // panel's own shadow, so a tap there must close it rather than follow
  // whatever link sits underneath.
  _closeUserDropdownOnOutside = (event) => {
    if (!this.isUserDropdownOpen) return;
    const target = event.target;
    if (!target || target.closest?.(".wbo-user-menu-wrap")) return;
    event.preventDefault();
    event.stopPropagation();
    this.isUserDropdownOpen = false;
  };

  _closeUserDropdownOnEscape = (event) => {
    if (event.key !== "Escape") return;
    if (this.isUserDropdownOpen) {
      this.isUserDropdownOpen = false;
    }
    if (this.isDrawerOpen) {
      this.isDrawerOpen = false;
    }
  };

  // Close the drawer and the account panel on any route change — covers
  // taps on category links rendered by Discourse's own CategoriesSection
  // (we don't own their click handlers) and back/forward navigation.
  _closeOnRouteChange = () => {
    if (this.isDrawerOpen) {
      this.isDrawerOpen = false;
    }
    if (this.isUserDropdownOpen) {
      this.isUserDropdownOpen = false;
    }
  };

  _refreshCounts() {
    if (!this.currentUser) {
      this.totalUnread = 0;
      this.totalNew = 0;
      return;
    }
    this.totalUnread = this.topicTrackingState?.countUnread?.() ?? 0;
    this.totalNew = this.topicTrackingState?.countNew?.() ?? 0;
  }

  // Latest routes to /latest, which surfaces both unread and new topics.
  // Its badge is unread+new so a single indicator covers everything users
  // would want to see under "Latest".
  get latestBadge() {
    return this.totalUnread + this.totalNew;
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  get navItems() {
    // `settings` is the theme-settings global injected into theme JS.
    const raw = settings.nav_items;
    let items = DEFAULT_NAV_ITEMS;
    if (raw) {
      try {
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed) && parsed.length) {
          items = parsed;
        }
      } catch {
        // Malformed JSON in the setting -- fall through to the default
        // so the nav never renders empty.
      }
    }

    // Community is baked as active in the setting, but auth/account flows
    // ({login, signup, password-reset, email-login, invites, ...}) live in
    // Discourse without being part of the Community section — active state
    // should follow the intent (browsing the forum), not the fact that
    // the URL is on the Discourse origin.
    const communityActive = this._isCommunityActiveRoute();
    return items.map((item) =>
      item.isCommunity ? { ...item, active: communityActive } : item
    );
  }

  _isCommunityActiveRoute() {
    const route = this.router.currentRouteName || "";
    // Prefix match — Ember route names dot-delimit sub-routes (e.g.
    // `password-reset.token`, `invites.show`), so `startsWith` catches
    // the whole subtree with one entry.
    const NON_COMMUNITY_ROUTE_PREFIXES = [
      "login",
      "signup",
      "password-reset",
      "email-login",
      "invites",
      "account-created",
      "associate-account",
    ];
    return !NON_COMMUNITY_ROUTE_PREFIXES.some(
      (prefix) => route === prefix || route.startsWith(prefix + ".")
    );
  }

  get logoUrl() {
    return this.siteSettings.logo_url || this.siteSettings.logo || null;
  }

  get userAvatarUrl() {
    return this.currentUser?.avatar_template?.replace("{size}", "64") ?? null;
  }

  get CategoriesSection() {
    return this.currentUser
      ? UserCategoriesSection
      : AnonymousCategoriesSection;
  }

  // ── Create / reply context ────────────────────────────────────────────────

  get currentTopic() {
    const route = this.router.currentRouteName || "";
    if (!route.startsWith("topic.")) {
      return null;
    }
    const owner = getOwner(this);
    const topicController = owner?.lookup?.("controller:topic");
    return (
      topicController?.model ??
      this.router.currentRoute?.attributes?.topic ??
      this.router.currentRoute?.attributes ??
      null
    );
  }

  get currentCategory() {
    return this.router.currentRoute?.attributes?.category ?? null;
  }

  get isOnTopic() {
    return !!this.currentTopic;
  }

  get canReplyToTopic() {
    const t = this.currentTopic;
    if (!t || !this.currentUser) return false;
    if (t.archived || t.closed) return false;

    // Discourse's canonical check — covers permissions, consecutive-reply
    // throttling, post limits, group restrictions, etc. Conservative: if
    // we can't determine the flag, hide the button rather than show a
    // broken one.
    const details = t.details ?? t.get?.("details");
    const flag =
      details?.can_create_post ??
      details?.get?.("can_create_post") ??
      t.can_create_post ??
      t.get?.("can_create_post");

    return flag === true;
  }

  get canCreateTopic() {
    if (!this.currentUser) return false;
    const route = this.router.currentRouteName || "";
    return [
      "discovery.",
      "tag.",
      "tags.",
      "categories",
    ].some((prefix) => route.startsWith(prefix));
  }

  get showCreateButton() {
    return this.isOnTopic ? this.canReplyToTopic : this.canCreateTopic;
  }

  get createButtonIcon() {
    return this.isOnTopic ? "reply" : "plus";
  }

  get createButtonLabel() {
    return this.isOnTopic ? "Reply" : "New post";
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  @action
  toggleDrawer() {
    this.isDrawerOpen = !this.isDrawerOpen;
  }

  @action
  closeDrawer() {
    this.isDrawerOpen = false;
  }

  // On admin pages, Discourse's own sidebar holds the admin menu (Settings,
  // Users, Plugins…). The WBO drawer replaces that sidebar's toggle on
  // mobile, so it offers a way back in: close the WBO drawer and open
  // Discourse's (wbo-site-nav.scss unlocks it on admin routes only).
  get isAdminRoute() {
    const route = this.router.currentRouteName || "";
    return route === "admin" || route.startsWith("admin");
  }

  @action
  openAdminMenu() {
    this.isDrawerOpen = false;
    this.header.hamburgerVisible = true;
  }

  // Discourse's outside-close listens on the document at mousedown /
  // pointerdown / touchstart, all of which fire BEFORE `click`. Any of
  // those bubbling from the bell would close an open user menu, and then
  // our click-time proxy would reopen it. Snapshot the panel's open state
  // at pointerdown and stop those events from bubbling to Discourse's
  // outside-close listener. `click` then reads the snapshot to decide
  // whether to toggle (menu was closed → open it) or stay quiet (menu was
  // open → the tap counts as the close).
  _wasMenuOpenAtPointerDown = false;

  @action
  bellPointerDown(event) {
    this._wasMenuOpenAtPointerDown = !!document.querySelector(
      ".user-menu.revamped, .hamburger-panel .user-menu"
    );
    event?.stopPropagation();
  }

  @action
  openDiscourseUserMenu(event) {
    event?.stopPropagation();
    if (this._wasMenuOpenAtPointerDown) {
      // The user tapped the bell to close an open panel. Close it by
      // clicking the native trigger; without the pointerdown short-
      // circuit above, this same click would have re-opened it after
      // outside-close already fired.
      this._wasMenuOpenAtPointerDown = false;
    }
    const btn =
      document.querySelector(
        ".d-header-icons .header-dropdown-toggle.current-user button"
      ) ||
      document.querySelector(".d-header-icons .current-user button") ||
      document.querySelector(".header-dropdown-toggle.current-user button");
    btn?.click();
  }

  @action
  toggleUserDropdown(event) {
    // Stop the click from immediately reaching the outside-click closer.
    event?.stopPropagation();
    this.isUserDropdownOpen = !this.isUserDropdownOpen;
  }

  @action
  closeUserDropdown() {
    this.isUserDropdownOpen = false;
  }

  // WordPress's base URL (theme setting wp_base_url) for the logo and every
  // link back into WordPress.
  get wpBase() {
    return wpBase();
  }

  // Live counts from Discourse for the pill's activity dot and the
  // dropdown row badges. Names track the fields Discourse exposes on
  // currentUser today; guard everything with `?.` because upgrades have
  // renamed these before.
  get unreadNotifications() {
    const u = this.currentUser;
    if (!u) return 0;

    // `grouped_unread_notifications` is the per-type unread map Discourse
    // maintains for the notification menu itself — keys are notification-
    // type ids, values are counts. Summing it matches what the bell menu
    // actually surfaces. `all_unread_notifications_count` on the same user
    // has been observed at 0 while the groups map has real values (7 PMs
    // + 1 group + 1 plugin = 9), so trust the map.
    const grouped = u.grouped_unread_notifications;
    if (grouped && typeof grouped === "object") {
      let sum = 0;
      for (const v of Object.values(grouped)) {
        sum += Number(v) || 0;
      }
      return sum;
    }

    // Older releases: fall back to the split fields.
    if (typeof u.all_unread_notifications_count === "number") {
      return u.all_unread_notifications_count;
    }
    return (
      (u.unread_high_priority_notifications ?? 0) +
      (u.unread_notifications ?? 0)
    );
  }

  // Display name + Buddy Emblem for the pill come from the same WordPress
  // data the account panel reads (see components/wbo-user-panel.gjs).
  @tracked menuData = null;

  async _loadMenuData() {
    if (!this.currentUser) {
      return;
    }
    const data = await loadMenu(this.currentUser.username);
    if (!this.isDestroying && !this.isDestroyed) {
      this.menuData = data;
    }
  }

  get displayName() {
    return this.menuData?.name || this.currentUser?.username;
  }

  get pillEmblem() {
    return this.menuData?.emblems?.art || null;
  }

  icon = (name, size, cls) => wboIcon(name, size, cls);

  @action
  createOrReply() {
    if (this.isOnTopic) {
      const topic = this.currentTopic;
      if (!topic) return;
      this.composer.open({
        action: Composer.REPLY,
        topic,
        draftKey: topic.draft_key,
        draftSequence: topic.draft_sequence,
      });
    } else {
      this.composer.openNewTopic({
        category: this.currentCategory,
      });
    }
  }

  <template>
    {{! ── Nav bar (covers .d-header at the same position) ─────────────── }}
    {{! Mirrors WordPress header.php: .wbo-site-nav is the full-bleed fixed
        bar (.site-header), .wbo-site-nav__inner the 1200px-max row
        (.site-header-inner) — hamburger | logo | links | user. The drawer
        and its backdrop live INSIDE the bar, as .nav-drawer does inside
        .site-header: the bar is a stacking context (z 1002), so only
        siblings inside it can be layered hamburger (1020) > drawer (1009)
        > backdrop (1008). Outside it, the drawer covered the X. }}
    <div class="wbo-site-nav">
      <div class="wbo-site-nav__inner">
        {{! Below 960px the links move into the drawer, like WordPress. }}
        <button
          {{on "click" this.toggleDrawer}}
          type="button"
          class="wbo-hamburger {{if this.isDrawerOpen 'is-open'}}"
          aria-label={{if this.isDrawerOpen "Close menu" "Open menu"}}
          aria-expanded={{if this.isDrawerOpen "true" "false"}}
          aria-controls="wbo-nav-drawer"
        >
          {{#if this.isDrawerOpen}}
            {{this.icon "x-bold" null "wbo-hamburger__icon"}}
          {{else}}
            {{this.icon "list-bold" null "wbo-hamburger__icon"}}
            <span class="wbo-hamburger__label">Menu</span>
          {{/if}}
        </button>

        <a href={{this.wpBase}} class="wbo-site-nav__logo">
          {{#if this.logoUrl}}
            {{! Intrinsic width/height (natural 512x166) so the browser
                reserves the space before the image decodes -- without them
                the nav links reflow ~89px on every page load. }}
            <img src={{this.logoUrl}} alt="WBO" width="108" height="35" />
          {{else}}
            <span class="wbo-site-nav__logo-text">WBO</span>
          {{/if}}
        </a>

        <nav class="wbo-site-nav__links" aria-label="Primary">
          {{#each this.navItems as |item|}}
            <a
              href={{item.url}}
              class="wbo-site-nav__link {{if item.active 'is-active'}}"
            >{{item.label}}</a>
          {{/each}}
        </nav>

        <div class="wbo-site-nav__right">
          {{#if this.currentUser}}
            {{! Pill + account panel — WordPress's .user-menu-wrap. }}
            <div class="wbo-user-menu-wrap">
              <button
                {{on "click" this.toggleUserDropdown}}
                type="button"
                class="wbo-user-menu-link wbo-user-menu-trigger
                  {{if this.isUserDropdownOpen 'is-open'}}"
                aria-haspopup="true"
                aria-expanded={{if this.isUserDropdownOpen "true" "false"}}
                aria-controls="wbo-user-menu-dropdown"
              >
                <span class="{{if this.pillEmblem 'wbo-buddy-parent'}}">
                  <span class="avatar">
                    <img
                      src={{this.userAvatarUrl}}
                      width="32"
                      height="32"
                      alt=""
                    />
                  </span>
                  {{#if this.pillEmblem}}
                    <img class="wbo-buddy-emblem" src={{this.pillEmblem}} alt="" />
                  {{/if}}
                </span>
                <span class="wbo-user-menu-name">{{this.displayName}}</span>
                {{! "More" dots, not a caret: the panel opens at the side,
                    not as a drop-down. }}
                <span
                  class="wbo-user-menu-caret wbo-user-menu-panel-icon"
                  aria-hidden="true"
                >{{this.icon "dots-three-outline" 18}}</span>
              </button>

              {{#if this.isUserDropdownOpen}}
                <WboUserPanel @onClose={{this.closeUserDropdown}} />
              {{/if}}
            </div>

            {{! Bell — opens Discourse's own notification menu, right of the
                pill. pointerdown/mousedown/touchstart are intercepted so
                Discourse's outside-close never fires on a bell tap; click
                alone drives the toggle. }}
            <button
              {{on "pointerdown" this.bellPointerDown}}
              {{on "mousedown" this.bellPointerDown}}
              {{on "touchstart" this.bellPointerDown}}
              {{on "click" this.openDiscourseUserMenu}}
              type="button"
              class="wbo-bell"
              aria-label={{if
                this.unreadNotifications
                (concat "Notifications (" this.unreadNotifications " unread)")
                "Notifications"
              }}
            >
              {{this.icon "bell" 18}}
              {{#if this.unreadNotifications}}
                <span
                  class="wbo-bell__badge"
                  aria-hidden="true"
                >{{this.unreadNotifications}}</span>
              {{/if}}
            </button>
          {{else}}
            {{! Join Now + Log in, as on WordPress. Log in moves into the
                drawer below 720px. }}
            <a href="/signup" class="wbo-site-nav__join">Join Now</a>
            <a href="/login" class="wbo-site-nav__login">Log in</a>
          {{/if}}
        </div>
      </div>

    {{! ── Drawer (below 960px) ─────────────────────────────────────────── }}
    <div
      id="wbo-nav-drawer"
      class="wbo-nav-drawer {{if this.isDrawerOpen 'is-open'}}"
      aria-hidden={{if this.isDrawerOpen "false" "true"}}
      inert={{unless this.isDrawerOpen true}}
    >
      {{! Logo pinned in the drawer's top strip, as on WordPress. }}
      <a href={{this.wpBase}} class="wbo-nav-drawer__logo">
        {{#if this.logoUrl}}
          <img src={{this.logoUrl}} alt="WBO" width="111" height="36" />
        {{else}}
          <span class="wbo-nav-drawer__logo-text">WBO</span>
        {{/if}}
      </a>

      <nav aria-label="Primary mobile">
        {{#each this.navItems as |item|}}
          <a
            href={{item.url}}
            class="wbo-nav-drawer__link {{if item.active 'is-active'}}"
            {{on "click" this.closeDrawer}}
          >{{item.label}}</a>

          {{! Community expands in place with Latest / Unread / categories.
              Not an accordion — you're already in the section. }}
          {{#if item.isCommunity}}
            <div class="wbo-nav-drawer__community">
              <a
                href="/latest"
                class="wbo-nav-drawer__sublink"
                {{on "click" this.closeDrawer}}
              >
                <span class="wbo-nav-drawer__sublink-label">Latest</span>
                {{#if this.latestBadge}}
                  <span class="sidebar-section-link-suffix icon unread">
                    {{icon "circle"}}
                  </span>
                {{/if}}
              </a>

              {{#if this.currentUser}}
                <a
                  href="/unread"
                  class="wbo-nav-drawer__sublink"
                  {{on "click" this.closeDrawer}}
                >
                  <span class="wbo-nav-drawer__sublink-label">Unread</span>
                  {{#if this.totalUnread}}
                    <span class="sidebar-section-link-suffix icon unread">
                      {{icon "circle"}}
                    </span>
                  {{/if}}
                </a>
              {{/if}}

              {{! Discourse's own category section — live counts, permissions
                  and add/rename correctness for free. }}
              <div class="wbo-nav-drawer__categories">
                <this.CategoriesSection @collapsable={{false}} />
              </div>
            </div>
          {{/if}}
        {{/each}}
      </nav>

      {{#if this.isAdminRoute}}
        {{bodyClass "wbo-admin-route"}}
      {{/if}}

      {{#if this.currentUser.staff}}
        {{#if this.isAdminRoute}}
          <button
            type="button"
            class="wbo-nav-drawer__admin"
            {{on "click" this.openAdminMenu}}
          >Admin menu</button>
        {{else if this.currentUser.admin}}
          {{! Admin isn't in Discourse's mobile user menu; give staff a
              reachable link now that the second toggle is gone. }}
          <a
            href="/admin"
            class="wbo-nav-drawer__admin"
            {{on "click" this.closeDrawer}}
          >Admin</a>
        {{/if}}
      {{/if}}

      {{#if this.currentUser}}
        <a
          href="/logout"
          class="wbo-nav-drawer__logout"
          {{on "click" this.closeDrawer}}
        >Log out</a>
      {{else}}
        <div class="wbo-nav-drawer__auth">
          <a
            href="/signup"
            class="wbo-nav-drawer__auth-btn wbo-nav-drawer__auth-btn--primary"
            {{on "click" this.closeDrawer}}
          >Join Now</a>
          <a
            href="/login"
            class="wbo-nav-drawer__auth-btn wbo-nav-drawer__auth-btn--secondary"
            {{on "click" this.closeDrawer}}
          >Log in</a>
        </div>
      {{/if}}
    </div>

    {{#if this.isDrawerOpen}}
      {{! template-lint-disable no-invalid-interactive }}
      <div
        {{on "click" this.closeDrawer}}
        class="wbo-nav-backdrop"
        role="presentation"
      ></div>
    {{/if}}
    </div>

    {{! ── Mobile: floating create / reply button ──────────────────────── }}
    <div class="wbo-bottom-bar">
      {{#if this.showCreateButton}}
        <button
          {{on "click" this.createOrReply}}
          type="button"
          class="wbo-bottom-bar__create"
          aria-label={{this.createButtonLabel}}
        >
          {{icon this.createButtonIcon}}
        </button>
      {{/if}}
    </div>
  </template>
}
