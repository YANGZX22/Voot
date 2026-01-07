<div align="center">    
  <img src="https://github.com/YANGZX22/Voot/blob/main/entry/src/main/resources/base/media/title.png" width="300px">
</div>

# Voot – LLM-powered Live Translation for HarmonyOS

Voot, standing for "**Vo**ice **O**n **T**op," is an intelligent simultaneous-interpretation & text translation app for **HarmonyOS**, powered by **your own LLM / translation APIs**.  
It is designed with three core principles: **security, privacy, and simplicity**.

> [!NOTE]
> Voot does not provide or resell any LLM/translation service.  
> You bring your own API keys (OpenAI, DeepL, Ollama, 豆包, etc.).


## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Screenshots](#screenshots)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Clone](#clone)
  - [Run](#run)
- [Install Hap](#install-hap)
- [Configuration](#configuration)
  - [API Providers](#api-providers)
  - [Target Languages](#target-languages)
- [Usage](#usage)
- [Security & Privacy](#security--privacy)
- [Roadmap](#roadmap)
- [Blueprints](#blueprints)
- [Contributing](#contributing)
- [Model Performance](#model-performance)
- [Known Issues](#known-issues)
- [Acknowledgements](#acknowledgements)
- [License](#license)
- [Disclaimer](#disclaimer)


## Features

- 🔐 **Secure by design**
  - No built-in or hosted model – you must configure your own API keys.
  - API keys are stored **only in the HarmonyOS sandbox**, protected by **face / biometric unlock**.
  - No third-party analytics SDKs.
- 🕵️ **Privacy-first**
  - Audio is processed **locally** on-device for capture & pre-processing.
  - Recorded audio for translation is **not uploaded** and is **destroyed after processing**.
  - Only the minimal text required for translation is sent directly to the provider you configure.
- 🧩 **Multi-provider support**
  - OpenAI (GPT-style chat / translation)
  - DeepL
  - Ollama (local LLM gateway)
  - 豆包 / other custom endpoints (via configurable URL & API key)
- 🗣️ **Simultaneous interpretation**
  - One-tap start/stop of “live” translation.
  - Clear split between **original text** and **translated text**.
- 📚 **Glossary / Terminology Support**
  - Define custom term pairs (e.g., `HarmonyOS = 鸿蒙`) to force specific translations.
  - Injected directly into the LLM system prompt for high adherence.
- 🔄 **Device Continuation**
  - Seamlessly transfer your active translation session to another HarmonyOS device (e.g., from Phone to Tablet).
  - Keeps your current transcription and translation context intact.
- 🖼️ **Picture-in-Picture (PiP) Subtitles**
  - Floating subtitle window that works over other apps.
  - Resizable and movable overlay for seamless multitasking.
- 📱 **Desktop Widgets**
  - **Control Card**: Start/stop subtitle and interpretation directly from the home screen.
  - **Token Card**: Monitor your API token usage without opening the app.
- 💨 **Air Gestures**
  - Control translation start/stop without touching the screen.
  - Ideal for hands-free operation during presentations or cooking.
- ✨ **Text Polishing**
  - Improve the quality and tone of translated text.
  - Refine rough translations into more natural and professional language.
- 📷 **Scan & Translate**
  - Scan text from physical documents or screens using the camera.
  - Instantly translate scanned text with save functionality.
- 💡 **Simple UI, ArkTS only**
  - Frontend written purely in **ArkTS**, no extra UI framework.
  - Minimalist layout: buttons, text, and light effects – optimized for real-time usage.


## Architecture


```
Voot/
├─ entry/
│  ├─ src/main/ets/
│  │  ├─ pages/            # ArkUI pages (Index, Configuration, Translation, Settings, etc.)
│  │  ├─ services/         # Mic + ASR services (SherpaWhisperMicService, PipSubtitleManager)
│  │  ├─ storage/          # Preference-backed stores (API config, TokenUsage, etc.)
│  │  ├─ components/       # Shared UI builders (PolicySheet, TokenUsageChart, etc.)
│  │  ├─ widget/           # Service Cards (Desktop Widgets)
│  │  ├─ entryformability/ # Widget lifecycle management
│  │  └─ workers/          # Background ASR workers for long-running capture
│  ├─ src/main/resources/  # Raw HTML, media assets, Sherpa models
│  ├─ oh-package*.json5    # Module package definitions
│  └─ build-profile.json5  # Entry module build settings
├─ AppScope/               # Application-level configuration and assets
├─ hvigorfile.ts           # Workspace hvigor build script
└─ build-profile.json5     # Global build profile
```

## Screenshots

<div align="center">    
  <img src="https://github.com/YANGZX22/Voot/blob/main/entry/src/main/resources/base/media/screenshot.jpg">
</div>


## Getting Started

### Prerequisites

* HarmonyOS toolchain:

  * DevEco Studio with ArkTS support
  * HarmonyOS SDK (version matching the project, current: 6.0.1(21))
* A HarmonyOS device or emulator
* One or more API keys, for example:

  * OpenAI API key
  * DeepL API key
  * Ollama endpoint running locally or on LAN
  * 豆包 / other compatible HTTP API

### Clone

```bash
git clone https://github.com/YANGZX22/Voot.git
cd Voot
```

Open the project in [**DevEco Studio**](https://developer.huawei.com/consumer/cn/deveco-studio/).

### Run

1. Connect a HarmonyOS device or start an emulator.
2. In DevEco Studio, select the run configuration corresponding to the app.
3. Click **Run** to build and deploy.


## Install Hap

Or you can use [Auto-installer](https://github.com/likuai2010/auto-installer/) or [DevEcho Testing](https://developer.huawei.com/consumer/cn/deveco-testing/) for installation.

> [!IMPORTANT]
> Huawei's signing servers block IP addresses outside mainland China. To sideload software for HarmonyOS NEXT in countries/regions outside mainland China.

> [!NOTE]
> Apps sideloaded via self-signing on HarmonyOS NEXT have a default validity period of 14 days. Completing [Developer Real-Name Authentication](https://developer.huawei.com/consumer/cn/verified/enrollment) extends this period to 180 days.


## Configuration

### API Providers

In the **“配置 API”** tab:
1. Choose the current provider (e.g. OpenAI, DeepL, Ollama, 豆包).
2. Tap **“配置 API”**.
3. For each provider, fill in:

   * **API URL** (e.g. `https://api.openai.com/v1/chat/completions`,
     `https://api-free.deepl.com/v2/translate`, or your Ollama endpoint)
   * **API Key / Token**
   * Optional: custom **prompt / system message** used for translation.

The configuration is stored **locally** in the sandbox and bound to face / biometric verification when accessing/modifying.

### Target Languages

In the **“目标语言 / Target language”** section:

1. Select your default output language (e.g. 中文, English, etc.).
2. The chosen target language is used for all translation APIs by default.

### Glossary / Terminology

In the **“术语库 / Glossary”** menu:

1. Enter term pairs in the format `Original = Translation` (one per line).
2. Example:
   ```text
   HarmonyOS = 鸿蒙
   AI = 人工智能
   ```
3. These terms are automatically appended to the system prompt, instructing the LLM to strictly follow your terminology.


## Usage

1. Launch **Voot** on your HarmonyOS device.

2. **Configure API**:
   * Go to the first tab **Configuration**.
   * Select an API provider (OpenAI, DeepL, etc.) and enter your API Key/URL.
   * Set your **Target Language**.

3. **Live Translation (翻译)**:
   * Switch to the **Translation** tab.
   * Tap **“开启麦克风”** to start capturing audio.
   * Speak in the source language; the app will transcribe and translate in real-time.
   * **Air Gestures**: Wave your hand above the front camera to start/stop translation without touching the screen.
   * **Device Continuation**: Tap the **Transfer (流转)** icon to move the session to another HarmonyOS device.

4. **Text Polishing (润色)**:
   * Switch to the **Polishing** tab.
   * Input or paste text that needs refinement.
   * The AI will improve the tone, grammar, and clarity of the text.

5. **Scan & Translate (扫描)**:
   * Switch to the **Scan** tab.
   * Point the camera at a document or screen.
   * The app will recognize the text and provide an instant translation.
   * You can save the scanned results to History.

## Security & Privacy

Short summary (see in-app privacy policy / `privacy.html` for details):

* Audio:

  * Recorded only on device for the current translation session.
  * Not uploaded to our servers (we have none).
  * Discarded after processing.
* API Keys:

  * Stored in the app sandbox.
  * Protected with HarmonyOS face/biometric mechanisms.
  * Never transmitted to any server except the provider you configured.
* Data Flow:

  * Text is sent only to your chosen provider (OpenAI / DeepL / etc.).
  * No central logging, analytics, or telemetry from the developer.


## Roadmap

Finished / planned / possible steps:

* Subtitle (Realized ✅) 
* Live Window on HarmonyOS (Realized ✅) 
* Desktop Widgets (Realized ✅)
* Token usage analytics (Realized ✅)
* Glossary / Terminology Support (Realized ✅)
* Device Continuation (Realized ✅)
* History & Favorites (Realized ✅)
* Air Gestures (Realized ✅)
* Text Polishing (Realized ✅)
* Scan & Translate (Realized ✅)
* Pose Detection Button Dialog (Realized ✅)
* Support for more LLM / translation APIs (e.g. Google Translate)
* Enhanced ASR and cutoff logic
* More supported original languages

Feel free to open issues or PRs with feature requests.

## Blueprints

### 1. Audio-Direct Multimodal 
Moving beyond "Speech-to-Text-to-Translation" lossy pipelines:
*   **Direct Audio Input**
Sending VAD-filtered audio segments directly to multimodal models (e.g., GPT-4o Audio, Gemini 1.5 Pro).
*   **Nuance Capture**
Preserving tone, emotion (sarcasm, urgency), and speaker identity which are often lost in ASR.
*   **Feedback Loop**
Using the rich understanding from the multimodal engine to "feed back" into the frontend, correcting previous ASR errors or updating the context for the Fast Track.

### 2. Confidence Scoring & Visual Feedback
*   Implement a confidence scoring system that highlights translated text based on the model's certainty.
*   Low-confidence segments could be visually marked (e.g., colored or underlined), prompting users to review or wait for the Slow Track refinement.


## Contributing

Contributions are welcome!

1. Fork the repo.
2. Create a new branch for your feature/bugfix.
3. Make changes and add tests where appropriate.
4. Submit a pull request with a clear description and screenshots if UI-related.

Before submitting, please:

* Do not commit any real API keys or secrets.
* Ensure the app builds and runs on the current HarmonyOS SDK version.

## Model Performance

* Well performed LLM/Translating models on this APP by testing:

  * OpenAI: gpt-4o-mini (preferred👍), gpt-4o
  * DeepL: Free and Pro are both well performed (preferred👍)
  * 豆包（火山引擎）: DeepSeek v3.2 (deepseek-v3-2-251201) (preferred👍)

* Badly performed LLM/Translating models on this APP by testing:

  * OpenAI: gpt-5 and all thinking models series (for Translating task)
  * 豆包（火山引擎）: Doubao-Seed-1.6-lite (doubao-seed-1-6-lite-251015)

## Known Issues

* ASR accuracy may vary based on background noise and microphone quality.
* Some API providers may have rate limits or usage costs; monitor your usage carefully.
* ~~When tap **传译** button in desktop widget, the app may not open interpretation correctly due to HarmonyOS restrictions.~~ [Fixed]
* ~~Subtitle floating window may have layout issues on certain screen sizes, e.g. Pad. You can try to adjust the size of the floating window manually. An update may fix this in the future.~~ [Fixed]
* Doubao API always gives latente responses when use Lite models. This may be due to the server side of Doubao, not the app itself. [To be confirmed]

## Acknowledgements

- Inspiration: **[LiveCaptions Translator](https://github.com/SakiRinn/LiveCaptions-Translator)** on Windows.
- This project is an independent implementation and does not reuse any code from that repository.

## License

> [!IMPORTANT]
> **We are trying to push _Voot_ to launch on Huawei AppGallery. Before that, the source code is open-sourced under GPL-3.0 license. Please comply with the license terms when using or modifying the code. If launched on AppGallery, we may change the license.**

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

Please see the **[`LICENSE`](LICENSE)** file in this repository for full license text.

## Disclaimer

Voot is an independent open-source project.

* It is **not affiliated with or endorsed by** OpenAI, DeepL, Ollama, 豆包, or any other API provider.
* You are responsible for:

  * Complying with the terms of the APIs you connect to.
  * Any costs generated by your API usage.
  * Ensuring that your use of Voot and third-party services complies with local laws and regulations.
