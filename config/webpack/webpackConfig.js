// The source code including full typescript support is available at: 
// https://github.com/shakacode/react_on_rails_demo_ssr_hmr/blob/master/config/webpack/webpackConfig.js

const clientWebpackConfig = require('./clientWebpackConfig');
const serverWebpackConfig = require('./serverWebpackConfig');

const hasServerBundle = (clientConfig) => !!clientConfig.entry['server-bundle'];

const webpackConfig = (envSpecific) => {
  const clientConfig = clientWebpackConfig();

  let result;
  // For HMR, need to separate the the client and server webpack configurations
  if (process.env.WEBPACK_SERVE || process.env.CLIENT_BUNDLE_ONLY) {
    if (envSpecific) {
      envSpecific(clientConfig);
    }

    // eslint-disable-next-line no-console
    console.log('[React on Rails] Creating only the client bundles.');
    result = clientConfig;
  } else if (process.env.SERVER_BUNDLE_ONLY) {
    if (!hasServerBundle(clientConfig)) {
      throw new Error(
        "Create a pack with the file name 'server-bundle.js' containing all the server rendering files",
      );
    }

    const serverConfig = serverWebpackConfig();

    if (envSpecific) {
      envSpecific(clientConfig, serverConfig);
    }

    // eslint-disable-next-line no-console
    console.log('[React on Rails] Creating only the server bundle.');
    result = serverConfig;
  } else if (!hasServerBundle(clientConfig)) {
    if (envSpecific) {
      envSpecific(clientConfig);
    }

    // eslint-disable-next-line no-console
    console.log('[React on Rails] Creating only the client bundles.');
    result = clientConfig;
  } else {
    const serverConfig = serverWebpackConfig();

    if (envSpecific) {
      envSpecific(clientConfig, serverConfig);
    }

    // default is the standard client and server build
    // eslint-disable-next-line no-console
    console.log('[React on Rails] Creating both client and server bundles.');
    result = [clientConfig, serverConfig];
  }

  // To debug, uncomment next line and inspect "result"
  // debugger
  return result;
};

module.exports = webpackConfig;
