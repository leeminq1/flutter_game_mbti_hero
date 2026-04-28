{{flutter_js}}
{{flutter_build_config}}

const flutterHost = document.querySelector('#flutter-host');

if (flutterHost) {
  _flutter.loader.load({
    config: {
      hostElement: flutterHost,
    },
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}}
    }
  });
}
