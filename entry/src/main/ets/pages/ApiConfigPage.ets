import { hdsEffect, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode, HdsActionBar, ActionBarButton, ActionBarStyle } from '@kit.UIDesignKit';
import { MultiKeySlots, MAX_KEY_SLOTS } from '../storage/ApiConfigStorage';
import http from '@ohos.net.http';
import promptAction from '@ohos.promptAction';
import { ColorMetrics } from '@kit.ArkUI';

const TITLE_BAR_HEIGHT_MINI: number = 84;

export enum ApiMenuType {
  Prompt = 0,
  Glossary,
  OpenAI,
  DeepL,
  Ollama,
  Doubao
}

// 密钥槽位切换器组件
@Component
struct KeySlotSwitcher {
  @Prop currentSlotIndex: number = 0;
  @Prop totalSlots: number = MAX_KEY_SLOTS;
  @Prop hasApiKey: boolean = false;
  onSwitchSlot: (index: number) => void = () => {};
  onEditSlot: () => void = () => {};
  @State isExpand: boolean = true;

  build() {
    Column() {
      // 槽位指示器（在 ActionBar 上面）
      Row() {
        ForEach([0, 1, 2], (index: number) => {
          Text((index + 1).toString())
            .fontSize(12)
            .fontWeight(this.currentSlotIndex === index ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.currentSlotIndex === index ? Color.White : Color.Gray)
            .width(24)
            .height(24)
            .textAlign(TextAlign.Center)
            .borderRadius(12)
            .backgroundColor(this.currentSlotIndex === index ? '#bf3c1464' : Color.Transparent)
            .border({ width: 1, color: this.currentSlotIndex === index ? '#3c1464' : Color.Gray })
            .margin({ left: 4, right: 4 })
            .onClick(() => {
              this.onSwitchSlot(index);
            })
        })
      }
      .margin({ bottom: 6 })

      // ActionBar
      HdsActionBar({
        startButtons: [new ActionBarButton({
          baseIcon: $r('sys.symbol.chevron_left'),
          onClick: () => {
            if (this.currentSlotIndex > 0) {
              this.onSwitchSlot(this.currentSlotIndex - 1);
            }
          },
          hoverTips: '上一个槽位'
        })],
        endButtons: [new ActionBarButton({
          baseIcon: $r('sys.symbol.chevron_right'),
          onClick: () => {
            if (this.currentSlotIndex < this.totalSlots - 1) {
              this.onSwitchSlot(this.currentSlotIndex + 1);
            }
          },
          hoverTips: '下一个槽位'
        })],
        primaryButton: new ActionBarButton({
          baseIcon: this.hasApiKey ? $r('sys.symbol.pencil_waveform') : $r('sys.symbol.plus'),
          onClick: () => {
            this.isExpand = !this.isExpand;
            this.onEditSlot();
          },
          backgroundColor: ColorMetrics.rgba(60, 20, 100, 1),
          hoverTips: this.hasApiKey ? '编辑槽位 ' + (this.currentSlotIndex + 1).toString() : '添加密钥'
        }),
        actionBarStyle: new ActionBarStyle({
          isPrimaryIconChanged: false
        }),
        isExpand: this.isExpand!
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: 16 })
  }
}

// NOTE: Interface kept for type safety, but implementation will use component props
export interface ApiConfigPageProps {
  selectedMenu: ApiMenuType;
  promptText: string;
  // 多密钥槽位
  openAiKeySlots: MultiKeySlots;
  deepLKeySlots: MultiKeySlots;
  ollamaKeySlots: MultiKeySlots;
  doubaoKeySlots: MultiKeySlots;
  // 兼容旧版单密钥字段
  openAiApiUrl: string;
  openAiApiKey: string;
  openAiModel: string;
  deepLApiUrl: string;
  deepLApiKey: string;
  ollamaApiUrl: string;
  ollamaModel: string;
  doubaoApiUrl: string;
  doubaoApiKey: string;
  doubaoModel: string;
  glossary: string;
  onBack: () => void;
  onSelectMenu: (menu: ApiMenuType) => void;
  onUpdatePrompt: (value: string) => void;
  // 槽位切换回调
  onSwitchOpenAiSlot: (index: number) => void;
  onSwitchDeepLSlot: (index: number) => void;
  onSwitchOllamaSlot: (index: number) => void;
  onSwitchDoubaoSlot: (index: number) => void;
  // 更新槽位内容回调
  onUpdateOpenAiApiUrl: (value: string) => void;
  onUpdateOpenAiApiKey: (value: string) => void;
  onUpdateOpenAiModel: (value: string) => void;
  onUpdateDeepLApiUrl: (value: string) => void;
  onUpdateDeepLApiKey: (value: string) => void;
  onUpdateOllamaApiUrl: (value: string) => void;
  onUpdateOllamaModel: (value: string) => void;
  onUpdateDoubaoApiUrl: (value: string) => void;
  onUpdateDoubaoApiKey: (value: string) => void;
  onUpdateDoubaoModel: (value: string) => void;
  onUpdateGlossary: (value: string) => void;
  getConfigTextAreaHeight: (rows: number) => number;
}

// --- 1. Menu Button Component with Effects ---
@Component
struct MenuButton {
  @Prop label: string;
  @Prop menuType: ApiMenuType;
  @Prop isSelected: boolean;
  @Prop isLightEffectBright: boolean = true;
  @Prop isDarkMode: boolean = true;

