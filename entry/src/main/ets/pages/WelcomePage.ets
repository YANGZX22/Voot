/**
 * @fileoverview Welcome Page
 * 展示应用介绍
 */
import router from '@ohos.router';
import http from '@ohos.net.http';
import promptAction from '@ohos.promptAction';
import util from '@ohos.util';
import { hdsEffect } from '@kit.UIDesignKit';
import common from '@ohos.app.ability.common';
import { webview } from '@kit.ArkWeb';
import PhoneNumberAuthHelper from 'numberauth_standard';
import { TokenResultListener, AuthUIControlClickListener, AuthUiConfig } from 'numberauth_standard';
import app from '@system.app';
import bundleManager from '@ohos.bundle.bundleManager';
import { PolicySheetType, PolicySheetContent, getPolicySheetConfig, PolicySheetConfig } from '../components/PolicySheet';
import { OnboardingStorage } from '../storage/OnboardingStorage';
import { ApiConfigStorage, ApiConfigSnapshot, createDefaultMultiKeySlots } from '../storage/ApiConfigStorage';

// API 提供商类型
enum ApiProvider {
  OpenAI = 0,
  DeepL = 1,
  Ollama = 2,
  Doubao = 3
}

// API 提供商信息
interface ProviderInfo {
  id: ApiProvider;
  name: string;
  description: string;
  icon: Resource;
  needsApiKey: boolean;
  needsModel: boolean;
  defaultUrl: string;
  defaultModel: string;
  urlPlaceholder: string;
  modelPlaceholder: string;
}

const PROVIDERS: ProviderInfo[] = [
  {
    id: ApiProvider.OpenAI,
    name: 'OpenAI',
    description: '使用 GPT 系列模型进行翻译，支持各类兼容接口',
    icon: $r('app.media.OpenAI'),
    needsApiKey: true,
    needsModel: true,
    defaultUrl: 'https://api.openai.com/v1/chat/completions',
    defaultModel: 'gpt-4o-mini',
    urlPlaceholder: 'https://api.openai.com/v1/chat/completions',
    modelPlaceholder: 'gpt-4o-mini'
  },
  {
    id: ApiProvider.DeepL,
    name: 'DeepL',
    description: '专业翻译服务，翻译质量高',
    icon: $r('app.media.DeepL'),
    needsApiKey: true,
    needsModel: false,
    defaultUrl: 'https://api-free.deepl.com/v2/translate',
    defaultModel: '',
    urlPlaceholder: 'https://api-free.deepl.com/v2/translate',
    modelPlaceholder: ''
  },
  {
    id: ApiProvider.Ollama,
    name: 'Ollama',
    description: '本地运行开源模型，无需 API 密钥',
    icon: $r('app.media.Ollama'),
    needsApiKey: false,
    needsModel: true,
    defaultUrl: 'http://localhost:11434/api/chat',
    defaultModel: '',
    urlPlaceholder: 'http://localhost:11434/api/chat',
    modelPlaceholder: '请输入模型名称'
  },
  {
    id: ApiProvider.Doubao,
    name: 'Doubao',
    description: '字节跳动火山引擎或者广义HTTP请求模型',
    icon: $r('app.media.Doubao'),
    needsApiKey: true,
    needsModel: true,
    defaultUrl: 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
    defaultModel: 'ep-20251221220646-rnx4c',
    urlPlaceholder: 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
    modelPlaceholder: 'ep-20251221220646-rnx4c'
  }
];

// 引导页面的阶段
enum WelcomeStep {
  Intro = 0,        // 介绍页（第一页）
  Features = 1,     // 功能介绍页（第二页）
  ApiDriven = 2,    // API驱动介绍页（第三页）
  NumberAuth = 3,   // 号码认证页（第四页）
  ApiIntro = 4,     // API介绍页（第五页）
}

// 功能特性项（带 span 用于布局）
interface WelcomeFeature {
  title: string;
  description: string;
  icon: Resource;
  span: number; // 1 for Circle (x), 2 for Capsule (xx)
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
  },
  {
    title: '手势',
    description: '手势控制和左右手智感握姿。',
    icon: $r('app.media.airgesture'),
    span: 2
  },
  {
    title: '润色',
    description: '智能优化文本表达，让语言更加精练。',
    icon: $r('app.media.wand'),
    span: 1
  },
  {
    title: '扫描',
    description: '拍照识别文字并翻译，轻松处理纸质文档。',
    icon: $r('app.media.scan'),
    span: 2
  }
];

@Entry
@Component
struct WelcomePage {
  @StorageLink('isNumberVerified') isVerified: boolean = false;
  @State currentStep: WelcomeStep = WelcomeStep.Intro;
  @State isPolicySheetOpen: boolean = false;
  @State currentPolicyType: PolicySheetType = PolicySheetType.Terms;
  @State hasAcceptedTerms: boolean = false;
  @State hasAcceptedPrivacy: boolean = false;
  @State hasAcceptedDisclaimer: boolean = false;
  @State buttonScale: number = 1.0;
  @State isButtonActive: boolean = false;
  @State pageIndicatorIndex: number = 0;
  @State isSkipAllowed: boolean = false;
  @State detectedCountryCode: string = '';
  @State showOpenAIWarningPopup: boolean = false;
  @State showDeepLWarningPopup: boolean = false;
  @State isNavigating: boolean = false; // 防止快速连续点击导致跳过验证

  // Setup Sheet State
  @State isSetupSheetOpen: boolean = false;
  @State isKeyGuideSheetOpen: boolean = false;
  @State selectedProvider: ApiProvider = ApiProvider.OpenAI;
  @State apiUrl: string = PROVIDERS[0].defaultUrl;
  @State apiKey: string = '';
  @State model: string = PROVIDERS[0].defaultModel;
  @State isConfigValid: boolean = false;
  @State isTestingConnection: boolean = false;

