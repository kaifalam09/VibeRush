# VibeRush

Flutter MVP: daily challenges, polls, points, leaderboard, profile, local persistence, sharing and AdMob.

## Build
1. Push this project to GitHub.
2. Run Actions -> Build VibeRush APK.
3. Download `viberush-release-apk` from the workflow run.

## AdMob
The app uses Google test ad unit IDs by default. For real monetization, create your own AdMob app/ad units and add these GitHub Actions repository secrets:
- `ADMOB_APP_ID`
- `ADMOB_BANNER_ID`
- `ADMOB_INTERSTITIAL_ID`

The workflow passes them to Flutter at build time, so no source-code edit or new commit is needed.

Important: before publishing, add your own AdMob App ID as the `ADMOB_APP_ID` GitHub secret and complete AdMob verification/consent requirements for your users and region. The workflow uses Google's test App ID when the secret is absent.
