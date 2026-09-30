/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";
import FakeInputCreate from "../../components/fake-input-create";
import WboCommunityHeader from "../../components/wbo-community-header";

@classNames("discovery-navigation-bar-above-outlet", "custom-post-bar")
export default class CustomPostBar extends Component {
  <template>
    <FakeInputCreate />
    <WboCommunityHeader />
  </template>
}
