# Kotoba Flow privacy baseline

Kotoba Flow uses an anonymous Firebase identifier to synchronize study
preferences, quiz results, and review progress when Firebase is
configured. The app does not require a name, email address, or permanent
account.

The development build runs local-first and leaves advertisements disabled.
When ads are enabled, Google Mobile Ads and the required consent flow must be
configured for the distribution region. Store privacy disclosures, a hosted
privacy-policy URL, consent testing, data-deletion instructions, and
`app-ads.txt` remain release tasks.

Clearing app storage or uninstalling the app can remove locally held learning
history and access to an unlinked anonymous account.
