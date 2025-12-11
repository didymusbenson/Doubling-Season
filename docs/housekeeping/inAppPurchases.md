
## FLUTTER IN APP PURCHASE HANDLING.
Add in-app purchases for "tip jar" in order for users to support the developer and unlock app icons.
Flutter provides three main patterns for handling platform differences:
1. **Use existing packages** (preferred): Packages like `in_app_purchase`, `share_plus`, `url_launcher`
   abstract platform differences
2. **Platform checks in Dart**: Use `Platform.isIOS` / `Platform.isAndroid` for minor variations
3. **Platform channels**: Write custom native code when needed