  // Lighting Props
  @Prop isSource: boolean;      // True if THIS button is touched
  @Prop isIlluminated: boolean; // True if ANY button is touched

  // Callbacks
  onClickAction: () => void = () => {};
  onTouchStart: () => void = () => {};
  onTouchEnd: () => void = () => {};

  build() {
    Button() {
      Row() {
        Image($r('app.media.'+ this.label))
          .width(20)
          .height(20)
          .fillColor(Color.White)

        Text(" " + this.label)
          .layoutWeight(1)
          .fontSize(15)
          .fontWeight(this.isSelected ? FontWeight.Medium : FontWeight.Normal);

        if (this.isSelected) {
          Text('·')
            .fontColor(Color.White)
            .fontSize(20)
            .fontWeight(FontWeight.Bold);
        }
      }
      .width('100%');
    }
    .type(ButtonType.Capsule)
    .fontColor(Color.White)
    .width('100%')
    .height(44)
    .padding({ left: 12, right: 12 })
    .margin({ bottom: 8 })
    .backgroundColor(Color.Transparent)
    .borderRadius(12)
    .border({ width: 0 })
    // --- APPLY VISUAL EFFECT HERE ---
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
          (this.isSource
          ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
          : hdsEffect.PointLightSourceType.NONE),
        illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE :
          (this.isIlluminated
          ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
          : hdsEffect.PointLightIlluminatedType.NONE)
      })
      .buildEffect())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.onTouchStart();
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.onTouchEnd();
      }
    })
    .onClick(() => this.onClickAction());
  }
}

@Component
export struct ApiConfigPage {
  // Props
  @Prop selectedMenu: ApiMenuType = ApiMenuType.Prompt;
  @Prop promptText: string = "";
  // 多密钥槽位
  @Prop openAiKeySlots: MultiKeySlots = { slots: [], currentSlotIndex: 0 };
  @Prop deepLKeySlots: MultiKeySlots = { slots: [], currentSlotIndex: 0 };
  @Prop ollamaKeySlots: MultiKeySlots = { slots: [], currentSlotIndex: 0 };
  @Prop doubaoKeySlots: MultiKeySlots = { slots: [], currentSlotIndex: 0 };
  // 兼容旧版字段
  @Prop openAiApiUrl: string = "";
  @Prop openAiApiKey: string = "";
  @Prop openAiModel: string = "";
  @Prop deepLApiUrl: string = "";
  @Prop deepLApiKey: string = "";
  @Prop ollamaApiUrl: string = "";
  @Prop ollamaModel: string = "";
  @Prop doubaoApiUrl: string = "";
  @Prop doubaoApiKey: string = "";
  @Prop doubaoModel: string = "";
  @Prop glossary: string = "";
  @Prop isLightEffectBright: boolean = true;
  @Prop isDarkMode: boolean = true;

  // Callbacks (Initialized to empty functions)
  onBack: () => void = () => {};
  onSelectMenu: (menu: ApiMenuType) => void = () => {};
  onUpdatePrompt: (value: string) => void = () => {};
  // 槽位切换回调
  onSwitchOpenAiSlot: (index: number) => void = () => {};
  onSwitchDeepLSlot: (index: number) => void = () => {};
  onSwitchOllamaSlot: (index: number) => void = () => {};
  onSwitchDoubaoSlot: (index: number) => void = () => {};
  // 更新内容回调
  onUpdateOpenAiApiUrl: (value: string) => void = () => {};
  onUpdateOpenAiApiKey: (value: string) => void = () => {};
  onUpdateOpenAiModel: (value: string) => void = () => {};
  onUpdateDeepLApiUrl: (value: string) => void = () => {};
  onUpdateDeepLApiKey: (value: string) => void = () => {};
  onUpdateOllamaApiUrl: (value: string) => void = () => {};
  onUpdateOllamaModel: (value: string) => void = () => {};
  onUpdateDoubaoApiUrl: (value: string) => void = () => {};
  onUpdateDoubaoApiKey: (value: string) => void = () => {};
  onUpdateDoubaoModel: (value: string) => void = () => {};
  onUpdateGlossary: (value: string) => void = () => {};
  // Helper for TextArea height
  getConfigTextAreaHeight: (rows: number) => number = (rows: number) => rows * 20;

