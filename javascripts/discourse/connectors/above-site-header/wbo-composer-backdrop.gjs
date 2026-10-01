import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";

// ── Composer backdrop ─────────────────────────────────────────────────────────
//
// Dims the page behind the open composer so the panel reads as a foreground
// surface rather than one more --secondary card. Styling lives in
// scss/composer.scss; this component exists only to (a) put a real element in
// the DOM and (b) make clicking it do something sensible.
//
// Why an element and not body::before, which is what this started as: core
// clearfixes <body>, so body::before computes to display:table. position:fixed
// does NOT blockify a table box, it shrink-wraps, and inset:0 then resolves to
// a 0x0 box that paints nothing. A real div sidesteps that entirely -- and a
// pseudo-element can't take a click listener anyway.
//
// Click behaviour is collapse(), not close(). collapse() saves the draft and
// drops the composer to the 40px draft strip, so a stray click costs you
// nothing and never raises the "abandon draft?" dialog that close() would.
// This matches .wbo-nav-backdrop in wbo-site-nav.gjs, where clicking the
// backdrop dismisses the drawer.
//
// Visibility is CSS's job: core puts `composer-open` on <html> only while
// the composer is OPEN (not in the collapsed draft strip), and the backdrop is
// display:none otherwise, so it never swallows clicks while shut. An earlier
// version guarded on composer.model.composeState in the template, but that
// read isn't reactive here and the backdrop never appeared.
export default class WboComposerBackdrop extends Component {
  @service composer;
  @service site;

  // Mobile takes the composer fullscreen at z 1100, so there is nothing
  // left to dim -- and a tap-to-collapse target there would just be a way
  // to lose your place mid-post.
  get isVisible() {
    return !this.site.mobileView;
  }

  @action
  collapse() {
    this.composer.collapse();
  }

  <template>
    {{#if this.isVisible}}
      {{! template-lint-disable no-invalid-interactive }}
      <div
        {{on "click" this.collapse}}
        class="wbo-composer-backdrop"
        role="presentation"
      ></div>
    {{/if}}
  </template>
}
