# Copilot Instructions

## Architecture & Entry Flow
- `entry/src/main/ets/entryability/EntryAbility.ets` simply boots `pages/Index`, so most UX logic lives in that page component.
- `pages/Index.ets` is a 3-tab UI (Configuration, Style, Settings) built with ArkTS `@State` and `@Builder` patterns; keep new UI pieces in builder functions to avoid bloating `build()`.
- Configuration tab drives API/locale choices via `apiOptions`, `languageOptions`, and `selectedMenu`; mutations flow through button handlers rather than global singletons.
- Style tab wires microphone captioning and translation preview, so any new ASR/LLM features should thread state updates through `originalDemoText`/`translatedDemoText` to stay in sync.
- Settings tab is currently a stub; scaffold new toggles there instead of overloading other tabs.

## Speech & Audio Stack
- `services/SherpaWhisperMicService.ets` is the primary ASR path: it builds a `OfflineRecognizer` from `sherpa/NonStreamingAsr.ets`, captures mic audio at 16 kHz mono, issues partial decodes every ~1.2 s, and invokes UI callbacks with `AsrResult`.
- Sherpa model files live under `entry/src/main/resources/rawfile/sherpa-onnx-moonshine-tiny-en-int8`; keep filenames in sync with the paths assigned in both `SherpaWhisperMicService` and `workers/NonStreamingAsrWithVadWorker.ets`.
- `getShortSegmentFromAsr`/`scheduleRealtimeTranslation` in `Index.ets` assume partial transcripts grow monotonically; if you change decoding cadence, also adjust that diff logic.
- `MicRecorderService.ets` + `VoskAsrService.ets` provide an alternative pipeline backed by a `vosk` NAPI binding; ensure `vosk_napi` exports `initModel/pushPcm/close` before invoking.
- The worker-based ASR (`workers/NonStreamingAsrWithVadWorker.ets`) mirrors the Sherpa config inside a background thread; use it when you need long-running capture without blocking the UI thread.

## Translation & Networking
- `translateCurrentDemo()` in `Index.ets` chooses among OpenAI, DeepL, Ollama, and Doubao implementations; add new providers by extending `ApiMenuType`, `apiOptions`, and `renderApiConfigContent()`.
- Each provider uses `http.createHttp()` and must call `destroy()` after requests to avoid leaking sockets; follow the existing pattern if you add streaming or retries.
- Prompting relies on `promptText` with a `{0}` placeholder for the target language; always replace it before hitting an LLM to keep instructions coherent.
- Debounced real-time translation stores the most recent ASR chunk in `originalDemoText`; keep async code `await`-safe so UI booleans like `isTranslating` remain accurate.
- Secrets (API keys) are plain `@State` strings today; consider swapping in encrypted storage before shipping but don't hardcode values in source.

## Permissions, Lifecycle, and Context
- `requestMicPermission()` runs in `onDidBuild`; reuse its `abilityAccessCtrl` flow for any new privileged capabilities so dialogs/settings fallbacks stay consistent.
- `aboutToAppear()` eagerly calls `initSherpaAsr()` and caches the service on `this.micService`; reuse that context instead of reloading models inside UI events.
- `startMicCaptioning()` sets optimistic UI text before the mic is ready, then wires callbacks; when extending, keep the early state update so buttons feel responsive.
- Always stop capture via `stopMicCaptioning()` or `SherpaWhisperMicService.stop()` to trigger a final decode and tear down timers.
- Model loaders require a `common.UIAbilityContext` for the `resourceManager`; pass the same context into any new audio/ASR helpers.

## Build, Testing, and Resources
- Run `ohpm install` in both repo root and `entry/` if dependencies change; `oh-package*.json5` files define module-level packages.
- Use DevEco Studio or `hvigorw assemble --module entry --runtime-mode debug` from the repo root to build; the provided VS Code task `arkts.tasks` simply shells out to the same hvigor entry point.
- `entry/build-profile.json5` disables obfuscation by default; toggle the `release` rule before publishing if you add sensitive ArkTS.
- UI tests live under `entry/src/ohosTest/ets` and unit tests under `entry/src/test`; mirror their folder structure when adding scenarios so DevEco picks them up automatically.
- Large model binaries belong under `entry/src/main/resources/rawfile`; update both Sherpa service files whenever you change filenames or sample rates.
