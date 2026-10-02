import { apiInitializer } from "discourse/lib/api";

// A lightboxed image at least this tall gets the blurred backdrop; smaller
// ones (icons, inline screenshots) stay as they are.
const MEDIA_WELL_MIN_HEIGHT = 250;

export default apiInitializer((api) => {
  // Post controls read "Like", "Reply", "Copy link" beside their icons, on
  // phones too (core shows icons only, and hides Reply's label on phones).
  // Order and look are in scss/thread.scss.
  api.registerValueTransformer(
    "post-menu-buttons",
    ({ context: { buttonLabels, buttonKeys } }) => {
      buttonLabels.show(buttonKeys.LIKE);
      buttonLabels.show(buttonKeys.REPLY);
      buttonLabels.show(buttonKeys.COPY_LINK);
      buttonLabels.show(buttonKeys.SHARE);
    }
  );

  // A large image narrower than the post sits centred on a blurred copy of
  // itself, like the feed's thumbnails. CSS can't read an <img>'s src, so
  // hand it over as a custom property (scss/thread.scss draws it).
  api.decorateCookedElement(
    (element) => {
      element.querySelectorAll(".lightbox-wrapper").forEach((wrapper) => {
        const img = wrapper.querySelector("a.lightbox > img");
        const src = img?.getAttribute("src");
        if (
          !src ||
          Number(img.getAttribute("height")) < MEDIA_WELL_MIN_HEIGHT ||
          wrapper.closest(".d-image-grid, .onebox, aside.quote")
        ) {
          return;
        }
        wrapper.style.setProperty(
          "--wbo-media-bg",
          `url("${src.replace(/["\\\n]/g, encodeURIComponent)}")`
        );
        wrapper.classList.add("wbo-media-well");
      });
    },
    { id: "wbo-media-well" }
  );
});
