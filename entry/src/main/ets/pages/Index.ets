import http from '@ohos.net.http';
import { SherpaWhisperMicService, AsrResult, AsrResultCallback, AsrErrorCallback } from '../services/SherpaWhisperMicService';
import abilityAccessCtrl, { Permissions, PermissionRequestResult } from '@ohos.abilityAccessCtrl';
import type { BusinessError } from '@ohos.base';
import common from '@ohos.app.ability.common';
import { hdsEffect, HdsTabs, HdsTabsAttribute, HdsTabsController, DividerMode } from '@kit.UIDesignKit';
import { webview } from '@kit.ArkWeb';
import { ConfigurationPage } from './ConfigurationPage';
import { TranslationPage } from './TranslationPage';
import { SettingsPage } from './SettingsPage';
import { ApiConfigPage, ApiMenuType } from './ApiConfigPage';
import App from '@system.app';
import { ApiConfigStorage, ApiConfigSnapshot } from '../storage/ApiConfigStorage';
import { OnboardingStorage } from '../storage/OnboardingStorage';
import { PolicySheetType, PolicySheetContent, getPolicySheetConfig } from '../components/PolicySheet';


// ---------- Shared types for JSON parsing ----------

interface ChatMessage {
  role: string;
  content: string;
}

interface ChatCompletionMessage {
  content: string;
}

interface ChatCompletionChoice {
  message: ChatCompletionMessage;
}

interface ChatCompletionResponse {
  choices: ChatCompletionChoice[];
}

// DeepL
interface DeepLTranslation {
  text: string;
}

interface DeepLResponse {
  translations: DeepLTranslation[];
}

interface DeepLRequestBody {
  text: string[];
  target_lang: string;
}

// Ollama chat
interface OllamaChatMessage {
  role: string;
  content: string;
}

interface OllamaChatResponse {
  message: OllamaChatMessage;
}

// Doubao chat
interface DoubaoChatMessage {
  role: string;
  content: string;
}

interface DoubaoChatChoice {
  message: DoubaoChatMessage;
}

interface DoubaoChatResponse {
  choices: DoubaoChatChoice[];
}

interface AsrWindowChunk {
  text: string;
  timestamp: number;
}

enum WelcomeStage {
  Intro = 0,
  TermsAccepted,
  PrivacyAccepted
}

interface WelcomeFeature {
  title: string;
  description: string;
}

const WELCOME_FEATURES: Array<WelcomeFeature> = [
  {
    title: '自由配置',
    description: '随心切换翻译引擎与字幕样式，匹配不同的交流场景。'
  },
  {
    title: '隐私守护',
    description: 'API 密钥与语音只在本地处理，不会上传到云端。'
  },
  {
    title: '多场景适配',
    description: '会议、听障辅助、跨语对话皆可使用，实时沟通更轻松。'
  }
];

@Entry
@Component
struct Index {
  // Tabs: 0 = Configuration, 1 = Translation, 2 = Settings
  @State currentTab: number = 0;

  // Under Configuration: main vs API Settings subpage
  @State showApiSettings: boolean = false;

  // Configuration main-page state
  @State apiOptions: string[] = ['OpenAI', 'DeepL', 'Ollama', 'Doubao'];
  @State selectedApiIndex: number = 0;

  @State languageOptions: string[] = ['Chinese', 'English', 'Spanish', 'French', 'Japanese'];
  @State languageDisplayOptions: string[] = ['中文', '英语', '西班牙语', '法语', '日语'];
  @State selectedLanguageIndex: number = 0;

  // API Settings subpage state
  @State selectedMenu: ApiMenuType = ApiMenuType.Prompt;

  // DeepL config
  @State deepLApiUrl: string = 'https://api-free.deepl.com/v2/translate';
  @State deepLApiKey: string = '';

  // OpenAI config
  @State openAiApiUrl: string = 'https://api.openai.com/v1/chat/completions';
  @State openAiApiKey: string = '';
  @State openAiModel: string = 'gpt-4o-mini';

  // Ollama config (local model server)
  @State ollamaApiUrl: string = 'http://localhost:11434/api/chat';
  @State ollamaModel: string = 'llama3.1:latest';

  // Doubao config (chat/completions endpoint)
  @State doubaoApiUrl: string = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
  @State doubaoApiKey: string = '';
  @State doubaoModel: string = 'ep-20251125172005-phn6b';

  // Prompt template (used in LLM system message)
  @State promptText: string =
    'Act as an elite simultaneous interpreter who only hears imperfect microphone pickups. ' +
      'You receive roughly five-second snippets of speech, so rely on the snippet enclosed in [abc] and reasonably infer missing words while staying faithful to the speaker. ' +
      'Translate that snippet into {0} in a single fluent line, preserving intent and tone even when the audio is noisy. No matter how, you must output only one summarized sentences.';

