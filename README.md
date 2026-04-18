# SafeChain Mobile Application

A community personal safety application built with Flutter, designed to provide peace of mind through a smart digital safety keychain device. SafeChain connects residents to their barangay's emergency response network via Bluetooth Low Energy (BLE), LoRa, and GPS tracking.

---

## 🚀 Features

### 🔐 Secure Authentication
- User registration with email, strong password validation, and CAPTCHA verification (slider captcha)
- Login with session persistence and "Remember Me" functionality
- Forgot password flow via deep-linked email reset token
- Password strength indicator with real-time feedback
- Change password with current password verification

### 👤 Dynamic Profile Management
- View and edit personal information (name, email, address, contact number)
- Philippine mobile number formatter with `+63` prefix
- Upload a profile photo from the device gallery or create a custom avatar using Fluttermoji
- Manage medical conditions (multi-select with an "Others" free-text option)
- Real-time email verification status
- Profile completion banner that prompts users to fill in missing details

### 🔗 BLE Device Pairing Flow
- Step-by-step guided pairing wizard with animated transitions
- QR code scanner to capture the device's Bluetooth MAC address
- Bluetooth and location permission request with graceful fallback
- Local BLE verification (connect + disconnect test) before cloud registration
- Cloud ownership check — prevents linking a device already registered to another account
- ESP32 BLE provisioning: writes the assigned `device_id` via the Nordic UART Service (NUS)
- LoRa gateway test: sends a `safe` packet and waits for an ACK from the network
- Device rename, unlink, and "report as missing" (deactivates device to prevent false alarms)
- Battery level indicator per device

### 🗺️ Real-Time GPS Tracking
- Live device location displayed on an interactive map (CartoDB Voyager tiles)
- Barangay Gulod boundary polygon with fill and border overlay
- Barangay Hall / Evacuation Center marker
- Compass-based heading cone for the tracked device
- User's own location displayed via the device GPS

### 📍 Geofencing
- Ray-casting algorithm to detect arrival and departure from Barangay Gulod boundaries
- Push a local notification when the device enters or exits the geofenced area

### 🔔 Push & Local Notifications
- Firebase Cloud Messaging (FCM) for remote push notifications (announcements, alerts)
- Background FCM message handler with silent inbox save
- `flutter_local_notifications` for foreground banners
- In-app notification inbox with unread badge count, multi-select delete, swipe-to-dismiss, and mark-all-read
- Real-time unread count stream across all screens

### 📢 Announcements
- Paginated community announcements feed fetched from the server
- Expandable cards with author info, timestamps (timeago), and view count
- Image media attachment support
- Auto-refresh every 30 seconds; pull-to-refresh

### 📵 Background BLE Connection Service
- Singleton `BleConnectionService` powered by `flutter_foreground_task`
- Keeps the device connected and streaming GPS data even when the screen is off
- Auto-reconnect on disconnection with configurable retry delay
- Geofence checks on every incoming GPS coordinate

### 📶 Offline Detection
- Periodic HTTP ping to `safechain.site` to detect connectivity
- Animated `OfflineBanner` slides in/out at the top of every screen
- Buttons that would fail while offline are blocked with a user-friendly snackbar

### 🛡️ Account Restriction System
- Resident accounts can be set to `restricted` status by barangay admins
- Restricted devices display a banner and all BLE / GPS tracking features are disabled
- Status is refreshed from the server on every home screen load

### 🧭 User Guide
- Expandable guide sections: Emergency Buttons, GPS Testing, Battery & Charging, Troubleshooting
- In-app support contact dialog

### 🎨 Modern UI/UX
- Animated startup screen with fade-in
- Smooth fade page route transitions throughout the app
- Animated card entrance (staggered slide + fade)
- Custom-shaped app bars with gradient headers
- Animated success and error modals
- Responsive design for various device sizes

---

## 🛠️ Technologies Used

