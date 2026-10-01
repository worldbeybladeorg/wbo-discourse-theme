import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { i18n } from "discourse-i18n";
import { wboIcon } from "../lib/wbo-icon";
import { fetchOnlineCount } from "./wbo-about-panel";

// Slim Discord promo at the top of the feed, shown only where the right
// sidebar (and its Discord box) is hidden -- see scss/community.scss.
export default class WboDiscordStrip extends Component {
  @tracked onlineCount = null;

  constructor() {
    super(...arguments);
    const serverId = (settings.discord_server_id || "").trim();
    if (this.discordUrl && serverId) {
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
    {{#if this.discordUrl}}
      <a
        href={{this.discordUrl}}
        class="wbo-discord-strip"
        target="_blank"
        rel="noopener noreferrer"
      >
        {{wboIcon "chat" 18 "wbo-discord-strip__icon"}}
        <span class="wbo-discord-strip__text">
          <span class="wbo-discord-strip__title">
            {{i18n (themePrefix "discord_strip.title")}}
          </span>
          {{#if this.onlineLabel}}
            <span class="wbo-discord-strip__online">{{this.onlineLabel}}</span>
          {{/if}}
        </span>
        <span class="wbo-discord-strip__join">
          {{i18n (themePrefix "discord_strip.join")}}
          {{wboIcon "arrow-right" 14}}
        </span>
      </a>
    {{/if}}
  </template>
}
