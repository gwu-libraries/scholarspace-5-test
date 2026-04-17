import ReactOnRails from 'react-on-rails';
import Homepage from '../bundles/homepage/Homepage';

ReactOnRails.register({
  Homepage,
});

function bootReactOnRails() {
  ReactOnRails.reactOnRailsPageLoaded();
}

document.addEventListener('turbolinks:load', bootReactOnRails);
document.addEventListener('turbo:load', bootReactOnRails);

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', bootReactOnRails, { once: true });
} else {
  bootReactOnRails();
}
