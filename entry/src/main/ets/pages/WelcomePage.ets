/**
 * @fileoverview Welcome Page
 * 展示应用介绍
 */
import router from '@ohos.router';
import http from '@ohos.net.http';
import promptAction from '@ohos.promptAction';
import { hdsEffect } from '@kit.UIDesignKit';
import common from '@ohos.app.ability.common';
import { webview } from '@kit.ArkWeb';
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
  ApiIntro = 2,     // API介绍页（第三页）
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
    title: '隔空手势',
    description: '通过手势控制翻译、字幕与传译，无需触摸屏幕。',
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
  @State currentStep: WelcomeStep = WelcomeStep.Intro;
  @State isPolicySheetOpen: boolean = false;
  @State currentPolicyType: PolicySheetType = PolicySheetType.Terms;
  @State hasAcceptedTerms: boolean = false;
  @State hasAcceptedPrivacy: boolean = false;
  @State hasAcceptedDisclaimer: boolean = false;
  @State buttonScale: number = 1.0;
  @State isButtonActive: boolean = false;
  @State pageIndicatorIndex: number = 0;

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
      polishPromptText: '你是一个专业的文本润色助手。请对以下文本进行润色优化，使其更加通顺、专业、易读。\n\n要求：\n1. 保持原文的核心意思不变\n2. 优化语法和表达方式\n3. 直接输出润色后的文本，不要添加任何解释\n\n原文：\n{text}',
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
      subtitleHeight: 20,
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
    let index = 0;
    this.breathingTimer = setInterval(() => {
      // Pulse current card
      animateTo({ duration: 600, curve: Curve.EaseInOut }, () => {
        this.breathingScales[index] = 1.05;
      });
      
      setTimeout(() => {
        animateTo({ duration: 600, curve: Curve.EaseInOut }, () => {
          this.breathingScales[index] = 1.0;
        });
      }, 600);

      index = (index + 1) % this.breathingScales.length;
    }, 1200);
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
      case WelcomeStep.ApiIntro:
        return '开始配置';
      default:
        return '下一步';
    }
  }

  // 处理主按钮点击
  private handleMainButtonClick(): void {
    switch (this.currentStep) {
      case WelcomeStep.Intro:
        if (!this.hasAcceptedTerms) {
          this.openPolicySheet(PolicySheetType.Terms);
        } else if (!this.hasAcceptedPrivacy) {
          this.openPolicySheet(PolicySheetType.Privacy);
        } else {
          // 协议已确认，进入功能介绍页
          this.swiperController.showNext();
        }
        break;
      case WelcomeStep.Features:
        this.showDisclaimerDialog();
        break;
    }
  }

  private showDisclaimerDialog() {
    this.disclaimerDialogController = new CustomDialogController({
      builder: DisclaimerDialog({
        action: () => {
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
        .shadow({ radius: 40, color: '#66000000', offsetY: 10 })
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
        .margin({ top: 48, bottom: 8 })
        .alignSelf(ItemAlign.Start)
        .padding({ left: 24 })

      Text(subtitle)
        .fontSize(16)
        .fontColor('#AAFFFFFF')
        .margin({ bottom: 32 })
        .alignSelf(ItemAlign.Start)
        .padding({ left: 24 })
    }
    .width('100%')
  }

  // 功能介绍页内容
  @Builder
  FeaturesContent() {
    Column() {
      this.PageHeader('核心功能', '点击按钮，探索 Voot 的强大能力')

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

        // Row 3: xx x x (隔空手势、润色、扫描)
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
      .backgroundColor('#8d3c1464')
      .borderRadius(18)
      .onAppear(() => {
        this.startSequentialBreathing();
      })
      .onDisAppear(() => {
        this.stopSequentialBreathing();
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  // API 介绍页内容
  @Builder
  ApiIntroContent() {
    Column() {
      this.PageHeader('配置 API', '连接顶尖 AI 翻译引擎')

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
              Text('我有 API Key')
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
              Text('我还没有 API Key')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .margin({ bottom: 4 })
              Text('了解原理与获取方式')
                .fontSize(14)
                .fontColor('#AAFFFFFF')
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
        .onClick(() => {
          this.isKeyGuideSheetOpen = true;
        })
      }
      .width('90%')
      .constraintSize({ maxWidth: 360 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
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
            Text('选择服务商')
              .fontSize(14)
              .fontColor('#666666')
              .fontWeight(FontWeight.Medium)
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
          .fillColor((this.activeFeatureCard === index || feature.title === '隐私守护' || feature.title === '隔空手势') ? '#3c1464' : Color.White)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .type(ButtonType.Normal)
    .backgroundColor((this.activeFeatureCard === index || feature.title === '隐私守护' || feature.title === '隔空手势') ? Color.White : "#b33c1464")
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
        sourceType: (this.activeFeatureCard === index || feature.title === '隐私守护' || feature.title === '隔空手势')
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
          this.ApiIntroContent()
        }
        .layoutWeight(1)
        .width('100%')
        .loop(false)
        .disableSwipe(
          (!this.hasAcceptedTerms || !this.hasAcceptedPrivacy) || 
          (this.currentStep === WelcomeStep.Features && !this.hasAcceptedDisclaimer)
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
          animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
            this.currentStep = index;
          });
          
          if (index === WelcomeStep.Features) {
            this.startSequentialBreathing();
          } else {
            this.stopSequentialBreathing();
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
                  this.swiperController.showPrevious();
                })
                .transition(TransitionEffect.OPACITY.animation({ duration: 300 })
                  .combine(TransitionEffect.translate({ x: -20 })))
            }

            if (this.currentStep !== WelcomeStep.ApiIntro) {
              Button(this.getButtonText())
                .type(ButtonType.Capsule)
                .backgroundColor(Color.White)
                .fontColor('#3c1464')
                .layoutWeight(1)
                .height(56)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .scale({ x: this.buttonScale, y: this.buttonScale })
                .shadow({ radius: 20, color: '#443c1464', offsetY: 8 })
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

      Text('请确认您了解什么是〖API〗和〖密钥〗，您也可以稍后进入下一页了解。Voot 是一款依赖大模型运行的语言处理工具，不提供任何公共语言处理服务或内置密钥。\n\n您需要使用自己的 API 密钥（包括但不限于 豆包、OpenAI、DeepL 等）来驱动功能。\n\n请确保您遵守相关大模型服务商的使用条款以及当地允许的法律法规。')
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
