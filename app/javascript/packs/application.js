// This is the main Shakapacker entrypoint for application assets

import "@rails/activestorage";
import "@hotwired/turbo";

// Required by Blacklight
import $ from "jquery";
window.$ = $;
window.jQuery = $;
globalThis.$ = $;
globalThis.jQuery = $;
import "@rails/ujs";

// Import stylesheets
import "stylesheets/application.css";
import "stylesheets/openseadragon.css";

const BOOTSTRAP_TRIGGER_SELECTOR = [
  "[data-toggle]",
  "[data-bs-toggle]",
  ".dropdown-toggle",
  ".collapse",
  ".modal",
  ".carousel",
].join(",");

const JQUERY_UI_TRIGGER_SELECTOR = [
  "[data-autocomplete-url]",
  "[data-behavior*='autocomplete']",
  ".ui-autocomplete-input",
].join(",");

let bootstrapLoaded = false;
let jqueryUiLoaded = false;
let bootstrapLoadPromise = null;
let jqueryUiLoadPromise = null;

function ensureBootstrapLoaded() {
  if (bootstrapLoaded) return Promise.resolve();
  if (bootstrapLoadPromise) return bootstrapLoadPromise;

  bootstrapLoadPromise = import("popper.js")
    .then(() => import("bootstrap"))
    .then(() => {
      bootstrapLoaded = true;
    })
    .catch((error) => {
      bootstrapLoaded = false;
      bootstrapLoadPromise = null;
      throw error;
    });

  return bootstrapLoadPromise;
}

function ensureJqueryUiLoaded() {
  if (jqueryUiLoaded) return Promise.resolve();
  if (jqueryUiLoadPromise) return jqueryUiLoadPromise;

  jqueryUiLoadPromise = import("jquery-ui")
    .then(() => {
      jqueryUiLoaded = true;
    })
    .catch((error) => {
      jqueryUiLoaded = false;
      jqueryUiLoadPromise = null;
      throw error;
    });

  return jqueryUiLoadPromise;
}

function loadBootstrapIfNeeded() {
  if (bootstrapLoaded) return;
  if (!document.querySelector(BOOTSTRAP_TRIGGER_SELECTOR)) return;

  ensureBootstrapLoaded().catch(() => {});
}

function loadJqueryUiIfNeeded() {
  if (jqueryUiLoaded) return;
  if (!document.querySelector(JQUERY_UI_TRIGGER_SELECTOR)) return;

  ensureJqueryUiLoaded().catch(() => {});
}

function eventTargetElement(event) {
  return event.target instanceof Element ? event.target : null;
}

function installInteractionFallbackLoaders() {
  document.addEventListener(
    "click",
    (event) => {
      if (bootstrapLoaded) return;

      const target = eventTargetElement(event);
      if (!target) return;

      const trigger = target.closest(BOOTSTRAP_TRIGGER_SELECTOR);
      if (!trigger) return;
      if (trigger.dataset.uiBootstrapLoading === "1") return;

      event.preventDefault();
      event.stopPropagation();
      trigger.dataset.uiBootstrapLoading = "1";

      ensureBootstrapLoaded()
        .then(() => {
          delete trigger.dataset.uiBootstrapLoading;
          trigger.click();
        })
        .catch(() => {
          delete trigger.dataset.uiBootstrapLoading;
        });
    },
    true,
  );

  document.addEventListener(
    "focusin",
    (event) => {
      if (jqueryUiLoaded) return;

      const target = eventTargetElement(event);
      if (!target) return;
      if (!target.matches(JQUERY_UI_TRIGGER_SELECTOR)) return;

      ensureJqueryUiLoaded().catch(() => {});
    },
    true,
  );
}

function loadOptionalUiDependencies() {
  loadBootstrapIfNeeded();
  loadJqueryUiIfNeeded();
}

document.addEventListener("turbo:load", loadOptionalUiDependencies);
document.addEventListener("turbolinks:load", loadOptionalUiDependencies);
installInteractionFallbackLoaders();

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", loadOptionalUiDependencies, {
    once: true,
  });
} else {
  loadOptionalUiDependencies();
}
