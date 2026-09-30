import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";
import { wboIcon } from "../lib/wbo-icon";
import WboAboutPanel from "./wbo-about-panel";

const ABOUT_CLASS = "wbo-about-tab-open";

// Narrow-screen header for the top-level feeds, Reddit style:
//   [Create topic] [Discord]
//   Feed | About                       Latest ▾
// Only renders where the right sidebar is hidden (CSS, <= 1160px); the
// Create/Discord row and the sort menu only on phones (<= 719px), where the
// desktop "Create topic" bar and Discourse's navigation bar are hidden.
// The About tab shows the same panel the right sidebar shows on desktop.
export default class WboCommunityHeader extends Component {
  @service router;
  @service siteSettings;
  @service composer;
  @service currentUser;
  @service topicTrackingState;

  @tracked tab = "feed";

  constructor() {
    super(...arguments);
    this.router.on("routeDidChange", this.resetTab);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.router.off("routeDidChange", this.resetTab);
    document.body.classList.remove(ABOUT_CLASS);
  }

  // Any navigation (a sort change, a category, a topic) returns to the feed,
  // so the About tab can't leave a hidden feed behind on the next page.
  @action
  resetTab() {
    this.setTab("feed");
  }

  get topMenu() {
    return this.siteSettings.top_menu.split("|").filter(Boolean);
  }

  get currentFilter() {
    return this.router.currentRoute?.localName;
  }

  get isTopRoute() {
    return this.topMenu.includes(this.currentFilter);
  }

  get isAbout() {
    return this.tab === "about";
  }

  get canCreateTopic() {
    return this.currentUser?.can_create_topic;
  }

  get discordUrl() {
    return (settings.discord_invite_url || "").trim();
  }

  get sortOptions() {
    return this.topMenu.map((name) => {
      let label = i18n(`filters.${name}.title`);
      let count = 0;
      if (this.currentUser && name === "unread") {
        count = this.topicTrackingState.countUnread();
      } else if (this.currentUser && name === "new") {
        count = this.topicTrackingState.countNew();
      }
      if (count > 0) {
        label = `${label} (${count})`;
      }
      return { name, label, selected: name === this.currentFilter };
    });
  }

  get currentSortLabel() {
    return this.sortOptions.find((o) => o.selected)?.label;
  }

  @action
  setTab(tab) {
    this.tab = tab;
    document.body.classList.toggle(ABOUT_CLASS, tab === "about");
  }

  @action
  changeSort(event) {
    this.router.transitionTo(`discovery.${event.target.value}`);
  }

  @action
  createTopic() {
    this.composer.open({
      action: Composer.CREATE_TOPIC,
      draftKey: Composer.NEW_TOPIC_KEY,
    });
  }

  <template>
    {{#if this.isTopRoute}}
      <div class="wbo-community-header">
        <div class="wbo-community-header__actions">
          {{#if this.canCreateTopic}}
            <button
              type="button"
              class="btn btn-primary"
              {{on "click" this.createTopic}}
            >
              {{wboIcon "pencil" 18}}
              <span>{{i18n
                  (themePrefix "community_header.create_topic")
                }}</span>
            </button>
          {{/if}}
          {{#if this.discordUrl}}
            <a
              href={{this.discordUrl}}
              class="btn wbo-btn-discord"
              target="_blank"
              rel="noopener noreferrer"
            >
              {{wboIcon "chat" 18}}
              <span>{{i18n (themePrefix "community_header.discord")}}</span>
            </a>
          {{/if}}
        </div>

        <div class="wbo-community-header__bar">
          <div
            class="wbo-community-header__tabs"
            role="tablist"
            aria-label={{i18n (themePrefix "community_header.sections")}}
          >
            <button
              type="button"
              role="tab"
              class="wbo-community-header__tab"
              aria-selected={{if this.isAbout "false" "true"}}
              {{on "click" (fn this.setTab "feed")}}
            >{{i18n (themePrefix "community_header.feed")}}</button>
            <button
              type="button"
              role="tab"
              class="wbo-community-header__tab"
              aria-selected={{if this.isAbout "true" "false"}}
              {{on "click" (fn this.setTab "about")}}
            >{{i18n (themePrefix "community_header.about")}}</button>
          </div>

          {{#unless this.isAbout}}
            <label class="wbo-community-header__sort">
              <span class="sr-only">
                {{i18n (themePrefix "community_header.sort")}}
              </span>
              {{! The visible label; the native select sits invisibly on top
                  of it, so it opens the OS picker but sizes to the label. }}
              <span class="wbo-community-header__sort-label" aria-hidden="true">
                {{this.currentSortLabel}}
              </span>
              <select {{on "change" this.changeSort}}>
                {{#each this.sortOptions as |opt|}}
                  <option
                    value={{opt.name}}
                    selected={{opt.selected}}
                  >{{opt.label}}</option>
                {{/each}}
              </select>
              {{wboIcon "caret-down" 16}}
            </label>
          {{/unless}}
        </div>
      </div>

      {{#if this.isAbout}}
        <div class="wbo-community-header__about">
          <WboAboutPanel />
        </div>
      {{/if}}
    {{/if}}
  </template>
}
