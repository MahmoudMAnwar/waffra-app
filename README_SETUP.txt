Waffra Google Sign-In integration files

UPLOAD:
1. pubspec.yaml -> repository root /pubspec.yaml (replace existing)
2. google-services.json -> /firebase/google-services.json (new file)
3. waffra_google_auth.dart -> /lib/waffra_google_auth.dart (new file)

REQUIRED INTEGRATION STILL TO DO:
- In .github/workflows/android.yml, AFTER flutter create, copy firebase/google-services.json to android/app/google-services.json and add the com.google.gms.google-services Gradle plugin to the generated Android app.
- In lib/main.dart initialize Firebase before runApp and wire Google sign-in button to WaffraGoogleAuth.signIn(), handling cancellations/errors and account profile persistence.
- Ensure the Release signing certificate SHA-1/SHA-256 is registered in Firebase; debug SHA may not match GitHub APK.
- Test flutter pub get, flutter analyze, flutter test, build and on-device Google login.

These files alone do not finish the integration or produce a working APK.
