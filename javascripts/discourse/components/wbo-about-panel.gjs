import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { i18n } from "discourse-i18n";
import { wboIcon } from "../lib/wbo-icon";

// The Discord server widget's online count, shared by every panel instance
// and refreshed at most every five minutes. The widget endpoint is public
// and CORS-enabled; it 404s/403s when Server Widget is off in Discord, in
// which case the count line simply never appears.
const CACHE_MS = 5 * 60 * 1000;
let cachedCount = null;
let cachedAt = 0;
let inFlight = null;

async function fetchOnlineCount(serverId) {
  if (cachedCount !== null && Date.now() - cachedAt < CACHE_MS) {
    return cachedCount;
  }
  if (!inFlight) {
    inFlight = fetch(
      `https://discord.com/api/guilds/${encodeURIComponent(serverId)}/widget.json`
    )
      .then((r) => (r.ok ? r.json() : null))
      .then((data) => {
        const n = data?.presence_count;
        cachedCount = Number.isFinite(n) ? n : null;
        cachedAt = Date.now();
        return cachedCount;
      })
      .catch(() => null)
      .finally(() => {
        inFlight = null;
      });
  }
  return inFlight;
}

// The community "About" content: right sidebar on wide screens, the About
// tab on narrow ones (see wbo-community-header). Everything it says comes
// from theme settings, so it's edited in admin, not here.
export default class WboAboutPanel extends Component {
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
      .map((r, i) => ({ ...r, number: i + 1, open: i === 0 }));
  }

  get supportUrl() {
    return (settings.support_url || "").trim();
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
            {{#if settings.discord_description}}
              <p class="wbo-about__muted">{{settings.discord_description}}</p>
            {{/if}}
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
            {{wboIcon "chat" 18}}
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
                      <span class="wbo-about__rule-num">{{rule.number}}</span>
                      <span class="wbo-about__rule-title">{{rule.title}}</span>
                      {{wboIcon "caret-down" 16 "wbo-about__rule-caret"}}
                    </summary>
                    <p class="wbo-about__muted">{{rule.detail}}</p>
                  </details>
                {{else}}
                  <div class="wbo-about__rule">
                    <span class="wbo-about__rule-num">{{rule.number}}</span>
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

      {{#if this.supportUrl}}
        <section class="wbo-about__card">
          <h2 class="wbo-about__heading">
            {{i18n (themePrefix "about_panel.help_heading")}}
          </h2>
          {{#if settings.support_text}}
            <p class="wbo-about__muted">{{settings.support_text}}</p>
          {{/if}}
          <a href={{this.supportUrl}} class="btn btn-default wbo-about__button">
            <span>{{i18n (themePrefix "about_panel.open_ticket")}}</span>
            {{wboIcon "arrow-right" 16}}
          </a>
        </section>
      {{/if}}
    </div>
  </template>
}
