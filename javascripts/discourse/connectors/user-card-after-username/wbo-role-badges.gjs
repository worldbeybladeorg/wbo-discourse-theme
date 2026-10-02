import Component from "@glimmer/component";
import { memberData } from "../../lib/wbo-member";

// The Staff / Organizer / Judge pills under the user card's name — the same
// list WordPress shows on the member's profile card (wbo_profile_user_badges).
// They stand in for core's staff shield, which scss/user-card.scss hides.
export default class WboRoleBadges extends Component {
  get badges() {
    return memberData(this.args.outletArgs.user?.username)?.badges || [];
  }

  <template>
    {{#if this.badges.length}}
      <div class="wbo-uc-badges">
        {{#each this.badges as |b|}}
          <span class="wbo-uc-badge {{b.class}}">{{b.label}}</span>
        {{/each}}
      </div>
    {{/if}}
  </template>
}
