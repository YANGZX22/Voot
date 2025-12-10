# VOOT

# Voot – LLM-powered Live Translation for HarmonyOS

Voot is an intelligent simultaneous-interpretation & text translation app for **HarmonyOS**, powered by **your own LLM / translation APIs**.  
It is designed with three core principles: **security, privacy, and simplicity**.

> ⚠️ Voot does not provide or resell any LLM/translation service.  
> You bring your own API keys (OpenAI, DeepL, Ollama, 豆包, etc.).

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Screenshots](#screenshots)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Clone](#clone)
  - [Run](#run)
- [Configuration](#configuration)
  - [API Providers](#api-providers)
  - [Target Languages](#target-languages)
- [Usage](#usage)
- [Security & Privacy](#security--privacy)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)
- [Disclaimer](#disclaimer)
- [Chinese README / 中文说明](#chinese-readme--中文说明)

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
│  │  ├─ services/         # Mic + ASR services (SherpaWhisperMicService, Vosk pipelines)
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

> Replace the paths with your actual image files in the repo.

- Main translation page  
  `docs/screenshots/voot-translate.png`
- Provider & language selection  
  `docs/screenshots/voot-settings.png`
- API configuration (OpenAI / DeepL / Ollama / 豆包)  
  `docs/screenshots/voot-api-config.png`

```markdown
![Translate](docs/screenshots/voot-translate.png)
![Settings](docs/screenshots/voot-settings.png)
![API Config](docs/screenshots/voot-api-config.png)


## License

This project is distributed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.en.html). You must:

- Keep copyright and license notices intact.
- Publish complete source (including your modifications and any larger works that include VOOT) under GPLv3.
- Provide the same patent grant to downstream users.

See the LICENSE file or the official GPL site for full terms before redistributing or shipping derivatives.
