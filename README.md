# 🏃 Runner Chase

<p align="center">
  <strong>A fast-paced endless runner built with Flutter & Dart</strong>
</p>

<p align="center">
  Swipe. Dodge. Collect. Escape the police. Beat your highest score.
</p>

<p align="center">

![Flutter](https://img.shields.io/badge/Flutter-Framework-02569B?style=for-the-badge&logo=flutter)
![Dart](https://img.shields.io/badge/Dart-Language-0175C2?style=for-the-badge&logo=dart)
![Android](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)
[![pub package](https://img.shields.io/pub/v/runner_chase_utils.svg?style=for-the-badge)](https://pub.dev/packages/runner_chase_utils)

</p>

<p align="center">
  <strong>A fast-paced endless runner built with Flutter & Dart</strong>
</p>

<p align="center">
  Swipe. Dodge. Collect. Escape the police. Beat your highest score.
</p>


---

## 📌 Overview

**Runner Chase** is a mobile endless-runner game developed with **Flutter and Dart**.

The player controls a runner moving across three lanes while avoiding incoming traffic and obstacles, collecting coins, and escaping a pursuing police vehicle.

The game becomes progressively more challenging as the player's speed increases, creating a dynamic difficulty curve rather than a fixed gameplay loop.

---

## 🎮 Gameplay

The objective is simple:

> **Survive as long as possible, collect coins, avoid obstacles, escape the police, and beat your highest score.**

### Controls

| Action | Control |
|---|---|
| Move Left | Swipe Left |
| Move Right | Swipe Right |
| Collect Coin | Move into Coin |
| Avoid Obstacle | Change Lane |
| Restart | Restart Button |

---

## ✨ Features

- 🏃 Three-lane endless runner gameplay
- 👆 Swipe-based lane controls
- 🚔 Dynamic police pursuit system
- 🚗 Randomized traffic
- 🚧 Multiple obstacle types
- 🌿 Bush obstacles
- 🪙 Collectible coins
- 📈 Progressive difficulty
- ⚡ Gradually increasing game speed
- 🚧 Increasing obstacle frequency
- 🪙 Increasing coin frequency
- 🚗 Random car variations
- 🏆 Highest-score tracking
- 🔄 Instant game restart
- 📱 Android support
- 🎨 Asset-based game visuals

---

## 🧠 Game Mechanics

### Dynamic Difficulty

The game continuously increases its difficulty as the player survives.

The progression affects:

- Player environment speed
- Obstacle spawn frequency
- Number of spawned objects
- Coin availability
- Traffic probability
- Overall gameplay pressure

This creates a gradual progression from an easier opening phase to a significantly more challenging late-game experience.

### Police Pursuit

The police vehicle dynamically follows the player's lane.

If the police catches the player, the game ends.

### Scoring

Players earn points by:

- Surviving over time
- Collecting coins

The highest score is tracked during the current game session and displayed as the player's best score.

---

## 🛠️ Tech Stack

| Technology | Purpose |
|---|---|
| **Flutter** | Cross-platform UI & application framework |
| **Dart** | Application & game logic |
| **Material Design** | UI components |
| **CustomPainter** | Animated road markings |
| **Timer** | Game loop & state updates |
| **Random** | Procedural object generation |
| **Flutter Assets** | Game sprites & visual resources |

---

## 📂 Project Structure

```text
my_app/
│
├── android/
├── ios/
├── linux/
├── macos/
├── web/
├── windows/
│
├── assets/
│   └── game/
│       ├── car1.jpg
│       ├── car2.png
│       ├── character.gif
│       ├── coin.png
│       ├── police.png
│       └── bushes.png
│
├── lib/
│   └── main.dart
│
├── test/
│
├── pubspec.yaml
├── analysis_options.yaml
├── .gitignore
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

Make sure you have the following installed:

- Flutter SDK
- Dart SDK
- Android Studio or Android SDK
- VS Code or another Flutter-compatible IDE
- Android emulator or physical Android device

Verify your Flutter installation:

```bash
flutter doctor
```

---

## 📥 Installation

Clone the repository:

```bash
git clone https://github.com/farhanhabib01/my_app.git
```

Navigate into the project:

```bash
cd my_app
```

Install dependencies:

```bash
flutter pub get
```

---

## ▶️ Run the Game

Connect an Android device or start an emulator.

Then run:

```bash
flutter run
```

---

## 📦 Build APK

To generate a release APK:

```bash
flutter build apk --release
```

The generated APK can be found at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🧪 Development

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Format the project:

```bash
dart format .
```

---

## 🎯 Roadmap

Future improvements may include:

- [ ] Persistent high score storage
- [ ] Main menu
- [ ] Pause/resume functionality
- [ ] Sound effects
- [ ] Background music
- [ ] Multiple characters
- [ ] Character customization
- [ ] More vehicle types
- [ ] Additional obstacle types
- [ ] Power-ups
- [ ] Leaderboard system
- [ ] Difficulty levels
- [ ] Improved animations
- [ ] Android release distribution

---

## 🏆 Project Goals

This project was created to practice and demonstrate:

- Flutter application development
- Dart programming
- Stateful UI development
- Real-time game loops
- Collision detection
- Procedural spawning
- Randomized gameplay
- Gesture-based interaction
- Progressive difficulty systems
- Android application packaging

---

## 🤝 Contributing

Contributions, suggestions, and improvements are welcome.

1. Fork the repository
2. Create a feature branch

```bash
git checkout -b feature/your-feature
```

3. Commit your changes

```bash
git commit -m "feat: add your feature"
```

4. Push the branch

```bash
git push origin feature/your-feature
```

5. Open a Pull Request

---

## 📄 License

This project is licensed under the **MIT License**.

See the [`LICENSE`](LICENSE) file for details.

---

## 👨‍💻 Author

**M. Farhan Habib**

AI Developer | Flutter Developer | C++ Developer

GitHub: [@farhanhabib01](https://github.com/farhanhabib01)

---

<p align="center">
  Built with ❤️ using Flutter & Dart
</p>
