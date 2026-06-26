/** @type {import('@bacons/apple-targets/app.plugin').ConfigFunction} */
module.exports = () => ({
  type: 'widget',
  name: 'StudyWidget',
  displayName: 'Study Timer',
  // Live Activities require iOS 16.2+. Interactive controls (App Intents)
  // need 17+, gated with @available in Swift.
  deploymentTarget: '16.2',
  frameworks: ['SwiftUI', 'WidgetKit', 'ActivityKit'],
});
