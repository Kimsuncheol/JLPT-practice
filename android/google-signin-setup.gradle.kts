/**
 * Google Sign-In Configuration
 *
 * This file provides helper functions for configuring Google Sign-In
 * You can apply this to your build.gradle.kts to manage clientId and serverClientId
 *
 * Usage in build.gradle.kts:
 *   apply(from = "./google-signin-setup.gradle.kts")
 */

/**
 * Configure Google Sign-In client IDs
 *
 * Required:
 * - google.signin.web.client.id: Web OAuth 2.0 client ID (needed for Android serverClientId)
 * - google.signin.android.client.id: Android OAuth 2.0 client ID (optional, auto-provided by google-services.json)
 *
 * These can be configured in:
 * 1. local.properties (not committed to git)
 * 2. gradle.properties
 * 3. Environment variables: GOOGLE_SIGNIN_WEB_CLIENT_ID
 *
 * Example local.properties:
 *   google.signin.web.client.id=1234567890-abcdefghijklmnop.apps.googleusercontent.com
 *   google.signin.android.client.id=1234567890-zyxwvutsrqponmlkjih.apps.googleusercontent.com
 */

fun getGoogleSignInProperty(propertyName: String, envVarName: String = ""): String? {
    // Try to get from gradle properties first
    val gradleProperty = project.findProperty(propertyName)?.toString()
    if (!gradleProperty.isNullOrEmpty()) {
        return gradleProperty
    }

    // Then try environment variable
    if (envVarName.isNotEmpty()) {
        val envValue = System.getenv(envVarName)
        if (!envValue.isNullOrEmpty()) {
            return envValue
        }
    }

    return null
}

// Example usage - this is for reference
val webClientId = getGoogleSignInProperty(
    "google.signin.web.client.id",
    "GOOGLE_SIGNIN_WEB_CLIENT_ID"
)

val androidClientId = getGoogleSignInProperty(
    "google.signin.android.client.id",
    "GOOGLE_SIGNIN_ANDROID_CLIENT_ID"
)

println("Google Sign-In Configuration:")
if (webClientId != null) {
    println("  ✓ Web Client ID configured")
} else {
    println("  ⚠ Web Client ID not configured")
}

if (androidClientId != null) {
    println("  ✓ Android Client ID configured")
} else {
    println("  ⚠ Android Client ID not configured (will use google-services.json)")
}
