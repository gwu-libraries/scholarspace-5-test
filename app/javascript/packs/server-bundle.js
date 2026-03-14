import ReactOnRails from 'react-on-rails';

import Ramp from '../bundles/Ramp/components/RampServer';
import Clover from '../bundles/Clover/components/CloverServer';

// This is how react_on_rails can see the HelloWorld in the browser.
ReactOnRails.register({
  Ramp,
  Clover
});
