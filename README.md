# ME — Your Mindful Companion 🌿

**"Your mind is a sky. We're here to help you understand the weather."**

ME is a premium, privacy-first emotional sanctuary and intelligent journal built for the modern soul. Designed with a striking "Indie Clarity" aesthetic, ME combines the art of mindfulness with the science of on-device AI to provide a personalized, safe space for reflection, growth, and calm.

---

## ✨ The ME Experience

### 🧠 On-Device Intelligence
We believe your most personal thoughts should never leave your hand. ME brings the power of highly optimized Small Language Models directly to your phone.
*   **Instant Insights**: Like a warm cup of tea for your thoughts, receive a specific, gentle observation immediately after every check-in.
*   **Weekly & Monthly Themes**: Identify the recurring emotional threads in your life with summaries that look at the big picture.
*   **Mindful Notifications**: Forget generic reminders. ME generates unique, AI-powered tips tailored to your last logged mood, delivered exactly when you need them.

### 💬 Meet Your Companion
A dedicated, real-time chat interface where you can talk to **ME**, your mindful partner. Unlike generic bots, your Companion is:
*   **Context-Aware**: It knows if you've had a tough morning and adjusts its tone.
*   **Non-Clinical & Warm**: Designed to be a supportive friend, not a medical tool.
*   **100% Private**: Every word stays encrypted on your device.

### 🎨 Indie Clarity UI Design & Personalization
*   **Tactile & Real**: We stepped away from generic glossy interfaces to create an authentic "Indie Clarity" look featuring halftone dot-texture overlays, bespoke typography, and soothing color palettes.
*   **Just for You**: ME greets you by your preferred name securely stored on your device, making every interaction feel deeply personal.
*   **Deep Analytics**: Elegant charts track your emotional volume over time, accompanied by a gamified XP & badge system.

---

## 🤖 Meet the "Minds" Behind ME

To provide you with high-quality reflection without compromising your privacy, ME uses state-of-the-art **Small Language Models (SLMs)**:

| Model | Personality | Size | Best For |
| :--- | :--- | :--- | :--- |
| **Qwen3 0.6B** | *Quick & Fast* | ~600 MB | Extremely fast and conversational responses. |
| **Phi-4 Mini** | *Versatile & Wise* | ~1.9 GB | Comprehensive logic and creative encouragement. |
| **Gemma 4 E2B** | *Deep & Insightful* | ~1.4 GB | Complex reflections and detailed monthly themes. |

### How these models impact you:
By running these models **locally**, ME ensures zero latency for your data and zero risk of your journals being used for training cloud models. 

**Persistent Downloads**: Downloading a large AI model shouldn't lock you inside the app. ME handles model downloads natively through the Android Foreground Service, meaning you can lock your phone or close the app entirely, and the download will continue uninterrupted in the background. When you reopen the app, the UI seamlessly re-attaches to the ongoing task. 

---

## 🐛 Known Bugs & Recent Fixes
In our journey to make ME as resilient and robust as possible, we have heavily fortified the AI management layer to solve several underlying pipeline issues:
- **Foreground Service Collisions**: Removed errant parameters that caused the native Android download WorkManager chain to silently stall.
- **Progress Stream Type Safety**: Rewrote the progress hook to dynamically parse `DownloadProgress` objects safely, bypassing catastrophic math exceptions that halted progress updates.
- **GPU Delegate Crashes**: Secured the `_ensureInitialised` handshake between the UI and the MediaPipe engine. AI models are now strictly registered into local memory *only once* per boot cycle, completely resolving hardware-related app crashes on second use.
- **Double-Download Race Conditions**: Modified the app initialization sequence to carefully inspect local disk states and running foreground services instead of blindly re-invoking network downloads on startup.
- **Active Cancellation**: Plumbed native `CancelToken` architectures into the UI, giving you exactly what you need to safely and completely kill a 2GB download instantly without corrupting local app state.
- **Safe Storage Overwrites**: Switching AI models now correctly and physically destroys the previous `.litertlm`/`.task` file from your device, but **only after** the new model verifies its integrity, ensuring zero wasted storage space.
- **Zero-Overflow Layout**: Refactored the entire mood selection interface with `SafeArea` and dynamic `MediaQuery` scaling, ensuring a premium, crash-free experience on every Android screen dimension.
- **Unified Audio Architecture**: Consolidated background music and tactile sound effects into a single, high-performance service, eliminating redundant legacy logic and reducing the app's memory footprint.
- **7-Stage Notification Scheduling**: Deployed a robust, multi-channel notification engine with precise daily and weekly reminders, including AI-driven personalized insights and level-up milestones.

---

## 🛠 Technical Foundation
- **Core**: [Flutter](https://flutter.dev) for a butter-smooth cross-platform experience.
- **AI Engine**: [MediaPipe LLM Inference](https://developers.google.com/mediapipe) via `flutter_gemma`.
- **Background Processes**: Native Android `WorkManager` & Foreground Services integrated via the plugin to survive app lifecycle terminations.
- **Database**: [Sqflite](https://pub.dev/packages/sqflite) for robust, local data persistence.
- **Architecture**: A strict **Feature-First** structure for maximum maintainability and performance.

---

## 💌 A Touch of Love & Support
Building ME was a journey of understanding that **it's okay not to be okay**. This app is dedicated to the "Night Owls," the "Consistency Masters," and everyone somewhere in between. 

Wherever you are on your path, remember: every entry is a step closer to yourself. You are doing a great job just by showing up.

**Stay mindful. Stay you.** ❤️

---
*Developed with love for personal growth and emotional clarity.*
