# Android Release Signing Guide for Equilibrium

This document outlines the standard, secure process for signing production builds of the Equilibrium mobile application (`app.equilibrium.mobile`).

## 1. Why Release Signing Matters

The default build uses an Android Debug Certificate (`CN=Android Debug`, SHA-256 `767F4011F59707CEACE46ABE2A71E30D257687071064CF08E65F79E8842432CC`).
For official Google Play Store or permanent production distribution, Android requires an immutable, private cryptographic keystore (`.jks` or `.keystore`).

## 2. Generate a Production Keystore

Run the following command in a secure terminal (outside version control):

```bash
keytool -genkey -v -keystore equilibrium-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias equilibrium-key -storetype JKS
```

When prompted:
1. Set a strong `storePassword` and `keyPassword`.
2. Fill in your organizational details (e.g. `CN=Equilibrium Team, O=Equilibrium`).
3. Store `equilibrium-release.jks` in a secure location (e.g. `equilibrium_app/android/` or a secure secrets manager).

> [!WARNING]
> Keep your `.jks` file and passwords strictly confidential. **NEVER** commit `key.properties` or `*.jks` to Git. They are explicitly excluded in `.gitignore`.

## 3. Configure `key.properties`

Create a file named `key.properties` inside `equilibrium_app/android/` (use `key.properties.example` as a template):

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=equilibrium-key
storeFile=equilibrium-release.jks
```

## 4. Build Signed Release APK

Once `key.properties` is present, `build.gradle.kts` will automatically detect it:

```bash
cd equilibrium_app
flutter build apk --release
```

## 5. Verify the Certificate

To verify the newly signed APK with `apksigner`:

```bash
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
```

You should see:
- `Verified using v2 scheme (APK Signature Scheme v2): true`
- `Signer #1 certificate DN: CN=Equilibrium Team, O=Equilibrium`
