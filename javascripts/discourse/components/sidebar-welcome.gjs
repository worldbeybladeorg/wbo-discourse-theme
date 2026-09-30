import Component from "@glimmer/component";
import { service } from "@ember/service";
import WboAboutPanel from "./wbo-about-panel";

// Right sidebar on the top-level feeds (Latest, Unread, Hot…): the community
// About panel. Category and tag pages show their own About cards instead.
export default class SidebarWelcome extends Component {
  @service router;
  @service siteSettings;

  get isTopRoute() {
    const { currentRoute } = this.router;
    const topMenuRoutes = this.siteSettings.top_menu.split("|").filter(Boolean);
    return topMenuRoutes.includes(currentRoute.localName);
  }

  <template>
    {{#if this.isTopRoute}}
      <WboAboutPanel />
    {{/if}}
  </template>
}
