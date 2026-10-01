import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";
import { wboIcon } from "../lib/wbo-icon";
import WboAboutPanel from "./wbo-about-panel";

// Right sidebar on the top-level feeds (Latest, Unread, Hot…): the Create
// topic button (the same .btn-primary as the phone header) above the
// community About panel. Category and tag pages show their own About cards.
export default class SidebarWelcome extends Component {
  @service router;
  @service siteSettings;
  @service composer;
  @service currentUser;

  get isTopRoute() {
    const { currentRoute } = this.router;
    const topMenuRoutes = this.siteSettings.top_menu.split("|").filter(Boolean);
    return topMenuRoutes.includes(currentRoute.localName);
  }

  get canCreateTopic() {
    return this.currentUser?.can_create_topic;
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
      {{#if this.canCreateTopic}}
        <button
          type="button"
          class="btn btn-primary wbo-rail-create"
          {{on "click" this.createTopic}}
        >
          {{wboIcon "pencil" 18}}
          <span>{{i18n (themePrefix "community_header.create_topic")}}</span>
        </button>
      {{/if}}
      <WboAboutPanel />
    {{/if}}
  </template>
}
