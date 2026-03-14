import ReactOnRails from 'react-on-rails';
import 'video.js/dist/video-js.css';
import '@samvera/ramp/dist/ramp.css';
import Ramp from '../bundles/Ramp/components/Ramp';

// This is how react_on_rails can see the HelloWorld in the browser.
ReactOnRails.register({
  Ramp,
});
