# VOOT

An ArkTS/HarmonyOS application that delivers real-time multilingual captioning and translation powered by local ASR, configurable LLM backends, and a polished onboarding experience. The goal is to keep speech data and API secrets on-device while offering flexible UI tooling for live caption scenarios such as meetings, accessibility support, and cross-language chats.

## Highlights

- **Real-time ASR pipeline** – Uses Sherpa Whisper-based mic service plus optional Vosk worker to decode speech locally and stream condensed segments into the translation loop.
- **Configurable translation providers** – Switch between OpenAI, DeepL, Ollama, and Doubao, or plug in new providers through the `ApiConfigPage` without touching business logic.
- **Prompt & locale tuning** – Per-language presets plus editable prompt templates keep translations faithful to tone and domain.
- **Stateful UI tabs** – Configuration, live Translation view, and Settings each keep independent ArkUI state so you can tweak APIs or display preferences without losing mic context.
- **First-run onboarding** – A welcome screen walks new users through privacy/terms confirmation using rawfile HTML assets before enabling mic capture or network access.
- **Policy sheets & dialogs** – Shared `PolicySheet` component renders agreements either as WebViews (HTML) or native ArkTS cards, reused in Settings and onboarding flows.

## Project Layout

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
├─ DOCS/                   # Reference materials & UI design notes
├─ hvigorfile.ts           # Workspace hvigor build script
└─ build-profile.json5     # Global build profile
```

## Prerequisites

- [DevEco Studio](https://developer.harmonyos.com/) or HarmonyOS SDK with `hvigorw`
- HarmonyOS/OpenHarmony device or emulator running API level that supports ArkTS + ArkUI 4.0
- `ohpm` (OpenHarmony package manager) available in your shell
- (Optional) API keys for OpenAI, DeepL, Doubao, or an accessible Ollama server

## Setup

1. **Install dependencies**
   ```powershell
   ohpm install
   cd entry
   ohpm install
   ```

2. **Configure API secrets**
   - Launch the app once to reach the Configuration tab.
   - Choose *Configure API*, pass biometric auth, then fill in keys/URLs for the providers you plan to use.
   - Settings persist via `ApiConfigStorage` (Preferences), so no plaintext files are required.

3. **Prepare ASR models**
   - Default Sherpa ONNX models live under `entry/src/main/resources/rawfile/sherpa-onnx-moonshine-tiny-en-int8`.
   - If you swap models, update the paths referenced in `SherpaWhisperMicService` and `NonStreamingAsrWithVadWorker`.

## Build & Run

Using DevEco Studio:
1. Import the repo as a HarmonyOS project.
2. Select the `entry` module and run on a connected device/emulator.

Using CLI:
```powershell
# From repo root
hvigorw assemble --module entry --runtime-mode debug
```
The output package appears under `entry/build/default/outputs/`.

## Developer Notes

- **Onboarding flow**: The first launch checks `OnboardingStorage`. Until users accept both the Terms and Privacy sheets, mic permissions and ASR init stay dormant.
- **Shared Policy sheets**: `components/PolicySheet.ets` centralizes text, HTML assets, and rendering for both Settings and onboarding overlays.
- **ASR lifecycle**: `Index.ets` boots Sherpa when entering the foreground and tears down via `SherpaWhisperMicService.stop()` when captioning stops. Ensure new features call the same helpers to avoid dangling audio sessions.
- **Networking**: Translation providers use `http.createHttp()` and must call `destroy()` after each request to avoid file-descriptor leaks.
- **Styling**: Most UI surfaces use ArkUI visual effects (HDS point lights, capsules). When adding controls, prefer builder functions to keep `build()` lean.

## Contributing

Issues and pull requests are welcome. Please lint your ArkTS code (`ohpm run lint` if configured) and ensure `hvigorw assemble --module entry` succeeds before submitting.

## License

This project is distributed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.en.html). You must:

- Keep copyright and license notices intact.
- Publish complete source (including your modifications and any larger works that include VOOT) under GPLv3.
- Provide the same patent grant to downstream users.

See the LICENSE file or the official GPL site for full terms before redistributing or shipping derivatives.
