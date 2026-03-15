# CLC Quote Maker

A fully offline Android application built with Flutter for "The Story Book by CLC". This app helps generate professionally formatted WhatsApp quotation messages for photography clients.

## Features
- **Offline First**: All data is stored locally using SQLite.
- **Quick Selection**: Tappable chips for events, services, and deliverables.
- **Live Preview**: See the WhatsApp message format in real-time as you fill the form.
- **One-Tap Copy**: Copy the formatted message to your clipboard instantly.
- **Smart Formatting**: Automatic bolding, lists, and footer generation following brand guidelines.

## Tech Stack
- **Framework**: Flutter (Dart)
- **Database**: SQLite (via `sqflite`)
- **State Management**: Provider
- **Navigation**: go_router

## Build Instructions

### Local Build
1. Ensure Flutter is installed and configured.
2. Clone the repository.
3. Run `flutter pub get`.
4. Build the release APK:
   ```bash
   flutter build apk --release
   ```

### EAS Build (Cloud)
1. Ensure EAS CLI is installed.
2. Run:
   ```bash
   eas build --platform android --profile production
   ```

## Branding
- **Company**: The Story Book by CLC
- **Primary Color**: Black (#000000)
- **Design Philosophy**: Minimal, Clean, Professional.
