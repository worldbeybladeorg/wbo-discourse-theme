import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import CategoryNotificationsTracking from "discourse/components/category-notifications-tracking";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import replaceEmoji from "discourse/helpers/replace-emoji";
import getURL from "discourse/lib/get-url";
import { NotificationLevels } from "discourse/lib/notification-levels";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import Composer from "discourse/models/composer";
import NavItem from "discourse/models/nav-item";
import PermissionType from "discourse/models/permission-type";
import { i18n } from "discourse-i18n";
import { wboIcon } from "../lib/wbo-icon";
import AddToSidebar from "./add-to-sidebar";
import WboAboutPanel from "./wbo-about-panel";

const ABOUT_CLASS = "wbo-about-tab-open";
const CREATE_OFFSCREEN_CLASS = "wbo-header-create-offscreen";
// The WBO nav bar is fixed over the top 56px, so a button scrolled under it
// counts as out of view.
const NAV_HEIGHT = 56;

// Narrow-screen header for the top-level feeds, Reddit style:
//   [New post] [Discord]
//   Posts | About                      Latest ▾
// Only shows where the right sidebar is hidden (CSS, <= 1160px), where it
// replaces Discourse's navigation bar: phones and tablets alike.
// The About tab shows the same panel the right sidebar shows on desktop.
//
// A category page gets the same header, scoped to the category, under a title
// row that names it (in place of the old colour banner):
//   ■ Beyblade General                         [settings]
//   [New post] [Watching]
//   Posts | About                      Latest ▾
// The title row shows at every width. Above 1160px it is all that shows, and
// it carries the Watching control and the sidebar star (New post is at the
// top of the right sidebar there, and the filters are Discourse's own tabs).
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

  get routeAttributes() {
    return this.router.currentRoute?.attributes;
  }

  // The category this page lists, if it is a category page (a tag within a
  // category counts as that category's page, as it does for the sidebar).
  get category() {
    return this.routeAttributes?.category;
  }

  get tag() {
    return this.routeAttributes?.tag;
  }

  get currentFilter() {
    return (
      (this.category && this.routeAttributes.filterType) ||
      this.router.currentRoute?.localName
    );
  }

  get isTopRoute() {
    return this.topMenu.includes(this.router.currentRoute?.localName);
  }

  get show() {
    return !!this.category || this.isTopRoute;
  }

  // The category's own mark, as in the sidebar: its icon or emoji if it has
  // one, otherwise a square of its colour.
  get categoryIcon() {
    return this.category.style_type === "icon" ? this.category.icon : null;
  }

  get categoryEmoji() {
    return this.category.style_type === "emoji" ? this.category.emoji : null;
  }

  get categoryEmojiCode() {
    return `:${this.categoryEmoji}:`;
  }

  get categoryColorStyle() {
    const color = this.category.color;
    if (!/^[0-9a-f]{3,8}$/i.test(color || "")) {
      return null;
    }
    return htmlSafe(
      this.categoryIcon ? `color: #${color}` : `background-color: #${color}`
    );
  }

  get notificationLevel() {
    if (
      this.currentUser?.indirectly_muted_category_ids?.includes(
        this.category.id
      )
    ) {
      return NotificationLevels.MUTED;
    }
    // get(): notification_level is set() by the model, so read it tracked.
    return get(this.category, "notification_level");
  }

  get isAbout() {
    return this.tab === "about";
  }

  get canCreateTopic() {
    if (!this.currentUser?.can_create_topic) {
      return false;
    }
    return !this.category || this.category.permission === PermissionType.FULL;
  }

  get discordUrl() {
    return (settings.discord_invite_url || "").trim();
  }

  get sortOptions() {
    const category = this.category;
    const noSubcategories = !!this.routeAttributes?.noSubcategories;
    // Within a category the counts and links are the category's own, and
    // "Categories" (a site-wide page) drops out.
    const tag = category ? this.tag : null;
    const scope = category
      ? { categoryId: category.id, tagId: tag?.id, noSubcategories }
      : {};
    const names = category
      ? this.topMenu.filter((name) => name !== "categories")
      : this.topMenu;

    return names.map((name) => {
      let label = i18n(`filters.${name}.title`);
      let count = 0;
      if (this.currentUser && name === "unread") {
        count = this.topicTrackingState.countUnread(scope);
      } else if (this.currentUser && name === "new") {
        count = this.topicTrackingState.countNew(scope);
      }
      if (count > 0) {
        label = `${label} (${count})`;
      }
      return {
        name,
        label,
        href: category
          ? NavItem.pathFor(name, { category, noSubcategories, tag })
          : getURL(`/${name}`),
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
      categoryId: this.category?.id,
      tags: this.category ? this.tag?.name : undefined,
    });
  }

  @action
  changeNotificationLevel(level) {
    return this.category.setNotification(level);
  }

  // The same destination as core's own wrench button on category pages.
  @action
  editCategory() {
    DiscourseURL.routeTo(`/c/${Category.slugFor(this.category)}/edit`);
  }

  <template>
    {{#if this.show}}
      <div
        class="wbo-community-header
          {{if this.category 'wbo-community-header--category'}}"
      >
        {{#if this.category}}
          <div class="wbo-community-header__title">
            {{#if this.categoryIcon}}
              <span
                class="wbo-community-header__mark"
                style={{this.categoryColorStyle}}
              >{{icon this.categoryIcon}}</span>
            {{else if this.categoryEmoji}}
              <span class="wbo-community-header__mark">{{replaceEmoji
                  this.categoryEmojiCode
                }}</span>
            {{else}}
              <span
                class="wbo-community-header__swatch"
                style={{this.categoryColorStyle}}
              ></span>
            {{/if}}
            <h1 class="wbo-community-header__name">{{this.category.name}}</h1>
            {{#if this.currentUser}}
              <span class="wbo-community-header__rail-only">
                <CategoryNotificationsTracking
                  @levelId={{this.notificationLevel}}
                  @onChange={{this.changeNotificationLevel}}
                  @showFullTitle={{true}}
                  @showCaret={{true}}
                />
                <AddToSidebar @category={{this.category}} />
              </span>
            {{/if}}
            {{#if this.category.can_edit}}
              <DButton
                @action={{this.editCategory}}
                @icon="wrench"
                @title="category.edit_title"
                class="btn-flat wbo-community-header__settings"
              />
            {{/if}}
          </div>
        {{/if}}

        <div class="wbo-community-header__actions">
          {{#if this.canCreateTopic}}
            <button
              type="button"
              class="btn btn-primary"
              {{on "click" this.createTopic}}
              {{this.watchCreateButton}}
            >
              {{wboIcon "plus-bold" 18}}
              <span>{{i18n
                  (themePrefix "community_header.create_topic")
                }}</span>
            </button>
          {{/if}}
          {{#if this.category}}
            {{#if this.currentUser}}
              <CategoryNotificationsTracking
                @levelId={{this.notificationLevel}}
                @onChange={{this.changeNotificationLevel}}
                @showFullTitle={{true}}
                @showCaret={{true}}
              />
            {{/if}}
          {{else if this.discordUrl}}
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
          <WboAboutPanel @mobile={{true}} @category={{this.category}} />
        </div>
      {{/if}}
    {{/if}}
  </template>
}
