/** @type {import('@bacons/apple-targets/app.plugin').ConfigFunction} */
module.exports = (config) => ({
  type: 'widget',
  name: 'StudyWidget',
  displayName: 'Study Timer',
  // Live Activities require iOS 16.2+. Interactive controls (App Intents)
  // need 17+, gated with @available in Swift.
  deploymentTarget: '16.2',
  frameworks: ['SwiftUI', 'WidgetKit', 'ActivityKit'],
  entitlements: {
    // Mirror the app's App Group so the widget can read shared state.
    'com.apple.security.application-groups':
      config.ios.entitlements['com.apple.security.application-groups'],
  },
});