  // --- STATE FOR LIGHTING EFFECT ---
  // Tracks which menu ID is currently being touched. -1 means none.
  @State activeMenuId: number = -1;
  // State for sidebar visibility
  @State isSideBarShown: boolean = false;

  // --- 半模态弹窗状态 ---
  @State isKeyEditSheetOpen: boolean = false;
  @State editingApiUrl: string = '';
  @State editingApiKey: string = '';
  @State editingModel: string = '';
  @State isTestingConnection: boolean = false;
  @State isConfigValid: boolean = false;

  // 检查当前槽位是否有密钥
  private getCurrentSlotHasKey(): boolean {
    switch (this.selectedMenu) {
      case ApiMenuType.OpenAI:
        return this.openAiApiKey.length > 0;
      case ApiMenuType.DeepL:
        return this.deepLApiKey.length > 0;
      case ApiMenuType.Ollama:
        return this.ollamaApiUrl.length > 0;
      case ApiMenuType.Doubao:
        return this.doubaoApiKey.length > 0;
      default:
        return false;
    }
  }

  // 打开编辑弹窗
  private openKeyEditSheet(): void {
    // 根据当前选中的菜单，填充编辑字段
    switch (this.selectedMenu) {
      case ApiMenuType.OpenAI:
        this.editingApiUrl = this.openAiApiUrl;
        this.editingApiKey = this.openAiApiKey;
        this.editingModel = this.openAiModel;
        break;
      case ApiMenuType.DeepL:
        this.editingApiUrl = this.deepLApiUrl;
        this.editingApiKey = this.deepLApiKey;
        this.editingModel = '';
        break;
      case ApiMenuType.Ollama:
        this.editingApiUrl = this.ollamaApiUrl;
        this.editingApiKey = '';
        this.editingModel = this.ollamaModel;
        break;
      case ApiMenuType.Doubao:
        this.editingApiUrl = this.doubaoApiUrl;
        this.editingApiKey = this.doubaoApiKey;
        this.editingModel = this.doubaoModel;
        break;
    }
    this.validateEditingConfig();
    this.isKeyEditSheetOpen = true;
  }

  // 验证编辑中的配置
  private validateEditingConfig(): void {
    let isValid = true;
    if (!this.editingApiUrl) isValid = false;

    switch (this.selectedMenu) {
      case ApiMenuType.OpenAI:
      case ApiMenuType.Doubao:
        if (!this.editingApiKey) isValid = false;
        if (!this.editingModel) isValid = false;
        break;
      case ApiMenuType.DeepL:
        if (!this.editingApiKey) isValid = false;
        break;
      case ApiMenuType.Ollama:
        if (!this.editingModel) isValid = false;
        break;
    }
    this.isConfigValid = isValid;
  }

