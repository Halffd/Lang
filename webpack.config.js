const createExpoWebpackConfigAsync = require('@expo/webpack-config');

module.exports = async function (env, argv) {
  const config = await createExpoWebpackConfigAsync(
    {
      ...env,
      babel: {
        dangerouslyAddModulePathsToTranspile: ['@native-base/icons']
      }
    },
    argv
  );

  // Customize the config before returning it.
  config.resolve.alias = {
    ...config.resolve.alias,
    'react-native$': 'react-native-web',
  };

  // Configure dev server options
  if (config.devServer) {
    config.devServer = {
      ...config.devServer,
      allowedHosts: 'all',
      hot: true,
      liveReload: true,
      compress: true,
      historyApiFallback: true,
      client: {
        overlay: true,
      },
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
    };
  }

  return config;
}; 