  // Demo translation text for Appearance page
  @State originalDemoText: string = '';
  @State translatedDemoText: string = '';
  @State isTranslating: boolean = false;

  @State isWelcomeFlowActive: boolean = true;
  @State welcomeStage: WelcomeStage = WelcomeStage.Intro;
  @State isWelcomeSheetOpen: boolean = false;
  @State welcomeButtonScale: number = 1.0;
  @State isWelcomeButtonActive: boolean = false;
  @State welcomeFeatureScales: number[] = [1.0, 1.0, 1.0];
  @State activeWelcomeFeature: number = -1;

  private translationDebounceId: number | undefined = undefined;
  private lastAsrText: string = '';
  private pendingTranslationText: string = '';  // text we want to translate next
  private readonly realtimeMaxChars: number = 120;
  private readonly realtimeTranslationIntervalMs: number = 1200;
  private lastRealtimeTranslateTs: number = 0;
  private readonly asrWindowMs: number = 5000;  // keep roughly five seconds of audio
  private asrWindowChunks: AsrWindowChunk[] = [];
  private lastAsrUpdateTs: number = 0;

  private tabsController: HdsTabsController = new HdsTabsController();
  private tabsAttr?: HdsTabsAttribute;

  private welcomePolicyType: PolicySheetType = PolicySheetType.Terms;
  private welcomePolicyController: webview.WebviewController = new webview.WebviewController();
  private hasStartedMainExperience: boolean = false;

  // Mic captioning / ASR state
  @State isListening: boolean = false;
  @State isAsrReady: boolean = false;
  // Sherpa-onnx (Whisper) mic+ASR service
  private micService?: SherpaWhisperMicService;

  private scheduleRealtimeTranslation(): void {
    if (!this.originalDemoText || this.originalDemoText.length < 3) {
      return;
    }

    if (this.translationDebounceId !== undefined) {
      clearTimeout(this.translationDebounceId);
      this.translationDebounceId = undefined;
    }

    const now: number = Date.now();
    const elapsed: number = now - this.lastRealtimeTranslateTs;
    if (elapsed >= this.realtimeTranslationIntervalMs) {
      this.lastRealtimeTranslateTs = now;
      this.startTranslation(this.originalDemoText);
      return;
    }

    const delay: number = this.realtimeTranslationIntervalMs - elapsed;
    this.translationDebounceId = setTimeout((): void => {
      this.translationDebounceId = undefined;
      this.lastRealtimeTranslateTs = Date.now();
      this.startTranslation(this.originalDemoText);
    }, delay);
  }

  private getShortSegmentFromAsr(newText: string): string {
    let prev: string = this.lastAsrText;
    const normalizedPrev: string = prev.trim();
    const normalizedNew: string = newText.trim();
    const now: number = Date.now();
    const elapsedSinceUpdate: number = now - this.lastAsrUpdateTs;

    if (normalizedNew.length === 0) {
      this.lastAsrText = '';
      this.asrWindowChunks = [];
      this.lastAsrUpdateTs = now;
      return '';
    }

    this.asrWindowChunks = this.asrWindowChunks.filter((chunk) => (now - chunk.timestamp) <= this.asrWindowMs);

    if (normalizedNew === normalizedPrev) {
      const isStaleDuplicate: boolean = elapsedSinceUpdate >= this.asrWindowMs;
      if (!isStaleDuplicate) {
        return '';
      }

      // The ASR engine is repeating the same text after a long pause; reset window so we can treat it as fresh.
      prev = '';
      this.lastAsrText = '';
      this.asrWindowChunks = [];
    }

    const minLen: number = Math.min(prev.length, newText.length);

    // Find longest common prefix between previous and new text
    let i: number = 0;
    while (i < minLen && prev.charCodeAt(i) === newText.charCodeAt(i)) {
      i++;
    }

    // The "delta" is the new part
    let segment: string = newText.substring(i).trim();

    const changedButEmptyDelta: boolean =
      segment.length === 0 && normalizedNew !== normalizedPrev;

    if (changedButEmptyDelta) {
      const shrankToPrefix: boolean = normalizedPrev.startsWith(normalizedNew);
      if (shrankToPrefix) {
        // Recognizer restarted with a shorter snippet; reset window so new snippet can flow.
        this.asrWindowChunks = [];
        segment = normalizedNew;
      } else {
        // Some other re-alignment produced no delta; treat the refreshed text as a new chunk.
        segment = normalizedNew;
      }
    }

    if (segment.length > 0) {
      const words: string[] = segment.split(/\s+/);
      if (words.length > 40) {
        segment = words.slice(-40).join(' ');
      }
    }

    // Remember this full text for the next call
    this.lastAsrText = newText;

    if (segment.length > 0) {
      this.asrWindowChunks.push({ text: segment, timestamp: now });
      this.lastAsrUpdateTs = now;
    }
    const windowText: string = this.asrWindowChunks.map((chunk) => chunk.text).join(' ').trim();

    if (windowText.length > 0) {
      return windowText;
    }

    return newText.trim();
  }

