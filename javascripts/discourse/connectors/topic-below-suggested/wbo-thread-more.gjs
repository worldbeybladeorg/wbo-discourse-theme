import WboThreadMore from "../../components/wbo-thread-more";

const WboThreadMoreConnector = <template>
  <WboThreadMore @topic={{@outletArgs.model}} />
</template>;

export default WboThreadMoreConnector;
