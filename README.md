# CityGuide Flutter frontend

Flutter mobile app connected to the City Guide Spring Boot API.

## Backend

The app uses the deployed API at:

`https://app-citi-guide-backend.onrender.com`

The base URL is defined in `lib/store.dart`. Update it there if the backend URL changes.

## Run locally

1. Install Flutter 3.22+ and Dart 3.3+.
2. From the project folder run:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

3. For Android, internet and location permissions are already declared in the main manifest.

## Authentication and data

- Registration and login are handled by the backend.
- Access and refresh tokens are stored with Flutter Secure Storage.
- Expired access tokens are refreshed automatically using the refresh token.
- Cities, places, profile, favourites, reviews and review likes are loaded from the API.
- Password hashes are never stored by the Flutter app.
- The old demo account and generated local review data have been removed.
- Profile photos are uploaded to the backend.
- Password reset is unavailable until SMTP email delivery is configured on the backend. The app does not generate or display fake reset codes.

## API security

Protected API requests use `Authorization: Bearer <accessToken>`. The backend remains the source of truth for users, places, favourites and reviews.

## Notes

- Render's free web service may take time to wake after inactivity.
- Native Flutter apps do not use browser CORS rules.
- Run `flutter analyze` and `flutter test` locally before building a release APK.
