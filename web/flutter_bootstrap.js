{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  hostElement: document.querySelector('#game-container'),
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  }
});
