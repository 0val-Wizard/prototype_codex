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

