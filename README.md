# J.A.R.V.I.S. Android Flutter Assistant

This project is an upgraded version of the supplied JARVIS Flutter generator.

## Features
- Wake phrases: Hey Jarvis, Jarvis, Hi GPT, GPT
- Hindi + English local command parsing
- WhatsApp, YouTube, Chrome, Camera and Calculator launching
- Contact lookup for WhatsApp compose intents
- Battery and connectivity data
- Launchable installed-app list
- Speech-to-text and text-to-speech
- Gemini fallback
- Continuous listening with guarded restart logic

## Important Android limitation
WhatsApp message composition is opened through an Android intent. The app does **not** claim that a message was sent automatically. The user may still need to press Send in WhatsApp.

## Build
Run `flutter pub get`, then `flutter analyze`, then `flutter build apk --release` from the project root using a local Flutter SDK.
