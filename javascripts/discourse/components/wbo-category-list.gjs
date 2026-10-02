import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import ReorderCategories from "discourse/components/modal/reorder-categories";
import categoryLink from "discourse/helpers/category-link";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";
import { wboIcon } from "../lib/wbo-icon";
import WboCategoryMark from "./wbo-category-mark";

// The Tournaments category is link-only (its topics power the comments on the
// WordPress event pages) and stays out of every list. Matched by slug, as in
// scss/categories.scss: its id differs between the dev and live forums.
const HIDDEN_SLUGS = ["tournaments"];

// The categories page as a list of cards, in the feed column, in place of
// core's table (hidden in scss/categories.scss):
//   ■ Beyblade General
//   Post anything about any generation of Beyblade products!
//   4 topics · 5 posts · 2 unread
// then the viewer's muted categories, folded away, and for staff the two
// actions core keeps in a corner dropdown: New category, Reorder.
export default class WboCategoryList extends Component {
  @service currentUser;
  @service modal;
  @service router;
  @service topicTrackingState;

  get show() {
    return this.router.currentRouteName === "discovery.categories";
  }

  get cards() {
    return (this.args.categories || [])
      .filter((category) => !HIDDEN_SLUGS.includes(category.slug))
      .map((category) => this.card(category));
  }

  get listed() {
    return this.cards.filter((card) => !card.muted);
  }

  get muted() {
    return this.cards.filter((card) => card.muted);
  }

  card(category) {
    const all = [category, ...(category.subcategories || [])];
    const topics = all.reduce((n, c) => n + (c.topic_count || 0), 0);
    const posts = all.reduce((n, c) => n + (c.post_count || 0), 0);
    const scope = { categoryId: category.id };
    const unread = this.currentUser
      ? this.topicTrackingState.countUnread(scope)
      : 0;
    const fresh = this.currentUser
      ? this.topicTrackingState.countNew(scope)
      : 0;

    return {
      category,
      url: category.url,
      muted: category.isMuted,
      description: category.description_text
        ? htmlSafe(category.description_text)
        : null,
      subcategories: category.subcategories || [],
      topicsLabel: topics
        ? i18n(themePrefix("category_list.topics"), { count: topics })
        : i18n(themePrefix("category_list.no_topics")),
      postsLabel: topics
        ? i18n(themePrefix("category_list.posts"), { count: posts })
        : null,
      unreadLabel: unread
        ? i18n(themePrefix("category_list.unread"), { count: unread })
        : null,
      unreadUrl: `${category.url}/l/unread`,
      newLabel: fresh
        ? i18n(themePrefix("category_list.new"), { count: fresh })
        : null,
      newUrl: `${category.url}/l/new`,
    };
  }

  // The same two actions as core's categories admin dropdown
  // (components/discovery/navigation.gjs).
  get canManage() {
    return !!this.router.currentRoute?.attributes?.can_create_category;
  }

  @action
  createCategory() {
    const chooser = getOwner(this).lookup("service:category-type-chooser");
    if (chooser?.createCategory) {
      chooser.createCategory();
    } else {
      DiscourseURL.routeTo(getURL("/new-category"));
    }
  }

  @action
  reorderCategories() {
    this.modal.show(ReorderCategories);
  }

  <template>
    {{#if this.show}}
      <div class="wbo-category-list">
        {{#each this.listed as |card|}}
          <CategoryCard @card={{card}} />
        {{/each}}

        {{#if this.muted.length}}
          <details class="wbo-category-list__muted">
            <summary>
              <span>{{i18n "categories.muted"}}</span>
              {{wboIcon "caret-down" 16}}
            </summary>
            <div class="wbo-category-list__muted-items">
              {{#each this.muted as |card|}}
                <CategoryCard @card={{card}} />
              {{/each}}
            </div>
          </details>
        {{/if}}

        {{#if this.canManage}}
          <div class="wbo-category-list__manage">
            <button type="button" {{on "click" this.createCategory}}>
              {{wboIcon "plus-bold" 14}}
              <span>{{i18n (themePrefix "category_list.new_category")}}</span>
            </button>
            <button type="button" {{on "click" this.reorderCategories}}>
              {{i18n (themePrefix "category_list.reorder")}}
            </button>
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}

// One category. The name is the card's link and covers the whole card; the
// links inside it (subcategories, unread, new) sit above that.
const CategoryCard = <template>
  <article class="wbo-category-card">
    <h2 class="wbo-category-card__name">
      <WboCategoryMark @category={{@card.category}} />
      <a href={{@card.url}} class="wbo-category-card__link">
        {{@card.category.name}}
      </a>
      {{#if @card.category.read_restricted}}
        {{icon "lock" class="wbo-category-card__lock"}}
      {{/if}}
    </h2>
    {{#if @card.description}}
      <p class="wbo-category-card__description">{{@card.description}}</p>
    {{/if}}
    {{#if @card.subcategories.length}}
      <div class="wbo-category-card__subcategories">
        {{#each @card.subcategories as |subcategory|}}
          {{categoryLink subcategory}}
        {{/each}}
      </div>
    {{/if}}
    <p class="wbo-category-card__meta">
      <span>{{@card.topicsLabel}}</span>
      {{#if @card.postsLabel}}
        <span>{{@card.postsLabel}}</span>
      {{/if}}
      {{#if @card.unreadLabel}}
        <a href={{@card.unreadUrl}}>{{@card.unreadLabel}}</a>
      {{/if}}
      {{#if @card.newLabel}}
        <a href={{@card.newUrl}}>{{@card.newLabel}}</a>
      {{/if}}
    </p>
  </article>
</template>;
