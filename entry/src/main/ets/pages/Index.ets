/**
 * @fileoverview This file contains code related to AI content generation.
 * @compliance EU AI Act, US EO 14110, China Interim Measures for Generative AI Services
 * @metadata {
 *   "Label": "AI_Generated_Content",
 *   "ContentProducer": "Voot_App",
 *   "ProduceID": "VOOT_GEN_001",
 *   "ReservedCode1": "RESERVED",
 *   "ContentPropagator": "Voot_App",
 *   "PropagateID": "VOOT_PROP_001",
 *   "ReservedCode2": "RESERVED"
 * }
 */
import http from '@ohos.net.http';
import { TextReader } from '@kit.SpeechKit';
import { SherpaWhisperMicService, AsrResult, AsrResultCallback, AsrErrorCallback } from '../services/SherpaWhisperMicService';
import abilityAccessCtrl, { Permissions, PermissionRequestResult } from '@ohos.abilityAccessCtrl';
import type { BusinessError } from '@ohos.base';
import common from '@ohos.app.ability.common';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import Want from '@ohos.app.ability.Want';
import wantConstant from '@ohos.app.ability.wantConstant';
import { hdsEffect, HdsTabs, HdsTabsAttribute, HdsTabsController, DividerMode } from '@kit.UIDesignKit';
import { ConfigurationPage } from './ConfigurationPage';
import { TranslationPage } from './TranslationPage';
import { HistoryTabPage } from './HistoryTabPage';
import { SettingsPage } from './SettingsPage';
import { ApiConfigPage, ApiMenuType } from './ApiConfigPage';
import App from '@system.app';
import { ApiConfigStorage, ApiConfigSnapshot, MultiKeySlots, createDefaultMultiKeySlots, MAX_KEY_SLOTS } from '../storage/ApiConfigStorage';
import { TokenUsageStorage } from '../storage/TokenUsageStorage';
import { HistoryStorage } from '../storage/HistoryStorage';
import window from '@ohos.window';
import promptAction from '@ohos.promptAction';
import { PipSubtitleManager, SubtitleParams } from '../services/PipSubtitleManager';
import { PiPWindow } from '@kit.ArkUI';
import { ContinuityService, ContinuityState, CONTINUITY_KEY, DeviceInfo, SubtitleStyleConfig } from '../services/ContinuityService';
import { deviceInfo } from '@kit.BasicServicesKit';

// 扩展流转状态（包含翻译状态和当前Tab）
interface ContinuityStateExtended extends ContinuityState {
  isTranslating?: boolean;
  currentTab?: number;
  // 实时朗读状态
  isRealtimeReading?: boolean;
  // PiP 悬浮窗状态
  isPipEnabled?: boolean;
  // 字幕样式配置
  subtitleConfig?: SubtitleStyleConfig;
}

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
  finish_reason?: string;
}

interface ChatCompletionTokensDetails {
  reasoning_tokens?: number;
}

interface ChatCompletionUsage {
  total_tokens: number;
  completion_tokens_details?: ChatCompletionTokensDetails;
}

interface ChatCompletionResponse {
  choices: ChatCompletionChoice[];
  usage?: ChatCompletionUsage;
}

// OpenAI Responses API
interface OpenAIResponsesContentItem {
  type?: string;
  text?: string;
}

interface OpenAIResponsesOutputItem {
  content?: OpenAIResponsesContentItem[];
}

interface OpenAIResponsesUsage {
  total_tokens?: number;
}

interface OpenAIResponsesResponse {
  output_text?: string;
  output?: OpenAIResponsesOutputItem[];
  usage?: OpenAIResponsesUsage;
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
  eval_count?: number;
  prompt_eval_count?: number;
}

// Doubao chat
interface DoubaoChatMessage {
  role: string;
  content: string;
}

interface DoubaoChatChoice {
  message: DoubaoChatMessage;
}

interface DoubaoUsage {
  total_tokens: number;
}

interface DoubaoChatResponse {
  choices: DoubaoChatChoice[];
  usage?: DoubaoUsage;
}

// 功能特性（用于 FeatureDialog）
interface WelcomeFeature {
  title: string;
  description: string;
  icon: Resource;
  span: number;
}