  // 测试连接
  private async testConnection(): Promise<boolean> {
    this.isTestingConnection = true;
    try {
      const httpRequest = http.createHttp();
      let url = this.editingApiUrl;
      let method = http.RequestMethod.POST;
      let extraData: Record<string, Object> = {};
      let headers: Record<string, string> = {
        'Content-Type': 'application/json'
      };

      const isResponsesEndpoint: boolean = url.includes('/v1/responses') || url.endsWith('/responses');

      if (this.selectedMenu === ApiMenuType.OpenAI || this.selectedMenu === ApiMenuType.Doubao) {
        headers['Authorization'] = `Bearer ${this.editingApiKey}`;

        if (isResponsesEndpoint) {
          // OpenAI Responses API（以及部分兼容网关）
          // 说明：这里用最小 payload 做“连通性 + 模型可用性”验证。
          extraData = {
            'model': this.editingModel,
            'input': 'Hi',
            'max_output_tokens': 1
          };
        } else {
          // OpenAI Chat Completions（以及兼容网关）
          let msg: Record<string, Object> = { 'role': 'user', 'content': 'Hi' };
          extraData = {
            'model': this.editingModel,
            'messages': [msg],
            'max_tokens': 50
          };
        }
      } else if (this.selectedMenu === ApiMenuType.DeepL) {
        headers['Authorization'] = `DeepL-Auth-Key ${this.editingApiKey}`;
        extraData = {
          'text': ['Hello'],
          'target_lang': 'ZH'
        };
      } else if (this.selectedMenu === ApiMenuType.Ollama) {
        let msg: Record<string, Object> = { 'role': 'user', 'content': 'Hi' };
        extraData = {
          'model': this.editingModel,
          'messages': [msg],
          'stream': false
        };
      }

      let response = await httpRequest.request(url, {
        method: method,
        header: headers,
        extraData: extraData,
        connectTimeout: 10000,
        readTimeout: 10000
      });

      // OpenAI 兼容：部分模型在 chat/completions 下不支持 max_tokens，要求 max_completion_tokens
      if ((this.selectedMenu === ApiMenuType.OpenAI || this.selectedMenu === ApiMenuType.Doubao) &&
        !isResponsesEndpoint &&
        response.responseCode === 400) {
        const resultStr: string = typeof response.result === 'string' ? (response.result as string) : JSON.stringify(response.result);
        if (resultStr.includes('max_completion_tokens') && resultStr.includes('max_tokens')) {
          let msg: Record<string, Object> = { 'role': 'user', 'content': 'Hi' };
          extraData = {
            'model': this.editingModel,
            'messages': [msg],
            'max_completion_tokens': 50
          };
          response = await httpRequest.request(url, {
            method: method,
            header: headers,
            extraData: extraData,
            connectTimeout: 10000,
            readTimeout: 10000
          });
        }
      }

      httpRequest.destroy();

      if (response.responseCode === 200 || response.responseCode === 201) {
        promptAction.showToast({
          message: '验证成功',
          duration: 2000
        });
        return true;
      } else {
        const resultStr: string = typeof response.result === 'string' ? (response.result as string) : JSON.stringify(response.result);
        const snippet: string = resultStr.length > 160 ? (resultStr.slice(0, 160) + '...') : resultStr;
        console.error('Connection failed:', response.responseCode, response.result);

        // 针对 /v1/responses + 404 给出更明确提示：可能是模型不存在/无权限，或网关不支持该接口
        let msg = '验证失败: ' + response.responseCode.toString();
        if (response.responseCode === 404 && isResponsesEndpoint) {
          msg = '验证失败: 404（模型不存在/无权限，或服务不支持 /v1/responses）';
        }
        promptAction.showToast({
          message: msg + (snippet ? ('\n' + snippet) : ''),
          duration: 3000
        });
        return false;
      }
    } catch (error) {
      console.error('Connection error:', error);
      promptAction.showToast({
        message: '连接错误，请检查网络',
        duration: 3000
      });
      return false;
    } finally {
      this.isTestingConnection = false;
    }
  }

  // 保存验证后的配置
  private async saveVerifiedConfig(): Promise<void> {
    if (!this.isConfigValid) return;

    const isConnected = await this.testConnection();
    if (!isConnected) return;

    // 验证成功，保存配置
    switch (this.selectedMenu) {
      case ApiMenuType.OpenAI:
        this.onUpdateOpenAiApiUrl(this.editingApiUrl);
        this.onUpdateOpenAiApiKey(this.editingApiKey);
        this.onUpdateOpenAiModel(this.editingModel);
        break;
      case ApiMenuType.DeepL:
        this.onUpdateDeepLApiUrl(this.editingApiUrl);
        this.onUpdateDeepLApiKey(this.editingApiKey);
        break;
      case ApiMenuType.Ollama:
        this.onUpdateOllamaApiUrl(this.editingApiUrl);
        this.onUpdateOllamaModel(this.editingModel);
        break;
      case ApiMenuType.Doubao:
        this.onUpdateDoubaoApiUrl(this.editingApiUrl);
        this.onUpdateDoubaoApiKey(this.editingApiKey);
        this.onUpdateDoubaoModel(this.editingModel);
        break;
    }

    this.isKeyEditSheetOpen = false;
    promptAction.showToast({
      message: '密钥配置已保存',
      duration: 2000
    });
  }

  // 获取当前 API 类型名称
  private getCurrentApiName(): string {
    switch (this.selectedMenu) {
      case ApiMenuType.OpenAI: return 'OpenAI';
      case ApiMenuType.DeepL: return 'DeepL';
      case ApiMenuType.Ollama: return 'Ollama';
      case ApiMenuType.Doubao: return 'Doubao';
      default: return '';
    }
  }

  // 是否需要 API Key
  private needsApiKey(): boolean {
    return this.selectedMenu === ApiMenuType.OpenAI ||
           this.selectedMenu === ApiMenuType.DeepL ||
           this.selectedMenu === ApiMenuType.Doubao;
  }

