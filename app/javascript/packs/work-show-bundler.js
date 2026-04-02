import ReactOnRails from "react-on-rails";
import WorkShow from "../bundles/work_show/WorkShow";
import "video.js/dist/video-js.css";
import "@samvera/ramp/dist/ramp.css";

ReactOnRails.register({
  WorkShow,
});

document.addEventListener("turbo:render", () => {
  ReactOnRails.reactOnRailsPageLoaded();
});
