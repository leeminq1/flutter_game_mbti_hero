{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    hostElement: document.querySelector('#flutter-host'),
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  }
});
