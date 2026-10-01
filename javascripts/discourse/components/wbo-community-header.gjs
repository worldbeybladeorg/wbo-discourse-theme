import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";
import { wboIcon } from "../lib/wbo-icon";
import WboAboutPanel from "./wbo-about-panel";

const ABOUT_CLASS = "wbo-about-tab-open";
const CREATE_OFFSCREEN_CLASS = "wbo-header-create-offscreen";
// The WBO nav bar is fixed over the top 56px, so a button scrolled under it
// counts as out of view.
const NAV_HEIGHT = 56;

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
  @tracked sortOpen = false;

  // Watches the header's Create topic button: once it scrolls out of view
  // (under the nav bar), body gets CREATE_OFFSCREEN_CLASS and the floating
  // create button in the bottom corner comes back (scss/community.scss).
  watchCreateButton = modifier((element) => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        document.body.classList.toggle(
          CREATE_OFFSCREEN_CLASS,
          !entry.isIntersecting
        );
      },
      { rootMargin: `-${NAV_HEIGHT}px 0px 0px 0px` }
    );
    observer.observe(element);
    return () => {
      observer.disconnect();
      document.body.classList.remove(CREATE_OFFSCREEN_CLASS);
    };
  });

  constructor() {
    super(...arguments);
    this.router.on("routeDidChange", this.resetTab);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.router.off("routeDidChange", this.resetTab);
    this.closeSort();
    document.body.classList.remove(ABOUT_CLASS);
  }

  // Any navigation (a sort change, a category, a topic) returns to the feed,
  // so the About tab can't leave a hidden feed behind on the next page.
  @action
  resetTab() {
    this.closeSort();
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
      return {
        name,
        label,
        href: getURL(`/${name}`),
        selected: name === this.currentFilter,
      };
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

  // Custom sort menu (not a native <select>, so it matches the header's type
  // and the site's surfaces). Closes on outside tap, Escape, or navigation.
  @action
  toggleSort() {
    this.sortOpen ? this.closeSort() : this.openSort();
  }

  openSort() {
    this.sortOpen = true;
    document.addEventListener("click", this.onOutsideClick, true);
    document.addEventListener("keydown", this.onSortKeydown);
  }

  @action
  closeSort() {
    this.sortOpen = false;
    document.removeEventListener("click", this.onOutsideClick, true);
    document.removeEventListener("keydown", this.onSortKeydown);
  }

  @action
  onOutsideClick(event) {
    if (!event.target.closest(".wbo-community-header__sort")) {
      this.closeSort();
    }
  }

  @action
  onSortKeydown(event) {
    if (event.key === "Escape") {
      this.closeSort();
      document.querySelector(".wbo-community-header__sort-trigger")?.focus();
    }
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
              {{this.watchCreateButton}}
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
              {{icon "fab-discord"}}
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
            <div class="wbo-community-header__sort">
              <button
                type="button"
                class="wbo-community-header__sort-trigger"
                aria-haspopup="true"
                aria-expanded={{if this.sortOpen "true" "false"}}
                aria-label={{i18n (themePrefix "community_header.sort")}}
                {{on "click" this.toggleSort}}
              >
                <span>{{this.currentSortLabel}}</span>
                {{wboIcon "caret-down" 16}}
              </button>
              {{#if this.sortOpen}}
                <ul class="wbo-community-header__sort-menu">
                  {{#each this.sortOptions as |opt|}}
                    <li>
                      <a
                        href={{opt.href}}
                        class="wbo-community-header__sort-item
                          {{if opt.selected 'active'}}"
                        aria-current={{if opt.selected "page"}}
                        {{on "click" this.closeSort}}
                      >{{opt.label}}</a>
                    </li>
                  {{/each}}
                </ul>
              {{/if}}
            </div>
          {{/unless}}
        </div>
      </div>

      {{#if this.isAbout}}
        <div class="wbo-community-header__about">
          <WboAboutPanel @mobile={{true}} />
        </div>
      {{/if}}
    {{/if}}
  </template>
}
