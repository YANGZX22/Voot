<p align="center">
<img src="https://github.com/YANGZX22/Voot/blob/main/entry/src/main/resources/base/media/Icon2.png" width="400px">
</p>

# Voot – LLM-powered Live Translation for HarmonyOS

Voot, standing for **Vo**ice **o**n **t**op, is an intelligent simultaneous-interpretation & text translation app for **HarmonyOS**, powered by **your own LLM / translation APIs**.  
It is designed with three core principles: **security, privacy, and simplicity**.

>[!NOTE]
> - Voot does not provide or resell any LLM/translation service.  
> - You bring your own API keys (OpenAI, DeepL, Ollama, 豆包, etc.).

---

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
- [Contributing](#contributing)
- [License](#license)
- [Disclaimer](#disclaimer)

---

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

- 🌐 **Flexible language configuration**
  - Global “target language” selector.
  - Per-API configuration (prompt, system instructions, etc.).

- 💡 **Simple UI, ArkTS only**
  - Frontend written purely in **ArkTS**, no extra UI framework.
  - Minimalist layout: buttons, text, and light effects – optimized for real-time usage.

---

## Architecture


```
Voot/
├─ entry/
│  ├─ src/main/ets/
│  │  ├─ pages/            # ArkUI pages (Index, Configuration, Translation, Settings, etc.)
│  │  ├─ services/         # Mic + ASR services
│  │  ├─ storage/          # Preference-backed stores (API config, onboarding flag)
│  │  ├─ components/       # Shared UI builders (PolicySheet, etc.)
│  │  └─ workers/          # Background ASR workers for long-running capture
│  ├─ src/main/resources/  # Raw HTML, media assets, Sherpa models
│  ├─ oh-package*.json5    # Module package definitions
│  └─ build-profile.json5  # Entry module build settings
├─ AppScope/               # Application-level configuration and assets
├─ hvigorfile.ts           # Workspace hvigor build script
└─ build-profile.json5     # Global build profile
```
---

## Screenshots

![image](https://github.com/YANGZX22/Voot/blob/main/entry/src/main/resources/base/media/screenshot.jpg?raw=true)

---

## Getting Started

### Prerequisites

* HarmonyOS toolchain:

  * DevEco Studio with ArkTS support
  * HarmonyOS SDK (version matching the project)
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

---

## Install Hap

Use [Auto-installer](https://github.com/likuai2010/auto-installer/) or [DevEcho Testing](https://developer.huawei.com/consumer/cn/deveco-testing/) as mentioned above.


> [!NOTE]
> Apps sideloaded using self-signed certificates on HarmonyOS NEXT have a default validity period of 14 days. Completing [Developer Reality Authentication](https://developer.huawei.com/consumer/cn/verified/enrollment) extends this validity period to 180 days.

---

## Configuration

### API Providers

In the **“配置 / Configure”** tab:

1. Choose the current provider (e.g. OpenAI, DeepL, Ollama, 豆包).
2. Tap **“配置 API / Configure API”**.
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

---

## Usage

1. Launch **Voot** on your HarmonyOS device.
2. In the **配置** tab:

   * Pick an API provider.
   * Configure API URL + Key.
   * Set your target language.
3. Go to the **翻译 / Translate** tab:

   * Tap **“开启麦克风”** to start capturing audio.
   * Speak in the source language.
   * Tap **“使用 API 翻译”** to send recognized text to the selected provider.
4. The UI will show:

   * **原始文本** (recognized source text)
   * **翻译文本** (translated result)

Use it as a live interpreter in meetings, lectures, or travel scenarios.

---

## Security & Privacy

Short summary (see in-app privacy policy / `PRIVACY.html` for details):

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

---

## Roadmap

Planned / possible future work:

* Subtitle
* Live Window on HarmonyOS
* More supported original languages

Feel free to open issues or PRs with feature requests.

---

## Contributing

Contributions are welcome!

1. Fork the repo.
2. Create a new branch for your feature/bugfix.
3. Make changes and add tests where appropriate.
4. Submit a pull request with a clear description and screenshots if UI-related.

Before submitting, please:

* Do not commit any real API keys or secrets.
* Ensure the app builds and runs on the current HarmonyOS SDK version.

---

## License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

You should have received a copy of the GNU General Public License along with this program.
If not, see: [https://www.gnu.org/licenses/gpl-3.0.en.html](https://www.gnu.org/licenses/gpl-3.0.en.html)

Please see the [`LICENSE`](LICENSE) file in this repository for full license text.

---

## Disclaimer

Voot is an independent open-source project.

* It is **not affiliated with or endorsed by** OpenAI, DeepL, Ollama, 豆包, or any other API provider.
* You are responsible for:

  * Complying with the terms of the APIs you connect to.
  * Any costs generated by your API usage.
  * Ensuring that your use of Voot and third-party services complies with local laws and regulations.

