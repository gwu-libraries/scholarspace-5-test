// The source code including full typescript support is available at: 
// https://github.com/shakacode/react_on_rails_demo_ssr_hmr/blob/master/config/webpack/commonWebpackConfig.js

// Common configuration applying to client and server configuration
const { generateWebpackConfig, merge } = require('shakapacker')

const commonOptions = {
  resolve: {
    extensions: ['.css', '.ts', '.tsx'],
  },
};

// Generate the base webpack configuration and merge with common options
const commonWebpackConfig = () => merge({}, generateWebpackConfig(), commonOptions);

module.exports = commonWebpackConfig;
