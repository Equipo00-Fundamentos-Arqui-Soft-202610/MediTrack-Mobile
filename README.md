# meditrack_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Gateway URL

By default the app points at the production Gateway (`https://meditrack-gateway.onrender.com`).
To run against a local Gateway + backend stack on the Android emulator, override it at build/run time:

```bash
flutter run --dart-define=GATEWAY_URL=http://10.0.2.2:5000
```

`10.0.2.2` is the Android emulator's alias for the host machine's `localhost`.
