import { ExpoConfig } from 'expo/config';

const config: ExpoConfig = {
  name: 'Lang Mobile',
  slug: 'lang-mobile',
  version: '1.0.0',
  orientation: 'portrait',
  icon: './assets/icon.png',
  splash: {
    image: './assets/splash.png',
    resizeMode: 'contain',
    backgroundColor: '#ffffff'
  },
  updates: {
    fallbackToCacheTimeout: 0
  },
  assetBundlePatterns: [
    '**/*'
  ],
  ios: {
    supportsTablet: true,
    bundleIdentifier: 'com.lang.mobile'
  },
  android: {
    adaptiveIcon: {
      foregroundImage: './assets/adaptive-icon.png',
      backgroundColor: '#FFFFFF'
    },
    package: 'com.lang.mobile'
  },
  web: {
    favicon: './assets/favicon.png'
  }
}

export default config; 