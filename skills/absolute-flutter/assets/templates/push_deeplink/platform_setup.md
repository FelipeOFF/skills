# Platform setup — push + deep link

Native wiring the Dart/Swift templates depend on. Replace `app` / `App` /
`com.example.app` with the real package id, and any real host with
`https://api.example.com`.

## Android — `android/app/src/main/AndroidManifest.xml`

Inside `<application>`, declare the DEFAULT notification channel. Its id MUST
match the `_channel` id created in `push_notification_service.dart`
(`high_importance_channel`) or background notifications land on no channel and
never show.

```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="high_importance_channel" />
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@drawable/ic_notification" />
<meta-data
    android:name="com.google.firebase.messaging.default_notification_color"
    android:resource="@color/notification_color" />
```

Branch keys + the test-mode flag (test vs live key is chosen by build, never
hard-coded):

```xml
<meta-data android:name="io.branch.sdk.BranchKey" android:value="key_live_xxx" />
<meta-data android:name="io.branch.sdk.BranchKey.test" android:value="key_test_xxx" />
<meta-data android:name="io.branch.sdk.TestMode" android:value="false" />
```

Branch link intent-filters on the launcher activity (App Links + the
`app.link` / custom-scheme entries):

```xml
<!-- App Links (verified https) -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="example.app.link" />
</intent-filter>
<!-- Custom scheme fallback -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="app" />
</intent-filter>
```

The `@drawable/ic_notification` icon and `@color/notification_color` resource
must exist. Provide a white, transparent-background icon — Android tints it.

## iOS — `ios/Runner/Info.plist`

```xml
<key>branch_key</key>
<dict>
    <key>live</key><string>key_live_xxx</string>
    <key>test</key><string>key_test_xxx</string>
</dict>
<key>branch_universal_link_domains</key>
<array>
    <string>example.app.link</string>
    <string>example-alternate.app.link</string>
</array>
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

## iOS — entitlements (`ios/Runner/Runner.entitlements`)

```xml
<key>aps-environment</key>
<string>development</string> <!-- production for release builds -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:example.app.link</string>
    <string>applinks:example-alternate.app.link</string>
</array>
```

## iOS — `AppDelegate.swift`

Register the local-notifications plugin registrant and the notification-center
delegate so taps reach Flutter:

```swift
import UserNotifications
import flutter_local_notifications

// inside application(_:didFinishLaunchingWithOptions:):
FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
    GeneratedPluginRegistrant.register(with: registry)
}
if #available(iOS 10.0, *) {
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
}
```

## iOS — Notification Service Extension target

The rich-media extension (`NotificationService.swift`) is a SEPARATE target,
not part of Runner.

1. In Xcode: **File ▸ New ▸ Target ▸ Notification Service Extension**. Name it
   e.g. `AppNotificationService`.
2. Replace the generated `NotificationService.swift` with the template.
3. The extension's `Info.plist` MUST contain:

   ```xml
   <key>NSExtension</key>
   <dict>
       <key>NSExtensionPointIdentifier</key>
       <string>com.apple.usernotifications.service</string>
       <key>NSExtensionPrincipalClass</key>
       <string>$(PRODUCT_MODULE_NAME).NotificationService</string>
   </dict>
   ```

4. Add `CryptoKit` (system framework) — no extra dependency.
5. The push payload MUST carry `mutable-content: 1` and an `image` URL, or the
   extension is never invoked.

## Payload shape (backend contract)

The backend sends a DATA-ONLY message (the app renders the notification). The
`data` map deserializes into `PushResponseDto`:

```json
{
  "data": {
    "code": "evt_123",
    "title": "Example title",
    "message": "Example body",
    "image": "https://api.example.com/n/img.png",
    "icon": "@drawable/ic_notification"
  },
  "apns": { "payload": { "aps": { "mutable-content": 1 } } }
}
```
