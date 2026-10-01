/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";
import FakeInputCreate from "../../components/fake-input-create";
import WboDiscordStrip from "../../components/wbo-discord-strip";

@classNames("discovery-navigation-bar-above-outlet", "custom-post-bar")
export default class CustomPostBar extends Component {
  <template>
    <FakeInputCreate />
    <WboDiscordStrip />
  </template>
}
