import ReactOnRails from "react-on-rails";
// import Homepage from '../bundles/homepage/Homepage';

ReactOnRails.register({
  Homepage,
});

document.addEventListener("turbo:render", () => {
  ReactOnRails.reactOnRailsPageLoaded();
});
