import Component from "@glimmer/component";
import { wboIcon } from "../../lib/wbo-icon";
import { memberData } from "../../lib/wbo-member";

// "View Profile" in place of core's Message button (hidden in
// scss/user-card.scss). Members' profiles live on WordPress, so it links
// there; a member with no linked WordPress account falls back to their
// Discourse profile. Rendered straight away so the card doesn't shift when
// the lookup lands — the href fills in then.
export default class WboViewProfile extends Component {
  get user() {
    return this.args.outletArgs.user;
  }

  get href() {
    const data = memberData(this.user?.username);
    if (data?.profile_url) {
      return data.profile_url;
    }
    return data === null ? this.user?.path : undefined;
  }

  <template>
    <a
      class="btn btn-primary btn-icon-text wbo-uc-profile"
      href={{this.href}}
    >
      {{wboIcon "user" 16}}
      <span class="d-button-label">View Profile</span>
    </a>
  </template>
}
