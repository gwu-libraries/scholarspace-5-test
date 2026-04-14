import ReactOnRails from 'react-on-rails';
import Homepage from '../bundles/homepage/Homepage';

ReactOnRails.register({
  Homepage,
});

function bootReactOnRails() {
  ReactOnRails.reactOnRailsPageLoaded();
}

document.addEventListener('turbolinks:load', bootReactOnRails);
document.addEventListener('turbo:render', bootReactOnRails);
