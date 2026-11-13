/// Google sign-in client IDs.
///
/// [webClientId] is the same public client the website ships, and the server
/// accepts it through `GOOGLE_ALLOWED_CLIENT_IDS`. Android signs the user in
/// against that client through the `vendoph.rider` Android OAuth client, so the
/// package name and this build's SHA-1 must exist in the same Google Cloud
/// project.
///
/// Every value can be overridden at build time, for example
/// `--dart-define=GOOGLE_WEB_CLIENT_ID=<id>`, which is what a different Google
/// Cloud project needs.
class GoogleAuthConfig {
  const GoogleAuthConfig._();

  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '468116080938-db4garqg6u4nt2q9535s58k77h9t1pc1.apps.googleusercontent.com',
  );

  static const String iosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static const String macosClientId =
      String.fromEnvironment('GOOGLE_MACOS_CLIENT_ID');
}
