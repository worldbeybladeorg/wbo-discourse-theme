/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import CustomTagBanner from "../../components/custom-tag-banner";

// Tag pages keep their banner. Category pages are named by the title row in
// the feed column instead (components/wbo-community-header.gjs).
@tagName("")
export default class CustomCategoryBannerConnector extends Component {
  <template><CustomTagBanner /></template>
}
