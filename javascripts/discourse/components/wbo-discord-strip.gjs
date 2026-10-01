import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
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
    return i18n(themePrefix("discord_strip.online"), {
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
        <span class="wbo-discord-strip__text">
          {{#if this.onlineLabel}}
            <span
              class="wbo-discord-strip__dot"
              aria-hidden="true"
            ></span>{{this.onlineLabel}}
          {{else}}
            {{i18n (themePrefix "discord_strip.title")}}
          {{/if}}
        </span>
        <span class="wbo-discord-strip__join">
          {{! Font Awesome's brand icon from Discourse's own set; about.json
              adds it to the icon subset (modifiers.svg_icons). }}
          {{icon "fab-discord"}}
          {{i18n (themePrefix "discord_strip.join")}}
        </span>
      </a>
    {{/if}}
  </template>
}
