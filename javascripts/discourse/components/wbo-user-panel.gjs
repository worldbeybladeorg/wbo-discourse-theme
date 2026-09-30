import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { wboIcon, wpBase } from "../lib/wbo-icon";

// The account panel — the Discourse copy of WordPress's user menu
// (header.php .user-menu-dropdown.um-card). Same markup and class names, so
// scss/wbo-user-menu.scss is WordPress's assets/user-menu.css run through
// tools/sync-wp-tokens.mjs rather than a hand-kept twin.
//
// Its data comes from the same WordPress function that renders the WP panel
// (wbo_user_menu_data, via GET /wp-json/wbo/v1/user-menu). The public part —
// name, role pills, level, emblem art, links — always loads. The private part
// — next event, My Events count, Emblem Tickets — only when the browser sends
// the WordPress login cookie, i.e. when the forum and WordPress share a
// domain. Until then those rows fall back to plain links.

const MODES = { system: 1, light: 2, dark: 3 };

// Module-level so every mount (desktop bar, route changes) shares one fetch.
let cache = null;
let cacheAt = 0;
let inflight = null;

export async function loadMenu(username) {
  if (cache && Date.now() - cacheAt < 60_000) {
    return cache;
  }
  if (!inflight) {
    const url = `${wpBase()}/wp-json/wbo/v1/user-menu?username=${encodeURIComponent(username)}`;
    inflight = fetch(url, { credentials: "include" })
      .then((r) => (r.ok ? r.json() : null))
      .catch(() => null)
      .then((data) => {
        cache = data;
        cacheAt = Date.now();
        inflight = null;
        return data;
      });
  }
  return inflight;
}

export default class WboUserPanel extends Component {
  @service currentUser;
  @service interfaceColor;

  @tracked data = cache;
  @tracked mode = this.currentMode();

  constructor() {
    super(...arguments);
    this.refresh();
  }

  async refresh() {
    const username = this.currentUser?.username;
    if (!username) {
      return;
    }
    const data = await loadMenu(username);
    if (!this.isDestroying && !this.isDestroyed) {
      this.data = data;
    }
  }

  // ── Identity ──────────────────────────────────────────────────────────────

  get name() {
    return this.data?.name || this.currentUser?.name || this.currentUser?.username;
  }

  // Same length thresholds as WordPress (header.php → .um-name--xl/l/m/s).
  get nameSize() {
    const n = (this.name || "").length;
    return n <= 8 ? "xl" : n <= 12 ? "l" : n <= 16 ? "m" : "s";
  }

  get avatarUrl() {
    return this.currentUser?.avatar_template?.replace("{size}", "168");
  }

  get emblemArt() {
    return this.data?.emblems?.art || null;
  }

  get badges() {
    return this.data?.badges || [];
  }

  get level() {
    return this.data?.level || null;
  }

  get levelStyle() {
    return `width:${Number(this.level?.pct) || 0}%;`;
  }

  get profileUrl() {
    return this.data?.profile_url || `${wpBase()}/u/${this.currentUser?.username}/`;
  }

  get settingsUrl() {
    return this.data?.settings_url || `${wpBase()}/settings/`;
  }

  get supportUrl() {
    return this.data?.support_url || `${wpBase()}/support/my-tickets/`;
  }

  get eventsUrl() {
    return this.data?.events_url || `${wpBase()}/tournaments/?mine=1`;
  }

  get emblemsUrl() {
    return this.data?.emblems?.url || `${wpBase()}/get-emblems/`;
  }

  get nextEvent() {
    return this.data?.next_event || null;
  }

  get eventsCount() {
    return Number(this.data?.events_count) || 0;
  }

  get hasTickets() {
    return typeof this.data?.emblems?.tickets === "number";
  }

  // ── Appearance ────────────────────────────────────────────────────────────
  //
  // Discourse's own light/dark machinery does the switching: the theme ships
  // a "WBO Light" and a "WBO" (dark) colour scheme, and interface-color flips
  // between their stylesheets. The choice is saved to the Discourse account
  // (interface_color_mode, 1/2/3) and — when the WordPress cookie is present —
  // to WordPress too, so both halves open in the same mode everywhere.

  currentMode() {
    const cm = this.interfaceColor?.colorMode;
    if (cm === "light" || cm === "dark") {
      return cm;
    }
    if (cm === "auto") {
      return "system";
    }
    const opt = this.currentUser?.user_option?.interface_color_mode;
    return opt === 2 ? "light" : opt === 3 ? "dark" : "system";
  }

  get isSystem() {
    return this.mode === "system" ? "true" : "false";
  }
  get isLight() {
    return this.mode === "light" ? "true" : "false";
  }
  get isDark() {
    return this.mode === "dark" ? "true" : "false";
  }

  @action
  setMode(value) {
    this.mode = value;
    if (value === "light") {
      this.interfaceColor.forceLightMode();
    } else if (value === "dark") {
      this.interfaceColor.forceDarkMode();
    } else {
      this.interfaceColor.useAutoMode();
    }

    const username = this.currentUser?.username;
    if (!username) {
      return;
    }
    if (this.currentUser.user_option) {
      this.currentUser.user_option.interface_color_mode = MODES[value];
    }
    ajax(`/u/${encodeURIComponent(username)}.json`, {
      type: "PUT",
      data: { interface_color_mode: MODES[value] },
    }).catch(() => {});

    const nonce = this.data?.nonce;
    if (nonce) {
      const body = new URLSearchParams({ value, nonce });
      fetch(`${wpBase()}/wp-json/wbo/v1/theme-pref`, {
        method: "POST",
        body,
        credentials: "include",
      }).catch(() => {});
      if (cache) {
        cache.theme_pref = value;
      }
    }
  }

