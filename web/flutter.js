// The value below is injected by flutter build, do not touch.
const serviceWorkerVersion = '{{flutter_service_worker_version}}';

// This script adds the flutter initialization JS code
window.addEventListener('load', function(ev) {
  // Download main.dart.js
  _flutter.loader.load({
    serviceWorker: {
      serviceWorkerVersion: serviceWorkerVersion,
    },
    onEntrypointLoaded: function(engineInitializer) {
      engineInitializer.initializeEngine().then(function(appRunner) {
        appRunner.runApp();
      });
    }
  });
}); 