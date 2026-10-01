import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { wboIcon } from "../lib/wbo-icon";

// The Discord server widget's online count. Discord's widget endpoint is
// public and CORS-enabled, but it intermittently answers 503 (and 403/404
// when Server Widget is off). So:
//   - a good count is reused for five minutes, across page loads too
//     (localStorage), so we ask Discord far less often;
//   - when a request fails, the last good count from the past day is shown
//     instead of dropping the line;
//   - with no count at all, the line simply doesn't appear.
const FRESH_MS = 5 * 60 * 1000;
const STALE_MS = 24 * 60 * 60 * 1000;
const STORAGE_KEY = "wbo-discord-online";
let memo = null; // { count, at }
let inFlight = null;

function readStored() {
  if (memo) {
    return memo;
  }
  try {
    const stored = JSON.parse(localStorage.getItem(STORAGE_KEY));
    if (Number.isFinite(stored?.count) && Number.isFinite(stored?.at)) {
      memo = stored;
    }
  } catch {
    // Storage blocked or unparseable: fall through to the network.
  }
  return memo;
}

function store(count) {
  memo = { count, at: Date.now() };
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(memo));
  } catch {
    // Storage blocked: the in-memory copy still serves this page.
  }
}

function lastGood(maxAge) {
  const stored = readStored();
  return stored && Date.now() - stored.at < maxAge ? stored.count : null;
}

async function fetchOnlineCount(serverId) {
  const fresh = lastGood(FRESH_MS);
  if (fresh !== null) {
    return fresh;
  }
  if (!inFlight) {
    inFlight = fetch(
      `https://discord.com/api/guilds/${encodeURIComponent(serverId)}/widget.json`
    )
      .then((r) => (r.ok ? r.json() : null))
      .then((data) => {
        const n = data?.presence_count;
        if (Number.isFinite(n)) {
          store(n);
          return n;
        }
        return lastGood(STALE_MS);
      })
      .catch(() => lastGood(STALE_MS))
      .finally(() => {
        inFlight = null;
      });
  }
  return inFlight;
}

// The community "About" content: description, Discord box (with the live
// online count), rules. Right sidebar on wide screens; the About tab on
// narrow ones (@mobile), which also lists the categories. Copy comes from
// theme settings.
export default class WboAboutPanel extends Component {
  @service site;

  @tracked onlineCount = null;

  constructor() {
    super(...arguments);
    const serverId = (settings.discord_server_id || "").trim();
    if (serverId) {
      fetchOnlineCount(serverId).then((n) => {
        if (!this.isDestroying && !this.isDestroyed) {
          this.onlineCount = n;
        }
      });
    }
  }

  get discordUrl() {
    return (settings.discord_invite_url || "").trim();
  }

  // Top-level categories the viewer can see (site.categories already omits
  // ones they can't), for the About tab.
  get categories() {
    if (!this.args.mobile) {
      return [];
    }
    return (this.site.categories || [])
      .filter((c) => !c.parent_category_id && !c.isUncategorizedCategory)
      .map((c) => ({
        name: c.name,
        url: c.url,
        description: c.description_text,
        swatchStyle: htmlSafe(`background-color: #${c.color}`),
      }));
  }

  get onlineLabel() {
    if (this.onlineCount === null) {
      return null;
    }
    return i18n(themePrefix("about_panel.online_now"), {
      count: this.onlineCount.toLocaleString(),
    });
  }

  get rules() {
    return (settings.rules || [])
      .filter((r) => r?.title)
      .map((r, i) => ({ ...r, open: i === 0 }));
  }

  <template>
    <div class="wbo-about">
      <section class="wbo-about__card">
        <h2 class="wbo-about__heading">
          {{i18n (themePrefix "about_panel.about_heading")}}
        </h2>
        <p class="wbo-about__text">{{settings.about_text}}</p>
        {{#if settings.about_footnote}}
          <p class="wbo-about__muted">{{settings.about_footnote}}</p>
        {{/if}}
      </section>

      {{#if this.discordUrl}}
        <section class="wbo-about__card wbo-about__discord">
          <div>
            <h3
              class="wbo-about__discord-title"
            >{{settings.discord_heading}}</h3>
          </div>
          {{#if this.onlineLabel}}
            <p class="wbo-about__online">
              <span class="wbo-about__online-dot" aria-hidden="true"></span>
              {{this.onlineLabel}}
            </p>
          {{/if}}
          <a
            href={{this.discordUrl}}
            class="btn wbo-btn-discord wbo-about__button"
            target="_blank"
            rel="noopener noreferrer"
          >
            {{icon "fab-discord"}}
            <span>{{i18n (themePrefix "about_panel.join_discord")}}</span>
          </a>
        </section>
      {{/if}}

      {{#if this.rules.length}}
        <section class="wbo-about__card">
          <h2 class="wbo-about__heading">
            {{i18n (themePrefix "about_panel.rules_heading")}}
          </h2>
          <ol class="wbo-about__rules">
            {{#each this.rules as |rule|}}
              <li>
                {{#if rule.detail}}
                  <details class="wbo-about__rule" open={{rule.open}}>
                    <summary>
                      <span class="wbo-about__rule-title">{{rule.title}}</span>
                      {{wboIcon "caret-down" 16 "wbo-about__rule-caret"}}
                    </summary>
                    <p class="wbo-about__muted">{{rule.detail}}</p>
                  </details>
                {{else}}
                  <div class="wbo-about__rule">
                    <span class="wbo-about__rule-title">{{rule.title}}</span>
                  </div>
                {{/if}}
              </li>
            {{/each}}
          </ol>
          {{#if settings.rules_url}}
            <a href={{settings.rules_url}} class="wbo-about__link">
              {{i18n (themePrefix "about_panel.read_all_rules")}}
              {{wboIcon "arrow-right" 14}}
            </a>
          {{/if}}
        </section>
      {{/if}}

      {{#if this.categories.length}}
        <section class="wbo-about__card">
          <h2 class="wbo-about__heading">
            {{i18n (themePrefix "about_panel.categories_heading")}}
          </h2>
          <ul class="wbo-about__categories">
            {{#each this.categories as |category|}}
              <li>
                <a href={{category.url}} class="wbo-about__category">
                  <span
                    class="wbo-about__category-swatch"
                    style={{category.swatchStyle}}
                  ></span>
                  <span class="wbo-about__category-text">
                    <span class="wbo-about__category-name">
                      {{category.name}}
                    </span>
                    {{#if category.description}}
                      <span class="wbo-about__muted">
                        {{category.description}}
                      </span>
                    {{/if}}
                  </span>
                </a>
              </li>
            {{/each}}
          </ul>
        </section>
      {{/if}}
    </div>
  </template>
}