### Framework & Language
| Technology | Purpose |
|---|---|
| [Flutter](https://flutter.dev/) | Cross-platform mobile UI framework |
| [Dart](https://dart.dev/) | Primary programming language |

### Backend & Database
| Technology | Purpose |
|---|---|
| [Firebase Authentication](https://firebase.google.com/products/auth) | Not used directly — custom PHP auth |
| [Firebase Cloud Messaging (FCM)](https://firebase.google.com/products/cloud-messaging) | Remote push notifications |
| [Firebase Core](https://firebase.google.com/docs/flutter/setup) | Firebase SDK initialization |
| [PHP](https://www.php.net/) | RESTful backend API |
| [MySQL](https://www.mysql.com/) | Relational database (hosted on Hostinger) |

### Mapping & Location
| Package | Purpose |
|---|---|
| [flutter_map ^8.2.2](https://pub.dev/packages/flutter_map) | Interactive map rendering |
| [latlong2 ^0.9.1](https://pub.dev/packages/latlong2) | Geographic coordinate types |
| [geolocator ^13.0.0](https://pub.dev/packages/geolocator) | Device GPS position |
| [flutter_compass ^0.8.1](https://pub.dev/packages/flutter_compass) | Device compass heading |
| [location ^8.0.1](https://pub.dev/packages/location) | Location service wrapper |
| CartoDB Voyager | Map tile provider (OpenStreetMap data) |

### Bluetooth & Hardware
| Package | Purpose |
|---|---|
| [flutter_blue_plus ^1.36.8](https://pub.dev/packages/flutter_blue_plus) | BLE scanning, connecting, and GATT characteristic read/write/notify |
| [mobile_scanner ^7.2.0](https://pub.dev/packages/mobile_scanner) | QR code / barcode scanning |

### Notifications
| Package | Purpose |
|---|---|
| [firebase_messaging ^15.2.10](https://pub.dev/packages/firebase_messaging) | FCM remote push notifications |
| [flutter_local_notifications ^21.0.0](https://pub.dev/packages/flutter_local_notifications) | Local foreground notification banners |

### Background Tasks
| Package | Purpose |
|---|---|
| [flutter_foreground_task ^8.17.0](https://pub.dev/packages/flutter_foreground_task) | Android foreground service to keep BLE alive in background |

### UI & UX
| Package | Purpose |
|---|---|
| [animations ^2.1.1](https://pub.dev/packages/animations) | `FadeThroughTransition` for step-by-step flows |
| [fluttermoji ^1.0.2](https://pub.dev/packages/fluttermoji) | SVG avatar builder and display |
| [slider_captcha ^1.0.2](https://pub.dev/packages/slider_captcha) | Slider CAPTCHA for signup and password reset |
| [timeago ^3.7.1](https://pub.dev/packages/timeago) | Human-readable relative timestamps |
| [flutter_svg ^2.2.3](https://pub.dev/packages/flutter_svg) | SVG rendering |

### Networking & Storage
| Package | Purpose |
|---|---|
| [http ^1.6.0](https://pub.dev/packages/http) | HTTP client for REST API calls |
| [shared_preferences ^2.5.4](https://pub.dev/packages/shared_preferences) | Local key-value storage (session, notifications, FCM token) |
| [image_picker ^1.2.1](https://pub.dev/packages/image_picker) | Camera / gallery image selection |
| [permission_handler ^11.4.0](https://pub.dev/packages/permission_handler) | Runtime permission requests |
| [app_links ^3.5.1](https://pub.dev/packages/app_links) | Deep link handling for password reset |

---

## 🗄️ Backend API Endpoints

All endpoints are hosted at `https://safechain.site/api/mobile/`.

| Endpoint | Method | Description |
|---|---|---|
| `login.php` | POST | Authenticate user, return session data |
| `register.php` | POST | Create a new resident account |
| `forgot_password.php` | POST | Generate reset token, send HTML email |
| `reset_password.php` | POST | Validate token, update password |
| `change_password.php` | POST | Change password with current password verification |
| `get_profile.php` | GET | Fetch resident profile by `resident_id` |
| `update_profile.php` | POST (multipart) | Update profile fields and/or upload profile picture |
| `get_contacts.php` | GET | List emergency contacts for a resident |
| `add_contact.php` | POST | Add a new emergency contact |
| `update_contact.php` | POST | Edit an existing emergency contact |
| `delete_contact.php` | POST | Delete an emergency contact |
| `get_devices.php` | GET | List paired devices for a resident |
| `add_device.php` | POST | Register a new BLE device |
| `check_device.php` | GET | Check if a device MAC is available, owned, or taken |
| `update_device.php` | POST | Rename a device |
| `delete_device.php` | POST | Unlink a device |
| `mark_missing.php` | POST | Mark a device as missing (deactivates it) |

---

## ⚙️ Setup and Installation

### Prerequisites
- Flutter SDK `>=3.38.1` installed
- Android Studio or VS Code with the Flutter plugin
- A Firebase project with Android app configured
- A PHP/MySQL server (or Hostinger hosting) for the backend

### Installation

1. **Clone the repository:**
   ```sh
   git clone https://github.com/your_username/safechain.git
   cd safechain
   ```

2. **Set up Firebase:**
   - Create a new project on the [Firebase Console](https://console.firebase.google.com/).
   - Add an Android app with package name `com.safechain.safechain`.
   - Download `google-services.json` and place it in `android/app/`.
   - Enable **Firebase Cloud Messaging** in your project.
   - The `lib/firebase_options.dart` file must be configured with your project credentials (use the FlutterFire CLI or edit manually).

3. **Set up the backend:**
   - Upload the contents of the `api/` directory to your PHP server.
   - Update `api/mobile/db_connection.php` with your MySQL credentials.
   - Create a `password_resets` table in your database:
     ```sql
     CREATE TABLE password_resets (
       id INT AUTO_INCREMENT PRIMARY KEY,
       email VARCHAR(255) NOT NULL,
       token VARCHAR(64) NOT NULL,
       created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
     );
     ```
   - Upload FCM token storage endpoint at `api/fcm/save_token.php`.

4. **Install dependencies:**
   ```sh
   flutter pub get
   ```

5. **Run the app:**
   ```sh
   flutter run
   ```

### Android Permissions Required
The following permissions are declared in `AndroidManifest.xml`:

- `INTERNET` — API communication
- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` — GPS tracking
- `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE` — BLE device pairing
- `POST_NOTIFICATIONS` — Local and push notifications
- `CAMERA` — QR code scanning
- `VIBRATE` — Notification vibration
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_CONNECTED_DEVICE` — Background BLE service
- `RECEIVE_BOOT_COMPLETED` — Scheduled notification receiver

---

## 🏗️ Project Structure

```
lib/
├── main.dart                    # App entry point, FCM setup, deep link init
├── firebase_options.dart        # Firebase configuration
├── modals/                      # Reusable dialog widgets (success, error)
├── screens/
│   ├── add_device/              # 9-step BLE device pairing wizard
│   ├── announcement/            # Paginated community announcements
│   ├── forgot_password/         # Forgot & reset password screens
│   ├── guide/                   # User guide with expandable sections
│   ├── home/                    # Home screen, device list, BLE card
│   ├── login/                   # Login screen with Remember Me
│   ├── notification/            # In-app notification inbox
│   ├── profile/                 # Profile, contacts, change password
│   ├── signup/                  # Registration with CAPTCHA & Terms
│   ├── startup/                 # Animated splash screen
│   ├── tracking/                # Live GPS map with geofence overlay
│   └── welcome/                 # Onboarding / landing screen
├── services/
│   ├── ble_connection_service.dart   # Background BLE singleton
│   ├── connectivity_service.dart     # Internet connectivity watcher
│   ├── geofence_service.dart         # Ray-casting geofence checker
│   ├── notification_service.dart     # FCM + local notifications + inbox
│   └── session_manager.dart          # SharedPreferences session CRUD
└── widgets/
    ├── battery_indicator.dart        # Custom battery level widget
    ├── curved_app_bar.dart           # Clipped gradient app bar
    ├── fade_page_route.dart          # Fade transition page route
    ├── offline_banner.dart           # Animated offline/online banner
    ├── phone_number_formatter.dart   # PH number formatter (XXX-XXX-XXXX)
    ├── phone_number_input.dart       # Phone input field widget
    ├── profile_completion_banner.dart # Incomplete profile warning
    └── safechain_logo.dart           # Logo text widget
```

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

---

## 📄 License
This project is developed for Barangay Gulod, Novaliches, Quezon City. All rights reserved © 2026 SafeChain.
