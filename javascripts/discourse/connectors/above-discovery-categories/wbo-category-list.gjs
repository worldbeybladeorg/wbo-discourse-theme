import WboCategoryList from "../../components/wbo-category-list";

const WboCategoryListConnector = <template>
  <WboCategoryList @categories={{@outletArgs.categories}} />
</template>;

export default WboCategoryListConnector;
