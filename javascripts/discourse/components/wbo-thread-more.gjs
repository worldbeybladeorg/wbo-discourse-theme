import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

// Under "more topics" on a regular topic: buttons in place of core's sentence
// ("There are 25 unread topics remaining, or browse other topics in …"), from
// the same counts (core: components/more-topics/browse-more.gjs).
//   [See all 25 unread topics] [■ Browse WBO Updates]
// Private messages keep core's sentence (scss/thread.scss).
export default class WboThreadMore extends Component {
  @service currentUser;
  @service site;
  @service topicTrackingState;

  get show() {
    return !!this.args.topic && !this.args.topic.isPrivateMessage;
  }

  get category() {
    const category = this.args.topic.category;
    return category && category.id !== this.site.uncategorized_category_id
      ? category
      : null;
  }

  get categoryDotStyle() {
    const color = this.category?.color;
    return /^[0-9a-f]{3,8}$/i.test(color || "")
      ? htmlSafe(`background-color: #${color}`)
      : null;
  }

  get unreadCount() {
    return this.currentUser ? this.topicTrackingState.countUnread() : 0;
  }

  get newCount() {
    return this.currentUser ? this.topicTrackingState.countNew() : 0;
  }

  get unreadLabel() {
    return i18n(themePrefix("thread.see_unread"), { count: this.unreadCount });
  }

  get newLabel() {
    return i18n(themePrefix("thread.see_new"), { count: this.newCount });
  }

  get browseLabel() {
    return i18n(themePrefix("thread.browse_category"), {
      category: this.category.name,
    });
  }

  <template>
    {{#if this.show}}
      <div class="wbo-thread-more">
        {{#if this.unreadCount}}
          <a class="btn btn-primary" href={{getURL "/unread"}}>
            {{this.unreadLabel}}
          </a>
        {{/if}}

        {{#if this.newCount}}
          <a
            class="btn {{if this.unreadCount 'btn-default' 'btn-primary'}}"
            href={{getURL "/new"}}
          >
            {{this.newLabel}}
          </a>
        {{/if}}

        {{#if this.category}}
          <a class="btn btn-default" href={{this.category.url}}>
            <span
              class="wbo-thread-more__dot"
              style={{this.categoryDotStyle}}
            ></span>
            {{this.browseLabel}}
          </a>
        {{else}}
          <a class="btn btn-default" href={{getURL "/latest"}}>
            {{i18n (themePrefix "thread.latest")}}
          </a>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
