# HubParking

Native iOS parking management app for HUB Car Share, built with SwiftUI and Supabase.

## Build

1. Copy `PrivateConfig.example.xcconfig` to `PrivateConfig.xcconfig` and supply the existing local test-account password and team PINs. Never commit that file.
2. Open `HubParking.xcodeproj`, resolve Swift packages and select the Hub Car Rentals signing team.
3. Run on an iPhone. Database migrations are in `Migrations/`.

Release prepared: 1.1 (15). Includes MIA/FLL/OFFICE parking, fleet and AirTag management, photo gallery, deleted history records, restoration, duplicate-parking warning, Face ID and refreshed Miami branding.

## Distribution

Use Xcode Archive and App Store Connect / TestFlight for the work group. Local PINs are an app-level convenience, not a replacement for Supabase authentication and row-level access policies.
