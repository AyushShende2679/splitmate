# SplitMate

A smart, user-friendly, and comprehensive solution for tracking daily, group, and personal expenses — built with Flutter and Firebase.

![SplitMate](assets/App%20icon.png)

---

## ✨ Features

- **📊 Comprehensive Expense Tracking:** Effortlessly manage personal and group expenses.
- **💸 Micro-Expense Tracking:** Dedicated features for small transactions (₹1–₹10).
- **🔐 Secure Authentication:** Seamless Google Sign-In and secure Firebase authentication.
- **🔄 Offline Logging & Auto-Sync:** Fully functional offline mode using local databases (Hive & SQLite) with automatic synchronization when online.
- **👨‍👩‍👦 Parental Monitoring:** Optional, permission-based parental supervision features.
- **📄 Monthly PDF Reports:** Generate and share professional PDF reports and analytics of your spending.
- **🌙 Dynamic UI & Theming:** Modern, responsive design with Light and Dark mode support.
- **🌐 Cross-Platform:** Built to run beautifully on Android, iOS, and Web.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>=3.10.0)
- [Dart SDK](https://dart.dev/get-dart)
- A Firebase project (for backend services)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/AyushShende2679/splitmate.git
   cd splitmate
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase:**
   Ensure you have configured your Firebase project and placed `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS) in their respective directories. (Note: These files are ignored in Git for security).

4. **Run the application:**
   ```bash
   flutter run
   ```

---

## 🛠️ Technology Stack

- **Frontend:** Flutter & Dart
- **Backend/BaaS:** Firebase (Auth, Firestore, Cloud Functions)
- **Local Storage:** Hive, sqflite, shared_preferences
- **State Management:** Provider
- **UI/Charts:** fl_chart, lottie, shimmer

---

## 🧾 License

MIT © 2025 Ayush Shende