  private trimRealtimeBuffer(text: string): string {
    const trimmed: string = text.trim();
    if (trimmed.length <= this.realtimeMaxChars) {
      return trimmed;
    }
    return trimmed.substring(trimmed.length - this.realtimeMaxChars).trimStart();
  }

  private requestMicPermission(): void {
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const context = this.getUIContext().getHostContext();
    const permissions: Permissions[] = ['ohos.permission.MICROPHONE'];

    atManager.requestPermissionsFromUser(
      context,
      permissions,
      (err: BusinessError, data: PermissionRequestResult) => {
        if (err) {
          console.error('[MicPermission] requestPermissionsFromUser error: ' + JSON.stringify(err));
          return;
        }

        const authResults: number[] = data.authResults;
        const granted: boolean = authResults.length > 0 && authResults[0] === 0; // 0 = PERMISSION_GRANTED

        if (!granted) {
          console.warn('[MicPermission] User did not grant microphone permission in dialog.');

          atManager.requestPermissionOnSetting(context, permissions)
            .then((results: abilityAccessCtrl.GrantStatus[]) => {
              const grantedInSettings: boolean =
                results.length > 0 &&
                  results[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;

              if (!grantedInSettings) {
                console.warn('[MicPermission] User still did not grant microphone permission in Settings.');
              } else {
                console.info('[MicPermission] Microphone permission granted via Settings.');
              }
            })
            .catch((error: BusinessError) => {
              console.error('[MicPermission] requestPermissionOnSetting error: ' + JSON.stringify(error));
            });
        } else {
          console.info('[MicPermission] Microphone permission granted via dialog.');
        }
      }
    );
  }

  aboutToAppear(): void {
    this.evaluateFirstLaunch();
  }

  private async initSherpaAsr(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;

      if (!this.micService) {
        this.micService = new SherpaWhisperMicService();
      }
      await this.micService.init(ctx);
      this.isAsrReady = true;
    } catch (e) {
      console.error('initSherpaAsr error: ' + JSON.stringify(e));
      this.isAsrReady = false;
    }
  }

