import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";
import { wboIcon } from "../lib/wbo-icon";
import WboAboutPanel from "./wbo-about-panel";

// Right sidebar on a tag page: the same sidebar as the top-level feeds and
// category pages -- the New topic button above the About panel -- with the
// panel's first box about this tag. New topic opens the composer with the tag
// filled in. Watching and the sidebar star are in the page's title row
// (wbo-community-header.gjs). A tag within a category is that category's
// page (sidebar-about-category.gjs).
export default class SidebarAboutTag extends Component {
  @service router;
  @service currentUser;
  @service composer;

  get routeAttributes() {
    return this.router.currentRoute?.attributes;
  }

  get tag() {
    const attrs = this.routeAttributes;
    return attrs?.category ? null : attrs?.tag;
  }

  get canCreateTopic() {
    const attrs = this.routeAttributes;
    return (
      this.currentUser?.can_create_topic &&
      attrs.canCreateTopic !== false &&
      !!attrs.canCreateTopicOnTag
    );
  }

  @action
  createTopic() {
    this.composer.open({
      action: Composer.CREATE_TOPIC,
      draftKey: Composer.NEW_TOPIC_KEY,
      tags: this.tag.name,
    });
  }

  <template>
    {{#if this.tag}}
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
      <WboAboutPanel @tag={{this.tag}} />
    {{/if}}
  </template>
}
