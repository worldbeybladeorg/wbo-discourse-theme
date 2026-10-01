import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import avatar from "discourse/helpers/avatar";
import Composer from "discourse/models/composer";
import { and } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { wboIcon } from "../lib/wbo-icon";

export default class FakeInputCreate extends Component {
  @service composer;
  @service router;
  @service currentUser;

  get hasDrafts() {
    return this.currentUser.get("draft_count");
  }

  get draftsLabel() {
    return i18n(themePrefix("drafts_link"), { count: this.hasDrafts });
  }

  get category() {
    return this.router.currentRoute?.attributes?.category;
  }

  get tag() {
    return this.router.currentRoute?.attributes?.tag;
  }

  @action
  customCreateTopic() {
    if (document.querySelector(".d-editor-input")) {
      document.querySelector(".d-editor-input").focus();
    } else {
      this.composer.open({
        action: Composer.CREATE_TOPIC,
        draftKey: Composer.NEW_TOPIC_KEY,
        categoryId: this.category?.id,
        tags: this.tag?.name,
      });
    }
  }

  <template>
    {{#if (and this.currentUser this.currentUser.can_create_topic)}}
      <div class="custom-post-bar-contents">
        <a href="/u/{{this.currentUser.username}}">
          {{avatar this.currentUser imageSize="medium"}}
        </a>
        <Input
          @type="text"
          placeholder={{i18n (themePrefix "post_input_placeholder")}}
          {{on "click" this.customCreateTopic}}
        />
        {{#if this.hasDrafts}}
          {{! A plain link to the drafts list. Core's TopicDraftsDropdown
              became a create-topic combo button that needs @action and
              @showDrafts; rendered bare it was a dead button. }}
          <a
            href="/my/activity/drafts"
            class="wbo-drafts-link"
            title={{this.draftsLabel}}
            aria-label={{this.draftsLabel}}
          >
            {{wboIcon "pencil" 18}}
            <span class="wbo-drafts-link__count">{{this.hasDrafts}}</span>
          </a>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
