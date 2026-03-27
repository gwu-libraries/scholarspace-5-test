// This is the main Shakapacker entrypoint for application assets

import "@rails/activestorage";
import "@hotwired/turbo";

// Required by Blacklight
import $ from "jquery";
window.$ = $;
window.jQuery = $;
globalThis.$ = $;
globalThis.jQuery = $;
import "jquery-ui";
import "@rails/ujs";
import "popper.js";
import "bootstrap";
import ReactOnRails from "react-on-rails";

// Import stylesheets
import "stylesheets/application.css";
import "stylesheets/openseadragon.css";
