import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Composer from "discourse/models/composer";
import PermissionType from "discourse/models/permission-type";
import { i18n } from "discourse-i18n";
import { wboIcon } from "../lib/wbo-icon";
import WboAboutPanel from "./wbo-about-panel";

// Right sidebar on a category page: the same sidebar as the top-level feeds
// (sidebar-welcome.gjs) -- the New post button above the About panel -- with
// the panel's first box about this category. New post opens the composer in
// the category. Watching and the sidebar star are in the page's title row
// (wbo-community-header.gjs).
export default class SidebarAboutCategory extends Component {
  @service router;
  @service currentUser;
  @service composer;

  get category() {
    return this.router.currentRoute?.attributes?.category;
  }

  get tag() {
    return this.router.currentRoute?.attributes?.tag;
  }

  get canCreateTopic() {
    return (
      this.currentUser?.can_create_topic &&
      this.category.permission === PermissionType.FULL
    );
  }

  @action
  createTopic() {
    this.composer.open({
      action: Composer.CREATE_TOPIC,
      draftKey: Composer.NEW_TOPIC_KEY,
      categoryId: this.category.id,
      tags: this.tag?.name,
    });
  }

  <template>
    {{#if this.category}}
      {{#if this.canCreateTopic}}
        <button
          type="button"
          class="btn btn-primary wbo-rail-create"
          {{on "click" this.createTopic}}
        >
          {{wboIcon "plus-bold" 18}}
          <span>{{i18n (themePrefix "community_header.create_topic")}}</span>
        </button>
      {{/if}}
      <WboAboutPanel @category={{this.category}} />
    {{/if}}
  </template>
}
