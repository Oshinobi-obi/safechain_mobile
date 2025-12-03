# SafeChain Mobile Application

A personal safety application built with Flutter, designed to provide peace of mind through a digital safety keychain.

## 🚀 Features

- **Secure User Authentication**:
  - User signup with email and strong password validation.
  - Secure login and session management.
  - "Remember Me" functionality for convenience.
  - Password reset via an email link sent to the user.
- **Dynamic Profile Management**:
  - View and edit personal and emergency contact information.
  - Upload and display a custom profile picture from the device gallery.
  - Real-time email verification status with a prompt to send a verification email.
- **Interactive Home Screen**:
  - Personalized welcome message with the user's name.
  - Real-time user location displayed on an interactive map.
  - Custom map marker using the user's profile picture.
- **Modern UI/UX**:
  - Animated startup screen.
  - Custom-shaped app bars.
  - Animated success modals for key actions like registration and profile updates.
  - Responsive design for various device sizes.

## 🛠️ Technologies Used

- **Framework**: [Flutter](https://flutter.dev/)
- **Language**: [Dart](https://dart.dev/)
- **Backend & Database**: [Firebase](https://firebase.google.com/)
  - **Authentication**: Firebase Authentication (Email & Password)
  - **Database**: Cloud Firestore (NoSQL)
  - **Storage**: Firebase Storage (for profile pictures)
- **Mapping**:
  - [MapTiler](https://www.maptiler.com/) for map tiles.
  - [flutter_map](https://pub.dev/packages/flutter_map) package for map rendering.
- **Local Storage**: [shared_preferences](https://pub.dev/packages/shared_preferences) for saving "Remember Me" credentials.

## ⚙️ Setup and Installation

To get a local copy up and running, follow these simple steps.

### Prerequisites

- Flutter SDK installed on your machine.
- An editor like Android Studio or VS Code with the Flutter plugin.

### Installation

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/your_username/safechain.git
    ```

2.  **Set up Firebase:**
    - Create a new project on the [Firebase Console](https://console.firebase.google.com/).
    - Follow the instructions to add an Android and/or iOS app to your Firebase project.
    - Download the `google-services.json` file for Android and place it in the `android/app/` directory.
    - The `lib/firebase_options.dart` file should be configured for your project, which is typically handled by the FlutterFire CLI.

3.  **Set up MapTiler API Key:**
    - Open the `lib/screens/home/home_screen.dart` file.
    - Replace the placeholder `YOUR_MAPTILER_API_KEY` with your actual API key from MapTiler.

4.  **Install dependencies:**
    ```sh
    flutter pub get
    ```

5.  **Run the app:**
    ```sh
    flutter run
    ```
