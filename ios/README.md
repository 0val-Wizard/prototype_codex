# Shopee AR Demo

Native iOS SwiftUI scaffold for an AR shopping demo.

## Structure

- `project.yml`: XcodeGen spec for generating the Xcode project
- `ShopeeARDemo/`: app source
- `ShopeeARDemo/Resources/`: bundled mock catalog data

## Generate The Project

1. Install XcodeGen if needed.
2. From `ios/`, run `xcodegen generate`.
3. Open `ShopeeARDemo.xcodeproj` in Xcode.
4. Build on an iPhone or AR-capable simulator target.

## Current Scope

- Native SwiftUI app shell
- Search-driven recommendations
- Collapsible recommendation sheet
- RealityKit-powered AR preview surface
- Cart flow inside the native app

This is intentionally a clean native starting point, not a WebView port.

## Local HTTPS For Realtime Voice

The embedded agent page should be served over HTTPS on iPhone so `getUserMedia()` and WebRTC microphone access work reliably.

1. Create a local certificate and key for your laptop LAN IP or hostname.
2. Save them under `certs/` in the repo root, for example:
   `certs/dev-key.pem`
   `certs/dev-cert.pem`
3. Add these values to the root `.env`:
   `SSL_KEY_FILE=certs/dev-key.pem`
   `SSL_CERT_FILE=certs/dev-cert.pem`
4. Start the server with `node server.mjs`.
5. Update `AgentBaseURL` in `ShopeeARDemo/Info.plist` to match the HTTPS URL your phone can reach, for example `https://192.168.1.73:3000`.

The iOS app currently accepts the dev certificate in `WKWebView` for this embedded agent flow, which is suitable for local development only.
