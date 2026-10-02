import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import TopicNotificationsTracking from "discourse/components/topic-notifications-tracking";
import avatar from "discourse/helpers/avatar";
import { i18n } from "discourse-i18n";

// What sits between the first post and the replies (scss/thread.scss):
//   [avatar] [Add a reply…]
//   3 replies                              Watching ▾
// Rendered after every post's article (connectors/post-article__after), but
// only the first post shows anything.
export default class WboThreadReplies extends Component {
  @service currentUser;

  get topic() {
    return this.args.post?.topic;
  }

  get isFirstPost() {
    return this.args.post?.post_number === 1 && !!this.topic;
  }

  get canReply() {
    return !!this.currentUser && !!this.topic.details?.can_create_post;
  }

  get canLogIn() {
    return !this.currentUser;
  }

  get title() {
    const count = Math.max(this.topic.replyCount || 0, 0);
    return count
      ? i18n(themePrefix("thread.replies"), { count })
      : i18n(themePrefix("thread.no_replies"));
  }

  get notificationLevel() {
    return this.topic.details?.notification_level;
  }

  // The same action as core's own Reply button in the topic footer.
  @action
  reply() {
    getOwner(this).lookup("controller:topic").replyToPost();
  }

  @action
  logIn() {
    getOwner(this).lookup("route:application").send("showLogin");
  }

  @action
  changeNotificationLevel(levelId) {
    if (levelId !== this.notificationLevel) {
      return this.topic.details.updateNotifications(levelId);
    }
  }

  <template>
    {{#if this.isFirstPost}}
      <div class="wbo-thread-replies">
        {{#if this.canReply}}
          <div class="wbo-thread-replies__bar">
            <a
              href="/u/{{this.currentUser.username}}"
              data-user-card={{this.currentUser.username}}
            >
              {{avatar this.currentUser imageSize="medium"}}
            </a>
            <button
              type="button"
              class="wbo-thread-replies__prompt"
              {{on "click" this.reply}}
            >
              {{i18n (themePrefix "thread.reply_placeholder")}}
            </button>
          </div>
        {{else if this.canLogIn}}
          <div class="wbo-thread-replies__bar">
            <button
              type="button"
              class="wbo-thread-replies__prompt"
              {{on "click" this.logIn}}
            >
              {{i18n (themePrefix "thread.log_in_to_reply")}}
            </button>
          </div>
        {{/if}}

        <div class="wbo-thread-replies__head">
          <h3 class="wbo-thread-replies__title">{{this.title}}</h3>

          {{#if this.currentUser}}
            <TopicNotificationsTracking
              @levelId={{this.notificationLevel}}
              @onChange={{this.changeNotificationLevel}}
              @showFullTitle={{true}}
              @showCaret={{true}}
              @topic={{this.topic}}
            />
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
