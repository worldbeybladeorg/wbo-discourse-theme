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

export async function fetchOnlineCount(serverId) {
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

// The right sidebar on the top-level feeds: a short description and the
// Discord box. Narrow screens, where the sidebar is hidden, get the slim
// wbo-discord-strip instead. Copy comes from theme settings.
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

    </div>
  </template>
}