  private async hydrateStoredApiConfig(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const defaults: ApiConfigSnapshot = this.buildApiConfigSnapshot();
      const snapshot: ApiConfigSnapshot = await ApiConfigStorage.loadSnapshot(ctx, defaults);
      this.applyApiConfigSnapshot(snapshot);
    } catch (error) {
      console.error('[ApiConfig] hydrateStoredApiConfig error: ' + JSON.stringify(error));
    }
  }

  private applyApiConfigSnapshot(snapshot: ApiConfigSnapshot): void {
    this.promptText = snapshot.promptText;
    this.openAiApiUrl = snapshot.openAiApiUrl;
    this.openAiApiKey = snapshot.openAiApiKey;
    this.openAiModel = snapshot.openAiModel;
    this.deepLApiUrl = snapshot.deepLApiUrl;
    this.deepLApiKey = snapshot.deepLApiKey;
    this.ollamaApiUrl = snapshot.ollamaApiUrl;
    this.ollamaModel = snapshot.ollamaModel;
    this.doubaoApiUrl = snapshot.doubaoApiUrl;
    this.doubaoApiKey = snapshot.doubaoApiKey;
    this.doubaoModel = snapshot.doubaoModel;
  }

  private buildApiConfigSnapshot(): ApiConfigSnapshot {
    return {
      promptText: this.promptText,
      openAiApiUrl: this.openAiApiUrl,
      openAiApiKey: this.openAiApiKey,
      openAiModel: this.openAiModel,
      deepLApiUrl: this.deepLApiUrl,
      deepLApiKey: this.deepLApiKey,
      ollamaApiUrl: this.ollamaApiUrl,
      ollamaModel: this.ollamaModel,
      doubaoApiUrl: this.doubaoApiUrl,
      doubaoApiKey: this.doubaoApiKey,
      doubaoModel: this.doubaoModel
    };
  }

  private persistApiConfigSnapshot(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const snapshot: ApiConfigSnapshot = this.buildApiConfigSnapshot();
      ApiConfigStorage.saveSnapshot(ctx, snapshot).catch((error: BusinessError | Error) => {
        console.error('[ApiConfig] saveSnapshot error: ' + JSON.stringify(error));
      });
    } catch (error) {
      console.error('[ApiConfig] saveSnapshot context error: ' + JSON.stringify(error));
    }
  }

  private async evaluateFirstLaunch(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const isFirstLaunch: boolean = await OnboardingStorage.isFirstLaunch(ctx);
      this.isWelcomeFlowActive = isFirstLaunch;
      if (!isFirstLaunch) {
        this.startMainExperience();
      }
    } catch (error) {
      console.error('[Onboarding] evaluateFirstLaunch error: ' + JSON.stringify(error));
      this.isWelcomeFlowActive = false;
      this.startMainExperience();
    }
  }

  private startMainExperience(): void {
    if (this.hasStartedMainExperience) {
      return;
    }
    this.hasStartedMainExperience = true;
    this.requestMicPermission();
    this.initSherpaAsr();
    this.hydrateStoredApiConfig();
  }

  private handleWelcomeContinue(): void {
    if (this.welcomeStage === WelcomeStage.Intro) {
      this.openWelcomePolicySheet(PolicySheetType.Terms);
      return;
    }
    if (this.welcomeStage === WelcomeStage.TermsAccepted) {
      this.openWelcomePolicySheet(PolicySheetType.Privacy);
      return;
    }
    if (this.welcomeStage === WelcomeStage.PrivacyAccepted) {
      this.completeWelcomeFlow();
    }
  }

  private getWelcomeButtonLabel(): string {
    return this.welcomeStage === WelcomeStage.PrivacyAccepted ? '进入应用' : '继续';
  }

  private openWelcomePolicySheet(sheet: PolicySheetType): void {
    this.welcomePolicyType = sheet;
    this.welcomePolicyController = new webview.WebviewController();
    this.isWelcomeSheetOpen = true;
  }

  private handleWelcomeSheetConfirmed(): void {
    this.isWelcomeSheetOpen = false;
    if (this.welcomePolicyType === PolicySheetType.Terms) {
      this.welcomeStage = WelcomeStage.TermsAccepted;
      return;
    }
    if (this.welcomePolicyType === PolicySheetType.Privacy) {
      this.welcomeStage = WelcomeStage.PrivacyAccepted;
    }
  }

  private async completeWelcomeFlow(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      await OnboardingStorage.markCompleted(ctx);
    } catch (error) {
      console.error('[Onboarding] markCompleted error: ' + JSON.stringify(error));
    }
    this.isWelcomeFlowActive = false;
    this.startMainExperience();
  }

  private pressWelcomeButton(): void {
    this.isWelcomeButtonActive = true;
    animateTo({
      duration: 100,
      curve: Curve.EaseIn
    }, () => {
      this.welcomeButtonScale = 0.9;
    });
  }

  private releaseWelcomeButton(): void {
    this.isWelcomeButtonActive = false;
    animateTo({
      duration: 200,
      curve: Curve.EaseOut
    }, () => {
      this.welcomeButtonScale = 1.0;
    });
  }

  private pressWelcomeFeature(index: number): void {
    this.activeWelcomeFeature = index;
    animateTo({
      duration: 100,
      curve: Curve.EaseIn
    }, () => {
      const nextScales: number[] = [...this.welcomeFeatureScales];
      nextScales[index] = 0.9;
      this.welcomeFeatureScales = nextScales;
    });
  }

  private releaseWelcomeFeature(index: number): void {
    this.activeWelcomeFeature = -1;
    animateTo({
      duration: 200,
      curve: Curve.EaseOut
    }, () => {
      const nextScales: number[] = [...this.welcomeFeatureScales];
      nextScales[index] = 1.0;
      this.welcomeFeatureScales = nextScales;
    });
  }

  @Builder
  private WelcomeFeatureCard(feature: WelcomeFeature, index: number) {
    Button() {
      Column() {
        Text(feature.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .margin({ bottom: 6 })
        Text(feature.description)
          .fontSize(13)
          .fontColor(Color.Grey)
          .lineHeight(20)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .type(ButtonType.Normal)
    .backgroundColor("#b33c1464")
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .margin({ bottom: index === (WELCOME_FEATURES.length - 1) ? 0 : 12 })
    .borderRadius(18)
    .shadow({
      radius: 18,
      color: '#22000000',
      offsetY: 2,
      offsetX: 0
    })
    .scale({ x: this.welcomeFeatureScales[index], y: this.welcomeFeatureScales[index] })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.activeWelcomeFeature === index
          ? hdsEffect.PointLightSourceType.BRIGHT
          : hdsEffect.PointLightSourceType.NONE,
        illuminatedType: this.activeWelcomeFeature >= 0
          ? hdsEffect.PointLightIlluminatedType.BORDER
          : hdsEffect.PointLightIlluminatedType.NONE
      })
      .buildEffect())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressWelcomeFeature(index);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.releaseWelcomeFeature(index);
      }
    })
  }

  @Builder
  private WelcomeScreen() {
    Column() {
      Image($r('app.media.foreground'))
        .width(96)
        .height(96)
        // .margin({ bottom: 6 })
        .objectFit(ImageFit.Contain)
        .alignSelf(ItemAlign.Center)
      Column() {
        Text('欢迎使用 Voot')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ bottom: 12 })
        Text('Voot 的诞生致力于用LLM赋能同声传译')
          .fontSize(15)
          .fontColor('#DDFFFFFF')
          .lineHeight(22)
          .margin({ bottom: 24 })
        Column() {
          ForEach(WELCOME_FEATURES, (feature: WelcomeFeature, index?: number) => {
            this.WelcomeFeatureCard(feature, index ?? 0);
          }, (feature: WelcomeFeature, index?: number) => `${index ?? 0}-${feature.title}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        .backgroundColor('#333c1464')
        .borderRadius(18)
      }
      .width('100%')
      Column() {
        Button(this.getWelcomeButtonLabel())
          .type(ButtonType.Capsule)
          .backgroundColor('#e63c1464')
          .width('100%')
          .height(48)
          .fontSize(16)
          .scale({ x: this.welcomeButtonScale, y: this.welcomeButtonScale })
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              sourceType: this.isWelcomeButtonActive
                ? hdsEffect.PointLightSourceType.BRIGHT
                : hdsEffect.PointLightSourceType.NONE,
              illuminatedType: this.isWelcomeButtonActive
                ? hdsEffect.PointLightIlluminatedType.BORDER
                : hdsEffect.PointLightIlluminatedType.NONE
            })
            .buildEffect())
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.pressWelcomeButton();
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.releaseWelcomeButton();
            }
          })
          .onClick(() => {
            this.handleWelcomeContinue();
          })
        Text(
          this.welcomeStage === WelcomeStage.PrivacyAccepted
            ? '政策确认完毕，可进入应用配置界面。'
            : '首次使用需依次确认《用户协议》和《隐私政策》。'
        )
          .fontSize(12)
          .fontColor(Color.Grey)
          .textAlign(TextAlign.Center)
          .margin({ top: 12 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 32, right: 32, top: 80, bottom: 48 })
    .justifyContent(FlexAlign.SpaceBetween)
  }

  build() {
    Stack() {
      Image($r('app.media.app_background_pic'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover);

      if (this.isWelcomeFlowActive) {
        this.WelcomeScreen();
      } else {
        Column() {
        HdsTabs({ controller: this.tabsController }) {
        TabContent() {
          Column() {
            if (this.showApiSettings) {
              ApiConfigPage({
                selectedMenu: this.selectedMenu,
                promptText: this.promptText,
                openAiApiUrl: this.openAiApiUrl,
                openAiApiKey: this.openAiApiKey,
                openAiModel: this.openAiModel,
                deepLApiUrl: this.deepLApiUrl,
                deepLApiKey: this.deepLApiKey,
                ollamaApiUrl: this.ollamaApiUrl,
                ollamaModel: this.ollamaModel,
                doubaoApiUrl: this.doubaoApiUrl,
                doubaoApiKey: this.doubaoApiKey,
                doubaoModel: this.doubaoModel,
                onBack: () => {
                  this.currentTab = 0;
                  this.showApiSettings = false;
                },
                onSelectMenu: (menu: ApiMenuType) => this.selectedMenu = menu,
                onUpdatePrompt: (value: string) => {
                  this.promptText = value;
                  this.persistApiConfigSnapshot();
                },
                onUpdateOpenAiApiUrl: (value: string) => {
                  this.openAiApiUrl = value;
                  this.persistApiConfigSnapshot();
                },
                onUpdateOpenAiApiKey: (value: string) => {
                  this.openAiApiKey = value;
                  this.persistApiConfigSnapshot();
                },
                onUpdateOpenAiModel: (value: string) => {
                  this.openAiModel = value;
                  this.persistApiConfigSnapshot();
                },
                onUpdateDeepLApiUrl: (value: string) => {
                  this.deepLApiUrl = value;
                  this.persistApiConfigSnapshot();
                },
                onUpdateDeepLApiKey: (value: string) => {
                  this.deepLApiKey = value;
                  this.persistApiConfigSnapshot();
                },
                onUpdateOllamaApiUrl: (value: string) => {
                  this.ollamaApiUrl = value;
                  this.persistApiConfigSnapshot();
                },
                onUpdateOllamaModel: (value: string) => {
                  this.ollamaModel = value;
                  this.persistApiConfigSnapshot();
                },
                onUpdateDoubaoApiUrl: (value: string) => {
                  this.doubaoApiUrl = value;
                  this.persistApiConfigSnapshot();
                },
                onUpdateDoubaoApiKey: (value: string) => {
                  this.doubaoApiKey = value;
                  this.persistApiConfigSnapshot();
                },
                onUpdateDoubaoModel: (value: string) => {
                  this.doubaoModel = value;
                  this.persistApiConfigSnapshot();
                },
                getConfigTextAreaHeight: (rows: number) => this.getConfigTextAreaHeight(rows)
              });
            } else {
              ConfigurationPage({
                apiOptions: this.apiOptions,
                selectedApiIndex: this.selectedApiIndex,
                languageOptions: this.languageOptions,
                languageDisplayOptions: this.languageDisplayOptions,
                selectedLanguageIndex: this.selectedLanguageIndex,
                onCycleApi: () => {
                  this.selectedApiIndex = (this.selectedApiIndex + 1) % this.apiOptions.length;
                },
                onCycleLanguage: () => {
                  this.selectedLanguageIndex =
                    (this.selectedLanguageIndex + 1) % this.languageOptions.length;
                },
                onOpenApiSettings: () => {
                  this.showApiSettings = true;
                  this.selectedMenu = this.mapApiIndexToMenu(this.selectedApiIndex);
                }
              });
            }
          }
          .width('100%')
          // .padding({ left: 24, right: 24, top: 24, bottom: 48 });
        }
        .tabBar(new BottomTabBarStyle($r('app.media.configuration') ,'配置')
          .iconStyle({ selectedColor: Color.White })
          .labelStyle({ selectedColor: Color.White})
        )

        TabContent() {
          Column() {
            TranslationPage({
              isListening: this.isListening,
              isAsrReady: this.isAsrReady,
              originalDemoText: this.originalDemoText,
              translatedDemoText: this.translatedDemoText,
              isTranslating: this.isTranslating,
              currentApiLabel: this.getCurrentApiLabel(),
              currentLanguageLabel: this.getCurrentLanguageLabel(),
              onToggleCaptioning: () => {
                if (this.isListening) {
                  this.stopMicCaptioning();
                } else {
                  this.startMicCaptioning();
                }
              },
              onTranslateDemo: () => this.translateCurrentDemo(),
              onOriginalTextChange: (value: string) => {
                this.originalDemoText = this.trimRealtimeBuffer(value);
              },
              onTranslatedTextChange: (value: string) => this.updateTranslationField(value)
            });
          }
          .width('100%')
          // .padding({ left: 24, right: 24, top: 24, bottom: 48 });
        }
        .tabBar(new BottomTabBarStyle($r('app.media.translation') ,'翻译')
          .iconStyle({ selectedColor: Color.White })
          .labelStyle({ selectedColor: Color.White})
        )

        TabContent() {
          Column() {
            SettingsPage();
          }
          .width('100%')
          // .padding({ left: 24, right: 24, top: 24, bottom: 48 });
        }
        .tabBar(new BottomTabBarStyle($r('app.media.settings') ,'设置')
          .iconStyle({ selectedColor: Color.White })
          .labelStyle({ selectedColor: Color.White})
        )
      }
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .barPosition(BarPosition.End)
      .barHeight(70)
      // .barBackgroundColor(Color.Gray)
      .scrollable(true)
      .divider({
        mode: DividerMode.FOLLOW_SCROLL,
        style: {
          color: Color.Transparent,
          strokeWidth: 1
        }
      })
      .animationDuration(200)
      .barOverlap(true)
      .vertical(false)
      .barBackgroundStyle({
        maskColor: "#99594781",
        maskHeight: 70
      })
      .onChange((index: number) => {
        this.currentTab = index;
        if (index !== 0 && this.showApiSettings) {
          this.showApiSettings = false;
        }
      });
        }
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
        // .backgroundColor("#ff0f5f5f")
        .width('100%')
        .height('100%')
      }
    }
    .bindSheet(
      $$this.isWelcomeSheetOpen,
      PolicySheetContent(
        getPolicySheetConfig(this.welcomePolicyType),
        this.welcomePolicyController,
        () => {
          this.handleWelcomeSheetConfirmed();
        }
      ), {
        detents: [SheetSize.FIT_CONTENT, SheetSize.MEDIUM],
        dragBar: true,
        backgroundColor: '#e63c1464',
        blurStyle: BlurStyle.BACKGROUND_REGULAR,
        enableOutsideInteractive: false
      }
    )
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    .width('100%')
    .height('100%');
  }

  // =======================
  // Translation helpers
  // =======================

  private getTargetLanguageName(): string {
    return this.languageOptions[this.selectedLanguageIndex];
  }

  private getCurrentApiLabel(): string {
    if (this.selectedApiIndex >= 0 && this.selectedApiIndex < this.apiOptions.length) {
      return this.apiOptions[this.selectedApiIndex];
    }
    return this.apiOptions.length > 0 ? this.apiOptions[0] : '';
  }

  private getCurrentLanguageLabel(): string {
    const hasDisplayLabel: boolean = this.languageDisplayOptions.length > this.selectedLanguageIndex;
    if (this.selectedLanguageIndex >= 0 && this.selectedLanguageIndex < this.languageOptions.length) {
      if (hasDisplayLabel) {
        return this.languageDisplayOptions[this.selectedLanguageIndex];
      }
      return this.languageOptions[this.selectedLanguageIndex];
    }
    if (this.languageDisplayOptions.length > 0) {
      return this.languageDisplayOptions[0];
    }
    return this.languageOptions.length > 0 ? this.languageOptions[0] : '';
  }

  private buildSystemPromptWithSource(text: string): string {
    const langName: string = this.getTargetLanguageName();
    const promptWithLanguage: string = this.promptText.replace('{0}', langName);
    const trimmedSource: string = text ? text.trim() : '';
    const sourceForPrompt: string = trimmedSource.length > 0 ? trimmedSource : text;
    const wrappedSource: string = '[' + (sourceForPrompt ?? '') + ']';
    return promptWithLanguage.replace('[abc]', wrappedSource);
  }

  private getTargetLanguageCode(): string {
    const lang: string = this.languageOptions[this.selectedLanguageIndex];
    if (lang === 'English') { return 'en'; }
    if (lang === 'Spanish') { return 'es'; }
    if (lang === 'French') { return 'fr'; }
    if (lang === 'Chinese') { return 'zh'; }
    if (lang === 'Japanese') { return 'ja'; }
    return 'en';
  }

  private mapApiIndexToMenu(index: number): ApiMenuType {
    if (index === 0) {
      return ApiMenuType.OpenAI;
    }
    if (index === 1) {
      return ApiMenuType.DeepL;
    }
    if (index === 2) {
      return ApiMenuType.Ollama;
    }
    return ApiMenuType.Doubao;
  }

  private getConfigTextAreaHeight(lines: number = 3): number {
    const lineHeight: number = 28;
    return Math.max(64, lineHeight * lines);
  }

  private updateTranslationField(text: string): void {
    this.translatedDemoText = this.trimRealtimeBuffer(text);
  }


  private startTranslation(text: string): void {
    if (!text || text.length < 3) {
      return;
    }

    // If a translation is already in progress, just remember the latest text.
    // Once the current translation finishes, we'll translate this latest one.
    if (this.isTranslating) {
      this.pendingTranslationText = text;
      return;
    }

    this.isTranslating = true;
    this.pendingTranslationText = '';

    void this.doTranslate(text).finally(() => {
      this.isTranslating = false;

      // If new text arrived while translating, translate the latest one next.
      if (this.pendingTranslationText && this.pendingTranslationText !== text) {
        const next: string = this.pendingTranslationText;
        this.pendingTranslationText = '';
        this.startTranslation(next);
      }
    });
  }

  private async doTranslate(text: string): Promise<void> {
    if (!text || text.length === 0) {
      return;
    }

    const selectedApiName: string = this.apiOptions[this.selectedApiIndex];

    try {
      if (selectedApiName === 'OpenAI') {
        await this.translateWithOpenAI(text);
      } else if (selectedApiName === 'DeepL') {
        await this.translateWithDeepL(text);
      } else if (selectedApiName === 'Ollama') {
        await this.translateWithOllama(text);
      } else if (selectedApiName === 'Doubao') {
        await this.translateWithDoubao(text);
      }
    } catch (e) {
      console.error('doTranslate error: ' + JSON.stringify(e));
      this.updateTranslationField('[translation error]');
    }
  }

  private async translateCurrentDemo(): Promise<void> {
    if (!this.originalDemoText || this.originalDemoText.length === 0) {
      return;
    }

    this.startTranslation(this.originalDemoText);
  }

  // --- OpenAI implementation ---
  private async translateWithOpenAI(text: string): Promise<void> {
    const httpRequest: http.HttpRequest = http.createHttp();

    const systemPrompt: string = this.buildSystemPromptWithSource(text);

    const messages: ChatMessage[] = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: text }
    ];

    const body: string = JSON.stringify({
      model: this.openAiModel,
      messages: messages
    });

    const response: http.HttpResponse = await httpRequest.request(this.openAiApiUrl, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + this.openAiApiKey
      },
      extraData: body,
      expectDataType: http.HttpDataType.STRING
    });

    const resultStr: string = response.result as string;
    let translated: string = '';

    const parsed = JSON.parse(resultStr) as ChatCompletionResponse;
    if (parsed.choices && parsed.choices.length > 0) {
      translated = parsed.choices[0].message.content;
    }

    this.updateTranslationField(translated);
    httpRequest.destroy();
  }

  // --- DeepL implementation ---
  private async translateWithDeepL(text: string): Promise<void> {
    const httpRequest: http.HttpRequest = http.createHttp();

    const langCode: string = this.getTargetLanguageCode().toUpperCase();
    const bodyObj: DeepLRequestBody = {
      text: [text],
      target_lang: langCode
    };
    const body: string = JSON.stringify(bodyObj);

    const response: http.HttpResponse = await httpRequest.request(this.deepLApiUrl, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': 'DeepL-Auth-Key ' + this.deepLApiKey
      },
      extraData: body,
      expectDataType: http.HttpDataType.STRING
    });

    const resultStr: string = response.result as string;
    let translated: string = '';

    const parsed = JSON.parse(resultStr) as DeepLResponse;
    if (parsed.translations && parsed.translations.length > 0) {
      translated = parsed.translations[0].text;
    } else {
      translated = '[DeepL: empty translations]';
    }

    this.updateTranslationField(translated);
    httpRequest.destroy();
  }

  // --- Ollama implementation ---
  private async translateWithOllama(text: string): Promise<void> {
    const httpRequest: http.HttpRequest = http.createHttp();

    const systemPrompt: string = this.buildSystemPromptWithSource(text);

    const messages: ChatMessage[] = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: text }
    ];

    const body: string = JSON.stringify({
      model: this.ollamaModel,
      messages: messages,
      stream: false
    });

    const response: http.HttpResponse = await httpRequest.request(this.ollamaApiUrl, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json'
      },
      extraData: body,
      expectDataType: http.HttpDataType.STRING
    });

    const resultStr: string = response.result as string;
    let translated: string = '';

    const parsed = JSON.parse(resultStr) as OllamaChatResponse;
    translated = parsed.message.content;

    this.updateTranslationField(translated);
    httpRequest.destroy();
  }

  // --- Doubao implementation ---
  private async translateWithDoubao(text: string): Promise<void> {
    const httpRequest: http.HttpRequest = http.createHttp();

    const systemPrompt: string = this.buildSystemPromptWithSource(text);

    const messages: ChatMessage[] = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: text }
    ];

    const body: string = JSON.stringify({
      model: this.doubaoModel,
      max_completion_tokens: 2048,
      messages: messages,
      reasoning_effort: 'medium'
    });

    const response: http.HttpResponse = await httpRequest.request(this.doubaoApiUrl, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + this.doubaoApiKey
      },
      extraData: body,
      expectDataType: http.HttpDataType.STRING
    });

    const resultStr: string = response.result as string;
    let translated: string = '';

    const parsed = JSON.parse(resultStr) as DoubaoChatResponse;
    if (parsed.choices && parsed.choices.length > 0) {
      translated = parsed.choices[0].message.content;
    } else {
      translated = '[Doubao: no choices in response]';
    }

    this.updateTranslationField(translated);
    httpRequest.destroy();
  }

  // =======================
  // Mic
  // =======================

  private handleRecognizedSpeech(text: string): void {
    this.originalDemoText = this.trimRealtimeBuffer(text);
    this.translateCurrentDemo();
  }

  private async startMicCaptioning(): Promise<void> {
    if (this.isListening) {
      return;
    }

    // 1) Always show something immediately so you know the button worked
    this.isListening = true;
    this.originalDemoText = this.trimRealtimeBuffer('[speech recognition starting…]');
    this.translateCurrentDemo();

    // 2) Try real mic + sherpa-onnx (Whisper) in the background (if it works)
    if (!this.isAsrReady || !this.micService) {
      await this.initSherpaAsr();
    }
    if (!this.micService || !this.isAsrReady) {
      // If mic / ASR not ready (emulator, permission, etc.), show message
      this.updateTranslationField('[Mic/ASR not ready – showing stub only]');
      this.isListening = false;
      return;
    }

    const onResult: AsrResultCallback = (res: AsrResult): void => {
      // Extract a short 1–2 second chunk from the full ASR text
      const shortText: string = this.getShortSegmentFromAsr(res.text);
      if (shortText) {
        // Show only this short chunk in the "Original text" area
        this.originalDemoText = this.trimRealtimeBuffer(shortText);

        // If you want real-time translation on each chunk, keep the debounce:
        this.scheduleRealtimeTranslation();
      }

      // On final result (after STOP), you can still run your existing logic
      if (res.isFinal) {
        // Optional: if handleRecognizedSpeech expects to translate originalDemoText,
        // it will now work on the latest shortText.
        this.handleRecognizedSpeech(res.text);
      }
    };

    const onError: AsrErrorCallback = (msg: string): void => {
      console.error('Mic ASR error: ' + msg);
      // Also show in UI so you can see it on emulator
      this.updateTranslationField('[Mic ASR error] ' + msg);
      this.isListening = false;
    };

    try {
      await this.micService.start(onResult, onError);
    } catch (e) {
      const msg: string = 'startMicCaptioning error: ' + JSON.stringify(e);
      console.error(msg);
      this.updateTranslationField(msg);
      this.isListening = false;
    }
  }

  private async stopMicCaptioning(): Promise<void> {
    if (!this.isListening) {
      return;
    }

    if (this.micService) {
      this.micService.stop();
    }

    this.isListening = false;
    this.lastRealtimeTranslateTs = 0;

    // Optional: cancel any pending debounce and translate current text now
    if (this.translationDebounceId !== undefined) {
      clearTimeout(this.translationDebounceId);
      this.translationDebounceId = undefined;
    }
    if (this.originalDemoText && this.originalDemoText.length > 0) {
      this.translateCurrentDemo();
    }
  }

}
