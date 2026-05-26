import ReactOnRails from "react-on-rails";

import {
  ViewerToggle,
} from "../bundles/viewers";
import { WorkShowServer as WorkShow } from "../bundles/work-show";
import { HomepageServer as Homepage } from "../bundles/homepage";

// This is how react_on_rails can see the HelloWorld in the browser.
ReactOnRails.register({
  ViewerToggle,
  WorkShow,
  Homepage,
});
