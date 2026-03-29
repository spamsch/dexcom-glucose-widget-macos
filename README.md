# Glucose Widget for macOS

A native macOS app and widget that displays real-time glucose readings from the Dexcom Share API. Built with SwiftUI and WidgetKit.

## Features

- **Desktop widgets** in small and medium sizes, color-coded by glucose range (green for in range, orange for low/high, red for urgent)
- **Dashboard** with current glucose value, trend arrow, and a 3-hour chart with hover tooltips
- **Notifications** for low and high glucose, with configurable thresholds and an urgent-only mode
- **Supports mg/dL and mmol/L** display units
- **Secure credential storage** via macOS Keychain
- **Automatic refresh** every 5 minutes, matching the Dexcom CGM update interval

## Requirements

- macOS 14.0 or later
- Xcode 15+
- A Dexcom Share account with sharing enabled
- An Apple Developer account (for code signing and App Group entitlements)

## Setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you don't have it:

   ```
   brew install xcodegen
   ```

2. Generate the Xcode project:

   ```
   cd dexcom-widget-mac
   xcodegen generate
   ```

3. Open in Xcode:

   ```
   open DexcomWidget.xcodeproj
   ```

4. Select your development team in Signing & Capabilities for both targets (DexcomWidget and GlucoseWidgetExtension).

5. Build and run the DexcomWidget scheme.

## Usage

On first launch, the app shows an onboarding flow where you enter your Dexcom Share credentials and select your region (USA or Outside USA). After signing in, the dashboard displays your current glucose reading and recent trend.

To add the widget to your desktop, right-click the desktop, select "Edit Widgets", and search for "Glucose Monitor".

### Settings

Open settings via the gear icon in the top bar. From there you can:

- Update your Dexcom credentials
- Set custom low/high glucose thresholds
- Switch between mg/dL and mmol/L
- Enable notifications with test buttons to verify they work
- Sign out and clear all stored data

## Project Structure

```
Shared/              Dexcom API client, data models, Keychain helper, shared store
DexcomWidget/App/    Main macOS app (onboarding, dashboard, settings)
GlucoseWidget/       WidgetKit extension (small and medium widget views)
project.yml          XcodeGen project configuration
```

## How It Works

The app authenticates against the Dexcom Share API using the same endpoints as the Dexcom Follow system. Glucose readings are fetched via HTTPS and stored in a shared App Group UserDefaults container so both the main app and the widget extension can access the data. Credentials are stored in the macOS Keychain.

The widget timeline refreshes every 5 minutes. Each refresh fetches the latest reading from the API and updates the shared store, which triggers a widget reload.

## License

This project is for personal use.
