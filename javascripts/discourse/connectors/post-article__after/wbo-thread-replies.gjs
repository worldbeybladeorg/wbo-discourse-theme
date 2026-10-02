import WboThreadReplies from "../../components/wbo-thread-replies";

// `post-article` wraps each post's <article>; its `__after` slot is inside the
// post's own element, straight after the article.
const WboThreadRepliesConnector = <template>
  <WboThreadReplies @post={{@outletArgs.post}} />
</template>;

export default WboThreadRepliesConnector;
