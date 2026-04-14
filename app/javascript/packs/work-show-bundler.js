import ReactOnRails from "react-on-rails";
import WorkShow from "../bundles/work_show/WorkShow";
import "video.js/dist/video-js.css";
import "@samvera/ramp/dist/ramp.css";

const DOWNLOAD_IFRAME_NAME = "work-show-global-download";

function ensureDownloadIframe() {
  let frame = document.querySelector(`iframe[name="${DOWNLOAD_IFRAME_NAME}"]`);
  if (frame) return frame;

  frame = document.createElement("iframe");
  frame.name = DOWNLOAD_IFRAME_NAME;
  frame.title = DOWNLOAD_IFRAME_NAME;
  frame.style.display = "none";
  document.body.appendChild(frame);
  return frame;
}

function forceBackgroundDownloadLinks() {
  ensureDownloadIframe();

  document.addEventListener("click", (event) => {
    const link = event.target.closest("a[href]");
    if (!link) return;
    if (link.origin !== window.location.origin) return;
    if (!link.pathname.startsWith("/downloads/")) return;

    link.setAttribute("data-turbo", "false");
    link.setAttribute("data-turbolinks", "false");
    link.setAttribute("target", DOWNLOAD_IFRAME_NAME);
    if (!link.hasAttribute("download")) {
      link.setAttribute("download", "");
    }
  });
}

ReactOnRails.register({
  WorkShow,
});

forceBackgroundDownloadLinks();

function bootReactOnRails() {
  ensureDownloadIframe();
  ReactOnRails.reactOnRailsPageLoaded();
}

document.addEventListener("turbolinks:load", bootReactOnRails);
document.addEventListener("turbo:render", bootReactOnRails);