const WELCOME_FEATURES: Array<WelcomeFeature> = [
  {
    title: '自由配置',
    description: '随心切换翻译引擎与字幕样式，匹配不同的交流场景。',
    icon: $r('app.media.configuration'),
    span: 2
  },
  {
    title: '多场景适配',
    description: '会议、听障辅助、跨语对话皆可使用，实时沟通更轻松。',
    icon: $r('app.media.translation'),
    span: 2
  },
  {
    title: '隐私守护',
    description: 'API 密钥与语音只在本地处理，不会上传到云端。',
    icon: $r('app.media.privacy'),
    span: 1
  },
  {
    title: '历史记录',
    description: '本地存储对话历史，随时回顾重要信息。',
    icon: $r('app.media.history'),
    span: 1
  },
  {
    title: '悬浮窗',
    description: '支持画中画模式，在其他应用上层显示字幕。',
    icon: $r('app.media.pip'),
    span: 2
  },
  {
    title: '设备流转',
    description: '手机、平板间翻译无缝流转。',
    icon: $r('app.media.share'),
    span: 2
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

  // Continuity
  @State showDeviceDialog: boolean = false;
  @State deviceList: DeviceInfo[] = [];
  @State selectedApiIndex: number = 0;

  @State intervalOptions: string[] = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];
  @State intervalIndex: number = 4;

  @State contextsOptions: string[] = ['1', '2', '3', '4', '5', '6'];
  @State contextsIndex: number = 2;

  @State temperatureOptions: string[] = ['0.0', '0.1', '0.2', '0.3', '0.4', '0.5', '0.6', '0.7', '0.8', '0.9', '1.0', '1.1', '1.2', '1.3', '1.4', '1.5', '1.6', '1.7', '1.8', '1.9', '2.0'];
  @State temperatureIndex: number = 3; // Default 0.3

  @State maxTokensOptions: string[] = ['64', '100', '128', '256', '512', '1024'];

  private hasShownReasoningModelHint: boolean = false;
  @State maxTokensIndex: number = 3; // Default 256

  @State vadSensitivityOptions: string[] = ['低', '中', '高'];
  @State selectedVadSensitivityIndex: number = 1; // Default Medium

  @State minMatchLenOptions: string[] = ['3', '5', '7', '10'];
  @State selectedMinMatchLenIndex: number = 1; // Default 5

  @State languageOptions: string[] = ['Chinese', 'English', 'Spanish', 'French', 'Japanese'];
  @State languageDisplayOptions: string[] = ['中文', '英语', '西班牙语', '法语', '日语'];
  @State selectedLanguageIndex: number = 0;

  // API Settings subpage state
  @State selectedMenu: ApiMenuType = ApiMenuType.Prompt;

  // 多密钥槽位配置
  @State openAiKeySlots: MultiKeySlots = createDefaultMultiKeySlots(
    'https://api.openai.com/v1/chat/completions', '', 'gpt-4o-mini'
  );
  @State deepLKeySlots: MultiKeySlots = createDefaultMultiKeySlots(
    'https://api-free.deepl.com/v2/translate', '', ''
  );
  @State ollamaKeySlots: MultiKeySlots = createDefaultMultiKeySlots(
    'http://localhost:11434/api/chat', '', ''
  );
  @State doubaoKeySlots: MultiKeySlots = createDefaultMultiKeySlots(
    'https://ark.cn-beijing.volces.com/api/v3/chat/completions', '', 'ep-20251221220646-rnx4c'
  );

  // DeepL config (兼容字段，从当前槽位同步)
  @State deepLApiUrl: string = 'https://api-free.deepl.com/v2/translate';
  @State deepLApiKey: string = '';

  // OpenAI config (兼容字段，从当前槽位同步)
  @State openAiApiUrl: string = 'https://api.openai.com/v1/chat/completions';
  @State openAiApiKey: string = '';
  @State openAiModel: string = 'gpt-4o-mini';

  // Ollama config (兼容字段，从当前槽位同步)
  @State ollamaApiUrl: string = 'http://localhost:11434/api/chat';
  @State ollamaModel: string = '';

  // Doubao config (兼容字段，从当前槽位同步)
  @State doubaoApiUrl: string = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
  @State doubaoApiKey: string = '';
  @State doubaoModel: string = 'ep-20251221220646-rnx4c';

  // Glossary
  @State glossary: string = 'HarmonyOS = 鸿蒙';

  // Subtitle Style Config
  @State subtitleFontSize: number = 20;
  @State subtitleFontColor: string = '#FFFFFF';
  @State subtitleBackgroundColor: string = '#3c1464';

  @State subtitleHeight: number = 20;

  // Prompt template (used in LLM system message)
  @State promptText: string =
    'Act as an elite simultaneous interpreter who only hears imperfect microphone pickups. ' +
      'You receive roughly five-second snippets of speech, so rely on the snippet enclosed in [abc] and reasonably infer missing words while staying faithful to the speaker. ' +
      'Translate that snippet into {0} in a single fluent line, preserving intent and tone even when the audio is noisy. No matter how, you must output the translation directly.';

  // Demo translation text for Appearance page
  @State originalDemoText: string = '';
  @State translatedDemoText: string = '';
  @State isTranslating: boolean = false;

  // Feature dialog（保留用于配置页面中的帮助）
  @State currentFeatureIndex: number = 0;
  featureDialogController: CustomDialogController = new CustomDialogController({
    builder: FeatureDialog({ index: $currentFeatureIndex }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  // Global light effect brightness: true = BRIGHT, false = SOFT
  @State isLightEffectBright: boolean = true;
  // Theme mode: 0 = Light, 1 = Dark, 2 = Follow System
  @State themeMode: number = 2; // 默认跟随系统
  // Computed dark mode for compatibility with child components
  @State isDarkMode: boolean = true;
  
  @StorageProp('currentColorMode') @Watch('onColorModeChange') currentMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;

  onColorModeChange() {
    // 只有在跟随系统模式下才响应系统主题变化
    if (this.themeMode === 2) {
      if (this.currentMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
        this.isDarkMode = true;
      } else if (this.currentMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
        this.isDarkMode = false;
      }
    }
  }
  
  // 更新主题模式并计算 isDarkMode
  updateThemeMode(mode: number) {
    this.themeMode = mode;
    if (mode === 0) {
      // 浅色模式
      this.isDarkMode = false;
    } else if (mode === 1) {
      // 深色模式
      this.isDarkMode = true;
    } else {
      // 跟随系统
      if (this.currentMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
        this.isDarkMode = true;
      } else {
        this.isDarkMode = false;
      }
    }
    // 持久化主题设置
    this.persistApiConfigSnapshot();
  }

  // Subtitle Window State
  @State isRealtimeReadingEnabled: boolean = false;

  // PiP Subtitle State
  @State isPipSubtitleEnabled: boolean = false;
  @State isPipActive: boolean = false;
  private pipSubtitleManager: PipSubtitleManager = PipSubtitleManager.getInstance();
  private isPipInitialized: boolean = false;

  // Widget trigger states
  @StorageProp('widgetPipToggle') @Watch('onWidgetPipToggle') widgetPipToggle: number = 0;
  @StorageProp('widgetRealtimeReadingToggle') @Watch('onWidgetReadingToggle') widgetReadingToggle: number = 0;
  private lastWidgetPipToggle: number = 0;
  private lastWidgetReadingToggle: number = 0;
  private isComponentReady: boolean = false;

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
  private hasStartedMainExperience: boolean = false;

  // Mic captioning / ASR state
  @State isListening: boolean = false;
  @State isAsrReady: boolean = false;
  // Sherpa-onnx (Whisper) mic+ASR service
  private micService?: SherpaWhisperMicService;
  private currentSessionId: number = -1;
  // 累积的完整原文（用于保存到历史）
  private fullOriginalText: string = '';
  // 累积的完整译文（用于保存到历史）
  private fullTranslatedText: string = '';
  // 上次保存到数据库的时间戳
  private lastDbSaveTs: number = 0;

  // 跨端流转状态监听
  @StorageProp('voot_continuity_restored') @Watch('onContinuityRestored') continuityRestored: boolean = false;
  private lastContinuityRestoreTs: number = 0;

  /**
   * Widget PiP toggle handler
   */
  onWidgetPipToggle(): void {
    // Ignore if component not ready or if this is the same trigger we already handled
    if (!this.isComponentReady || this.widgetPipToggle === 0 || this.widgetPipToggle === this.lastWidgetPipToggle) {
      return;
    }
    this.lastWidgetPipToggle = this.widgetPipToggle;
    console.info('[Index] onWidgetPipToggle triggered');
    this.togglePipSubtitle();
  }

  /**
   * Widget Reading toggle handler
   */
  onWidgetReadingToggle(): void {
    // Ignore if component not ready or if this is the same trigger we already handled
    if (!this.isComponentReady || this.widgetReadingToggle === 0 || this.widgetReadingToggle === this.lastWidgetReadingToggle) {
      return;
    }
    this.lastWidgetReadingToggle = this.widgetReadingToggle;
    console.info('[Index] onWidgetReadingToggle triggered, current state: ' + this.isRealtimeReadingEnabled);
    this.isRealtimeReadingEnabled = !this.isRealtimeReadingEnabled;
    if (!this.isRealtimeReadingEnabled) {
      TextReader.stop();
    }
    console.info('[Index] onWidgetReadingToggle new state: ' + this.isRealtimeReadingEnabled);
  }

  /**
   * 跨端流转状态恢复回调（@Watch 触发）
   */
  onContinuityRestored(): void {
    // 避免重复处理
    const now = Date.now();
    if (!this.continuityRestored || now - this.lastContinuityRestoreTs < 1000) {
      return;
    }
    this.lastContinuityRestoreTs = now;
    console.info('[Index] onContinuityRestored triggered via @Watch');

    const stateJson = AppStorage.get<string>('voot_continuity_state');
    if (!stateJson) {
      console.info('[Index] No continuity state to restore');
      return;
    }

    // 使用统一的恢复方法
    this.restoreContinuityStateDirectly(stateJson);
  }

  /**
   * 直接恢复流转状态（用于 aboutToAppear 和 onContinuityRestored）
   */
  private restoreContinuityStateDirectly(stateJson: string): void {
    try {
      const state = JSON.parse(stateJson) as ContinuityStateExtended;
      console.info('[Index] restoreContinuityStateDirectly: ' +
        'isListening=' + state.isListening +
        ', currentTab=' + state.currentTab +
        ', originalTextLen=' + state.originalText.length);

      // 恢复显示文本（仅用于展示，不影响后续录音）
      this.originalDemoText = state.originalText;
      this.translatedDemoText = state.translatedText;
      this.fullOriginalText = state.fullOriginalText;
      this.fullTranslatedText = state.fullTranslatedText;
      this.currentSessionId = state.sessionId;
      
      // 重要：不恢复 isTranslating 和 isListening 状态！
      // 目标设备需要从干净状态开始，避免卡住
      this.isTranslating = false;
      this.isListening = false;
      this.pendingTranslationText = ''; // 清空待翻译文本

      // 恢复 API 配置
      if (state.apiConfig && state.apiConfig !== '{}') {
        try {
          const apiConfig: ApiConfigSnapshot = JSON.parse(state.apiConfig) as ApiConfigSnapshot;
          this.applyApiConfigSnapshot(apiConfig);
        } catch (e) {
          console.error('[Index] Failed to restore API config: ' + JSON.stringify(e));
        }
      }

      // 恢复字幕样式配置
      if (state.subtitleConfig) {
        this.subtitleFontSize = state.subtitleConfig.fontSize;
        this.subtitleFontColor = state.subtitleConfig.fontColor;
        this.subtitleBackgroundColor = state.subtitleConfig.backgroundColor;
        this.subtitleHeight = state.subtitleConfig.height;
      }

      // 恢复实时朗读状态
      if (state.isRealtimeReading) {
        this.isRealtimeReadingEnabled = true;
      }

      // 切换到翻译页（索引 1），确保流转后直接展示字幕/翻译状态
      const targetTab = state.currentTab !== undefined && state.currentTab >= 1 ? state.currentTab : 1;
      this.currentTab = targetTab;
      // 延迟切换 Tab，确保 HdsTabs 渲染完成
      setTimeout(() => {
        this.switchToTab(targetTab);
        console.info('[Index] Tab switched to: ' + targetTab);
      }, 100);
      setTimeout(() => {
        this.switchToTab(targetTab);
      }, 300);

      // 恢复 PiP 悬浮窗状态
      if (state.isPipEnabled || state.originalText.length > 0 || state.translatedText.length > 0) {
        setTimeout(() => {
          if (!this.isPipSubtitleEnabled) {
            this.togglePipSubtitle(true);
          }
        }, 1000);
      }

      // 处理录音状态
      if (state.isListening) {
        this.showContinueRecordingDialog();
      } else {
        promptAction.showToast({
          message: '已从其他设备接续字幕和翻译',
          duration: 2000
        });
      }

      // 清除恢复标记
      AppStorage.setOrCreate('voot_continuity_restored', false);
      AppStorage.setOrCreate('voot_continuity_state', '');

    } catch (err) {
      console.error('[Index] restoreContinuityStateDirectly error: ' + JSON.stringify(err));
    }
  }

  /**
   * 显示继续录音确认对话框
   */
  private showContinueRecordingDialog(): void {
    promptAction.showDialog({
      title: '接续传译',
      message: '检测到源设备正在进行语音识别，是否在本设备继续录音？',
      buttons: [
        { text: '仅查看字幕', color: '#666666' },
        { text: '继续录音', color: '#3c1464' }
      ]
    }).then((result) => {
      if (result.index === 1) {
        // 用户选择继续录音
        this.startMicCaptioning();
        promptAction.showToast({
          message: '已开始录音',
          duration: 2000
        });
      } else {
        // 仅查看字幕，不开始录音
        promptAction.showToast({
          message: '已接续字幕，可随时点击麦克风开始录音',
          duration: 2000
        });
      }
    }).catch((err: BusinessError) => {
      console.error('[Index] showContinueRecordingDialog error: ' + JSON.stringify(err));
      // 对话框失败时默认显示提示
      promptAction.showToast({
        message: '已从其他设备接续字幕',
        duration: 2000
      });
    });
  }

  // 封装 tab 切换，兼容不同控制器方法名
  private switchToTab(targetTab: number): void {
    try {
      // HdsTabsController 使用 changeIndex 方法
      this.tabsController.changeIndex(targetTab);
      console.info('[Index] switchToTab via changeIndex: ' + targetTab);
    } catch (e) {
      console.warn('[Index] changeIndex failed, trying fallback: ' + JSON.stringify(e));
      // 备用方式：直接设置 currentTab 状态
      this.currentTab = targetTab;
    }
  }

  /**
   * 同步当前状态到 AppStorage（供流转使用）
   */
  private syncContinuityState(): void {
    AppStorage.setOrCreate('voot_is_listening', this.isListening);
    AppStorage.setOrCreate('voot_is_translating', this.isTranslating);
    AppStorage.setOrCreate('voot_original_text', this.originalDemoText);
    AppStorage.setOrCreate('voot_translated_text', this.translatedDemoText);
    AppStorage.setOrCreate('voot_session_id', this.currentSessionId);
    AppStorage.setOrCreate('voot_full_original_text', this.fullOriginalText);
    AppStorage.setOrCreate('voot_full_translated_text', this.fullTranslatedText);
    AppStorage.setOrCreate('voot_current_tab', this.currentTab);
    AppStorage.setOrCreate('voot_api_config_json', JSON.stringify(this.buildApiConfigSnapshot()));
    // 同步实时朗读和 PiP 状态
    AppStorage.setOrCreate('voot_is_realtime_reading', this.isRealtimeReadingEnabled);
    AppStorage.setOrCreate('voot_is_pip_enabled', this.isPipSubtitleEnabled);
    // 同步字幕样式
    AppStorage.setOrCreate('voot_subtitle_config', JSON.stringify({
      fontSize: this.subtitleFontSize,
      fontColor: this.subtitleFontColor,
      backgroundColor: this.subtitleBackgroundColor,
      height: this.subtitleHeight
    }));
  }

  /**
   * Get translation interval from config (in ms).
   */
  private getTranslationIntervalMs(): number {
    return parseInt(this.intervalOptions[this.intervalIndex]) * 1000;
  }

  private getTemperatureValue(): number {
    return parseFloat(this.temperatureOptions[this.temperatureIndex]);
  }

  private getMaxTokensValue(): number {
    return parseInt(this.maxTokensOptions[this.maxTokensIndex]);
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
    // Initialize theme mode from system setting (跟随系统模式)
    if (this.themeMode === 2) {
      if (this.currentMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
        this.isDarkMode = true;
      } else if (this.currentMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
        this.isDarkMode = false;
      }
    }

    AppStorage.setOrCreate('voot_translated_text', '');

    // 检查是否有待恢复的流转状态（在组件初始化时就检查）
    const pendingContinuity = AppStorage.get<boolean>('voot_continuity_restored');
    const pendingStateJson = AppStorage.get<string>('voot_continuity_state');
    
    // 如果是流转恢复，直接恢复状态
    if (pendingContinuity && pendingStateJson) {
      console.info('[Index] Continuity restore detected');
      this.hasStartedMainExperience = true;
      // 延迟执行恢复，确保组件完全渲染
      setTimeout(() => {
        this.restoreContinuityStateDirectly(pendingStateJson);
      }, 300);
      // 同时初始化必要服务
      this.requestMicPermission();
      this.initSherpaAsr();
    } else {
      // 正常启动，直接初始化主体验
      this.startMainExperience();
    }

    // 设置应用为可迁移状态（官方接续指导）
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      ctx.setMissionContinueState(AbilityConstant.ContinueState.ACTIVE, (result) => {
        console.info('[Index] setMissionContinueState ACTIVE result: ' + JSON.stringify(result));
      });
    } catch (e) {
      console.error('[Index] setMissionContinueState failed: ' + JSON.stringify(e));
    }

    // Mark component as ready after a short delay to avoid initial @Watch triggers
    setTimeout(() => {
      this.isComponentReady = true;
      // Initialize last toggle values to current values to avoid false triggers
      this.lastWidgetPipToggle = this.widgetPipToggle;
      this.lastWidgetReadingToggle = this.widgetReadingToggle;
      console.info('[Index] Component ready, widget triggers enabled');
    }, 500);

    // Initialize TextReader
    try {
      let context = getContext(this) as common.UIAbilityContext;
      const readerParams: TextReader.ReaderParam = {
        isVoiceBrandVisible: true,
        businessBrandInfo: {
          panelName: 'Voot 传译器',
          panelIcon: $r('app.media.startIcon')
        }
      };
      await TextReader.init(context, readerParams);

      // Initialize TokenUsageStorage
      await TokenUsageStorage.getInstance().init(context);
      // Initialize HistoryStorage
      await HistoryStorage.getInstance().init(context);
    } catch (e) {
      console.error(`Init failed: ${JSON.stringify(e)}`);
    }

    // Listen for widget button triggers
    // Widget triggers are handled via @StorageProp with @Watch in state declarations
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

  /**
   * Initialize PiP
   */
  private async initPipSubtitle(): Promise<boolean> {
    if (this.isPipInitialized) {
      return true;
    }

    // Check PiP
    if (!this.pipSubtitleManager.isPipEnabled()) {
      console.warn('[PiP] Picture-in-Picture is not available on this device');
      return false;
    }

    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const uiContext = this.getUIContext();

      // Convert subtitle height (10-30) to pixel value (100-300)
      const success = await this.pipSubtitleManager.init(ctx, uiContext, this.subtitleHeight * 10);
      if (success) {
        this.isPipInitialized = true;

        this.pipSubtitleManager.registerLifecycleCallback((state: PiPWindow.PiPState) => {
          if (state === PiPWindow.PiPState.STARTED) {
            this.isPipActive = true;
          } else if (state === PiPWindow.PiPState.STOPPED || state === PiPWindow.PiPState.ERROR) {
            this.isPipActive = false;
            // Sync toggle state when PiP is closed externally (e.g. via system UI)
            if (this.isPipSubtitleEnabled) {
              this.isPipSubtitleEnabled = false;
              this.persistApiConfigSnapshot();
            }
          }
        });

        // Sync Subtitle style
        this.pipSubtitleManager.updateStyle({
          fontSize: this.subtitleFontSize,
          fontColor: this.subtitleFontColor,
          backgroundColor: this.subtitleBackgroundColor
        });

        console.info('[PiP] PiP subtitle initialized successfully');
      }
      return success;
    } catch (e) {
      console.error('[PiP] initPipSubtitle error: ' + JSON.stringify(e));
      return false;
    }
  }

  private async togglePipSubtitle(forceOpen?: boolean): Promise<void> {
    const shouldOpen = forceOpen !== undefined ? forceOpen : !this.isPipSubtitleEnabled;

    if (!shouldOpen) {
      // Stop PiP
      await this.pipSubtitleManager.stopPip();
      this.isPipSubtitleEnabled = false;
      this.isPipActive = false;
      this.persistApiConfigSnapshot();
      promptAction.showToast({ message: '字幕已关闭' });
      return;
    }

    // Initialize PiP
    if (!this.isPipInitialized) {
      const success = await this.initPipSubtitle();
      if (!success) {
        promptAction.showToast({ message: 'PiP 不可用，请尝试传统字幕模式' });
        return;
      }
    }

    // Start PiP
    const started = await this.pipSubtitleManager.startPip();
    if (started) {
      this.isPipSubtitleEnabled = true;
      this.isPipActive = true; // Label ACTIVE
      // Syn Translation Text
      if (this.translatedDemoText) {
        this.pipSubtitleManager.updateSubtitle(this.translatedDemoText);
      }
      this.persistApiConfigSnapshot();
      promptAction.showToast({ message: '字幕已开启' });
    } else {
      promptAction.showToast({ message: '字幕启动失败' });
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
    
    // 应用多密钥槽位配置
    if (snapshot.openAiKeySlots && snapshot.openAiKeySlots.slots.length > 0) {
      this.openAiKeySlots = snapshot.openAiKeySlots;
    }
    if (snapshot.deepLKeySlots && snapshot.deepLKeySlots.slots.length > 0) {
      this.deepLKeySlots = snapshot.deepLKeySlots;
    }
    if (snapshot.ollamaKeySlots && snapshot.ollamaKeySlots.slots.length > 0) {
      this.ollamaKeySlots = snapshot.ollamaKeySlots;
    }
    if (snapshot.doubaoKeySlots && snapshot.doubaoKeySlots.slots.length > 0) {
      this.doubaoKeySlots = snapshot.doubaoKeySlots;
    }
    
    // 同步兼容字段（从当前槽位）
    this.syncCurrentSlotToCompatFields();
    
    this.selectedApiIndex = snapshot.selectedApiIndex;
    this.selectedLanguageIndex = snapshot.selectedLanguageIndex;
    this.intervalIndex = snapshot.intervalIndex;
    this.contextsIndex = snapshot.contextsIndex;
    this.temperatureIndex = snapshot.temperatureIndex !== undefined ? snapshot.temperatureIndex : 3; // Default 0.3
    this.maxTokensIndex = snapshot.maxTokensIndex !== undefined ? snapshot.maxTokensIndex : 3; // Default 256
    this.selectedVadSensitivityIndex = snapshot.vadSensitivityIndex !== undefined ? snapshot.vadSensitivityIndex : 1; // Default Medium
    this.selectedMinMatchLenIndex = snapshot.minMatchLenIndex !== undefined ? snapshot.minMatchLenIndex : 1; // Default 5
    this.subtitleFontSize = snapshot.subtitleFontSize;
    this.subtitleFontColor = snapshot.subtitleFontColor;
    this.subtitleBackgroundColor = snapshot.subtitleBackgroundColor;
    this.subtitleHeight = snapshot.subtitleHeight !== undefined ? snapshot.subtitleHeight : 20;
    this.glossary = snapshot.glossary !== undefined ? snapshot.glossary : '';
    
    // 应用主题模式
    if (snapshot.themeMode !== undefined) {
      this.updateThemeMode(snapshot.themeMode);
    }
  }
  
  // 从当前槽位同步兼容字段
  private syncCurrentSlotToCompatFields(): void {
    const openAiSlot = this.openAiKeySlots.slots[this.openAiKeySlots.currentSlotIndex];
    if (openAiSlot) {
      this.openAiApiUrl = openAiSlot.apiUrl;
      this.openAiApiKey = openAiSlot.apiKey;
      this.openAiModel = openAiSlot.model;
    }
    
    const deepLSlot = this.deepLKeySlots.slots[this.deepLKeySlots.currentSlotIndex];
    if (deepLSlot) {
      this.deepLApiUrl = deepLSlot.apiUrl;
      this.deepLApiKey = deepLSlot.apiKey;
    }
    
    const ollamaSlot = this.ollamaKeySlots.slots[this.ollamaKeySlots.currentSlotIndex];
    if (ollamaSlot) {
      this.ollamaApiUrl = ollamaSlot.apiUrl;
      this.ollamaModel = ollamaSlot.model;
    }
    
    const doubaoSlot = this.doubaoKeySlots.slots[this.doubaoKeySlots.currentSlotIndex];
    if (doubaoSlot) {
      this.doubaoApiUrl = doubaoSlot.apiUrl;
      this.doubaoApiKey = doubaoSlot.apiKey;
      this.doubaoModel = doubaoSlot.model;
    }
  }
  
  // 更新当前槽位的指定字段
  private updateCurrentSlot(provider: string, field: string, value: string): void {
    switch (provider) {
      case 'openai': {
        const slots = [...this.openAiKeySlots.slots];
        const idx = this.openAiKeySlots.currentSlotIndex;
        if (slots[idx]) {
          if (field === 'apiUrl') slots[idx].apiUrl = value;
          else if (field === 'apiKey') slots[idx].apiKey = value;
          else if (field === 'model') slots[idx].model = value;
        }
        this.openAiKeySlots = { slots, currentSlotIndex: idx };
        break;
      }
      case 'deepl': {
        const slots = [...this.deepLKeySlots.slots];
        const idx = this.deepLKeySlots.currentSlotIndex;
        if (slots[idx]) {
          if (field === 'apiUrl') slots[idx].apiUrl = value;
          else if (field === 'apiKey') slots[idx].apiKey = value;
        }
        this.deepLKeySlots = { slots, currentSlotIndex: idx };
        break;
      }
      case 'ollama': {
        const slots = [...this.ollamaKeySlots.slots];
        const idx = this.ollamaKeySlots.currentSlotIndex;
        if (slots[idx]) {
          if (field === 'apiUrl') slots[idx].apiUrl = value;
          else if (field === 'model') slots[idx].model = value;
        }
        this.ollamaKeySlots = { slots, currentSlotIndex: idx };
        break;
      }
      case 'doubao': {
        const slots = [...this.doubaoKeySlots.slots];
        const idx = this.doubaoKeySlots.currentSlotIndex;
        if (slots[idx]) {
          if (field === 'apiUrl') slots[idx].apiUrl = value;
          else if (field === 'apiKey') slots[idx].apiKey = value;
          else if (field === 'model') slots[idx].model = value;
        }
        this.doubaoKeySlots = { slots, currentSlotIndex: idx };
        break;
      }
    }
  }

  private buildApiConfigSnapshot(): ApiConfigSnapshot {
    return {
      promptText: this.promptText,
      // 多密钥槽位
      openAiKeySlots: this.openAiKeySlots,
      deepLKeySlots: this.deepLKeySlots,
      ollamaKeySlots: this.ollamaKeySlots,
      doubaoKeySlots: this.doubaoKeySlots,
      // 兼容字段
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
      maxTokensIndex: this.maxTokensIndex,
      temperatureIndex: this.temperatureIndex,
      vadSensitivityIndex: this.selectedVadSensitivityIndex,
      minMatchLenIndex: this.selectedMinMatchLenIndex,
      subtitleFontSize: this.subtitleFontSize,
      subtitleFontColor: this.subtitleFontColor,
      subtitleBackgroundColor: this.subtitleBackgroundColor,
      subtitleHeight: this.subtitleHeight,
      glossary: this.glossary,
      themeMode: this.themeMode
    };
  }

  private buildSubtitleStyleConfig(): SubtitleStyleConfig {
    const config: SubtitleStyleConfig = {
      fontSize: this.subtitleFontSize,
      fontColor: this.subtitleFontColor,
      backgroundColor: this.subtitleBackgroundColor,
      height: this.subtitleHeight
    };
    return config;
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

  // Index 页面不再处理欢迎流程，直接启动主体验
  private startMainExperience(): void {
    if (this.hasStartedMainExperience) {
      return;
    }
    this.hasStartedMainExperience = true;
    this.requestMicPermission();
    this.initSherpaAsr();
    this.hydrateStoredApiConfig();
  }

  private getDeviceTypeLabel(type: number | string): string {
    // Handle string types (from deviceInfo)
    if (typeof type === 'string') {
      const typeUpper = type.toUpperCase();
      switch (typeUpper) {
        case 'PHONE': return '手机';
        case 'TABLET':
        case 'PAD': return '平板';
        case 'WEARABLE':
        case 'WATCH': return '手表';
        case 'TV': return '智慧屏';
        case '2IN1': return '二合一';
        case 'CAR': return '车机';
        case 'PC': return '电脑';
      }
    }
    return '其他设备';
  }

  private getDeviceIcon(type: number | string): Resource {
    let typeStr = '';
    if (typeof type === 'string') {
      typeStr = type.toUpperCase();
    }

    switch (typeStr) {
      case 'PHONE': return $r('sys.symbol.phone_1');
      case 'TABLET': return $r('sys.symbol.unknown_device');
      case 'PAD': return $r('sys.symbol.pad');
      case 'WEARABLE': return $r('sys.symbol.unknown_device');
      case 'WATCH': return $r('sys.symbol.watch');
      case 'TV': return $r('sys.symbol.TV_tv');
      case '2IN1': return $r('sys.symbol.unknown_device');
      case 'PC': return $r('sys.symbol.pc');
      case 'CAR': return $r('sys.symbol.car');
      default: return $r('sys.symbol.bluetooth');
    }
  }

  @Builder
  private DeviceSelectionDialog() {
    Column() {
      Text('选择流转设备')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ bottom: 8, top: 16 })
        .width('100%')
        .textAlign(TextAlign.Center)

      Text('暂仅支持手机与平板流转')
        .fontSize(12)
        .fontColor($r('sys.color.font_on_secondary'))
        .margin({ bottom: 16 })
        .width('100%')
        .textAlign(TextAlign.Center)

      if (this.deviceList.length === 0) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .margin({ bottom: 10 })
          Text('正在搜索设备...')
            .fontSize(14)
            .fontColor($r('sys.color.font_on_secondary'))
        }
        .height(150)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.deviceList, (device: DeviceInfo) => {
            ListItem() {
              Row() {
                SymbolGlyph(this.getDeviceIcon(device.deviceType))
                  .fontSize(24)
                  .fontColor([Color.White])
                  .margin({ right: 16 })

                Column() {
                  Text(device.deviceName)
                    .fontSize(16)
                    .fontColor(Color.White)
                    .fontWeight(FontWeight.Medium)
                  Text(this.getDeviceTypeLabel(device.deviceType))
                    .fontSize(12)
                    .fontColor($r('sys.color.font_on_secondary'))
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)

                Blank()

                Button('流转')
                  .fontSize(14)
                  .height(32)
                  .backgroundColor("#3c1464")
                  .onClick(() => {
                    this.selectDevice(device);
                  })
              }
              .width('100%')
              .padding({ top: 12, bottom: 12, left: 16, right: 16 })
            }
          })
        }
        .constraintSize({ minHeight: 100, maxHeight: 300 })
        .width('100%')
      }

      Button('取消')
        .width('90%')
        .margin({ top: 16, bottom: 16 })
        .backgroundColor("#3c1464")
        .onClick(() => {
          this.showDeviceDialog = false;
          ContinuityService.getInstance().stopDiscovering();
        })
    }
    .width('100%')
    .backgroundColor(Color.Transparent)
    .borderRadius({ topLeft: 16, topRight: 16 })
  }

  build() {
    Stack() {
      Image($r('app.media.app_background_pic'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .blur(20);

      // Overlay gradient
      Rect()
        .width('100%')
        .height('100%')
        .fill(Color.Transparent)
        .linearGradient({
          angle: 180,
          colors: this.isDarkMode
            ? [['#e618052d', 0.0], ['#bf2a1243', 1.0]]
            : [['#4418052d', 0.0], ['#223c1464', 1.0]]
        })
        .animation({ duration: 500, curve: Curve.EaseInOut })

      Column() {
        HdsTabs({ controller: this.tabsController }) {
        TabContent() {
          Column() {
            if (this.showApiSettings) {
              ApiConfigPage({
                selectedMenu: this.selectedMenu,
                promptText: this.promptText,
                // 多密钥槽位
                openAiKeySlots: this.openAiKeySlots,
                deepLKeySlots: this.deepLKeySlots,
                ollamaKeySlots: this.ollamaKeySlots,
                doubaoKeySlots: this.doubaoKeySlots,
                // 兼容字段
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
                glossary: this.glossary,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                onBack: () => {
                  this.currentTab = 0;
                  this.showApiSettings = false;
                },
                onSelectMenu: (menu: ApiMenuType) => this.selectedMenu = menu,
                onUpdatePrompt: (value: string) => {
                  this.promptText = value;
                  this.persistApiConfigSnapshot();
                },
                // 槽位切换回调
                onSwitchOpenAiSlot: (index: number) => {
                  this.openAiKeySlots = {
                    slots: this.openAiKeySlots.slots,
                    currentSlotIndex: index
                  };
                  this.syncCurrentSlotToCompatFields();
                  this.persistApiConfigSnapshot();
                },
                onSwitchDeepLSlot: (index: number) => {
                  this.deepLKeySlots = {
                    slots: this.deepLKeySlots.slots,
                    currentSlotIndex: index
                  };
                  this.syncCurrentSlotToCompatFields();
                  this.persistApiConfigSnapshot();
                },
                onSwitchOllamaSlot: (index: number) => {
                  this.ollamaKeySlots = {
                    slots: this.ollamaKeySlots.slots,
                    currentSlotIndex: index
                  };
                  this.syncCurrentSlotToCompatFields();
                  this.persistApiConfigSnapshot();
                },
                onSwitchDoubaoSlot: (index: number) => {
                  this.doubaoKeySlots = {
                    slots: this.doubaoKeySlots.slots,
                    currentSlotIndex: index
                  };
                  this.syncCurrentSlotToCompatFields();
                  this.persistApiConfigSnapshot();
                },
                // 更新内容回调（同时更新槽位和兼容字段）
                onUpdateOpenAiApiUrl: (value: string) => {
                  this.openAiApiUrl = value;
                  this.updateCurrentSlot('openai', 'apiUrl', value);
                  this.persistApiConfigSnapshot();
                },
                onUpdateOpenAiApiKey: (value: string) => {
                  this.openAiApiKey = value;
                  this.updateCurrentSlot('openai', 'apiKey', value);
                  this.persistApiConfigSnapshot();
                },
                onUpdateOpenAiModel: (value: string) => {
                  this.openAiModel = value;
                  this.updateCurrentSlot('openai', 'model', value);
                  this.persistApiConfigSnapshot();
                },
                onUpdateDeepLApiUrl: (value: string) => {
                  this.deepLApiUrl = value;
                  this.updateCurrentSlot('deepl', 'apiUrl', value);
                  this.persistApiConfigSnapshot();
                },
                onUpdateDeepLApiKey: (value: string) => {
                  this.deepLApiKey = value;
                  this.updateCurrentSlot('deepl', 'apiKey', value);
                  this.persistApiConfigSnapshot();
                },
                onUpdateOllamaApiUrl: (value: string) => {
                  this.ollamaApiUrl = value;
                  this.updateCurrentSlot('ollama', 'apiUrl', value);
                  this.persistApiConfigSnapshot();
                },
                onUpdateOllamaModel: (value: string) => {
                  this.ollamaModel = value;
                  this.updateCurrentSlot('ollama', 'model', value);
                  this.persistApiConfigSnapshot();
                },
                onUpdateDoubaoApiUrl: (value: string) => {
                  this.doubaoApiUrl = value;
                  this.updateCurrentSlot('doubao', 'apiUrl', value);
                  this.persistApiConfigSnapshot();
                },
                onUpdateDoubaoApiKey: (value: string) => {
                  this.doubaoApiKey = value;
                  this.updateCurrentSlot('doubao', 'apiKey', value);
                  this.persistApiConfigSnapshot();
                },
                onUpdateDoubaoModel: (value: string) => {
                  this.doubaoModel = value;
                  this.updateCurrentSlot('doubao', 'model', value);
                  this.persistApiConfigSnapshot();
                },
                onUpdateGlossary: (value: string) => {
                  this.glossary = value;
                  this.persistApiConfigSnapshot();
                },
                getConfigTextAreaHeight: (rows: number) => this.getConfigTextAreaHeight(rows)
              });
            } else {
              ConfigurationPage({
                isVisible: this.currentTab === 0,
                apiOptions: this.apiOptions,
                selectedApiIndex: this.selectedApiIndex,
                languageOptions: this.languageOptions,
                languageDisplayOptions: this.languageDisplayOptions,
                selectedLanguageIndex: this.selectedLanguageIndex,
                intervalOptions: this.intervalOptions,
                selectedIntervalIndex: this.intervalIndex,
                maxTokensOptions: this.maxTokensOptions,
                selectedMaxTokensIndex: this.maxTokensIndex,
                contextsOptions: this.contextsOptions,
                selectedContextsIndex: this.contextsIndex,
                temperatureOptions: this.temperatureOptions,
                selectedTemperatureIndex: this.temperatureIndex,
                vadSensitivityOptions: this.vadSensitivityOptions,
                selectedVadSensitivityIndex: this.selectedVadSensitivityIndex,
                minMatchLenOptions: this.minMatchLenOptions,
                selectedMinMatchLenIndex: this.selectedMinMatchLenIndex,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
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
                },
                onSelectMaxTokens: (index: number) => {
                  this.maxTokensIndex = index;
                  this.persistApiConfigSnapshot();
                },
                onSelectTemperature: (index: number) => {
                  this.temperatureIndex = index;
                  this.persistApiConfigSnapshot();
                },
                onSelectVadSensitivity: (index: number) => {
                  this.selectedVadSensitivityIndex = index;
                  this.persistApiConfigSnapshot();
                  if (this.micService) {
                    this.micService.setVadSensitivity(index);
                  }
                },
                onSelectMinMatchLen: (index: number) => {
                  this.selectedMinMatchLenIndex = index;
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
              hasContinuityContent: this.originalDemoText.length > 0 || this.translatedDemoText.length > 0,
              isLightEffectBright: this.isLightEffectBright,
              isDarkMode: this.isDarkMode,
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
              onTranslatedTextChange: (value: string) => this.updateTranslationField(value),
              onContinuityTransfer: () => this.startContinuityTransfer()
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
            HistoryTabPage({
              isVisible: this.currentTab === 2,
              isLightEffectBright: this.isLightEffectBright,
              isDarkMode: this.isDarkMode
            })
          }
          .width('100%')
        }
        .tabBar(new BottomTabBarStyle($r('app.media.history') ,'历史/收藏')
          .iconStyle({ selectedColor: Color.White })
          .labelStyle({ selectedColor: Color.White})
        )

        TabContent() {
          Column() {
            SettingsPage({
              isRealtimeReadingEnabled: $isRealtimeReadingEnabled,
              isPipSubtitleEnabled: this.isPipSubtitleEnabled,
              isPipAvailable: this.pipSubtitleManager.isPipEnabled(),
              subtitleFontSize: $subtitleFontSize,
              subtitleFontColor: $subtitleFontColor,
              subtitleBackgroundColor: $subtitleBackgroundColor,
              subtitleHeight: $subtitleHeight,
              isLightEffectBright: $isLightEffectBright,
              themeMode: $themeMode,
              isDarkMode: this.isDarkMode,
              onTogglePipSubtitle: (isOn: boolean) => this.togglePipSubtitle(isOn),
              onToggleRealtimeReading: () => {
                if (!this.isRealtimeReadingEnabled) {
                  TextReader.stop();
                }
              },
              onThemeModeChange: (mode: number) => {
                this.updateThemeMode(mode);
              },
              onStyleChange: () => {
                this.persistApiConfigSnapshot();
                AppStorage.setOrCreate('subtitleFontSize', this.subtitleFontSize);
                AppStorage.setOrCreate('subtitleFontColor', this.subtitleFontColor);
                AppStorage.setOrCreate('subtitleBackgroundColor', this.subtitleBackgroundColor);
                if (this.isPipSubtitleEnabled) {
                  this.pipSubtitleManager.updateStyle({
                    fontSize: this.subtitleFontSize,
                    fontColor: this.subtitleFontColor,
                    backgroundColor: this.subtitleBackgroundColor
                  });
                  // Convert subtitle height (10-30) to pixel value (100-300)
                  this.pipSubtitleManager.updateContentSize(400, this.subtitleHeight * 10);
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
    .bindSheet(
      $$this.showDeviceDialog,
      this.DeviceSelectionDialog(),
      {
        detents: [SheetSize.FIT_CONTENT, SheetSize.MEDIUM, SheetSize.LARGE],
        dragBar: true,
        backgroundColor: Color.Transparent,
        blurStyle: BlurStyle.BACKGROUND_THIN,
        enableOutsideInteractive: true,
        onDisappear: () => {
          this.showDeviceDialog = false;
          ContinuityService.getInstance().stopDiscovering();
        }
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
    let promptWithLanguage: string = this.promptText.replace('{0}', langName);

    // Append Glossary instructions if available
    if (this.glossary && this.glossary.trim().length > 0) {
      promptWithLanguage += `\n\nStrictly follow this glossary only when you hear the relevant terms:\n${this.glossary}`;
    }

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

    // 累积译文到完整记录（追加新内容，避免重复）
    if (this.isListening && text.trim().length > 0 && !text.startsWith('[')) {
      const newTranslation = text.trim();
      // 检查是否已包含此翻译（避免完全重复）
      if (this.fullTranslatedText.length === 0) {
        this.fullTranslatedText = newTranslation;
      } else if (!this.fullTranslatedText.includes(newTranslation) &&
                 !newTranslation.includes(this.fullTranslatedText)) {
        // 只有当新翻译不是已有内容的子串或超集时才追加
        this.fullTranslatedText += '\n' + newTranslation;
      } else if (newTranslation.length > this.fullTranslatedText.length) {
        // 如果新翻译包含已有内容，说明是更完整的版本，直接替换
        this.fullTranslatedText = newTranslation;
      }
    }

    // 同步跨端流转状态
    this.syncContinuityState();

    // 同步更新 PiP 字幕（不再依赖 isPipActive，避免状态延迟导致字幕不同步）
    if (this.isPipSubtitleEnabled && this.translatedDemoText) {
      this.pipSubtitleManager.updateSubtitle(this.translatedDemoText);
    }

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

    const isResponsesEndpoint: boolean = this.openAiApiUrl.includes('/v1/responses') || this.openAiApiUrl.endsWith('/responses');

    // Single message with combined prompt for faster response
    const messages: ChatMessage[] = [
      { role: 'user', content: systemPrompt }
    ];

    const makeBodyChat = (useMaxCompletionTokens: boolean, includeTemperature: boolean): string => {
      let base: Record<string, Object> = {};
      base['model'] = this.openAiModel;
      base['messages'] = messages;

      if (includeTemperature) {
        base['temperature'] = this.getTemperatureValue();
      }

      if (useMaxCompletionTokens) {
        base['max_completion_tokens'] = this.getMaxTokensValue();
      } else {
        base['max_tokens'] = this.getMaxTokensValue();
      }
      return JSON.stringify(base);
    };

    const makeBodyResponses = (): string => {
      let base: Record<string, Object> = {};
      base['model'] = this.openAiModel;
      base['input'] = systemPrompt;
      base['max_output_tokens'] = this.getMaxTokensValue();
      return JSON.stringify(base);
    };

    let response: http.HttpResponse = await httpRequest.request(this.openAiApiUrl, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + this.openAiApiKey
      },
      extraData: isResponsesEndpoint ? makeBodyResponses() : makeBodyChat(false, true),
      expectDataType: http.HttpDataType.STRING
    });

    // 兼容：部分模型不支持 max_tokens / temperature
    if (!isResponsesEndpoint && response.responseCode === 400) {
      const firstStr: string = response.result as string;
      const headerObj: Record<string, string> = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + this.openAiApiKey
      };

      // 1) max_tokens -> max_completion_tokens
      if (firstStr && (firstStr.includes('max_completion_tokens') || firstStr.includes('max_tokens'))) {
        response = await httpRequest.request(this.openAiApiUrl, {
          method: http.RequestMethod.POST,
          header: headerObj,
          extraData: makeBodyChat(true, true),
          expectDataType: http.HttpDataType.STRING
        });
      }

      // 2) temperature 仅支持默认值：移除 temperature 让服务端走默认
      if (response.responseCode === 400) {
        const secondStr: string = response.result as string;
        if (secondStr && secondStr.includes('temperature') && secondStr.includes('default')) {
          response = await httpRequest.request(this.openAiApiUrl, {
            method: http.RequestMethod.POST,
            header: headerObj,
            extraData: makeBodyChat(true, false),
            expectDataType: http.HttpDataType.STRING
          });
        }
      }
    }

    const responseCode: number = response.responseCode;
    const resultStr: string = response.result as string;

    if (responseCode !== 200 && responseCode !== 201) {
      console.error(`OpenAI HTTP error: ${responseCode}, body: ${resultStr}`);
      this.updateTranslationField(`[OpenAI错误: HTTP ${responseCode}]`);
      httpRequest.destroy();
      return;
    }

    let translated: string = '';

    if (isResponsesEndpoint) {
      const parsed = JSON.parse(resultStr) as OpenAIResponsesResponse;
      if (parsed.output_text && parsed.output_text.length > 0) {
        translated = parsed.output_text;
      } else if (parsed.output && parsed.output.length > 0 &&
                 parsed.output[0].content && parsed.output[0].content!.length > 0 &&
                 parsed.output[0].content![0].text) {
        translated = parsed.output[0].content![0].text as string;
      } else {
        console.warn('OpenAI responses has no output_text/output: ' + resultStr);
        translated = '[OpenAI: 响应为空]';
      }

      if (parsed.usage && parsed.usage.total_tokens) {
        TokenUsageStorage.getInstance().addTokenUsage('OpenAI', parsed.usage.total_tokens);
      }
    } else {
      const parsed = JSON.parse(resultStr) as ChatCompletionResponse;
      const hasChoices: boolean = !!(parsed.choices && parsed.choices.length > 0);
      const firstChoice: ChatCompletionChoice | null = hasChoices ? parsed.choices[0] : null;
      const content: string = (firstChoice && firstChoice.message && typeof firstChoice.message.content === 'string')
        ? firstChoice.message.content
        : '';

      const reasoningTokens: number = parsed.usage?.completion_tokens_details?.reasoning_tokens ?? 0;
      if (reasoningTokens > 0 && !this.hasShownReasoningModelHint) {
        this.hasShownReasoningModelHint = true;
        promptAction.showToast({
          message: '您可能使用思考模型，影响实时翻译',
          duration: 3000
        });
      }

      if (content && content.length > 0) {
        translated = content;
      } else {
        const finishReason: string = (firstChoice && firstChoice.finish_reason) ? firstChoice.finish_reason : '';

        if (finishReason === 'length') {
          // 不自动重试/不自动调大 token：只提示用户手动调整或更换模型
          promptAction.showToast({
            message: '该模型可能为“思考模型”，实时翻译不建议使用；可尝试更换模型或调大 Max Tokens',
            duration: 3000
          });
          translated = '[OpenAI: 输出受限（finish_reason=length）。实时翻译不建议使用思考模型；请手动更换模型或调大 Max Tokens]';
        } else {
          console.warn('OpenAI response content empty: ' + resultStr);
          translated = '[OpenAI: 响应为空]';
        }
      }

      if (parsed.usage && parsed.usage.total_tokens) {
        TokenUsageStorage.getInstance().addTokenUsage('OpenAI', parsed.usage.total_tokens);
      }
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
      // DeepL charges by character, so we track characters as "tokens"
      const usage = text.length + translated.length;
      TokenUsageStorage.getInstance().addTokenUsage('DeepL', usage);
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
      num_predict: this.getMaxTokensValue(),
      temperature: this.getTemperatureValue()
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

    if (parsed.eval_count || parsed.prompt_eval_count) {
      const total = (parsed.eval_count || 0) + (parsed.prompt_eval_count || 0);
      TokenUsageStorage.getInstance().addTokenUsage('Ollama', total);
    }

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

    const makeBody = (useMaxCompletionTokens: boolean, includeTemperature: boolean): string => {
      let base: Record<string, Object> = {};
      base['model'] = this.doubaoModel;
      base['messages'] = messages;

      if (includeTemperature) {
        base['temperature'] = this.getTemperatureValue();
      }
      base['stream'] = false;

      if (useMaxCompletionTokens) {
        base['max_completion_tokens'] = this.getMaxTokensValue();
      } else {
        base['max_tokens'] = this.getMaxTokensValue();
      }
      return JSON.stringify(base);
    };

    try {
      let response: http.HttpResponse = await httpRequest.request(this.doubaoApiUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + this.doubaoApiKey
        },
        extraData: makeBody(false, true),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000, // 8s connection timeout
        readTimeout: 20000 // 20s read timeout
      });

      // 兼容：部分模型不支持 max_tokens，需要 max_completion_tokens
      if (response.responseCode === 400) {
        const firstStr: string = response.result as string;
        // 只要提示包含 max_completion_tokens，或者明确说 max_tokens 不支持，就尝试切换
        if (firstStr && (firstStr.includes('max_completion_tokens') || firstStr.includes('max_tokens'))) {
          response = await httpRequest.request(this.doubaoApiUrl, {
            method: http.RequestMethod.POST,
            header: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ' + this.doubaoApiKey
            },
            extraData: makeBody(true, true),
            expectDataType: http.HttpDataType.STRING,
            connectTimeout: 8000,
            readTimeout: 20000
          });
        }

        // temperature 仅支持默认值：移除 temperature 让服务端走默认
        if (response.responseCode === 400) {
          const secondStr: string = response.result as string;
          if (secondStr && secondStr.includes('temperature') && secondStr.includes('default')) {
            response = await httpRequest.request(this.doubaoApiUrl, {
              method: http.RequestMethod.POST,
              header: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + this.doubaoApiKey
              },
              extraData: makeBody(true, false),
              expectDataType: http.HttpDataType.STRING,
              connectTimeout: 8000,
              readTimeout: 20000
            });
          }
        }
      }

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
        if (parsed.usage && parsed.usage.total_tokens) {
          TokenUsageStorage.getInstance().addTokenUsage('Doubao', parsed.usage.total_tokens);
        }
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

    // 累积最终识别结果到完整记录（智能追加）
    if (text.trim().length > 0) {
      const currentText = text.trim();
      if (this.fullOriginalText.length === 0) {
        this.fullOriginalText = currentText;
      } else if (!this.fullOriginalText.includes(currentText) &&
                 !currentText.includes(this.fullOriginalText)) {
        this.fullOriginalText += '\n' + currentText;
      } else if (currentText.length > this.fullOriginalText.length) {
        this.fullOriginalText = currentText;
      }
    }

    // Update session with full text
    if (this.currentSessionId !== -1) {
      HistoryStorage.getInstance().updateSession(
        this.currentSessionId,
        this.fullOriginalText || this.originalDemoText,
        this.fullTranslatedText || this.translatedDemoText
      );
    }

    this.translateCurrentDemo();
  }

  /**
   * 启动跨端流转 - 将当前字幕会话流转到其他设备
   */
  private async startContinuityTransfer(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;

      // 确保状态已同步
      this.syncContinuityState();

      // 初始化设备管理服务
      const service = ContinuityService.getInstance();
      const initialized = await service.init(ctx);

      if (!initialized) {
        promptAction.showToast({ message: '无法初始化设备管理服务，请前往设置开启发现设备权限' });
        return;
      }

      // 获取已信任设备
      this.deviceList = service.getTrustedDevices();

      // 注册回调
      service.setOnDeviceFoundCallback((device: DeviceInfo) => {
        // 检查是否已存在
        const exists = this.deviceList.some(d => d.deviceId === device.deviceId);
        if (!exists) {
          this.deviceList.push(device);
        }
      });

      service.setOnDeviceLostCallback((deviceId: string) => {
        this.deviceList = this.deviceList.filter(d => d.deviceId !== deviceId);
      });

      // 开始发现设备
      service.startDiscovering();

      // 显示设备选择对话框
      this.showDeviceDialog = true;

    } catch (err) {
      console.error('[Index] startContinuityTransfer error: ' + JSON.stringify(err));
      promptAction.showToast({ message: '流转失败: ' + JSON.stringify(err) });
    }
  }

  private async selectDevice(device: DeviceInfo): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;

      promptAction.showToast({ message: '正在流转到 ' + device.deviceName });

      console.info(`[Index] selectDevice: name=${device.deviceName}, type=${device.deviceType}, networkId=${device.networkId}, deviceId=${device.deviceId}`);

      // 检查 networkId 是否有效
      const service = ContinuityService.getInstance();

      // 优先使用已有 networkId；若缺失再尝试绑定获取
      let targetNetworkId: string = device.networkId || '';
      if (!targetNetworkId || targetNetworkId.length === 0) {
        const bound = await service.bindDevice(device.deviceId);
        if (!bound) {
          console.warn('[Index] bindDevice failed for ' + device.deviceId);
        } else {
          const refreshedDevices = service.getTrustedDevices();
          const refreshed = refreshedDevices.find(d => d.deviceId === device.deviceId);
          if (refreshed && refreshed.networkId) {
            targetNetworkId = refreshed.networkId;
            device.networkId = targetNetworkId;
          }
        }
      }

      if (!targetNetworkId || targetNetworkId.length === 0) {
        targetNetworkId = device.deviceId;
      }
      if (!targetNetworkId || targetNetworkId.length === 0) {
        promptAction.showToast({ message: '设备网络ID无效，请确认已配对并在同一网络' });
        return;
      }

      // 同步当前状态到 AppStorage，供 onContinue 读取
      this.syncContinuityState();

      // 准备 API 配置快照（使用正确的属性名匹配 ApiConfigSnapshot）
      const apiConfigSnapshot: ApiConfigSnapshot = {
        promptText: this.promptText,
        openAiKeySlots: this.openAiKeySlots,
        deepLKeySlots: this.deepLKeySlots,
        ollamaKeySlots: this.ollamaKeySlots,
        doubaoKeySlots: this.doubaoKeySlots,
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
        temperatureIndex: this.temperatureIndex,
        maxTokensIndex: this.maxTokensIndex,
        subtitleFontSize: this.subtitleFontSize,
        subtitleFontColor: this.subtitleFontColor,
        subtitleBackgroundColor: this.subtitleBackgroundColor,
        subtitleHeight: this.subtitleHeight,
        glossary: this.glossary,
        themeMode: this.themeMode,
        vadSensitivityIndex: this.selectedVadSensitivityIndex,
        minMatchLenIndex: this.selectedMinMatchLenIndex
      };

      // 准备 continuation 数据（匹配 ContinuityState 接口）
      const continuationState: ContinuityStateExtended = {
        isListening: this.isListening,
        isTranslating: this.isTranslating,
        originalText: this.originalDemoText || this.fullOriginalText,
        translatedText: this.translatedDemoText || this.fullTranslatedText,
        sessionId: this.currentSessionId || 0,
        fullOriginalText: this.fullOriginalText || this.originalDemoText,
        fullTranslatedText: this.fullTranslatedText || this.translatedDemoText,
        apiConfig: JSON.stringify(apiConfigSnapshot),
        timestamp: Date.now(),
        currentTab: this.currentTab,
        // 新增：实时朗读和 PiP 状态
        isRealtimeReading: this.isRealtimeReadingEnabled,
        isPipEnabled: this.isPipSubtitleEnabled,
        // 新增：字幕样式配置
        subtitleConfig: this.buildSubtitleStyleConfig()
      };

      // 构建 want parameters，按文档使用字符串键以避免 ArkTS 限制
      const wantParams: Record<string, Object> = {};
      wantParams[CONTINUITY_KEY] = JSON.stringify(continuationState);

      // 使用 startAbility 进行跨端流转（最小参数集）
      const want: Want = {
        deviceId: targetNetworkId || device.deviceId,
        bundleName: 'com.zixiao.voot',
        abilityName: 'EntryAbility',
        moduleName: 'entry',
        action: 'ohos.want.action.sendData',
        flags: wantConstant.Flags.FLAG_INSTALL_ON_DEMAND,
        parameters: wantParams
      };

      console.info(`[Index] startAbility want: deviceId=${targetNetworkId || device.deviceId}, bundleName=com.zixiao.voot, action=sendData`);

      let startError: BusinessError | null = null;
      try {
        await ctx.startAbility(want);
      } catch (e) {
        startError = e as BusinessError;
        console.warn('[Index] startAbility first attempt failed: code=' + startError.code + ', msg=' + startError.message);
        if ((startError.code === 401 || startError.code === 16000011) && targetNetworkId !== device.deviceId) {
          want.deviceId = device.deviceId;
          console.info('[Index] retry startAbility with deviceId fallback');
          await ctx.startAbility(want);
          startError = null;
        }
      }

      if (startError) {
        throw new Error(`startAbility failed: code=${startError.code}, message=${startError.message}`);
      }

      this.showDeviceDialog = false;
      ContinuityService.getInstance().stopDiscovering();

      promptAction.showToast({ message: '流转成功' });

    } catch (err) {
      const e = err as BusinessError;
      console.error('[Index] selectDevice error: code=' + e.code + ', message=' + e.message);

      let msg = '流转失败';
      if (e.code === 16000050) {
        msg = '不支持该设备类型的流转';
      } else if (e.code === 401) {
        msg = '参数错误，请确保两设备登录同一华为账号、在同一网络，并在对端确认连接';
      } else if (e.code === 16000001) {
        msg = '目标设备上未安装 Voot';
      } else if (e.code === 16000011) {
        msg = '流转被拒绝，请检查设备连接';
      } else {
        msg = `流转失败: ${e.message || '未知错误'} (${e.code})`;
      }

      promptAction.showToast({ message: msg });
    }
  }

  // Helper to map normalized index back to original string index
  private getOriginalIndex(original: string, normIndex: number): number {
    let n = 0;
    for (let i = 0; i < original.length; i++) {
      // Check if char is "word character" (matches the regex used in normalization)
      if (/[\w\u4e00-\u9fa5]/.test(original[i])) {
        if (n === normIndex) return i;
        n++;
      }
    }
    return original.length;
  }

  // Helper for smart text appending (handling overlaps)
  private smartAppend(base: string, newText: string): string {
    if (!base) return newText;
    if (!newText) return base;

    // 1. Normalize
    const normalize = (s: string) => s.toLowerCase().replace(/[^\w\u4e00-\u9fa5]/g, '');
    const normBase = normalize(base);
    const normNew = normalize(newText);

    if (!normBase || !normNew) return base + '\n' + newText;

    const searchWindow = 300;
    const baseStartOffset = Math.max(0, normBase.length - searchWindow);
    const baseTail = normBase.substring(baseStartOffset);

    const minMatchLen = parseInt(this.minMatchLenOptions[this.selectedMinMatchLenIndex]);

    // Strategy A: Forward Match (Prefix of New found in BaseTail)
    // Good for: "Hello" -> "Hello world", "Hello world" -> "Hello word"
    let forwardMatchLen = 0;
    let forwardMatchIndexInTail = -1;

    const maxForwardLen = Math.min(baseTail.length, normNew.length);
    for (let len = maxForwardLen; len >= minMatchLen; len--) {
      const prefix = normNew.substring(0, len);
      const idx = baseTail.lastIndexOf(prefix);
      if (idx !== -1) {
        forwardMatchLen = len;
        forwardMatchIndexInTail = idx;
        break;
      }
    }

    // Strategy B: Reverse Match (Suffix of BaseTail found in New)
    // Good for: "world" -> "Hello world", "He was gone" -> "And then he was gone"
    let reverseMatchLen = 0;
    let reverseMatchIndexInNew = -1;

    const maxReverseLen = Math.min(baseTail.length, normNew.length);
    for (let len = maxReverseLen; len >= minMatchLen; len--) {
      const suffix = baseTail.substring(baseTail.length - len);
      const idx = normNew.indexOf(suffix);
      if (idx !== -1) {
        reverseMatchLen = len;
        reverseMatchIndexInNew = idx;
        break;
      }
    }

    // Decision
    if (forwardMatchLen === 0 && reverseMatchLen === 0) {
      return base + '\n' + newText;
    }

    // Prefer the longer match
    if (forwardMatchLen >= reverseMatchLen) {
      // Apply Forward Match
      // We found `prefix` of New at `forwardMatchIndexInTail` of BaseTail.
      // We cut Base at that index, and append New.
      const matchStartInNormBase = baseStartOffset + forwardMatchIndexInTail;
      const cutIndex = this.getOriginalIndex(base, matchStartInNormBase);
      return base.substring(0, cutIndex) + newText;
    } else {
      // Apply Reverse Match
      // We found `suffix` of BaseTail at `reverseMatchIndexInNew` of New.
      // The suffix starts at `baseTail.length - reverseMatchLen` in BaseTail.
      const matchStartInTail = baseTail.length - reverseMatchLen;
      const matchStartInNormBase = baseStartOffset + matchStartInTail;
      const cutIndex = this.getOriginalIndex(base, matchStartInNormBase);
      
      // We cut Base *before* the suffix, and append New (which contains the suffix + more)
      // Wait, if New contains the suffix, we should append New.
      // But New might contain stuff *before* the suffix too (e.g. "And then he was gone").
      // So replacing the suffix in Base with New is correct.
      return base.substring(0, cutIndex) + newText;
    }
  }

  private async startMicCaptioning(): Promise<void> {
    if (this.isListening) {
      return;
    }

    // 1) Show immediate feedback
    this.isListening = true;
    
    // 彻底重置所有翻译相关状态，确保新录音能正常触发翻译
    this.lastTranslatedText = ''; // Reset to allow first translation
    this.lastDisplayedText = ''; // Reset display tracking
    this.lastAsrText = ''; // Reset ASR text tracking
    this.lastAsrUpdateTs = 0; // Reset ASR timestamp
    this.translatedDemoText = ''; // Clear old translation
    this.originalDemoText = ''; // Clear old original text
    this.contextHistory = []; // Clear context history
    this.pendingTranslationText = ''; // Clear pending translation
    this.isTranslating = false; // Ensure not stuck in translating state
    
    // Cancel any pending translation debounce
    if (this.translationDebounceId !== undefined) {
      clearTimeout(this.translationDebounceId);
      this.translationDebounceId = undefined;
    }

    // Now show startup message
    this.originalDemoText = this.trimRealtimeBuffer('[正在启动语音识别…]');

    // Start new session
    const now = new Date();
    const dateStr = `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}-${now.getDate().toString().padStart(2, '0')}`;
    this.currentSessionId = await HistoryStorage.getInstance().createSession('新录音 ' + dateStr);

    // 重置累积变量
    this.fullOriginalText = '';
    this.fullTranslatedText = '';
    this.lastDbSaveTs = Date.now();
    this.lastRealtimeTranslateTs = 0; // 重置翻译时间戳

    // 同步状态到 AppStorage（供跨端流转使用）
    this.syncContinuityState();

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

        // 累积原文到完整记录（智能追加，避免重复）
        if (res.text.trim().length > 0) {
          const currentText = res.text.trim();
          if (this.fullOriginalText.length === 0) {
            // 首次设置
            this.fullOriginalText = currentText;
          } else {
            // Use smart append to handle overlaps and updates
            this.fullOriginalText = this.smartAppend(this.fullOriginalText, currentText);
          }
        }

        // 按用户设置的间隔时间保存到数据库
        const now = Date.now();
        const saveIntervalMs = parseInt(this.intervalOptions[this.intervalIndex]) * 1000;
        if (this.currentSessionId !== -1 && now - this.lastDbSaveTs >= saveIntervalMs) {
          this.lastDbSaveTs = now;
          HistoryStorage.getInstance().updateSession(
            this.currentSessionId,
            this.fullOriginalText,
            this.fullTranslatedText
          );
        }

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

    // Update session with final full text
    if (this.currentSessionId !== -1) {
      await HistoryStorage.getInstance().updateSession(
        this.currentSessionId,
        this.fullOriginalText || this.originalDemoText,
        this.fullTranslatedText || this.translatedDemoText
      );
      this.currentSessionId = -1;
    }

    this.isListening = false;
    this.lastRealtimeTranslateTs = 0;
    this.lastTranslatedText = ''; // Reset for next session
    this.lastDisplayedText = ''; // Reset display tracking
    this.fullOriginalText = ''; // Reset full text
    this.fullTranslatedText = ''; // Reset full translation

    // 同步停止状态到 AppStorage（流转时告知目标设备源已停止录音）
    this.syncContinuityState();

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

@CustomDialog
struct FeatureDialog {
  controller: CustomDialogController
  @Link index: number
  @State scaleValue: number = 0.9

  build() {
    Column() {
      // Animation: A gentle breathing effect
      Image(WELCOME_FEATURES[this.index].icon)
        .width(80)
        .height(80)
        .objectFit(ImageFit.Contain)
        .fillColor('#3c1464')
        .scale({ x: this.scaleValue, y: this.scaleValue })
        .onAppear(() => {
          animateTo({
            duration: 1500,
            iterations: -1,
            curve: Curve.EaseInOut,
            playMode: PlayMode.Alternate
          }, () => {
            this.scaleValue = 1.1
          })
        })
        .margin({ bottom: 24 })

      Text(WELCOME_FEATURES[this.index].title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.Black)
        .margin({ bottom: 12 })

      Text(WELCOME_FEATURES[this.index].description)
        .fontSize(16)
        .fontColor(Color.Gray)
        .textAlign(TextAlign.Center)
        .lineHeight(24)
        .margin({ bottom: 32 })

      Button('了解')
        .width('80%')
        .height(48)
        .backgroundColor('#3c1464')
        .onClick(() => {
          this.controller.close()
        })
    }
    .width(300)
    .padding(32)
    .backgroundColor(Color.White)
    .borderRadius(24)
    .shadow({ radius: 32, color: '#44000000', offsetY: 8 })
  }
}