  @action
  close() {
    this.args.onClose?.();
  }

  // ── Icons ─────────────────────────────────────────────────────────────────

  icon = (name, size) => wboIcon(name, size);

  <template>
    <div
      class="wbo-um-panel um-card"
      id="wbo-user-menu-dropdown"
      role="menu"
      aria-label="Account"
    >
      <div class="um-hero">
        <span class="{{if this.emblemArt 'wbo-buddy-parent'}}">
          <span class="um-avatar">
            {{#if this.avatarUrl}}
              <img src={{this.avatarUrl}} alt="" width="84" height="84" />
            {{/if}}
          </span>
          {{#if this.emblemArt}}
            <img class="wbo-buddy-emblem" src={{this.emblemArt}} alt="" />
          {{/if}}
        </span>

        <div class="um-name um-name--{{this.nameSize}}">{{this.name}}</div>

        {{#if this.badges.length}}
          <div class="um-badges">
            {{#each this.badges as |b|}}
              <span class="um-badge {{b.class}}">{{b.label}}</span>
            {{/each}}
          </div>
        {{/if}}

        {{#if this.level}}
          <div class="um-level">
            <div class="um-level-row">
              <span>Level {{this.level.level}}</span>
              <span>{{this.level.remaining}} XP to next</span>
            </div>
            <div
              class="um-level-bar"
              role="progressbar"
              aria-label="XP toward next level"
              aria-valuemin="0"
              aria-valuemax={{this.level.need}}
              aria-valuenow={{this.level.into}}
            ><span style={{this.levelStyle}}></span></div>
          </div>
        {{/if}}

        <div class="um-actions">
          <a class="um-action" role="menuitem" href={{this.profileUrl}}>
            {{this.icon "user" 16}}
            Profile
          </a>
          <a class="um-action" role="menuitem" href={{this.settingsUrl}}>
            {{this.icon "gear" 16}}
            Settings
          </a>
        </div>
      </div>

      <div class="um-body">
        <div class="um-panel">
          {{#if this.nextEvent}}
            <a class="um-next" role="menuitem" href={{this.nextEvent.url}}>
              <span class="um-next-date" aria-hidden="true">
                <span class="um-next-mon">{{this.nextEvent.mon}}</span>
                <span class="um-next-day">{{this.nextEvent.day}}</span>
              </span>
              <span class="um-next-text">
                <span class="um-eyebrow">Next event</span>
                <span class="um-next-title">{{this.nextEvent.title}}</span>
                {{#if this.nextEvent.venue}}
                  <span class="um-next-meta">
                    <span class="um-next-venue">{{this.nextEvent.venue}}</span>
                    {{#if this.nextEvent.time}}
                      <span aria-hidden="true">·</span>
                      <span class="um-next-time">{{this.nextEvent.time}}</span>
                    {{/if}}
                  </span>
                {{else if this.nextEvent.time}}
                  <span class="um-next-meta">
                    <span class="um-next-time">{{this.nextEvent.time}}</span>
                  </span>
                {{/if}}
              </span>
              <span class="um-chevron">{{this.icon "caret-right" 14}}</span>
            </a>
          {{/if}}
          <a class="um-row" role="menuitem" href={{this.eventsUrl}}>
            <span class="um-row-icon">{{this.icon "trophy" 18}}</span>
            <span class="um-row-label">My Events</span>
            {{#if this.eventsCount}}
              <span
                class="wbo-user-menu-item-count wbo-user-menu-item-count--all"
              >{{this.eventsCount}}</span>
            {{/if}}
          </a>
        </div>

        {{#if this.data.emblems}}
          <a
            class="um-panel um-emblems"
            role="menuitem"
            href={{this.emblemsUrl}}
          >
            <span class="um-emblems-art" aria-hidden="true">
              {{#if this.emblemArt}}
                <img src={{this.emblemArt}} alt="" width="44" height="44" />
              {{else}}
                {{this.icon "star-four" 22}}
              {{/if}}
            </span>
            <span class="um-next-text">
              <span class="um-next-title">Get Emblems</span>
              {{#if this.hasTickets}}
                <span class="um-emblems-count">
                  {{this.icon "star-four" 12}}
                  <strong>{{this.data.emblems.tickets}}</strong>
                  available
                </span>
              {{/if}}
            </span>
            <span class="um-chevron">{{this.icon "caret-right" 14}}</span>
          </a>
        {{/if}}
      </div>

      <div class="um-foot">
        <div class="um-appearance">
          <span
            class="um-appearance-label"
            id="wbo-um-appearance-label"
          >Appearance</span>
          <div
            class="um-seg"
            role="radiogroup"
            aria-labelledby="wbo-um-appearance-label"
          >
            <button
              type="button"
              role="radio"
              aria-checked={{this.isSystem}}
              {{on "click" (fn this.setMode "system")}}
            >Auto</button>
            <button
              type="button"
              role="radio"
              aria-checked={{this.isLight}}
              {{on "click" (fn this.setMode "light")}}
            >Light</button>
            <button
              type="button"
              role="radio"
              aria-checked={{this.isDark}}
              {{on "click" (fn this.setMode "dark")}}
            >Dark</button>
          </div>
        </div>
        <div class="um-foot-links">
          <a class="um-foot-link" role="menuitem" href={{this.supportUrl}}>
            {{this.icon "question" 16}}
            Support
          </a>
          <a
            class="um-foot-link um-foot-link--end"
            role="menuitem"
            href="/logout"
          >
            {{this.icon "sign-out" 16}}
            Log out
          </a>
        </div>
        <button
          type="button"
          class="wbo-um-close um-close"
          {{on "click" this.close}}
        >Close</button>
      </div>
    </div>
  </template>
}
