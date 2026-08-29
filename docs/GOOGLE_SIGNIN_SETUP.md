# Google Sign-In Configuration Guide

This document explains how to obtain SHA-1 and SHA-256 fingerprints for your Android app and configure Google Sign-In.

## Why These Fingerprints Matter

Google Sign-In on Android requires your app's signing certificate fingerprints to prevent unauthorized apps from impersonating your application. The error `serverClientId must be provided on Android` occurs when Google Sign-In cannot be properly configured without these fingerprints being registered in your Google Cloud project.

## Getting SHA-1 and SHA-256 Fingerprints

### Option 1: From Debug Keystore (Development)

Android Studio creates a debug keystore automatically. Find and extract fingerprints:

```bash
# On macOS/Linux, the debug keystore is typically at:
# ~/.android/debug.keystore

# Extract SHA-1 fingerprint
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep "SHA1"

# Extract SHA-256 fingerprint
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep "SHA-256"
```

On Windows:
```bash
# Debug keystore is at:
# %USERPROFILE%\.android\debug.keystore

keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### Option 2: From Release Keystore (Production)

For production releases, you'll need to create and manage a release keystore:

```bash
# Create a new keystore (do this once)
keytool -genkey -v -keystore my-release-key.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias my-key-alias

# Extract fingerprints from existing keystore
keytool -list -v -keystore my-release-key.keystore -alias my-key-alias
```

Store your release keystore securely and never commit it to version control.

### Option 3: Using Flutter

Flutter provides a convenience command to get the SHA-1 fingerprint:

```bash
# Requires Java/keytool in PATH
flutter doctor
```

Or use Gradle directly:

```bash
cd android
./gradlew signingReport
```

This will display both SHA-1 and SHA-256 for debug and release builds.

## Configuring Google Cloud Project

1. **Create/Open Your Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create or select your project

2. **Register Your Android App**
   - In Project Settings, click "Add App"
   - Select Android
   - Enter your app package name: `com.jlptpractice.jlpt_practice`

3. **Add Fingerprints**
   - Paste your SHA-1 and SHA-256 fingerprints in the registration form
   - Firebase will use these to validate your app

4. **Download google-services.json**
   - After registration, download `google-services.json`
   - Place it at: `android/app/google-services.json`

## Configuring Google Sign-In in Your App

### 1. Add Dependencies

In `pubspec.yaml`:

```yaml
dependencies:
  google_sign_in: ^6.2.0
  firebase_auth: ^6.5.6  # Already included
```

### 2. Configure Android Manifest

In `android/app/src/main/AndroidManifest.xml`, ensure Google Play Services are declared:

```xml
<manifest ...>
    <!-- Existing permissions -->
    
    <!-- Google Play Services metadata (usually auto-added) -->
    <application ...>
        <!-- Your activities -->
    </application>
</manifest>
```

### 3. Configure build.gradle.kts

In `android/app/build.gradle.kts`, ensure proper signing config:

```kotlin
android {
    // ... existing config ...
    
    signingConfigs {
        debug {
            keyAlias = "androiddebugkey"
            keyPassword = "android"
            storeFile = file(System.getProperty("user.home") + "/.android/debug.keystore")
            storePassword = "android"
        }
        
        release {
            // TODO: Configure with your release keystore
            // keyAlias = "my-key-alias"
            // keyPassword = "your-key-password"
            // storeFile = file("path/to/my-release-key.keystore")
            // storePassword = "your-store-password"
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.release  // Once configured above
        }
    }
}
```

### 4. Initialize Google Sign-In in Your App

In your Firebase bootstrap or auth service:

```dart
import 'package:google_sign_in/google_sign_in.dart';

final _googleSignIn = GoogleSignIn(
  serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
  // serverClientId is required for Android
  // Get this from Firebase Console > Project Settings > Service Accounts > Web
);

Future<UserCredential> signInWithGoogle() async {
  try {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    
    return await FirebaseAuth.instance.signInWithCredential(credential);
  } catch (e) {
    print('Google Sign-In error: $e');
    rethrow;
  }
}
```

### 5. Get Web Client ID

The `serverClientId` comes from your Google Cloud project:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to "APIs & Services" > "Credentials"
4. Look for "OAuth 2.0 Client IDs"
5. Find the "Web application" client ID (format: `XXX.apps.googleusercontent.com`)
6. This is your `serverClientId` for Android Google Sign-In

## Troubleshooting

### "serverClientId must be provided on Android"
- Ensure you've set the `serverClientId` parameter in `GoogleSignIn()`
- Verify the client ID is from a "Web application" OAuth credential, not Android

### Fingerprints Don't Match
- Make sure you're using the correct keystore file
- For debug: use `~/.android/debug.keystore`
- For release: use your actual release keystore
- Verify the alias name matches

### App Not Authenticating
- Confirm SHA-1 and SHA-256 are registered in Firebase Console
- Wait a few minutes after registering (Firebase needs time to propagate)
- Check that `google-services.json` is in the correct location
- Rebuild the app after changing configuration

## Security Notes

- ✅ Debug keystore fingerprints can be safely shared (they're for development only)
- ❌ Release keystore should NEVER be committed to version control or shared
- ❌ Keep your `google-services.json` out of public repositories if it contains sensitive data
- Store release keystores in a secure location with restricted access
- Use environment variables or secure credential management for sensitive values in CI/CD

## References

- [Android Keystore Documentation](https://developer.android.com/studio/publish/app-signing)
- [Google Sign-In for Flutter](https://pub.dev/packages/google_sign_in)
- [Firebase Authentication](https://firebase.google.com/docs/auth)
- [Google Cloud OAuth Credentials](https://cloud.google.com/docs/authentication/end-user)