  // 功能卡片状态
  @State featureCardScales: number[] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0];
  @State breathingScales: number[] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0];
  @State activeFeatureCard: number = -1;
  @State currentFeatureIndex: number = 0;
  @State gradientAngle: number = 0;
  private breathingTimer: number = -1;
  
  // SDK Key from config file
  private authSdkKey: string = '';
  
  private swiperController: SwiperController = new SwiperController();

  // Feature Dialog Controller
  featureDialogController: CustomDialogController = new CustomDialogController({
    builder: FeatureDialog({ index: $currentFeatureIndex }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  private policyController: webview.WebviewController = new webview.WebviewController();
  private policyDialogController: CustomDialogController | null = null;
  private disclaimerDialogController: CustomDialogController | null = null;

  aboutToAppear() {
    try {
      // Load SDK config
      this.loadAuthSdkConfig();
      
      // Check for initial target step from EntryAbility
      const initialStep = AppStorage.get<number>('initialTargetStep');
      if (initialStep !== undefined) {
        this.currentStep = initialStep;
        AppStorage.setOrCreate('initialTargetStep', undefined); // Clear it
      }

      const params = router.getParams() as Record<string, number>;
      if (params && params['targetStep'] !== undefined) {
        this.currentStep = params['targetStep'];
      }

      // 如果跳转到后续步骤，默认认为前序协议已同意，避免被 disableSwipe 卡住
      if (this.currentStep > WelcomeStep.Intro) {
        this.hasAcceptedTerms = true;
        this.hasAcceptedPrivacy = true;
      }
      if (this.currentStep > WelcomeStep.Features) {
        this.hasAcceptedDisclaimer = true;
      }
      
      this.checkIpLocation();
    } catch (e) {
      console.error('Failed to get params:', e);
    }
  }
  
  private loadAuthSdkConfig() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const rawFile = context.resourceManager.getRawFileContentSync('auth_sdk_config.json');
      const textDecoder = util.TextDecoder.create('utf-8');
      const jsonString = textDecoder.decodeToString(rawFile);
      const config: Record<string, string> = JSON.parse(jsonString);
      if (config['sdkKey']) {
        this.authSdkKey = config['sdkKey'];
        console.info('Loaded SDK key from config');
      }
    } catch (e) {
      console.error('Failed to load auth SDK config:', e);
    }
  }

  private async checkIpLocation() {
    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request('http://ip-api.com/json/?fields=countryCode', {
        method: http.RequestMethod.GET,
        connectTimeout: 5000,
        readTimeout: 5000
      });

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as Record<string, Object>;
        const countryCode = result['countryCode'] as string;
        this.detectedCountryCode = countryCode || '';
        if (countryCode !== 'CN') {
          this.isSkipAllowed = true;
        }
      }
      httpRequest.destroy();
    } catch (e) {
      console.error('IP check failed:', e);
    }
  }

  // 根据国家代码获取地区名称
  private getRegionName(): string {
    switch (this.detectedCountryCode) {
      case 'CN':
        return '中国大陆';
      case 'HK':
        return '中国香港特别行政区';
      case 'MO':
        return '中国澳门特别行政区';
      default:
        return '该地区';
    }
  }

  onPageShow() {
    if (this.currentStep === WelcomeStep.NumberAuth && this.isVerified) {
      this.swiperController.showNext();
    }
  }

  // 验证配置
  private validateConfig(): void {
    const provider = PROVIDERS[this.selectedProvider];
    let isValid = true;

    if (!this.apiUrl) isValid = false;
    if (provider.needsApiKey && !this.apiKey) isValid = false;
    if (provider.needsModel && !this.model) isValid = false;

    this.isConfigValid = isValid;
  }

  private async testConnection(): Promise<boolean> {
    this.isTestingConnection = true;
    try {
      const httpRequest = http.createHttp();
      let url = this.apiUrl;
      let method = http.RequestMethod.POST;
      let extraData: Record<string, Object> = {};
      let headers: Record<string, string> = {
        'Content-Type': 'application/json'
      };

      if (this.selectedProvider === ApiProvider.OpenAI || this.selectedProvider === ApiProvider.Doubao) {
        headers['Authorization'] = `Bearer ${this.apiKey}`;
        let msg: Record<string, Object> = { 'role': 'user', 'content': 'Hi' };
        extraData = {
          'model': this.model,
          'messages': [msg],
          'max_tokens': 50
        };
      } else if (this.selectedProvider === ApiProvider.DeepL) {
        headers['Authorization'] = `DeepL-Auth-Key ${this.apiKey}`;
        extraData = {
            'text': ['Hello'],
            'target_lang': 'ZH'
        };
      } else if (this.selectedProvider === ApiProvider.Ollama) {
        let msg: Record<string, Object> = { 'role': 'user', 'content': 'Hi' };
        extraData = {
          'model': this.model,
          'messages': [msg],
          'stream': false
        };
      }

      let response = await httpRequest.request(url, {
        method: method,
        header: headers,
        extraData: extraData,
        connectTimeout: 5000,
        readTimeout: 5000
      });

      // OpenAI 兼容：部分模型在 chat/completions 下不支持 max_tokens，要求 max_completion_tokens
      if ((this.selectedProvider === ApiProvider.OpenAI || this.selectedProvider === ApiProvider.Doubao) &&
        response.responseCode === 400) {
        const resultStr: string = typeof response.result === 'string' ? (response.result as string) : JSON.stringify(response.result);
        if (resultStr.includes('max_completion_tokens') && resultStr.includes('max_tokens')) {
          let msg: Record<string, Object> = { 'role': 'user', 'content': 'Hi' };
          extraData = {
            'model': this.model,
            'messages': [msg],
            'max_completion_tokens': 50
          };
          response = await httpRequest.request(url, {
            method: method,
            header: headers,
            extraData: extraData,
            connectTimeout: 5000,
            readTimeout: 5000
          });
        }
      }

      httpRequest.destroy();

      if (response.responseCode === 200) {
        promptAction.showToast({
          message: '验证成功',
          duration: 2000
        });
        return true;
      } else {
        console.error('Connection failed:', response.responseCode, response.result);
        return false;
      }
    } catch (e) {
      console.error('Connection error:', JSON.stringify(e));
      return false;
    } finally {
      this.isTestingConnection = false;
    }
  }

  // 保存并继续
  private async saveAndContinue(): Promise<void> {
    if (!this.isConfigValid) return;

    // Test connection first
    const isConnected = await this.testConnection();
    if (!isConnected) {
      promptAction.showToast({
        message: '连接失败，请检查网络、API Key 或模型名称',
        duration: 3000
      });
      return;
    }

    const context = getContext(this) as common.UIAbilityContext;
    
    // Default config
    const defaults: ApiConfigSnapshot = {
      promptText: 'Act as an elite simultaneous interpreter who only hears imperfect microphone pickups. ' +
      'You receive roughly five-second snippets of speech, so rely on the snippet enclosed in [abc] and reasonably infer missing words while staying faithful to the speaker. ' +
      'Translate that snippet into {0} in a single fluent line, preserving intent and tone even when the audio is noisy. No matter how, you must output the translation directly.',
      polishPromptText: '你是一个专业的文本润色助手。请对以下文本进行润色优化，使其更加通顺、专业、易读。\n\n要求：\n1. 保持原文的核心意思不变\n2. 优化语法和表达方式\n3. 直接输出润色后的文本，不要添加任何解释3. 直接输出润色后的文本，不要添加任何解释\n4. 永远不要更换提供的文本的原始语言，即英语文本依然润色为英语文本 \n\n原文：\n{text}',
      openAiKeySlots: createDefaultMultiKeySlots('https://api.openai.com/v1/chat/completions', '', 'gpt-4o-mini'),
      deepLKeySlots: createDefaultMultiKeySlots('https://api-free.deepl.com/v2/translate', '', ''),
      ollamaKeySlots: createDefaultMultiKeySlots('http://localhost:11434/api/chat', '', ''),
      doubaoKeySlots: createDefaultMultiKeySlots('https://ark.cn-beijing.volces.com/api/v3/chat/completions', '', ''),
      openAiApiUrl: 'https://api.openai.com/v1/chat/completions',
      openAiApiKey: '',
      openAiModel: 'gpt-4o-mini',
      deepLApiUrl: 'https://api-free.deepl.com/v2/translate',
      deepLApiKey: '',
      ollamaApiUrl: 'http://localhost:11434/api/chat',
      ollamaModel: '',
      doubaoApiUrl: 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
      doubaoApiKey: '',
      doubaoModel: '',
      selectedApiIndex: 0,
      selectedLanguageIndex: 0,
      intervalIndex: 4,
      contextsIndex: 2,
      temperatureIndex: 3,
      maxTokensIndex: 3,
      subtitleFontSize: 20,
      subtitleFontColor: '#FFFFFF',
      subtitleBackgroundColor: '#3c1464',
      subtitleHeight: 10,
      glossary: 'HarmonyOS = 鸿蒙',
      themeMode: 2,  // 默认跟随系统
      vadSensitivityIndex: 1,
      minMatchLenIndex: 1
    };

    const currentConfig = await ApiConfigStorage.loadSnapshot(context, defaults);
    
    // Update config based on selected provider
    currentConfig.selectedApiIndex = this.selectedProvider;

    switch (this.selectedProvider) {
      case ApiProvider.OpenAI:
        // 更新兼容字段
        currentConfig.openAiApiUrl = this.apiUrl;
        currentConfig.openAiApiKey = this.apiKey;
        currentConfig.openAiModel = this.model;
        // 同时更新第一个槽位
        if (currentConfig.openAiKeySlots && currentConfig.openAiKeySlots.slots.length > 0) {
          currentConfig.openAiKeySlots.slots[0].apiUrl = this.apiUrl;
          currentConfig.openAiKeySlots.slots[0].apiKey = this.apiKey;
          currentConfig.openAiKeySlots.slots[0].model = this.model;
          currentConfig.openAiKeySlots.currentSlotIndex = 0;
        }
        break;
      case ApiProvider.DeepL:
        // 更新兼容字段
        currentConfig.deepLApiUrl = this.apiUrl;
        currentConfig.deepLApiKey = this.apiKey;
        // 同时更新第一个槽位
        if (currentConfig.deepLKeySlots && currentConfig.deepLKeySlots.slots.length > 0) {
          currentConfig.deepLKeySlots.slots[0].apiUrl = this.apiUrl;
          currentConfig.deepLKeySlots.slots[0].apiKey = this.apiKey;
          currentConfig.deepLKeySlots.currentSlotIndex = 0;
        }
        break;
      case ApiProvider.Ollama:
        // 更新兼容字段
        currentConfig.ollamaApiUrl = this.apiUrl;
        currentConfig.ollamaModel = this.model;
        // 同时更新第一个槽位
        if (currentConfig.ollamaKeySlots && currentConfig.ollamaKeySlots.slots.length > 0) {
          currentConfig.ollamaKeySlots.slots[0].apiUrl = this.apiUrl;
          currentConfig.ollamaKeySlots.slots[0].model = this.model;
          currentConfig.ollamaKeySlots.currentSlotIndex = 0;
        }
        break;
      case ApiProvider.Doubao:
        // 更新兼容字段
        currentConfig.doubaoApiUrl = this.apiUrl;
        currentConfig.doubaoApiKey = this.apiKey;
        currentConfig.doubaoModel = this.model;
        // 同时更新第一个槽位
        if (currentConfig.doubaoKeySlots && currentConfig.doubaoKeySlots.slots.length > 0) {
          currentConfig.doubaoKeySlots.slots[0].apiUrl = this.apiUrl;
          currentConfig.doubaoKeySlots.slots[0].apiKey = this.apiKey;
          currentConfig.doubaoKeySlots.slots[0].model = this.model;
          currentConfig.doubaoKeySlots.currentSlotIndex = 0;
        }
        break;
    }

    await ApiConfigStorage.saveSnapshot(context, currentConfig);
    await OnboardingStorage.markCompleted(context);
    await OnboardingStorage.acceptAllPolicies(context);  // 记录已接受的政策版本

    router.replaceUrl({
      url: 'pages/Index'
    });
  }

  // 启动顺序呼吸动画
  private startSequentialBreathing() {
    this.stopSequentialBreathing();
    
    // Ensure all scales are 1.0 to start
    this.breathingScales = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0];
    
    this.startBreathingLoop();
  }

  private startBreathingLoop() {
    let index = 0;
    
    const breathe = () => {
      const currentIndex = index; // 捕获当前索引
      
      // Enlarge
      animateTo({ duration: 600, curve: Curve.EaseInOut }, () => {
        this.breathingScales[currentIndex] = 1.05;
      });
      
      // Shrink back
      setTimeout(() => {
        animateTo({ duration: 600, curve: Curve.EaseInOut }, () => {
          this.breathingScales[currentIndex] = 1.0;
        });
      }, 600);

      index = (index + 1) % this.breathingScales.length;
    };
    
    // Start immediately
    breathe();
    this.breathingTimer = setInterval(breathe, 1200);
  }

  // 停止呼吸动画
  private stopSequentialBreathing() {
    if (this.breathingTimer !== -1) {
      clearInterval(this.breathingTimer);
      this.breathingTimer = -1;
    }
    // Reset all scales
    animateTo({ duration: 300 }, () => {
      this.breathingScales = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0];
    });
  }

  // 按钮按下效果
  private pressButton(): void {
    animateTo({
      duration: 200,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.isButtonActive = true;
      this.buttonScale = 0.95;
    });
  }

  // 按钮释放效果
  private releaseButton(): void {
    animateTo({
      duration: 200,
      curve: Curve.EaseOut
    }, () => {
      this.isButtonActive = false;
      this.buttonScale = 1.0;
    });
  }

  // 功能卡片按下效果
  private pressFeatureCard(index: number): void {
    animateTo({
      duration: 200,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.activeFeatureCard = index;
      const nextScales: number[] = [...this.featureCardScales];
      nextScales[index] = 0.9;
      this.featureCardScales = nextScales;
    });
  }

  // 功能卡片释放效果
  private releaseFeatureCard(index: number): void {
    animateTo({
      duration: 200,
      curve: Curve.EaseOut
    }, () => {
      this.activeFeatureCard = -1;
      const nextScales: number[] = [...this.featureCardScales];
      nextScales[index] = 1.0;
      this.featureCardScales = nextScales;
    });
  }

  // 获取按钮文字
  private getButtonText(): string {
    switch (this.currentStep) {
      case WelcomeStep.Intro:
        if (!this.hasAcceptedTerms) return '阅读用户协议';
        if (!this.hasAcceptedPrivacy) return '阅读隐私政策';
        return '开启体验';
      case WelcomeStep.Features:
        return '下一步';
      case WelcomeStep.ApiDriven:
        return '下一步';
      case WelcomeStep.NumberAuth:
        if (!this.isVerified && this.isSkipAllowed) {
          return '暂时跳过';
        }
        return '下一步';
      case WelcomeStep.ApiIntro:
        return '开始配置';
      default:
        return '下一步';
    }
  }

  // 处理主按钮点击
  private handleMainButtonClick(): void {
    // 防止快速连续点击
    if (this.isNavigating) {
      return;
    }
    
    switch (this.currentStep) {
      case WelcomeStep.Intro:
        if (!this.hasAcceptedTerms) {
          this.openPolicySheet(PolicySheetType.Terms);
        } else if (!this.hasAcceptedPrivacy) {
          this.openPolicySheet(PolicySheetType.Privacy);
        } else {
          // 协议已确认，进入功能介绍页
          this.isNavigating = true;
          this.swiperController.showNext();
        }
        break;
      case WelcomeStep.Features:
        this.isNavigating = true;
        this.swiperController.showNext();
        break;
      case WelcomeStep.ApiDriven:
        this.showDisclaimerDialog();
        break;
      case WelcomeStep.NumberAuth:
        if (this.isVerified || this.isSkipAllowed) {
          this.isNavigating = true;
          this.swiperController.showNext();
        } else {
          promptAction.showToast({ message: '请先完成验证' });
        }
        break;
    }
  }

  private showDisclaimerDialog() {
    this.disclaimerDialogController = new CustomDialogController({
      builder: DisclaimerDialog({
        action: () => {
          if (this.isNavigating) return;
          this.isNavigating = true;
          this.hasAcceptedDisclaimer = true;
          this.swiperController.showNext();
        }
      }),
      autoCancel: false,
      alignment: DialogAlignment.Center,
      customStyle: true,
      backgroundColor: 'transparent'
    });
    this.disclaimerDialogController.open();
  }

  // 打开政策弹窗
  private openPolicySheet(type: PolicySheetType): void {
    this.currentPolicyType = type;
    this.policyController = new webview.WebviewController();
    
    this.policyDialogController = new CustomDialogController({
      builder: PolicyDialog({
        config: getPolicySheetConfig(this.currentPolicyType),
        webController: this.policyController,
        actionHandler: () => this.handlePolicyConfirmed()
      }),
      autoCancel: false,
      alignment: DialogAlignment.Center,
      customStyle: true,
      backgroundColor: 'transparent'
    });
    
    this.policyDialogController.open();
  }

  // 处理政策确认
  private handlePolicyConfirmed(): void {
    if (this.policyDialogController) {
      this.policyDialogController.close();
      this.policyDialogController = null;
    }

    if (this.currentPolicyType === PolicySheetType.Terms) {
      this.hasAcceptedTerms = true;
    } else if (this.currentPolicyType === PolicySheetType.Privacy) {
      this.hasAcceptedPrivacy = true;
    }
  }

  // 返回上一步
  private handleBack(): void {
    if (this.currentStep > WelcomeStep.Intro) {
      this.swiperController.showPrevious();
    }
  }

  // 介绍页内容
  @Builder
  IntroContent() {
    Column() {
      Blank()
      
      Image($r('app.media.foreground'))
        .width(140)
        .height(140)
        .objectFit(ImageFit.Contain)
        .borderRadius(70)
        .margin({ bottom: 40 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 600 }).combine(TransitionEffect.translate({ y: 20 })))

      Text('Voot')
        .fontSize(48)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ bottom: 12 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 600, delay: 100 }).combine(TransitionEffect.translate({ y: 20 })))

      Text('打破语言边界')
        .fontSize(20)
        .fontColor('#DDFFFFFF')
        .letterSpacing(4)
        .margin({ bottom: 24 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 600, delay: 200 }).combine(TransitionEffect.translate({ y: 20 })))

      Text('实时同声传译 · 多引擎支持 · 隐私安全')
        .fontSize(14)
        .fontColor('#88FFFFFF')
        .transition(TransitionEffect.OPACITY.animation({ duration: 600, delay: 300 }))

      Blank()
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

  @State backButtonScale: number = 1.0;
  @State isBackButtonActive: boolean = false;

  // ... existing code ...

  // Back Button Press
  private pressBackButton(): void {
    animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
      this.isBackButtonActive = true;
      this.backButtonScale = 0.9;
    });
  }

  private releaseBackButton(): void {
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.isBackButtonActive = false;
      this.backButtonScale = 1.0;
    });
  }

  // ... existing code ...

  @Builder
  PageHeader(title: string, subtitle: string) {
    Column() {
      Text(title)
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ top: 128, bottom: 8 })
        .alignSelf(ItemAlign.Start)
        .padding({ left: 24 })

      Text(subtitle)
        .fontSize(16)
        .fontColor('#AAFFFFFF')
        .alignSelf(ItemAlign.Start)
        .padding({ left: 24, right: 24 })
        .maxLines(3)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
  }

  // 功能介绍页内容
  @Builder
  FeaturesContent() {
    Column() {
      this.PageHeader('核心功能', '点击按钮，探索 Voot 的强大能力')

      Column() {
        // Feature Cards Grid
        Column() {
          // ... existing grid code ...
          // Row 1: xx xx x (span 2, 2, 1)
          Row({ space: 12 }) {
            ForEach(WELCOME_FEATURES.slice(0, 3), (feature: WelcomeFeature, index: number) => {
              this.FeatureCard(feature, index);
            })
          }
          .width('100%')
          .margin({ bottom: 12 })

          // Row 2: x xx xx (span 1, 2, 2)
          Row({ space: 12 }) {
            ForEach(WELCOME_FEATURES.slice(3, 6), (feature: WelcomeFeature, index: number) => {
              this.FeatureCard(feature, index + 3);
            })
          }
          .width('100%')
          .margin({ bottom: 12 })

          // Row 3: xx x x (手势、润色、扫描)
          Row({ space: 12 }) {
            ForEach(WELCOME_FEATURES.slice(6, 9), (feature: WelcomeFeature, index: number) => {
              this.FeatureCard(feature, index + 6);
            })
          }
          .width('100%')
        }
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .pointLight({
            illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
          })
          .buildEffect())
        .width('90%')
        .constraintSize({ maxWidth: 360 })
        .padding(16)
        .backgroundColor('#66190032')
        .borderColor('#cc794a9b')
        .borderRadius(18)
        .onAppear(() => {
          this.startSequentialBreathing();
        })
        .onDisAppear(() => {
          this.stopSequentialBreathing();
        })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  // API 驱动介绍页内容
  @Builder
  ApiDrivenContent() {
    Column() {
      this.PageHeader('自有 API 驱动', '连接您信任的大语言模型')

      Column() {
        // Icon
        Image($r('app.media.api'))
          .width(120)
          .height(120)
          .fillColor(Color.White)
          .objectFit(ImageFit.Contain)
          .margin({ bottom: 50 })

        // Description
        Text('连接你信任的大模型与密钥，无需依赖特定服务商，自由选择。\n\n隐私安全，由您掌握在手中。')
          .fontSize(16)
          .fontColor('#DDFFFFFF')
          .textAlign(TextAlign.Center)
          .lineHeight(28)
          .padding({ left: 32, right: 32 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  // 号码认证页内容
  @Builder
  NumberAuthContent() {
    Column() {
      this.PageHeader('手机号码认证', '以便我们对您的真实身份进行验证')

      Column() {
        Column({ space: 16 }) {
          // Option 1: One-click Login
          Button() {
            Row() {
              Image($r('app.media.mobiledata'))
                .width(40)
                .height(40)
                .objectFit(ImageFit.Contain)
                .fillColor('#3c1464')
                .margin({ right: 16 })
              
              Column() {
                Text('一键验证')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#3c1464')
                  .margin({ bottom: 4 })
                Text('快速验证本机号码')
                  .fontSize(14)
                  .fontColor('#663c1464')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Image($r('app.media.click'))
                .width(24)
                .height(24)
                .fillColor('#3c1464')
            }
            .width('100%')
            .padding(20)
          }
          .type(ButtonType.Normal)
          .backgroundColor(Color.White)
          .borderRadius(24)
          .height(88)
          .onClick(() => {
             this.createLoginAuth()
          })

          // Option 2: SMS Code Verify
          Button() {
            Row() {
              Image($r('app.media.message'))
                .width(40)
                .height(40)
                .objectFit(ImageFit.Contain)
                .fillColor(Color.White)
                .margin({ right: 16 })
              
              Column() {
                Text('验证码验证')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .margin({ bottom: 4 })
                Text('接收短信验证码验证')
                  .fontSize(14)
                  .fontColor('#AAFFFFFF')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Image($r('app.media.click'))
                .width(24)
                .height(24)
                .fillColor(Color.White)
            }
            .width('100%')
            .padding(20)
          }
          .type(ButtonType.Normal)
          .backgroundColor('#33FFFFFF')
          .borderRadius(24)
          .height(88)
          .onClick(() => {
            this.turnPage()
          })
        }
        .width('90%')
        .constraintSize({ maxWidth: 360 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column() {
        SymbolGlyph($r('sys.symbol.exclamationmark_shield_fill'))
          .fontSize(16)
          .fontColor([$r('sys.color.font_on_secondary')])
          .margin({ bottom: 8 })

        Text('手机号码是履行部分国家或地区法律法规关于网络实名制要求的必要信息，如果您不验证手机号码，我们可能无法为您提供生成式人工智能技术服务。')
          .fontSize(12)
          .fontColor($r('sys.color.font_on_secondary'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 32, right: 32, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  // API 介绍页内容
  @Builder
  ApiIntroContent() {
    Column() {
      this.PageHeader('配置 API', '连接顶尖 AI 模型引擎')

      Column() {
        Column({ space: 16 }) {
          // Option 1: I have a key
          Button() {
            Row() {
              Image($r('app.media.key')) // Placeholder icon
                .width(40)
                .height(40)
                .objectFit(ImageFit.Contain)
                .fillColor('#3c1464')
                .margin({ right: 16 })
              
              Column() {
                Text('我有 API 密钥')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#3c1464')
                  .margin({ bottom: 4 })
                Text('直接填入密钥开始使用')
                  .fontSize(14)
                  .fontColor('#663c1464')
              }
              .bindSheet(
                $$this.isSetupSheetOpen,
                this.SetupSheetContent(),
                {
                  detents: [SheetSize.MEDIUM, SheetSize.LARGE],
                  dragBar: true,
                  backgroundColor: '#F2F2F2',
                  blurStyle: BlurStyle.Thick,
                  enableOutsideInteractive: false,
                  onAppear: () => {console.log("BindSheet1 onAppear.")},
                  onDisappear: () => {console.log("BindSheet1 onDisappear.")}
                }
              )
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Image($r('app.media.click'))
                .width(24)
                .height(24)
                .fillColor('#3c1464')
            }
            .width('100%')
            .padding(20)
          }
          .type(ButtonType.Normal)
          .backgroundColor(Color.White)
          .borderRadius(24)
          .height(88)
          .onClick(() => {
            this.isSetupSheetOpen = true;
            this.validateConfig(); // Initial validation
          })

          // Option 2: No key
          Button() {
            Row() {
              Image($r('app.media.key_slash')) // Placeholder icon
                .width(40)
                .height(40)
                .objectFit(ImageFit.Contain)
                .fillColor(Color.White)
                .margin({ right: 16 })
              
              Column() {
                Text('我还没有 API 密钥')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .margin({ bottom: 4 })
                Text('了解原理与获取方式')
                  .fontSize(14)
                  .fontColor($r('sys.color.font_on_secondary'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .bindSheet(
                $$this.isKeyGuideSheetOpen,
                this.KeyGuideSheetContent(),
                {
                  detents: [SheetSize.MEDIUM, SheetSize.LARGE],
                  dragBar: true,
                  backgroundColor: '#F2F2F2',
                  blurStyle: BlurStyle.Thick,
                  enableOutsideInteractive: false,
                  onAppear: () => {console.log("BindSheet2 onAppear.")},
                  onDisappear: () => {console.log("BindSheet2 onDisappear.")}
                }
              )

              Image($r('app.media.click'))
                .width(24)
                .height(24)
                .fillColor(Color.White)
            }
            .width('100%')
            .padding(20)
          }
          .type(ButtonType.Normal)
          .backgroundColor('#33FFFFFF')
          .borderRadius(24)
          .height(88)
          .onClick(() => {
            this.isKeyGuideSheetOpen = true;
          })
        }
        .width('90%')
        .constraintSize({ maxWidth: 360 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 占位区域，与第三页底部提示信息高度一致
      Column()
        .width('100%')
        .height(100)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  SetupSheetContent() {
    Column() {
      // Header
      Text('配置翻译引擎')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ top: 24, bottom: 24 })
        .alignSelf(ItemAlign.Start)

      Scroll() {
        Column({ space: 24 }) {
          // Provider Selection
          Column({ space: 12 }) {
            Row({ space: 6 }) {
              Text('选择服务商')
                .fontSize(14)
                .fontColor('#666666')
                .fontWeight(FontWeight.Medium)
              
              // 当在CN、HK或MO地区且选择OpenAI时显示警告图标
              if ((this.detectedCountryCode === 'CN' || this.detectedCountryCode === 'HK' || this.detectedCountryCode === 'MO') && 
                  this.selectedProvider === ApiProvider.OpenAI) {
                SymbolGlyph($r('sys.symbol.info_circle_fill'))
                  .fontSize(16)
                  .fontColor([$r('sys.color.warning')])
                  .onClick(() => {
                    this.showOpenAIWarningPopup = true;
                  })
                  .bindPopup(this.showOpenAIWarningPopup, {
                    message: `OpenAI 在${this.getRegionName()}似乎不提供服务。请确认您能够访问该服务，并仔细阅读和遵守服务提供商的使用条款。`,
                    placementOnTop: false,
                    showInSubWindow: false,
                    primaryButton: {
                      value: '知道了',
                      action: () => {
                        this.showOpenAIWarningPopup = false;
                      }
                    },
                    onStateChange: (e) => {
                      if (!e.isVisible) {
                        this.showOpenAIWarningPopup = false;
                      }
                    },
                    backgroundBlurStyle: BlurStyle.BACKGROUND_REGULAR,
                    transition: TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.FastOutSlowIn })
                  })
              }
              
              // 当在CN地区且选择DeepL时显示网络警告图标
              if (this.detectedCountryCode === 'CN' && this.selectedProvider === ApiProvider.DeepL) {
                SymbolGlyph($r('sys.symbol.info_circle_fill'))
                  .fontSize(16)
                  .fontColor([$r('sys.color.warning')])
                  .onClick(() => {
                    this.showDeepLWarningPopup = true;
                  })
                  .bindPopup(this.showDeepLWarningPopup, {
                    message: `DeepL 服务在${this.getRegionName()}可能存在网络访问限制。请确认您能够正常连接该服务。`,
                    placementOnTop: false,
                    showInSubWindow: false,
                    primaryButton: {
                      value: '知道了',
                      action: () => {
                        this.showDeepLWarningPopup = false;
                      }
                    },
                    onStateChange: (e) => {
                      if (!e.isVisible) {
                        this.showDeepLWarningPopup = false;
                      }
                    },
                    backgroundBlurStyle: BlurStyle.BACKGROUND_REGULAR,
                    transition: TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.FastOutSlowIn })
                  })
              }
            }
            .alignSelf(ItemAlign.Start)

            Grid() {
              ForEach(PROVIDERS, (provider: ProviderInfo) => {
                GridItem() {
                  Column() {
                    Image(provider.icon)
                      .width(32)
                      .height(32)
                      .objectFit(ImageFit.Contain)
                      .margin({ bottom: 8 })
                    
                    Text(provider.name)
                      .fontSize(12)
                      .fontColor(this.selectedProvider === provider.id ? '#3c1464' : '#666666')
                      .fontWeight(this.selectedProvider === provider.id ? FontWeight.Bold : FontWeight.Normal)
                  }
                  .width('100%')
                  .height(80)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor(this.selectedProvider === provider.id ? '#1A3c1464' : '#F5F5F5')
                  .borderRadius(12)
                  .border({
                    width: 2,
                    color: this.selectedProvider === provider.id ? '#3c1464' : 'transparent'
                  })
                  .onClick(() => {
                    this.selectedProvider = provider.id;
                    this.apiUrl = provider.defaultUrl;
                    this.model = provider.defaultModel;
                    this.apiKey = ''; // Clear key on switch for safety/clarity
                    this.validateConfig();
                  })
                }
              })
            }
            .columnsTemplate('1fr 1fr 1fr 1fr')
            .rowsTemplate('1fr')
            .columnsGap(8)
            .height(80)
          }

          // Config Fields
          Column({ space: 16 }) {
            // API Key Field
            if (PROVIDERS[this.selectedProvider].needsApiKey) {
              Column({ space: 8 }) {
                Text('API Key (密钥)')
                  .fontSize(14)
                  .fontColor('#666666')
                  .fontWeight(FontWeight.Medium)
                  .alignSelf(ItemAlign.Start)
                
                TextInput({ placeholder: '请输入 API Key', text: this.apiKey })
                  .height(48)
                  .backgroundColor('#FFFFFF')
                  .borderRadius(12)
                  .padding({ left: 16, right: 16 })
                  .onChange((value: string) => {
                    this.apiKey = value;
                    this.validateConfig();
                  })
              }
            }

            // Model Field
            if (PROVIDERS[this.selectedProvider].needsModel) {
              Column({ space: 8 }) {
                Text('Model (模型)')
                  .fontSize(14)
                  .fontColor('#666666')
                  .fontWeight(FontWeight.Medium)
                  .alignSelf(ItemAlign.Start)
                
                TextInput({ 
                  placeholder: PROVIDERS[this.selectedProvider].modelPlaceholder, 
                  text: this.model 
                })
                  .height(48)
                  .backgroundColor('#FFFFFF')
                  .borderRadius(12)
                  .padding({ left: 16, right: 16 })
                  .onChange((value: string) => {
                    this.model = value;
                    this.validateConfig();
                  })
              }
            }

            // API URL Field
            Column({ space: 8 }) {
              Row() {
                Text('API URL (接口地址)')
                  .fontSize(14)
                  .fontColor('#666666')
                  .fontWeight(FontWeight.Medium)
                
                Blank()
                
                Text('恢复默认')
                  .fontSize(12)
                  .fontColor('#3c1464')
                  .onClick(() => {
                    this.apiUrl = PROVIDERS[this.selectedProvider].defaultUrl;
                    this.validateConfig();
                  })
              }
              .width('100%')
              
              TextInput({ 
                placeholder: PROVIDERS[this.selectedProvider].urlPlaceholder, 
                text: this.apiUrl 
              })
                .height(48)
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .padding({ left: 16, right: 16 })
                .onChange((value: string) => {
                  this.apiUrl = value;
                  this.validateConfig();
                })
            }
          }

          // Save Button
          Button(this.isTestingConnection ? '正在测试连接...' : '完成配置并开始')
            .width('100%')
            .height(52)
            .backgroundColor((this.isConfigValid && !this.isTestingConnection) ? '#3c1464' : '#CCCCCC')
            .enabled(this.isConfigValid && !this.isTestingConnection)
            .type(ButtonType.Capsule)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .margin({ top: 16, bottom: 32 })
            .onClick(() => {
              this.saveAndContinue();
            })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
    .backgroundColor(Color.Transparent)
  }

  @Builder
  KeyGuideSheetContent() {
    Column() {
      Text('什么是 API 密钥？')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ top: 24, bottom: 24 })
        .alignSelf(ItemAlign.Start)

      Scroll() {
        Column({ space: 16 }) {
          // Card 1: The Brain
          this.ConceptCard(
            $r('app.media.translation'),
            'Voot 是您的语言助手',
            '聆听、输入或扫描 → Voot 本地识别 → 将源语言送到模型提供商 → 翻译成目标语言或获取结果 → Voot 展示。翻译或润色本身由你选择和信任的“翻译引擎”（如 豆包/ OpenAI / DeepL / Ollama 等）来完成。',
            0
          )

          // Card 2: The Key
          this.ConceptCard(
            $r('app.media.brain'),
            'API Key 是连接大脑的钥匙',
            'API Key 通常是一串字符。它是服务商发给你的“通行证”，用来证明“这是你的账号在调用”，并把用量/费用记到你的账户上。请像密码一样保管：不要公开、不要转发给陌生人。',
            100
          )

          // Card 3: The Flow
          this.ConceptCard(
            $r('app.media.cloud'),
            '如何工作？',
            '在服务商后台创建 API Key → 粘贴到这里 → 点“完成配置并开始”。之后 Voot 会用它向该服务商发起加密请求并拿回结果；不想使用时也可以在服务商后台随时撤销/重新生成，Voot 并不干预。',
            200
          )

          // Security Note
          Row() {
            Image($r('app.media.privacy'))
              .width(24)
              .height(24)
              .fillColor('#3c1464')
              .margin({ right: 12 })
            
            Text('安全提示：Key 仅保存在这台设备上；请求直连你选择的服务商，不会经过 Voot 的服务器（Voot 也并不持有面向用户的服务器）。若选择云端服务（如 豆包（火山引擎）/ OpenAI / DeepL），内容会发送到对应服务商；选择本地/局域网服务（如 Ollama）则不会。')
              .fontSize(13)
              .fontColor('#3c1464')
              .layoutWeight(1)
              .lineHeight(20)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#1A3c1464')
          .borderRadius(16)
          .margin({ top: 8 })
        }
        .width('100%')
        .padding({ bottom: 48 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
    .backgroundColor(Color.Transparent)
  }

  @Builder
  ConceptCard(icon: Resource, title: string, desc: string, delay: number) {
    Column() {
      Row() {
        Image(icon)
          .width(48)
          .height(48)
          .objectFit(ImageFit.Contain)
          .fillColor('#3c1464')
          .margin({ right: 16 })
          .padding(8)
          .backgroundColor('#1A3c1464')
          .borderRadius(12)
        
        Column() {
          Text(title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ bottom: 4 })
          
          Text(desc)
            .fontSize(14)
            .fontColor('#666666')
            .lineHeight(22)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .shadow({ radius: 20, color: '#0D000000', offsetY: 4 })
    .transition(TransitionEffect.OPACITY.animation({ duration: 600, delay: delay })
      .combine(TransitionEffect.translate({ y: 20 })))
  }

  @Builder
  ApiStepRow(num: string, title: string, desc: string) {
    Row() {
      Text(num)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3c1464')
        .backgroundColor(Color.White)
        .width(24)
        .height(24)
        .textAlign(TextAlign.Center)
        .borderRadius(12)
        .margin({ right: 16 })

      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .margin({ bottom: 4 })
        
        Text(desc)
          .fontSize(13)
          .fontColor('#AAFFFFFF')
      }
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }

  // 功能卡片组件
  @Builder
  FeatureCard(feature: WelcomeFeature, index: number) {
    Button() {
      Column() {
        Image(feature.icon)
          .width(32)
          .height(32)
          .objectFit(ImageFit.Contain)
          .fillColor((this.activeFeatureCard === index || feature.title === '隐私守护' || feature.title === '手势') ? '#3c1464' : Color.White)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .type(ButtonType.Normal)
    .backgroundColor((this.activeFeatureCard === index || feature.title === '隐私守护' || feature.title === '手势') ? Color.White : "#b33c1464")
    .layoutWeight(feature.span)
    .aspectRatio(feature.span)
    .borderRadius(999)
    .shadow({
      radius: 18,
      color: '#22000000',
      offsetY: 2,
      offsetX: 0
    })
    .scale({
      x: this.featureCardScales[index] * this.breathingScales[index],
      y: this.featureCardScales[index] * this.breathingScales[index]
    })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: (this.activeFeatureCard === index || feature.title === '隐私守护' || feature.title === '手势')
          ? hdsEffect.PointLightSourceType.SOFT
          : hdsEffect.PointLightSourceType.NONE,
        illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
      })
      .buildEffect())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressFeatureCard(index);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.releaseFeatureCard(index);
      }
    })
    .onClick(() => {
      this.currentFeatureIndex = index;
      this.featureDialogController.open();
    })
  }

  private helper: PhoneNumberAuthHelper | undefined;

  public async turnPage() {
    console.info('Turn page clicked');
    router.pushUrl({
      url: 'pages/VerifyPage',
    }).catch((err: Error) => {
      console.log("====" + err.message)
    })
  }

  public createLoginAuth() {
    class TokenListener implements TokenResultListener {
      private page: WelcomePage

      constructor(page: WelcomePage) {
        this.page = page;
      }

      onSuccess(msg: string): void {
        console.log("auth:onSuccess:" + msg)
        const result: object = JSON.parse(msg)
        const code = result['_code'] + ''
        const token = result['_token'] + ''
        if (code == "600000") {
          this.page.quitLoginPage()
          promptAction.showToast({ message: '验证成功' });
          AppStorage.setOrCreate('isNumberVerified', true);
          OnboardingStorage.setNumberVerified(getContext(this.page) as common.UIAbilityContext, true);
          this.page.swiperController.showNext();
        }
      }

      onFailure(ret: string): void {
        console.log("auth:onFailure:" + ret)
        this.page.updateAuth()
        try {
          const result: Record<string, string> = JSON.parse(ret) as Record<string, string>
          const code: string = result['_code']
          // 700000: 用户取消登录/点击返回，不提示错误
          if (code !== '700000') {
            const msg: string = result['_msg'] || '验证失败'
            promptAction.showToast({ message: msg });
          }
        } catch (e) {
          promptAction.showToast({ message: '验证失败' });
        }
      }

    }
    let listener = new TokenListener(this)
    this.helper = PhoneNumberAuthHelper.getInstance(getContext(this), listener)
    let uiConfig: AuthUiConfig = new AuthUiConfig();
    
    // 号码栏样式
    uiConfig.numberMargin = { top: 220 }
    uiConfig.numberFontColor = '#FFFFFF'
    uiConfig.numberFontSize = 24

    // 登录按钮样式
    uiConfig.loginBtnText = "本机号码一键验证"
    uiConfig.loginBtnWidth = '80%'
    uiConfig.loginBtnHeight = 50
    uiConfig.loginBtnBackGroundColor = $r('sys.color.comp_background_primary')
    uiConfig.loginBtnDisableBackGroundColor = $r('sys.color.comp_background_tertiary')
    uiConfig.loginBtnFontColor = '#3c1464'
    uiConfig.loginBtnFontSize = 18
    uiConfig.loginBtnBorder = 25 // Number!
    uiConfig.loginBtnMargin = { top: 320 }
    uiConfig.loginBtnAlignRuleOption = {
      middle: { anchor: '__container__', align: HorizontalAlign.Center },
      top: { anchor: '__container__', align: VerticalAlign.Top },
    }

    // 弹窗
    uiConfig.needShowPrivacyAlert = false

    // 协议栏样式
    uiConfig.privacySpanBeforeFontColor = $r('sys.color.font_on_primary')
    uiConfig.privacySpanBeforeText = "阿里云提供认证服务，验证即代表同意"
    uiConfig.privacySpanEndText = '。验证仅本次有效，手机号码不会提供给应用。'
    uiConfig.privacyFontColor = $r('sys.color.font_emphasize')
    uiConfig.privacySpanEndFontColor = $r('sys.color.font_on_primary')
    uiConfig.privacyCbTipText = '请阅读并勾选协议'
    
    // Checkbox 布局
    uiConfig.privacyCbWidth = 20
    uiConfig.privacyCbHeight = 20
    uiConfig.privacyCbSelectColor = $r('sys.color.confirm')
    uiConfig.privacyCbMargin = { left: 30, bottom: 66 }
    uiConfig.privacyCbAlignRuleOption = {
      left: { anchor: '__container__', align: HorizontalAlign.Start },
      bottom: { anchor: '__container__', align: VerticalAlign.Bottom }
    }

    // 协议文本布局
    uiConfig.privacyMargin = { left: 60, right: 24, bottom: 40 }
    uiConfig.privacyAlignRuleOption = {
      left: { anchor: '__container__', align: HorizontalAlign.Start },
      bottom: { anchor: '__container__', align: VerticalAlign.Bottom }
    }

    uiConfig.loginPageComponent = wrapBuilder(clauseComponent)
    this.helper?.setAuthConfig(uiConfig)

    class UIListener implements AuthUIControlClickListener {
      onClick(code: string, jsonString: string): void {
        console.log("===" + code + "   " + jsonString);
      }
    }
    let clicklistener = new UIListener()
    this.helper.setUIClickListener(clicklistener)
    this.helper.checkEnvAvailable(1)
    
    // Use SDK key from config file
    if (this.authSdkKey) {
      this.helper.setAuthSDKInfo(this.authSdkKey)
    } else {
      console.error('Auth SDK key not loaded from config')
    }
    
    this.helper.getLoginToken(5000)
    
    bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_SIGNATURE_INFO).then((bundleInfo) => {
      const packageName = bundleInfo.name
      console.log("numberauth:pagname:" + packageName)
      const sign = bundleInfo.signatureInfo.fingerprint
      console.log("numberauth:sign:" + sign)
      const appIdentifier = bundleInfo.signatureInfo.appIdentifier
      console.log("numberauth:appid:" + appIdentifier)
    })
  }

  private quitLoginPage() {
    this.helper?.quitLoginPage()
    this.helper?.setAuthListener(undefined)
  }

  private updateAuth() {
    this.helper?.setAuthListener(undefined)
  }

  build() {
    Stack() {
      // Background
      Image($r('app.media.app_background_pic_voot_purple'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .blur(20)

      // Overlay gradient
      Rect()
        .width('100%')
        .height('100%')
        .fill(Color.Transparent)
        .linearGradient({
          angle: this.gradientAngle,
          colors: [['#AA000000', 0.0], ['#663c1464', 1.0]]
        })
        .onAppear(() => {
          animateTo({
            duration: 5000,
            curve: Curve.Linear,
            iterations: -1,
            playMode: PlayMode.Normal
          }, () => {
            this.gradientAngle = 360;
          })
        })

      Column() {
        Swiper(this.swiperController) {
          this.IntroContent()
          this.FeaturesContent()
          this.ApiDrivenContent()
          this.NumberAuthContent()
          this.ApiIntroContent()
        }
        .index(this.currentStep)
        .layoutWeight(1)
        .width('100%')
        .loop(false)
        .disableSwipe(
          // 第一页：未同意协议时禁止滑动
          (this.currentStep === WelcomeStep.Intro && (!this.hasAcceptedTerms || !this.hasAcceptedPrivacy)) ||
          // 第三页：未确认免责声明时禁止向后滑动
          (this.currentStep === WelcomeStep.ApiDriven && !this.hasAcceptedDisclaimer) ||
          // 第四页：未完成验证且不允许跳过时禁止向后滑动
          (this.currentStep === WelcomeStep.NumberAuth && !this.isVerified && !this.isSkipAllowed)
        )
        .indicator(
          Indicator.dot()
            .itemWidth(8)
            .itemHeight(8)
            .selectedItemWidth(24)
            .selectedItemHeight(8)
            .color('#44FFFFFF')
            .selectedColor(Color.White)
        )
        .onChange((index: number) => {
          // 重置导航状态，允许下一次点击
          this.isNavigating = false;
          
          animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
            this.currentStep = index;
          });
          
          if (index === WelcomeStep.Features) {
            this.startSequentialBreathing();
          } else {
            this.stopSequentialBreathing();
          }
          
          // 在第三页（ApiDriven）时提前进行IP检测
          if (index === WelcomeStep.ApiDriven) {
            this.checkIpLocation();
          }
        })

        // Bottom Area
        Column() {
          Row() {
            if (this.currentStep > WelcomeStep.Intro) {
              Button('返回')
                .type(ButtonType.Capsule)
                .backgroundColor('#22FFFFFF')
                .fontColor(Color.White)
                .layoutWeight(1)
                .height(56)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .margin({ right: this.currentStep === WelcomeStep.ApiIntro ? 0 : 16 })
                .scale({ x: this.backButtonScale, y: this.backButtonScale })
                .visualEffect(new hdsEffect.HdsEffectBuilder()
                  .pointLight({
                    sourceType: this.isBackButtonActive
                      ? hdsEffect.PointLightSourceType.SOFT
                      : hdsEffect.PointLightSourceType.NONE,
                    illuminatedType: this.isBackButtonActive
                      ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
                      : hdsEffect.PointLightIlluminatedType.NONE
                  })
                  .buildEffect())
                .onTouch((event: TouchEvent) => {
                  if (event.type === TouchType.Down) this.pressBackButton();
                  else if (event.type === TouchType.Up || event.type === TouchType.Cancel) this.releaseBackButton();
                })
                .onClick(() => {
                  if (this.isNavigating) return;
                  this.isNavigating = true;
                  this.swiperController.showPrevious();
                })
                .transition(TransitionEffect.OPACITY.animation({ duration: 300 })
                  .combine(TransitionEffect.translate({ x: -20 })))
            }

            if (this.currentStep !== WelcomeStep.ApiIntro) {
              Button(this.getButtonText())
                .type(ButtonType.Capsule)
                .backgroundColor(
                  (this.currentStep === WelcomeStep.NumberAuth && !this.isVerified && !this.isSkipAllowed) 
                  ? '#CCCCCC' 
                  : Color.White
                )
                .fontColor(
                  (this.currentStep === WelcomeStep.NumberAuth && !this.isVerified && !this.isSkipAllowed) 
                  ? '#666666' 
                  : '#3c1464'
                )
                .layoutWeight(1)
                .height(56)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .scale({ x: this.buttonScale, y: this.buttonScale })
                .shadow({ 
                  radius: 20, 
                  color: (this.currentStep === WelcomeStep.NumberAuth && !this.isVerified && !this.isSkipAllowed) ? '#00000000' : '#443c1464', 
                  offsetY: 8 
                })
                .visualEffect(new hdsEffect.HdsEffectBuilder()
                  .pointLight({
                    sourceType: this.isButtonActive
                      ? hdsEffect.PointLightSourceType.SOFT
                      : hdsEffect.PointLightSourceType.NONE,
                    illuminatedType: this.isButtonActive
                      ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
                      : hdsEffect.PointLightIlluminatedType.NONE
                  })
                  .buildEffect())
                .onTouch((event: TouchEvent) => {
                  if (event.type === TouchType.Down) this.pressButton();
                  else if (event.type === TouchType.Up || event.type === TouchType.Cancel) this.releaseButton();
                })
                .onClick(() => this.handleMainButtonClick())
            }
          }
          .width('100%')
          .padding({ left: 32, right: 32 })
          .margin({ bottom: 24 })

          // Policy Hint (Moved below buttons)
          if (this.currentStep === WelcomeStep.Intro) {
            Row() {
              Checkbox()
                .select(this.hasAcceptedTerms && this.hasAcceptedPrivacy)
                .selectedColor('#3c1464')
                .width(16)
                .height(16)
                .margin({ right: 8 })
                .enabled(false)
              
              Text() {
                Span('继续即代表同意 ')
                Span('用户协议')
                  .fontColor(Color.White)
                  .decoration({ type: TextDecorationType.Underline })
                  .onClick(() => {
                    this.openPolicySheet(PolicySheetType.Terms);
                  })
                Span(' 和 ')
                Span('隐私政策')
                  .fontColor(Color.White)
                  .decoration({ type: TextDecorationType.Underline })
                  .onClick(() => {
                    this.openPolicySheet(PolicySheetType.Privacy);
                  })
              }
              .fontSize(12)
              .fontColor('#AAFFFFFF')
            }
          }
        }
        .margin({ bottom: 48 })
      }
      .width('100%')
      .height('100%')
    }


  }
}

@CustomDialog
struct PolicyDialog {
  controller: CustomDialogController
  config: PolicySheetConfig = { title: '', intro: '', action: '', useWeb: false }
  webController: webview.WebviewController = new webview.WebviewController()
  actionHandler: () => void = () => {}
  
  build() {
    Column() {
      PolicySheetContent(
        this.config,
        this.webController,
        this.actionHandler,
        getContext(this) as common.UIAbilityContext
      )
    }
    .backgroundColor('#3c1464')
    .borderRadius(24)
    .width('90%')
  }
}

// 功能介绍对话框
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

@CustomDialog
struct DisclaimerDialog {
  controller: CustomDialogController
  action: () => void = () => {}

  build() {
    Column() {
      Text('模型与密钥')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.Black)
        .margin({ bottom: 16 })

      Text('请确认您了解什么是〖API〗和〖密钥〗，您也可以稍后在验证手机号码后了解。Voot 是一款依赖大模型运行的语言处理工具，不提供任何公共语言处理服务或内置密钥。\n\n您需要使用自己的 API 密钥（包括但不限于 豆包、OpenAI、DeepL 等）来驱动功能。\n\n请确保您遵守相关大模型服务商的使用条款以及当地的法律法规。')
        .fontSize(16)
        .fontColor(Color.Gray)
        .textAlign(TextAlign.Center)
        .lineHeight(24)
        .margin({ bottom: 24 })

      Row() {
        Button('取消')
          .layoutWeight(1)
          .height(48)
          .backgroundColor('#F2F2F2')
          .fontColor('#666666')
          .margin({ right: 12 })
          .onClick(() => {
            this.controller.close()
          })

        Button('我已知晓')
          .layoutWeight(1)
          .height(48)
          .backgroundColor('#3c1464')
          .onClick(() => {
            this.controller.close()
            this.action()
          })
      }
      .width('100%')
    }
    .width(300)
    .padding(32)
    .backgroundColor(Color.White)
    .borderRadius(24)
    .shadow({ radius: 32, color: '#44000000', offsetY: 8 })
  }
}

@Builder
export function clauseComponent(): void {
  // Background Layer
  Stack() {
    Image($r('app.media.app_background_pic_voot_purple'))
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Cover)
      .blur(20)

    Rect()
      .width('100%')
      .height('100%')
      .fill(Color.Transparent)
      .linearGradient({
        angle: 180,
        colors: [['#AA000000', 0.0], ['#663c1464', 1.0]]
      })
  }
  .width('100%')
  .height('100%')
  .alignRules({
    top: { anchor: '__container__', align: VerticalAlign.Top },
    left: { anchor: '__container__', align: HorizontalAlign.Start },
    bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
    right: { anchor: '__container__', align: HorizontalAlign.End }
  })

  // Logo Layer
  Image($r('app.media.person_crop'))
    .fillColor(Color.White)
    .width('80vp')
    .height('80vp')
    .margin({top:120})
    .alignRules({
      middle: { anchor: '__container__', align: HorizontalAlign.Center },
      top: { anchor: '__container__', align: VerticalAlign.Top },
    })
}