  // 是否需要 Model
  private needsModel(): boolean {
    return this.selectedMenu === ApiMenuType.OpenAI ||
           this.selectedMenu === ApiMenuType.Ollama ||
           this.selectedMenu === ApiMenuType.Doubao;
  }

  // 密钥编辑弹窗内容
  @Builder
  KeyEditSheetContent() {
    Column() {
      // 标题
      Text(this.getCurrentSlotHasKey() ? '编辑 ' + this.getCurrentApiName() + ' 密钥' : '添加 ' + this.getCurrentApiName() + ' 密钥')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ bottom: 8 })

      // API URL
      Column({ space: 8 }) {
        Text('API URL')
          .fontSize(14)
          .fontColor('#666666')
          .fontWeight(FontWeight.Medium)
          .alignSelf(ItemAlign.Start)

        TextInput({ placeholder: '请输入 API URL', text: this.editingApiUrl })
          .height(48)
          .backgroundColor('#F5F5F5')
          .borderRadius(12)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.editingApiUrl = value;
            this.validateEditingConfig();
          })
      }
      .width('100%')
      .margin({ bottom: 16 })

      // API Key (如果需要)
      if (this.needsApiKey()) {
        Column({ space: 8 }) {
          Text('API Key')
            .fontSize(14)
            .fontColor('#666666')
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)

          TextInput({ placeholder: '请输入 API Key', text: this.editingApiKey })
            .height(48)
            .backgroundColor('#F5F5F5')
            .borderRadius(12)
            .padding({ left: 16, right: 16 })
            .type(InputType.Password)
            .onChange((value: string) => {
              this.editingApiKey = value;
              this.validateEditingConfig();
            })
        }
        .width('100%')
        .margin({ bottom: 16 })
      }

      // Model (如果需要)
      if (this.needsModel()) {
        Column({ space: 8 }) {
          Text('Model')
            .fontSize(14)
            .fontColor('#666666')
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)

          TextInput({ placeholder: '请输入模型名称', text: this.editingModel })
            .height(48)
            .backgroundColor('#F5F5F5')
            .borderRadius(12)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.editingModel = value;
              this.validateEditingConfig();
            })
        }
        .width('100%')
        .margin({ bottom: 24 })
      }

      // 验证并保存按钮
      Button(this.isTestingConnection ? '正在验证...' : '验证并保存')
        .width('100%')
        .height(52)
        .backgroundColor((this.isConfigValid && !this.isTestingConnection) ? '#3c1464' : '#CCCCCC')
        .enabled(this.isConfigValid && !this.isTestingConnection)
        .type(ButtonType.Capsule)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .onClick(() => {
          this.saveVerifiedConfig();
        })

      // 取消按钮
      Button('取消')
        .width('100%')
        .height(44)
        .backgroundColor(Color.Transparent)
        .fontColor('#666666')
        .type(ButtonType.Capsule)
        .fontSize(16)
        .margin({ top: 12 })
        .onClick(() => {
          this.isKeyEditSheetOpen = false;
        })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 24, bottom: 32 })
  }

  build() {
    HdsNavigation() {
      Column() {
        Blank().height(TITLE_BAR_HEIGHT_MINI);

        SideBarContainer(SideBarContainerType.Embed) {
          // --- Side Panel (Menu) ---
          Stack({ alignContent: Alignment.TopStart }) {
            // Selection Indicator
            Column()
              .width('100%')
              .height(44)
              .backgroundColor("#bf3c1464")
              .borderRadius(22)
              .border({ width: 1, color: Color.Gray })
              .margin({ top: 24 }) // Match the initial Blank height
              .translate({ y: this.selectedMenu * 52 }) // 44 (height) + 8 (margin)
              .animation({ duration: 300, curve: Curve.EaseInOut })
              .hitTestBehavior(HitTestMode.None) // Allow clicks to pass through to buttons

            Column() {
              Blank().height(24);

              // Menu Item 1: Prompt
            MenuButton({
              label: 'Prompt',
              menuType: ApiMenuType.Prompt,
              isSelected: this.selectedMenu === ApiMenuType.Prompt,
              isLightEffectBright: this.isLightEffectBright,
              isDarkMode: this.isDarkMode,
              isSource: this.activeMenuId === ApiMenuType.Prompt,
              isIlluminated: this.activeMenuId !== -1, // Illuminated if ANY button is touched
              onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.Prompt; }) },
              onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
              onClickAction: () => this.onSelectMenu(ApiMenuType.Prompt)
            });

            // Menu Item 6: Glossary
            MenuButton({
              label: 'Glossary',
              menuType: ApiMenuType.Glossary,
              isSelected: this.selectedMenu === ApiMenuType.Glossary,
              isLightEffectBright: this.isLightEffectBright,
              isDarkMode: this.isDarkMode,
              isSource: this.activeMenuId === ApiMenuType.Glossary,
              isIlluminated: this.activeMenuId !== -1,
              onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.Glossary; }) },
              onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
              onClickAction: () => this.onSelectMenu(ApiMenuType.Glossary)
            });

            // Menu Item 2: OpenAI
            MenuButton({
              label: 'OpenAI',
              menuType: ApiMenuType.OpenAI,
              isSelected: this.selectedMenu === ApiMenuType.OpenAI,
              isLightEffectBright: this.isLightEffectBright,
              isDarkMode: this.isDarkMode,
              isSource: this.activeMenuId === ApiMenuType.OpenAI,
              isIlluminated: this.activeMenuId !== -1,
              onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.OpenAI; }) },
              onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
              onClickAction: () => this.onSelectMenu(ApiMenuType.OpenAI)
            });

            // Menu Item 3: DeepL
            MenuButton({
              label: 'DeepL',
              menuType: ApiMenuType.DeepL,
              isSelected: this.selectedMenu === ApiMenuType.DeepL,
              isLightEffectBright: this.isLightEffectBright,
              isDarkMode: this.isDarkMode,
              isSource: this.activeMenuId === ApiMenuType.DeepL,
              isIlluminated: this.activeMenuId !== -1,
              onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.DeepL; }) },
              onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
              onClickAction: () => this.onSelectMenu(ApiMenuType.DeepL)
            });

            // Menu Item 4: Ollama
            MenuButton({
              label: 'Ollama',
              menuType: ApiMenuType.Ollama,
              isSelected: this.selectedMenu === ApiMenuType.Ollama,
              isLightEffectBright: this.isLightEffectBright,
              isDarkMode: this.isDarkMode,
              isSource: this.activeMenuId === ApiMenuType.Ollama,
              isIlluminated: this.activeMenuId !== -1,
              onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.Ollama; }) },
              onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
              onClickAction: () => this.onSelectMenu(ApiMenuType.Ollama)
            });

            // Menu Item 5: Doubao
            MenuButton({
              label: 'Doubao',
              menuType: ApiMenuType.Doubao,
              isSelected: this.selectedMenu === ApiMenuType.Doubao,
              isLightEffectBright: this.isLightEffectBright,
              isDarkMode: this.isDarkMode,
              isSource: this.activeMenuId === ApiMenuType.Doubao,
              isIlluminated: this.activeMenuId !== -1,
              onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.Doubao; }) },
              onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
              onClickAction: () => this.onSelectMenu(ApiMenuType.Doubao)
            });

            Blank().height(16);
          }
          .width('100%')
          // .padding({ left: 4, right: 4, top: 24, bottom: 24 }) // Moved padding to Stack
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start);
          }
          .width('100%')
          .padding({ left: 4, right: 4, top: 24, bottom: 24 })
          .alignContent(Alignment.TopStart)

          // --- Content Panel ---
          this.ContentPanel()
        }
        .sideBarWidth('160vp')
        .minContentWidth('360vp')
        .autoHide(true)
        .showSideBar($$this.isSideBarShown)
        .sideBarPosition(SideBarPosition.Start)
        .showControlButton(false)
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 0, right:0, top: 12, bottom: 0 })
      .backgroundColor(Color.Transparent);
    }
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(false)
    .titleBar({
      style: {
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_on_tertiary'),
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_tertiary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_tertiary')
            }
          }
        },
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: Color.White,
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: Color.White
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: Color.White
            }
          }
        }
      },
      content: {
        title: {
          mainTitle: '配置 API',
        },
        menu: {
          value: [{
            content: {
              label: this.isSideBarShown ? '关闭侧边栏' : '打开侧边栏',
              icon: this.isSideBarShown ? $r('sys.symbol.open_sidebar') : $r('sys.symbol.close_sidebar'),
              isEnabled: true,
              action: () => {
                animateTo({
                  duration: 500,
                  curve: Curve.EaseInOut
                }, () => {
                  this.isSideBarShown = !this.isSideBarShown;
                });
              }
            }
          }]
        },
        backIcon: {
          label: 'Back',
          action: () => this.onBack()
        }
      },
      avoidLayoutSafeArea: true
    })
    .bindSheet($$this.isKeyEditSheetOpen, this.KeyEditSheetContent(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: true,
      title: { title: this.getCurrentSlotHasKey() ? '编辑密钥' : '添加密钥' },
      onDisappear: () => {
        this.isKeyEditSheetOpen = false;
      }
    })
  }

  // Helper Builder for the content panel to keep build() clean
  @Builder
  ContentPanel() {
    Column() {
      // 可滚动的配置内容
      Stack({ alignContent: Alignment.Bottom }) {
        Scroll() {
          Column() {
            if (this.selectedMenu === ApiMenuType.Prompt) {
              PromptContent({
                promptText: this.promptText,
                onUpdatePrompt: this.onUpdatePrompt,
                getConfigTextAreaHeight: this.getConfigTextAreaHeight
                // Pass only what is needed or create a sub-struct if complex
              } as ApiConfigPageProps);
              // Note: For simplicity in this example, passing specific props to sub-builders
              // In a real app, converting sub-builders to @Component structs is better.
            } else {
              if (this.selectedMenu === ApiMenuType.OpenAI) {
                this.RenderProviderHeader('OpenAI', $r('app.media.OpenAI'));
                this.RenderOpenAiConfig();
              } else if (this.selectedMenu === ApiMenuType.DeepL) {
                this.RenderProviderHeader('DeepL', $r('app.media.DeepL'));
                this.RenderDeepLConfig();
              } else if (this.selectedMenu === ApiMenuType.Ollama) {
                this.RenderProviderHeader('Ollama', $r('app.media.Ollama'));
                this.RenderOllamaConfig();
              } else if (this.selectedMenu === ApiMenuType.Doubao) {
                this.RenderProviderHeader('Doubao', $r('app.media.Doubao'));
                this.RenderDoubaoConfig();
              } else if (this.selectedMenu === ApiMenuType.Glossary) {
                this.RenderGlossaryConfig();
              }
            }
            // 底部留出空间给悬浮的 ActionBar
            Blank().height(150)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16 })
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        .friction(0.6)
        .width('100%')
        .height('100%')

        // 悬浮的密钥槽位切换器（仅在 API 配置页面显示）
        if (this.selectedMenu === ApiMenuType.OpenAI ||
            this.selectedMenu === ApiMenuType.DeepL ||
            this.selectedMenu === ApiMenuType.Ollama ||
            this.selectedMenu === ApiMenuType.Doubao) {
          Column() {
            this.RenderFloatingKeySlotSwitcher()
          }
          .width('100%')
          .padding({ bottom: 120 })
        }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  // 悬浮的密钥槽位切换器
  @Builder
  RenderFloatingKeySlotSwitcher() {
    if (this.selectedMenu === ApiMenuType.OpenAI) {
      KeySlotSwitcher({
        currentSlotIndex: this.openAiKeySlots.currentSlotIndex,
        totalSlots: MAX_KEY_SLOTS,
        hasApiKey: this.openAiApiKey.length > 0,
        onSwitchSlot: (index: number) => this.onSwitchOpenAiSlot(index),
        onEditSlot: () => this.openKeyEditSheet()
      })
    } else if (this.selectedMenu === ApiMenuType.DeepL) {
      KeySlotSwitcher({
        currentSlotIndex: this.deepLKeySlots.currentSlotIndex,
        totalSlots: MAX_KEY_SLOTS,
        hasApiKey: this.deepLApiKey.length > 0,
        onSwitchSlot: (index: number) => this.onSwitchDeepLSlot(index),
        onEditSlot: () => this.openKeyEditSheet()
      })
    } else if (this.selectedMenu === ApiMenuType.Ollama) {
      KeySlotSwitcher({
        currentSlotIndex: this.ollamaKeySlots.currentSlotIndex,
        totalSlots: MAX_KEY_SLOTS,
        hasApiKey: this.ollamaApiUrl.length > 0,
        onSwitchSlot: (index: number) => this.onSwitchOllamaSlot(index),
        onEditSlot: () => this.openKeyEditSheet()
      })
    } else if (this.selectedMenu === ApiMenuType.Doubao) {
      KeySlotSwitcher({
        currentSlotIndex: this.doubaoKeySlots.currentSlotIndex,
        totalSlots: MAX_KEY_SLOTS,
        hasApiKey: this.doubaoApiKey.length > 0,
        onSwitchSlot: (index: number) => this.onSwitchDoubaoSlot(index),
        onEditSlot: () => this.openKeyEditSheet()
      })
    }
  }

  @Builder
  RenderProviderHeader(title: string, icon?: ResourceStr) {
    Column() {
      if (icon) {
        Image(icon)
          .width(48)
          .height(48)
          .margin({ bottom: 8 })
          .fillColor(Color.White)
      }
      Text(title)
        .fontColor(Color.White)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 16 })
    }
    .alignItems(HorizontalAlign.Center)
    .width('100%')
  }

  @Builder
  RenderOpenAiConfig() {
    Column() {
      Text('API Url').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.openAiApiUrl })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('API Key').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.openAiApiKey ? '••••••••••••' : '未配置' })
        .fontColor(this.openAiApiKey ? Color.White : Color.Gray)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('Model').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.openAiModel || '未配置' })
        .fontColor(this.openAiModel ? Color.White : Color.Gray)
        .width('100%')
        .height(this.getConfigTextAreaHeight(3))
        .maxLines(4)
        .textAlign(TextAlign.Start)
        .enabled(false);
    }
    .width('100%')
    .padding(12)
    .borderRadius(12);
  }

  @Builder
  RenderDeepLConfig() {
    Column() {
      Text('API Url').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.deepLApiUrl })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('API Key').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.deepLApiKey ? '••••••••••••' : '未配置' })
        .fontColor(this.deepLApiKey ? Color.White : Color.Gray)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false);
    }
    .width('100%')
    .padding(12)
    .borderRadius(12);
  }

  @Builder
  RenderOllamaConfig() {
    Column() {
      Text('API Url').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.ollamaApiUrl || '未配置' })
        .fontColor(this.ollamaApiUrl ? Color.White : Color.Gray)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('Model').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.ollamaModel || '未配置' })
        .fontColor(this.ollamaModel ? Color.White : Color.Gray)
        .width('100%')
        .height(this.getConfigTextAreaHeight(3))
        .maxLines(4)
        .textAlign(TextAlign.Start)
        .enabled(false);
    }
    .width('100%')
    .padding(12)
    .borderRadius(12);
  }

  @Builder
  RenderDoubaoConfig() {
    Column() {
      Text('API Url').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.doubaoApiUrl })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('API Key').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.doubaoApiKey ? '••••••••••••' : '未配置' })
        .fontColor(this.doubaoApiKey ? Color.White : Color.Gray)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('Model').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.doubaoModel || '未配置' })
        .fontColor(this.doubaoModel ? Color.White : Color.Gray)
        .width('100%')
        .height(this.getConfigTextAreaHeight(3))
        .maxLines(4)
        .textAlign(TextAlign.Start)
        .enabled(false);
    }
    .width('100%')
    .padding(12)
    .borderRadius(12);
  }

  @Builder
  RenderGlossaryConfig() {
    Column() {
      Image($r('app.media.Glossary'))
        .width(48)
        .height(48)
        .margin({ bottom: 8 })
        .fillColor(Color.White)
      Text('术语库 (Glossary)').fontSize(20).fontWeight(FontWeight.Bold).margin({ bottom: 12 }).fontColor(Color.White);
      Text('每行输入一个术语对，格式为：原文 = 译文，例如：\nHarmonyOS = 鸿蒙\nAI = 人工智能')
        .fontSize(14)
        .fontColor($r('sys.color.font_on_secondary'))
        .margin({ bottom: 12 });

      TextArea({ text: this.glossary })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(10))
        .maxLines(20)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => this.onUpdateGlossary(value));
    }
    .width('100%')
    .padding(12)
    .borderRadius(12);
  }
}

// Global Builder for PromptContent (needed because of the switch case in the previous code)
// Ideally this should also be a @Component or a method inside the class.
@Builder
function PromptContent(props: ApiConfigPageProps) {
  Column() {
    Image($r('app.media.Prompt'))
      .width(48)
      .height(48)
      .margin({ bottom: 8 })
      .fillColor(Color.White)
    Text('提示词 (Prompt)')
      .fontColor(Color.White)
      .fontSize(20)
      .fontWeight(FontWeight.Bold)
      .margin({ bottom: 12 });

    Column() {
      Text('请确保 Prompt (提示词) 包含 {0} 与 [abc]。{0} 代表目标语言，[abc] 代表原始文本。')
        .fontColor($r('sys.color.font_on_secondary'))
        .fontSize(14)
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .margin({ bottom: 16 });

    Column() {
      Text('Prompt Text')
        .fontColor(Color.White)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 8 });

      TextArea({ text: props.promptText })
        .fontColor(Color.White)
        .width('100%')
        .height(props.getConfigTextAreaHeight(6))
        .maxLines(30)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => props.onUpdatePrompt(value));
    }
    .width('100%')
    .padding(12)
    .borderRadius(16);

    Blank().height(24);
  }
  .width('100%');
}