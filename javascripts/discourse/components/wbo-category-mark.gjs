import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import replaceEmoji from "discourse/helpers/replace-emoji";

// A category's own mark, as in the sidebar: its icon or emoji if it has one,
// otherwise a square of its colour. Sized by the parent (scss/community.scss).
export default class WboCategoryMark extends Component {
  get icon() {
    const category = this.args.category;
    return category.style_type === "icon" ? category.icon : null;
  }

  get emojiCode() {
    const category = this.args.category;
    return category.style_type === "emoji" && category.emoji
      ? `:${category.emoji}:`
      : null;
  }

  get colorStyle() {
    const color = this.args.category.color;
    if (!/^[0-9a-f]{3,8}$/i.test(color || "")) {
      return null;
    }
    return htmlSafe(
      this.icon ? `color: #${color}` : `background-color: #${color}`
    );
  }

  <template>
    {{#if this.icon}}
      <span class="wbo-category-mark --icon" style={{this.colorStyle}}>{{icon
          this.icon
        }}</span>
    {{else if this.emojiCode}}
      <span class="wbo-category-mark --emoji">{{replaceEmoji
          this.emojiCode
        }}</span>
    {{else}}
      <span class="wbo-category-mark --square" style={{this.colorStyle}}></span>
    {{/if}}
  </template>
}
