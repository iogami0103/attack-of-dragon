# Attack of the Dragon Privacy Policy

Last updated: 2026-07-04

Attack of the Dragon stores gameplay data only for running the game, showing rankings, restoring an account link, serving ads, and remembering whether the ad removal purchase is active.

## Data stored on this device

- Settings such as player name, player identifier, and volume.
- Local score history.
- Whether the non-consumable ad removal purchase has been enabled.

## Data sent to the online ranking service

- Player identifier, player name, score, defeated enemy count, play date, and game version.
- The public leaderboard may show player name, score, defeated enemy count, play date, and game version.

## Account linking

- If you use Google Sign-In or Sign in with Apple, the app sends the provider identity token to the Cloudflare Worker only to verify the account and restore the same player identifier.
- The ranking service stores the provider name, provider account subject identifier, player identifier, and player name.
- The service does not store your email address from the provider token.

## Ads

- The mobile app uses Google Mobile Ads. Google and its partners may process advertising identifiers, device information, IP address, and ad interaction data to provide and measure ads.
- You can manage ad personalization in your device or Google account settings where available.

## In-app purchases

- The app offers a non-consumable ad removal purchase.
- Payments are processed by Google Play or Apple App Store. The app does not collect or store payment card information.
- The app stores only whether ad removal has been enabled on the device.

## Infrastructure

- Online ranking and account-link data are processed by Cloudflare Workers and stored in Cloudflare D1.
- The app does not sell personal data.

## Data deletion

To delete a linked account and its online ranking data, use `Settings > Delete Account` in the app. You will be asked to confirm with the same sign-in provider before deletion. This permanently deletes the account link, online ranking entry, score history, and active run tokens for that player.

## Third-party services

- Google Sign-In: https://policies.google.com/privacy
- Sign in with Apple: https://www.apple.com/legal/privacy/
- Google Mobile Ads: https://policies.google.com/privacy
- Google Play: https://policies.google.com/privacy
- Apple App Store: https://www.apple.com/legal/privacy/
- Cloudflare: https://www.cloudflare.com/privacypolicy/
