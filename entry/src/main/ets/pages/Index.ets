import http from '@ohos.net.http';
import { TextReader } from '@kit.SpeechKit';
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
import window from '@ohos.window';
import promptAction from '@ohos.promptAction';


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

interface OllamaChatOptions {
  num_predict?: number;
  temperature?: number;
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

  @State intervalOptions: string[] = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];
  @State intervalIndex: number = 4;

  @State contextsOptions: string[] = ['1', '2', '3', '4', '5', '6'];
  @State contextsIndex: number = 2;

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
  @State doubaoModel: string = 'ep-20251221220646-rnx4c';

  // Subtitle Style Config
  @State subtitleFontSize: number = 30;
  @State subtitleFontColor: string = '#FFFFFF';
  @State subtitleBackgroundColor: string = '#3c1464';
  @State subtitleBackgroundOpacity: number = 0.4;
  @State subtitleHeight: number = 240;

  // Prompt template (used in LLM system message)
  @State promptText: string =
    'Act as an elite simultaneous interpreter who only hears imperfect microphone pickups. ' +
      'You receive roughly five-second snippets of speech, so rely on the snippet enclosed in [abc] and reasonably infer missing words while staying faithful to the speaker. ' +
      'Translate that snippet into {0} in a single fluent line, preserving intent and tone even when the audio is noisy. No matter how, you must output the translation directly.';

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

  // Subtitle Window State
  @State isSubtitleOpen: boolean = false;
  @State isRealtimeReadingEnabled: boolean = false;
  private subtitleWin: window.Window | null = null;

  private translationDebounceId: number | undefined = undefined;
  private lastAsrText: string = '';
  private pendingTranslationText: string = '';  // text we want to translate next
  private readonly realtimeMaxChars: number = 250; // keep display short
  private lastRealtimeTranslateTs: number = 0;
  private lastTtsPlayTime: number = 0;
  private lastAsrUpdateTs: number = 0;
  private contextHistory: string[] = [];
  private lastTranslatedText: string = ''; // avoid duplicate translations
  private lastDisplayedText: string = ''; // avoid flickering

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

  /**
   * Get translation interval from config (in ms).
   */
  private getTranslationIntervalMs(): number {
    return parseInt(this.intervalOptions[this.intervalIndex]) * 1000;
  }

  private scheduleRealtimeTranslation(): void {
    const text = this.originalDemoText;
    if (!text || text.length < 2) {
      return;
    }

    // Skip exact duplicate
    if (text === this.lastTranslatedText) {
      return;
    }

    // Cancel any pending debounce
    if (this.translationDebounceId !== undefined) {
      clearTimeout(this.translationDebounceId);
      this.translationDebounceId = undefined;
    }

    const intervalMs: number = this.getTranslationIntervalMs();
    const now: number = Date.now();
    const elapsed: number = now - this.lastRealtimeTranslateTs;
    
    // Immediate translate if interval elapsed
    if (elapsed >= intervalMs) {
      this.lastRealtimeTranslateTs = now;
      this.lastTranslatedText = text;
      this.startTranslation(text);
      return;
    }

    // Very short delay for batching rapid ASR updates (150ms max)
    // This catches rapid-fire partial results without noticeable delay
    const delay: number = Math.min(150, intervalMs - elapsed);
    this.translationDebounceId = setTimeout((): void => {
      this.translationDebounceId = undefined;
      const currentText = this.originalDemoText;
      if (currentText && currentText.length >= 2 && currentText !== this.lastTranslatedText) {
        this.lastRealtimeTranslateTs = Date.now();
        this.lastTranslatedText = currentText;
        this.startTranslation(currentText);
      }
    }, delay);
  }

  /**
   * Process ASR text for display.
   * ASR returns the full recognized text for the current audio window.
   * We apply stability filtering to reduce flicker from ASR wobble.
   */
  private getShortSegmentFromAsr(newText: string): string {
    const trimmed: string = newText.trim();
    const now: number = Date.now();

    // Empty input - clear state
    if (trimmed.length === 0) {
      this.lastAsrText = '';
      this.lastAsrUpdateTs = now;
      return '';
    }

    // Filter obvious noise patterns
    if (this.isAsrNoise(trimmed)) {
      return '';
    }

    const prevTrimmed: string = this.lastAsrText.trim();
    
    // Skip exact duplicate
    if (trimmed === prevTrimmed) {
      return '';
    }

    // Stability filter: detect minor ASR wobble
    if (prevTrimmed.length > 5 && trimmed.length > 5) {
      // Calculate similarity score
      const similarity = this.textSimilarity(prevTrimmed, trimmed);
      
      // High similarity (>85%) with small length change = ASR wobble
      if (similarity > 0.85) {
        const lenDiff = Math.abs(prevTrimmed.length - trimmed.length);
        // If text shrunk or barely changed, skip
        if (trimmed.length <= prevTrimmed.length || lenDiff < 3) {
          return '';
        }
      }
    }

    // Update state
    this.lastAsrText = newText;
    this.lastAsrUpdateTs = now;

    // Limit length (take end portion for long text)
    if (trimmed.length > this.realtimeMaxChars) {
      return trimmed.substring(trimmed.length - this.realtimeMaxChars);
    }
    return trimmed;
  }

  /**
   * Check if text looks like ASR noise (repeated chars, gibberish)
   */
  private isAsrNoise(text: string): boolean {
    if (text.length < 2) return true;
    
    // Check for repeated character patterns (e.g., "aaaa", "ththth")
    const repeatPattern = /(.)\1{3,}/;
    if (repeatPattern.test(text)) return true;
    
    // Check for very short repeated words
    const words = text.split(/\s+/);
    if (words.length >= 3) {
      const uniqueWords = new Set(words);
      // If >60% of words are duplicates, likely noise
      if (uniqueWords.size < words.length * 0.4) return true;
    }
    
    return false;
  }

  /**
   * Calculate similarity ratio between two strings (0-1)
   */
  private textSimilarity(a: string, b: string): number {
    if (a === b) return 1;
    if (a.length === 0 || b.length === 0) return 0;
    
    const longer = a.length > b.length ? a : b;
    const shorter = a.length > b.length ? b : a;
    
    // Count matching characters from start
    let prefixMatch = 0;
    for (let i = 0; i < shorter.length; i++) {
      if (shorter.charCodeAt(i) === longer.charCodeAt(i)) {
        prefixMatch++;
      } else {
        break;
      }
    }
    
    // Count matching characters from end
    let suffixMatch = 0;
    for (let i = 0; i < shorter.length - prefixMatch; i++) {
      if (shorter.charCodeAt(shorter.length - 1 - i) === longer.charCodeAt(longer.length - 1 - i)) {
        suffixMatch++;
      } else {
        break;
      }
    }
    
    const totalMatch = prefixMatch + suffixMatch;
    return totalMatch / longer.length;
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

  async aboutToAppear(): Promise<void> {
    this.evaluateFirstLaunch();
    AppStorage.setOrCreate('voot_translated_text', '');

    // Initialize TextReader
    try {
      let context = getContext(this) as common.BaseContext;
      const readerParams: TextReader.ReaderParam = {
        isVoiceBrandVisible: true,
        businessBrandInfo: {
          panelName: 'Voot 传译器',
          panelIcon: $r('app.media.startIcon')
        }
      };
      await TextReader.init(context, readerParams);
    } catch (e) {
      console.error(`TextReader init failed: ${JSON.stringify(e)}`);
    }
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

  private async toggleSubtitleWindow(forceOpen?: boolean): Promise<void> {
    const shouldOpen = forceOpen !== undefined ? forceOpen : !this.isSubtitleOpen;

    if (!shouldOpen) {
      // Try to find it if we don't have the reference, just to be sure we clean up
      if (!this.subtitleWin) {
        const win = AppStorage.get<window.Window>('voot_subtitle_win');
        this.subtitleWin = win ? win : null;
      }
      
      if (!this.subtitleWin) {
        try {
          this.subtitleWin = await window.findWindow('voot_subtitle');
        } catch (e) {
          // ignore
        }
      }

      if (this.subtitleWin) {
        await this.subtitleWin.destroyWindow();
        this.subtitleWin = null;
        AppStorage.setOrCreate('voot_subtitle_win', undefined);
      }
      this.isSubtitleOpen = false;
      this.persistApiConfigSnapshot();
      promptAction.showToast({ message: '字幕已关闭' });
      return;
    }

    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const windowStage = AppStorage.get<window.WindowStage>('windowStage');
      
      if (!windowStage) {
        console.error('WindowStage not found in AppStorage');
        this.isSubtitleOpen = false;
        this.persistApiConfigSnapshot();
        promptAction.showToast({ message: '无法获取窗口环境' });
        return;
      }

      // Check AppStorage first
      const storedWin = AppStorage.get<window.Window>('voot_subtitle_win');
      this.subtitleWin = storedWin ? storedWin : null;
      if (this.subtitleWin) {
         this.isSubtitleOpen = true;
         return;
      }

      // Check if window already exists to avoid 130002
      try {
        this.subtitleWin = await window.findWindow('voot_subtitle');
        if (this.subtitleWin) {
           AppStorage.setOrCreate('voot_subtitle_win', this.subtitleWin);
           await this.subtitleWin.showWindow();
           this.isSubtitleOpen = true;
           return;
        }
      } catch (e) {
        // Not found, proceed to create
      }

      try {
        // Try creating a system float window first (requires permission)
        const config: window.Configuration = {
          name: 'voot_subtitle',
          windowType: window.WindowType.TYPE_FLOAT,
          ctx: ctx
        };
        this.subtitleWin = await window.createWindow(config);
      } catch (createErr) {
        console.warn('Failed to create TYPE_FLOAT window, falling back to subwindow: ' + JSON.stringify(createErr));
        // Fallback to subwindow
        try {
           this.subtitleWin = await windowStage.createSubWindow('voot_subtitle');
        } catch (subErr) {
           console.error('createSubWindow failed: ' + JSON.stringify(subErr));
           // Last ditch effort: try findWindow again
           try {
              this.subtitleWin = await window.findWindow('voot_subtitle');
           } catch (findErr) {
              throw new Error('Failed to create or find subtitle window: ' + JSON.stringify(subErr));
           }
        }
      }

      if (this.subtitleWin) {
        AppStorage.setOrCreate('voot_subtitle_win', this.subtitleWin);
        // Load content FIRST to avoid "uiContent is null" error
        await this.subtitleWin.loadContent('pages/SubtitlePage');
        await this.subtitleWin.setWindowBackgroundColor('#00000000'); // Transparent
        
        // Set width to full screen, height to ~80vp (around 240px on xxhdpi)
        // Get main window to determine screen width
        try {
          const windowStage = AppStorage.get<window.WindowStage>('windowStage');
          if (windowStage) {
            const mainWin = windowStage.getMainWindowSync();
            const mainRect = mainWin.getWindowProperties().windowRect;
            const screenWidth = mainRect.width;
            const screenHeight = mainRect.height;
            const subtitleHeight = this.subtitleHeight; // Use state
            await this.subtitleWin.resize(screenWidth, subtitleHeight);
            // Position near bottom of screen (leave some margin)
            const defaultY = screenHeight - subtitleHeight - 200;
            await this.subtitleWin.moveWindowTo(0, defaultY);
          }
        } catch (resizeErr) {
          console.warn('Failed to resize window: ' + JSON.stringify(resizeErr));
        }
        
        await this.subtitleWin.setWindowTouchable(true); // Allow touch for dragging
        await this.subtitleWin.setWindowFocusable(false); // Don't steal focus
        await this.subtitleWin.showWindow();
        this.isSubtitleOpen = true;
        this.persistApiConfigSnapshot();
        promptAction.showToast({ message: '字幕已开启' });
      }
    } catch (e) {
      console.error('Failed to create subtitle window: ' + JSON.stringify(e));
      this.isSubtitleOpen = false;
      this.persistApiConfigSnapshot();
      promptAction.showToast({ message: '开启字幕失败: ' + JSON.stringify(e) });
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
    this.selectedApiIndex = snapshot.selectedApiIndex;
    this.selectedLanguageIndex = snapshot.selectedLanguageIndex;
    this.intervalIndex = snapshot.intervalIndex;
    this.contextsIndex = snapshot.contextsIndex;
    this.isSubtitleOpen = snapshot.isSubtitleOpen;
    this.subtitleFontSize = snapshot.subtitleFontSize;
    this.subtitleFontColor = snapshot.subtitleFontColor;
    this.subtitleBackgroundColor = snapshot.subtitleBackgroundColor;
    this.subtitleBackgroundOpacity = snapshot.subtitleBackgroundOpacity;
    this.subtitleHeight = snapshot.subtitleHeight !== undefined ? snapshot.subtitleHeight : 240;

    // Sync to AppStorage for SubtitlePage
    AppStorage.setOrCreate('subtitleFontSize', this.subtitleFontSize);
    AppStorage.setOrCreate('subtitleFontColor', this.subtitleFontColor);
    AppStorage.setOrCreate('subtitleBackgroundColor', this.subtitleBackgroundColor);
    AppStorage.setOrCreate('subtitleBackgroundOpacity', this.subtitleBackgroundOpacity);
    
    if (this.isSubtitleOpen) {
      // Restore subtitle window if it was open
      setTimeout(() => {
        this.toggleSubtitleWindow(true);
      }, 1000);
    }
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
      doubaoModel: this.doubaoModel,
      selectedApiIndex: this.selectedApiIndex,
      selectedLanguageIndex: this.selectedLanguageIndex,
      intervalIndex: this.intervalIndex,
      contextsIndex: this.contextsIndex,
      isSubtitleOpen: this.isSubtitleOpen,
      subtitleFontSize: this.subtitleFontSize,
      subtitleFontColor: this.subtitleFontColor,
      subtitleBackgroundColor: this.subtitleBackgroundColor,
      subtitleBackgroundOpacity: this.subtitleBackgroundOpacity,
      subtitleHeight: this.subtitleHeight
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
        .margin({ bottom: 12 })

        Text('试着点击上面的卡片，感受HarmonyOS为您带来的的光！')
          .fontSize(12)
          .fontColor(Color.Gray)
          .margin({ bottom: 12 });
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
                intervalOptions: this.intervalOptions,
                selectedIntervalIndex: this.intervalIndex,
                contextsOptions: this.contextsOptions,
                selectedContextsIndex: this.contextsIndex,
                onCycleApi: () => {
                  this.selectedApiIndex = (this.selectedApiIndex + 1) % this.apiOptions.length;
                  this.persistApiConfigSnapshot();
                },
                onCycleLanguage: () => {
                  this.selectedLanguageIndex =
                    (this.selectedLanguageIndex + 1) % this.languageOptions.length;
                  this.persistApiConfigSnapshot();
                },
                onOpenApiSettings: () => {
                  this.showApiSettings = true;
                  this.selectedMenu = this.mapApiIndexToMenu(this.selectedApiIndex);
                },
                onSelectInterval: (index: number) => {
                  this.intervalIndex = index;
                  this.persistApiConfigSnapshot();
                },
                onSelectContexts: (index: number) => {
                  this.contextsIndex = index;
                  this.persistApiConfigSnapshot();
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
            SettingsPage({
              isSubtitleOpen: this.isSubtitleOpen,
              isRealtimeReadingEnabled: this.isRealtimeReadingEnabled,
              subtitleFontSize: $subtitleFontSize,
              subtitleFontColor: $subtitleFontColor,
              subtitleBackgroundColor: $subtitleBackgroundColor,
              subtitleBackgroundOpacity: $subtitleBackgroundOpacity,
              subtitleHeight: $subtitleHeight,
              onToggleSubtitle: () => this.toggleSubtitleWindow(),
              onToggleRealtimeReading: () => {
                this.isRealtimeReadingEnabled = !this.isRealtimeReadingEnabled;
                if (!this.isRealtimeReadingEnabled) {
                  TextReader.stop();
                }
              },
              onStyleChange: () => {
                this.persistApiConfigSnapshot();
                AppStorage.setOrCreate('subtitleFontSize', this.subtitleFontSize);
                AppStorage.setOrCreate('subtitleFontColor', this.subtitleFontColor);
                AppStorage.setOrCreate('subtitleBackgroundColor', this.subtitleBackgroundColor);
                AppStorage.setOrCreate('subtitleBackgroundOpacity', this.subtitleBackgroundOpacity);
                
                // Resize window if open
                if (this.isSubtitleOpen && this.subtitleWin) {
                  try {
                    const windowStage = AppStorage.get<window.WindowStage>('windowStage');
                    if (windowStage) {
                      const mainWin = windowStage.getMainWindowSync();
                      const mainRect = mainWin.getWindowProperties().windowRect;
                      const screenWidth = mainRect.width;
                      this.subtitleWin.resize(screenWidth, this.subtitleHeight);
                    }
                  } catch (e) {
                    console.error('Failed to resize subtitle window: ' + JSON.stringify(e));
                  }
                }
              }
            });
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
        },
        getContext(this) as common.UIAbilityContext
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
    
    const numContexts: number = parseInt(this.contextsOptions[this.contextsIndex]);
    // Only include recent context (trimmed) for faster processing
    const recentContexts: string[] = this.contextHistory.slice(-numContexts);
    const contextPart: string = recentContexts.length > 0 
      ? `Prior context: ${recentContexts.map(c => c.substring(0, 80)).join(' | ')}. ` 
      : '';
    const wrappedSource: string = contextPart + '[' + trimmedSource + ']';
    
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
    AppStorage.setOrCreate('voot_translated_text', this.translatedDemoText);

    if (this.isRealtimeReadingEnabled && this.translatedDemoText) {
      const intervalSeconds = parseInt(this.intervalOptions[this.intervalIndex]);
      const intervalMs = intervalSeconds * 1000;
      const now = Date.now();

      if (now - this.lastTtsPlayTime >= intervalMs) {
        const readInfoList: TextReader.ReadInfo[] = [{
          id: now.toString(),
          title: { text: '同声传译中...', isClickable: false },
          bodyInfo: this.translatedDemoText
        }];
        TextReader.start(readInfoList);
        this.lastTtsPlayTime = now;
      }
    }
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

    // Single message with combined prompt for faster response
    const messages: ChatMessage[] = [
      { role: 'user', content: systemPrompt }
    ];

    const body: string = JSON.stringify({
      model: this.openAiModel,
      messages: messages,
      max_tokens: 256, // Limit output for speed
      temperature: 0.3 // Lower temp for consistent, fast output
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

    // Single message for faster processing
    const messages: ChatMessage[] = [
      { role: 'user', content: systemPrompt }
    ];

    const options: OllamaChatOptions = {
      num_predict: 256,
      temperature: 0.3
    };

    const body: string = JSON.stringify({
      model: this.ollamaModel,
      messages: messages,
      stream: false,
      options: options
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

    // Single message for faster response
    const messages: ChatMessage[] = [
      { role: 'user', content: systemPrompt }
    ];

    const body: string = JSON.stringify({
      model: this.doubaoModel,
      max_tokens: 100, // Further reduced for real-time translation
      messages: messages,
      temperature: 0.0, // Zero temperature for fastest, deterministic output
      stream: false
    });

    try {
      const response: http.HttpResponse = await httpRequest.request(this.doubaoApiUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + this.doubaoApiKey
        },
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000, // 8s connection timeout
        readTimeout: 20000 // 20s read timeout
      });

      const responseCode: number = response.responseCode;
      const resultStr: string = response.result as string;

      if (responseCode !== 200) {
        console.error(`Doubao HTTP error: ${responseCode}, body: ${resultStr}`);
        this.updateTranslationField(`[Doubao错误: HTTP ${responseCode}]`);
        httpRequest.destroy();
        return;
      }

      let translated: string = '';
      const parsed = JSON.parse(resultStr) as DoubaoChatResponse;
      if (parsed.choices && parsed.choices.length > 0) {
        translated = parsed.choices[0].message.content;
      } else {
        console.warn('Doubao response has no choices: ' + resultStr);
        translated = '[Doubao: 响应为空]';
      }

      this.updateTranslationField(translated);
    } catch (e) {
      const errMsg = JSON.stringify(e);
      console.error('translateWithDoubao error: ' + errMsg);
      // Show more specific error to help debugging
      if (errMsg.includes('timeout') || errMsg.includes('Timeout')) {
        this.updateTranslationField('[Doubao: 请求超时]');
      } else if (errMsg.includes('network') || errMsg.includes('Network')) {
        this.updateTranslationField('[Doubao: 网络错误]');
      } else {
        this.updateTranslationField('[Doubao: ' + errMsg.substring(0, 50) + ']');
      }
    } finally {
      httpRequest.destroy();
    }
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

    // 1) Show immediate feedback
    this.isListening = true;
    this.originalDemoText = this.trimRealtimeBuffer('[正在启动语音识别…]');
    this.lastTranslatedText = ''; // Reset to allow first translation

    // 2) Try real mic + sherpa-onnx (Whisper)
    if (!this.isAsrReady || !this.micService) {
      await this.initSherpaAsr();
    }
    if (!this.micService || !this.isAsrReady) {
      this.updateTranslationField('[Mic/ASR not ready – showing stub only]');
      this.isListening = false;
      return;
    }

    // 3) Configure ASR decode timing based on user settings
    // Shorter intervals = faster updates, more CPU
    const intervalSeconds: number = parseInt(this.intervalOptions[this.intervalIndex]);
    const numContexts: number = parseInt(this.contextsOptions[this.contextsIndex]);
    // Fast decode: 500-800ms based on interval setting
    const decodeIntervalMs: number = Math.max(500, Math.min(800, intervalSeconds * 300));
    // Smaller window for faster response: 2-5 seconds
    const windowSeconds: number = Math.min(2 + numContexts, 5);
    this.micService.setDecodeParams(decodeIntervalMs, windowSeconds);

    const onResult: AsrResultCallback = (res: AsrResult): void => {
      // Get processed ASR text
      const displayText: string = this.getShortSegmentFromAsr(res.text);
      
      // Update display if we have meaningful new content
      if (displayText.length > 0 && displayText !== this.lastDisplayedText) {
        this.lastDisplayedText = displayText;
        this.originalDemoText = displayText;
        // Trigger translation
        this.scheduleRealtimeTranslation();
      }

      // On final result (after STOP)
      if (res.isFinal) {
        if (this.translationDebounceId !== undefined) {
          clearTimeout(this.translationDebounceId);
          this.translationDebounceId = undefined;
        }
        // Save to context history (truncated)
        const historyEntry = res.text.length > 100 ? res.text.substring(res.text.length - 100) : res.text;
        this.contextHistory.push(historyEntry);
        if (this.contextHistory.length > 10) {
          this.contextHistory.shift();
        }
        // Clear state for fresh start
        this.lastAsrText = '';
        this.lastDisplayedText = '';
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
    this.lastTranslatedText = ''; // Reset for next session
    this.lastDisplayedText = ''; // Reset display tracking

    // Cancel pending debounce and do final translation
    if (this.translationDebounceId !== undefined) {
      clearTimeout(this.translationDebounceId);
      this.translationDebounceId = undefined;
    }
    if (this.originalDemoText && this.originalDemoText.length > 0) {
      this.translateCurrentDemo();
    }
  }

}
