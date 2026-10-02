import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import CategoryNotificationsTracking from "discourse/components/category-notifications-tracking";
import DButton from "discourse/components/d-button";
import NotificationsTracking from "discourse/components/notifications-tracking";
import icon from "discourse/helpers/d-icon";
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
import WboCategoryMark from "./wbo-category-mark";

const ABOUT_CLASS = "wbo-about-tab-open";
const CREATE_OFFSCREEN_CLASS = "wbo-header-create-offscreen";
// The WBO nav bar is fixed over the top 56px, so a button scrolled under it
// counts as out of view.
const NAV_HEIGHT = 56;

// Narrow-screen header for the top-level feeds, Reddit style:
//   [New topic] [Discord]
//   Latest ▾ | Categories | About
// The first tab is the topic list, named by its current sort. While it is the
// active tab, tapping it opens the sort menu; from another tab, tapping its
// label goes back to the list and tapping its caret opens the sort menu to go
// straight to a sort. (So nothing says "Topics" while the categories page is
// showing, and there is no separate sort control to fit on the line.)
// Only shows where the right sidebar is hidden (CSS, <= 1160px), where it
// replaces Discourse's navigation bar: phones and tablets alike.
// The About tab shows the same panel the right sidebar shows on desktop.
//
// A category or tag page gets the same header, scoped to that category or
// tag, under a title row that names it (in place of the old colour banner):
//   ■ Beyblade General                         [settings]
//   [New topic] [Watching]
//   Latest ▾ | About
// The title row shows at every width. Above 1160px it is all that shows, and
// it carries the Watching control and the sidebar star (New topic is at the
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

  // The tag this page lists, if it is a tag page.
  get pageTag() {
    return this.category ? null : this.tag;
  }

  // A page for several tags at once ("a + b"): named, but with nothing to
  // watch, star or edit, as in core.
  get isTagIntersection() {
    return !!this.routeAttributes?.additionalTags?.length;
  }

  get tagTitle() {
    const more = this.routeAttributes?.additionalTags || [];
    return [this.pageTag.name, ...more].join(" + ");
  }

  // A category or tag page: gets the title row, and its own links and counts.
  get isScoped() {
    return !!this.category || !!this.pageTag;
  }

  get currentFilter() {
    return (
      (this.isScoped && this.routeAttributes.filterType) ||
      this.router.currentRoute?.localName
    );
  }

  get isTopRoute() {
    return this.topMenu.includes(this.router.currentRoute?.localName);
  }

  // The /categories page: its own tab on the top-level pages.
  get isCategoriesPage() {
    return (
      !this.isScoped && this.router.currentRoute?.localName === "categories"
    );
  }

  get showCategoriesTab() {
    return !this.isScoped && this.topMenu.includes("categories");
  }

  get categoriesHref() {
    return getURL("/categories");
  }

  get categoriesActive() {
    return this.isCategoriesPage && !this.isAbout;
  }

  get topicsActive() {
    return !this.isCategoriesPage && !this.isAbout;
  }

  get show() {
    return this.isScoped || this.isTopRoute;
  }

  // Loaded by the tag route for signed-in users.
  get tagNotification() {
    return this.isTagIntersection
      ? null
      : this.routeAttributes?.tagNotification;
  }

  get tagNotificationLevel() {
    return get(this.tagNotification, "notification_level");
  }

  get canStarTag() {
    return this.currentUser && !this.isTagIntersection;
  }

  get canEditTag() {
    return (
      this.currentUser?.canEditTags &&
      !this.isTagIntersection &&
      this.pageTag.name !== "none"
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
    if (this.pageTag) {
      const attrs = this.routeAttributes;
      return attrs.canCreateTopic !== false && !!attrs.canCreateTopicOnTag;
    }
    return !this.category || this.category.permission === PermissionType.FULL;
  }

  get discordUrl() {
    return (settings.discord_invite_url || "").trim();
  }

  get sortOptions() {
    const scoped = this.isScoped;
    const category = this.category;
    const tag = scoped ? this.tag : null;
    const noSubcategories = !!this.routeAttributes?.noSubcategories;
    // Within a category or tag the counts and links are its own.
    // "Categories" is a page, not a sort: it has its own tab.
    const scope = scoped
      ? { categoryId: category?.id, tagId: tag?.id, noSubcategories }
      : {};
    const names = this.topMenu.filter((name) => name !== "categories");

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
        href: scoped
          ? NavItem.pathFor(name, { category, noSubcategories, tag })
          : getURL(`/${name}`),
        selected: name === this.currentFilter,
      };
    });
  }

  // The sort the first tab stands for: the one showing, or (on the categories
  // page, where no topic list is) the first, which is the default list.
  get currentSort() {
    const options = this.sortOptions;
    return options.find((o) => o.selected) || options[0];
  }

  get currentSortLabel() {
    return this.currentSort?.label;
  }

  @action
  setTab(tab) {
    this.tab = tab;
    document.body.classList.toggle(ABOUT_CLASS, tab === "about");
  }

  // The first tab. Active: opens the sort menu. Otherwise: back to the topic
  // list -- already on this page behind the About panel, or a page away from
  // the categories page.
  @action
  onTopicsTab() {
    if (this.topicsActive) {
      this.toggleSort();
      return;
    }
    this.closeSort();
    if (this.isCategoriesPage) {
      DiscourseURL.routeTo(this.currentSort.href);
    } else {
      this.setTab("feed");
    }
  }

  // A sort was picked, or the Categories tab tapped: the link navigates; if
  // it leads to the page already showing, bring its list back from behind
  // the About panel.
  @action
  showList() {
    this.closeSort();
    this.setTab("feed");
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
      tags: this.isScoped ? this.tag?.name : undefined,
    });
  }

  @action
  changeNotificationLevel(level) {
    return this.category.setNotification(level);
  }

  // As core's own tag notification menu does it (d-navigation.gjs).
  @action
  async changeTagNotificationLevel(level) {
    const response = await this.tagNotification.update({
      notification_level: level,
    });
    const payload = response.responseJson;
    this.tagNotification.set("notification_level", level);
    this.currentUser.setProperties({
      watched_tags: payload.watched_tags,
      watching_first_post_tags: payload.watching_first_post_tags,
      tracked_tags: payload.tracked_tags,
      muted_tags: payload.muted_tags,
      regular_tags: payload.regular_tags,
    });
  }

  // The same destinations as core's own wrench buttons on these pages.
  @action
  editCategory() {
    DiscourseURL.routeTo(`/c/${Category.slugFor(this.category)}/edit`);
  }

  @action
  editTag() {
    this.router.transitionTo(
      "tag.edit.tab",
      this.pageTag.slug,
      this.pageTag.id,
      "general"
    );
  }

  <template>
    {{#if this.show}}
      <div
        class="wbo-community-header
          {{if this.isScoped 'wbo-community-header--titled'}}"
      >
        {{#if this.category}}
          <div class="wbo-community-header__title">
            <WboCategoryMark @category={{this.category}} />
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
        {{else if this.pageTag}}
          <div class="wbo-community-header__title">
            <span class="wbo-community-header__mark">{{icon "tag"}}</span>
            <h1 class="wbo-community-header__name">{{this.tagTitle}}</h1>
            <span class="wbo-community-header__rail-only">
              {{#if this.tagNotification}}
                <NotificationsTracking
                  @levelId={{this.tagNotificationLevel}}
                  @onChange={{this.changeTagNotificationLevel}}
                  @showFullTitle={{true}}
                  @showCaret={{true}}
                  @prefix="tagging.notifications"
                  class="tag-notifications-tracking"
                />
              {{/if}}
              {{#if this.canStarTag}}
                <AddToSidebar @tag={{this.pageTag}} />
              {{/if}}
            </span>
            {{#if this.canEditTag}}
              <DButton
                @action={{this.editTag}}
                @icon="wrench"
                @title="tagging.edit"
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
          {{else if this.pageTag}}
            {{#if this.tagNotification}}
              <NotificationsTracking
                @levelId={{this.tagNotificationLevel}}
                @onChange={{this.changeTagNotificationLevel}}
                @showFullTitle={{true}}
                @showCaret={{true}}
                @prefix="tagging.notifications"
                class="tag-notifications-tracking"
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
            {{! The label and its caret read as one tab, so they share a
                wrapper (presentational: the tab still belongs to the list). }}
            <div
              class="wbo-community-header__sort
                {{if this.topicsActive 'is-active'}}"
              role="presentation"
            >
              {{! template-lint-disable require-context-role }}
              <button
                type="button"
                role="tab"
                class="wbo-community-header__tab wbo-community-header__tab--sort"
                aria-selected={{if this.topicsActive "true" "false"}}
                {{on "click" this.onTopicsTab}}
              >{{this.currentSortLabel}}</button>
              <button
                type="button"
                class="wbo-community-header__sort-trigger"
                aria-haspopup="true"
                aria-expanded={{if this.sortOpen "true" "false"}}
                aria-label={{i18n (themePrefix "community_header.sort")}}
                {{on "click" this.toggleSort}}
              >
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
                        {{on "click" this.showList}}
                      >{{opt.label}}</a>
                    </li>
                  {{/each}}
                </ul>
              {{/if}}
            </div>
            {{#if this.showCategoriesTab}}
              <a
                href={{this.categoriesHref}}
                role="tab"
                class="wbo-community-header__tab"
                aria-selected={{if this.categoriesActive "true" "false"}}
                {{on "click" this.showList}}
              >{{i18n "filters.categories.title"}}</a>
            {{/if}}
            <button
              type="button"
              role="tab"
              class="wbo-community-header__tab"
              aria-selected={{if this.isAbout "true" "false"}}
              {{on "click" (fn this.setTab "about")}}
            >{{i18n (themePrefix "community_header.about")}}</button>
          </div>
        </div>
      </div>

      {{#if this.isAbout}}
        <div class="wbo-community-header__about">
          <WboAboutPanel
            @mobile={{true}}
            @category={{this.category}}
            @tag={{this.pageTag}}
          />
        </div>
      {{/if}}
    {{/if}}
  </template>
}
