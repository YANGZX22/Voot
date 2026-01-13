import { hdsEffect, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode, HdsActionBar, ActionBarButton, ActionBarStyle } from '@kit.UIDesignKit';
import { MultiKeySlots, MAX_KEY_SLOTS } from '../storage/ApiConfigStorage';
import http from '@ohos.net.http';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { ColorMetrics, curves } from '@kit.ArkUI';
import { THEMES } from '../model/Theme';
import window from '@ohos.window';

const TITLE_BAR_HEIGHT_MINI: number = 84;

interface NavMenuContent {
  label: string;
  icon: Resource;
  isEnabled: boolean;
  action: () => void;
}

interface NavMenuItem {
  content: NavMenuContent;
}

export enum ApiMenuType {
  Prompt = 0,
  PolishPrompt,
  Glossary,
  OpenAI,
  DeepL,
  Ollama,
  Doubao
}

// 定义 SlotInfo 类
class SlotInfo {
  x: number = 0;
  width: number = 0;

  constructor(x: number = 0, width: number = 0) {
    this.x = x;
    this.width = width;
  }
}

// 密钥槽位切换器组件
@Component
struct KeySlotSwitcher {
  @Prop @Watch('onIndexChange') currentSlotIndex: number = 0;
  @Prop totalSlots: number = MAX_KEY_SLOTS;
  @Prop hasApiKey: boolean = false;
  @Prop providerName: string = '';
  @Prop aliases: string[] = []; // 使用数组接收别名
  onSwitchSlot: (index: number) => void = () => {};
  onEditSlot: () => void = () => {};
  @State isExpand: boolean = true;
  @StorageLink('themeColorIndex') themeColorIndex: number = 0;

  // 动画状态
  @State private indicatorX: number = 0;
  @State private indicatorWidth: number = 0;
  @State private slotInfos: SlotInfo[] = [
    new SlotInfo(0, 0), new SlotInfo(0, 0), new SlotInfo(0, 0)
  ];
  private previousIndex: number = 0;
  private pendingAnimation: boolean = false; // 标记是否有待执行的动画

  // 监听索引变化，标记需要动画
  onIndexChange() {
    if (this.currentSlotIndex !== this.previousIndex) {
      this.pendingAnimation = true;
    }
  }

  // 执行流动动画
  private executeAnimation(newIndex: number, newX: number, newWidth: number) {
    const oldX = this.indicatorX;
    const oldWidth = this.indicatorWidth;
    
    // 如果之前没有宽度（初始化），直接跳到新位置
    if (oldWidth === 0) {
      this.indicatorX = newX;
      this.indicatorWidth = newWidth;
      this.previousIndex = newIndex;
      this.pendingAnimation = false;
      return;
    }

    const isMovingRight = newX > oldX;
    const distance = Math.abs(newX - oldX);
    
    // 动态时长
    const stretchDuration = Math.min(250, 150 + distance * 0.5);
    const shrinkDuration = Math.min(300, 180 + distance * 0.6);

    if (isMovingRight) {
      // 向右移动
      // 快速延伸到覆盖新位置
      const targetStretchWidth = (newX + newWidth) - oldX;
      
      animateTo({ duration: stretchDuration, curve: Curve.EaseOut }, () => {
        this.indicatorWidth = targetStretchWidth;
      });

      // 尾部收缩到新位置
      setTimeout(() => {
        animateTo({ duration: shrinkDuration, curve: curves.springMotion(0.4, 0.8) }, () => {
          this.indicatorX = newX;
          this.indicatorWidth = newWidth;
        });
      }, stretchDuration * 0.7);
    } else {
      // 向左移动
      // 快速延伸到覆盖新位置
      const targetStretchWidth = (oldX + oldWidth) - newX;
      
      animateTo({ duration: stretchDuration, curve: Curve.EaseOut }, () => {
        this.indicatorX = newX;
        this.indicatorWidth = targetStretchWidth;
      });

      // 头部收缩
      setTimeout(() => {
        animateTo({ duration: shrinkDuration, curve: curves.springMotion(0.4, 0.8) }, () => {
          this.indicatorWidth = newWidth;
        });
      }, stretchDuration * 0.7);
    }

    this.previousIndex = newIndex;
    this.pendingAnimation = false;
  }

  // 更新槽位信息
  private updateSlotInfo(index: number, area: Area) {
    const x = Number(area.position.x);
    const width = Number(area.width);
    
    // 更新存储的位置信息
    this.slotInfos[index] = new SlotInfo(x, width);
    
    // 当前选中项布局变化时
    if (index === this.currentSlotIndex) {
      if (this.indicatorWidth === 0) {
        // 初始化
        this.indicatorX = x;
        this.indicatorWidth = width;
        this.previousIndex = index;
        this.pendingAnimation = false;
      } else if (this.pendingAnimation) {
        this.executeAnimation(index, x, width);
      } else if (this.previousIndex === index) {
        animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
          this.indicatorX = x;
          this.indicatorWidth = width;
        });
      }
    }
  }

  // 获取选中项的显示文本
  private getSelectedLabel(index: number): string {
    const alias = this.aliases[index];
    if (alias && alias.trim().length > 0) {
      return alias;
    }
    return `${this.providerName} ${index + 1}`;
  }

  // 获取槽位显示文本
  private getSlotLabel(index: number): string {
    if (this.currentSlotIndex === index) {
      return this.getSelectedLabel(index);
    }
    return `${index + 1}`;
  }

  build() {
    Column() {
      // 槽位指示器容器
      Stack({ alignContent: Alignment.TopStart }) {
        // 浮动指示器
        Column()
          .height(28)
          .borderRadius(14)
          .backgroundColor(THEMES[this.themeColorIndex].primaryColor)
          .position({ x: this.indicatorX, y: 0 })
          .width(this.indicatorWidth > 30 ? this.indicatorWidth : 30)
          .opacity(this.indicatorWidth > 0 ? 1 : 0) // 初始化前隐藏
          .shadow({ radius: 8, color: '#40000000', offsetY: 2 })

        // 按钮组
        Row() {
          ForEach([0, 1, 2], (index: number) => {
            if (this.currentSlotIndex === index) {
              // 选中状态
              Text(this.getSelectedLabel(index))
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .constraintSize({ minWidth: 30, maxWidth: 80 })
                .padding({ left: 12, right: 12 })
                .height(28)
                .textAlign(TextAlign.Center)
                .borderRadius(14)
                .backgroundColor(Color.Transparent) // 露出指示器
                .margin({ left: 4, right: 4 })
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE }) // 跑马灯
                .onClick(() => {
                  this.onSwitchSlot(index);
                })
                .onAreaChange((oldArea, newArea) => {
                  this.updateSlotInfo(index, newArea);
                })
            } else {
              // 未选中：圆形，只显示数字
              Text(`${index + 1}`)
                .fontSize(12)
                .fontWeight(FontWeight.Normal)
                .fontColor($r('sys.color.font_on_secondary'))
                .width(28) // 固定宽度保持圆形
                .height(28)
                .textAlign(TextAlign.Center)
                .borderRadius(14)
                .backgroundColor($r('sys.color.comp_background_secondary'))
                .margin({ left: 4, right: 4 })
                .onClick(() => {
                  this.onSwitchSlot(index);
                })
                .onAreaChange((oldArea, newArea) => {
                  this.updateSlotInfo(index, newArea);
                })
            }
          })
        }
      }
      .margin({ bottom: 12 })


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
          backgroundColor: ColorMetrics.resourceColor(THEMES[this.themeColorIndex].primaryColor),
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
  themeColorIndex: number;
}

// Menu Button Component with Effects
@Component
struct MenuButton {
  @Prop label: string;
  @Prop iconName: string;
  @Prop menuType: ApiMenuType;
  @Prop isSelected: boolean;
  @Prop isLightEffectBright: boolean = true;
  @Prop isDarkMode: boolean = true;
  @StorageLink('themeColorIndex') themeColorIndex: number = 0;

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
        Image($r('app.media.'+ this.iconName))
          .width(20)
          .height(20)
          .fillColor(this.isSelected ? THEMES[this.themeColorIndex].primaryColor : Color.White)

        Text(" " + this.label)
          .layoutWeight(1)
          .fontSize(15)
          .fontWeight(FontWeight.Normal);
      }
      .width('100%');
    }
    .type(ButtonType.Capsule)
    .fontColor(this.isSelected ? THEMES[this.themeColorIndex].primaryColor : Color.White)
    .width(180)
    .height(44)
    .padding({ left: 12, right: 12 })
    .margin({ left:8, bottom: 8 })
    .backgroundColor(Color.Transparent)
    .borderRadius(12)
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
  @Prop polishPromptText: string = ""; // 润色提示词
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
  // Alias 字段（用于显示用户自定义别名）
  @Prop openAiAlias: string = "";
  @Prop deepLAlias: string = "";
  @Prop ollamaAlias: string = "";
  @Prop doubaoAlias: string = "";
  @Prop glossary: string = "";
  @Prop isLightEffectBright: boolean = true;
  @Prop isDarkMode: boolean = true;
  @StorageLink('themeColorIndex') themeColorIndex: number = 0;

  // API Config Page Settings
  @StorageLink('apiConfigRequireScreenLock') apiConfigRequireScreenLock: boolean = true;
  @StorageLink('apiConfigPrivacyMode') apiConfigPrivacyMode: boolean = true;

  // 记录进入页面前的窗口状态，用于退出时恢复
  private previousPrivacyMode: boolean = false;

  // Callbacks (Initialized to empty functions)
  onBack: () => void = () => {};
  onSelectMenu: (menu: ApiMenuType) => void = () => {};
  onUpdatePrompt: (value: string) => void = () => {};
  onUpdatePolishPrompt: (value: string) => void = () => {}; // 润色提示词更新回调
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
  // Alias 更新回调
  onUpdateOpenAiAlias: (value: string) => void = () => {};
  onUpdateDeepLAlias: (value: string) => void = () => {};
  onUpdateOllamaAlias: (value: string) => void = () => {};
  onUpdateDoubaoAlias: (value: string) => void = () => {};
  onUpdateGlossary: (value: string) => void = () => {};
  // Helper for TextArea height
  getConfigTextAreaHeight: (rows: number) => number = (rows: number) => rows * 20;

  // --- STATE FOR LIGHTING EFFECT ---
  // Tracks which menu ID is currently being touched. -1 means none.
  @State activeMenuId: number = -1;
  // State for sidebar visibility
  @State isSideBarShown: boolean = false;
  
  // --- 指示器动画状态 ---
  @State private indicatorTop: number = 0; // 初始位置，将在 aboutToAppear 中根据 selectedMenu 设置
  @State private indicatorHeight: number = 24; // 初始高度
  @State private previousMenu: ApiMenuType = ApiMenuType.Prompt;
  @State private sidebarIndicatorInitialized: boolean = false; // 标记是否已初始化
  
  // 计算菜单项的Y位置 (居中位置)
  private getMenuItemY(menu: ApiMenuType): number {
    // 基础偏移: 34 (margin-top) + 88 (第一个按钮偏移)
    const baseOffset = 34 + 88;
    const itemHeight = 52; // 每个按钮高度 44 + margin 8
    const groupGap = 40; // 第二组分组标题高度
    
    if (menu < 3) {
      return baseOffset + menu * itemHeight;
    } else {
      return baseOffset + 3 * itemHeight + groupGap + (menu - 3) * itemHeight;
    }
  }
  
  // 触发指示器动画
  private animateIndicator(newMenu: ApiMenuType): void {
    if (newMenu === this.previousMenu) return;
    
    const oldY = this.getMenuItemY(this.previousMenu);
    const newY = this.getMenuItemY(newMenu);
    const isMovingDown = newY > oldY;
    const indicatorBaseHeight = 24;
    const distance = Math.abs(newY - oldY);
    
    // 根据距离动态调整时间，让短距离更快
    const stretchDuration = Math.min(250, 120 + distance * 0.3);
    const shrinkDuration = Math.min(300, 150 + distance * 0.4);
    
    if (isMovingDown) {
      // 向下移动
      // 快速延伸到目标（弹性曲线）
      animateTo({ 
        duration: stretchDuration, 
        curve: Curve.EaseOut
      }, () => {
        this.indicatorHeight = newY - oldY + indicatorBaseHeight;
      });
      
      // 顶部缓慢跟上，带轻微回弹
      setTimeout(() => {
        animateTo({ 
          duration: shrinkDuration, 
          curve: curves.springMotion(0.4, 0.8)
        }, () => {
          this.indicatorTop = newY;
          this.indicatorHeight = indicatorBaseHeight;
        });
      }, stretchDuration * 0.7);
    } else {
      // 向上移动
      // 顶部快速移动到新位置
      animateTo({ 
        duration: stretchDuration, 
        curve: Curve.EaseOut
      }, () => {
        this.indicatorTop = newY;
        this.indicatorHeight = oldY - newY + indicatorBaseHeight;
      });
      
      // 底部缓慢跟上
      setTimeout(() => {
        animateTo({ 
          duration: shrinkDuration, 
          curve: curves.springMotion(0.4, 0.8)
        }, () => {
          this.indicatorHeight = indicatorBaseHeight;
        });
      }, stretchDuration * 0.7);
    }
    
    this.previousMenu = newMenu;
  }

  private getNavigationMenuItems(): NavMenuItem[] {
    let items: NavMenuItem[] = [];
    
    // OpenAI 警告 (仅在 OpenAI 页面显示)
    if (this.selectedMenu === ApiMenuType.OpenAI) {
      let item: NavMenuItem = {
        content: {
          label: '服务可用性警告',
          icon: $r('sys.symbol.exclamationmark_circle'),
          isEnabled: true,
          action: () => {
            this.showOpenAIWarningPopup = true;
          }
        }
      };
      items.push(item);
    }

    // "如何填写" 帮助
    if (this.selectedMenu === ApiMenuType.OpenAI ||
        this.selectedMenu === ApiMenuType.DeepL ||
        this.selectedMenu === ApiMenuType.Ollama ||
        this.selectedMenu === ApiMenuType.Doubao) {
      let item: NavMenuItem = {
        content: {
          label: '如何填写',
          icon: $r('sys.symbol.book'),
          isEnabled: true,
          action: () => {
            router.pushUrl({ url: 'pages/ApiExplanationPage' });
          }
        }
      };
      items.push(item);
    }

    // 侧边栏开关
    let sidebarItem: NavMenuItem = {
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
    };
    items.push(sidebarItem);

    return items;
  }


  // --- 半模态弹窗状态 ---
  @State isKeyEditSheetOpen: boolean = false;
  @State editingApiUrl: string = '';
  @State editingApiKey: string = '';
  @State editingModel: string = '';
  @State editingAlias: string = '';  // 别名编辑状态
  @State isTestingConnection: boolean = false;
  @State isConfigValid: boolean = false;

  // OpenAI 警告弹窗状态
  @State showOpenAIWarningPopup: boolean = false;

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
    // 根据当前选中的菜单，填充编辑字段（直接从 slots 读取）
    switch (this.selectedMenu) {
      case ApiMenuType.OpenAI:
        this.editingApiUrl = this.openAiApiUrl;
        this.editingApiKey = this.openAiApiKey;
        this.editingModel = this.openAiModel;
        this.editingAlias = this.openAiKeySlots.slots[this.openAiKeySlots.currentSlotIndex]?.alias || `OpenAI ${this.openAiKeySlots.currentSlotIndex + 1}`;
        break;
      case ApiMenuType.DeepL:
        this.editingApiUrl = this.deepLApiUrl;
        this.editingApiKey = this.deepLApiKey;
        this.editingModel = '';
        this.editingAlias = this.deepLKeySlots.slots[this.deepLKeySlots.currentSlotIndex]?.alias || `DeepL ${this.deepLKeySlots.currentSlotIndex + 1}`;
        break;
      case ApiMenuType.Ollama:
        this.editingApiUrl = this.ollamaApiUrl;
        this.editingApiKey = '';
        this.editingModel = this.ollamaModel;
        this.editingAlias = this.ollamaKeySlots.slots[this.ollamaKeySlots.currentSlotIndex]?.alias || `Ollama ${this.ollamaKeySlots.currentSlotIndex + 1}`;
        break;
      case ApiMenuType.Doubao:
        this.editingApiUrl = this.doubaoApiUrl;
        this.editingApiKey = this.doubaoApiKey;
        this.editingModel = this.doubaoModel;
        this.editingAlias = this.doubaoKeySlots.slots[this.doubaoKeySlots.currentSlotIndex]?.alias || `Doubao ${this.doubaoKeySlots.currentSlotIndex + 1}`;
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
        this.onUpdateOpenAiAlias(this.editingAlias);
        break;
      case ApiMenuType.DeepL:
        this.onUpdateDeepLApiUrl(this.editingApiUrl);
        this.onUpdateDeepLApiKey(this.editingApiKey);
        this.onUpdateDeepLAlias(this.editingAlias);
        break;
      case ApiMenuType.Ollama:
        this.onUpdateOllamaApiUrl(this.editingApiUrl);
        this.onUpdateOllamaModel(this.editingModel);
        this.onUpdateOllamaAlias(this.editingAlias);
        break;
      case ApiMenuType.Doubao:
        this.onUpdateDoubaoApiUrl(this.editingApiUrl);
        this.onUpdateDoubaoApiKey(this.editingApiKey);
        this.onUpdateDoubaoModel(this.editingModel);
        this.onUpdateDoubaoAlias(this.editingAlias);
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

  // 获取当前槽位的别名（直接从 KeySlots 读取以确保实时更新）
  private getCurrentSlotAlias(): string {
    const providerName = this.getCurrentApiName();
    let alias: string = '';
    let slotIndex: number = 0;
    
    switch (this.selectedMenu) {
      case ApiMenuType.OpenAI:
        slotIndex = this.openAiKeySlots.currentSlotIndex;
        alias = this.openAiKeySlots.slots[slotIndex]?.alias || '';
        break;
      case ApiMenuType.DeepL:
        slotIndex = this.deepLKeySlots.currentSlotIndex;
        alias = this.deepLKeySlots.slots[slotIndex]?.alias || '';
        break;
      case ApiMenuType.Ollama:
        slotIndex = this.ollamaKeySlots.currentSlotIndex;
        alias = this.ollamaKeySlots.slots[slotIndex]?.alias || '';
        break;
      case ApiMenuType.Doubao:
        slotIndex = this.doubaoKeySlots.currentSlotIndex;
        alias = this.doubaoKeySlots.slots[slotIndex]?.alias || '';
        break;
      default:
        return '';
    }
    
    // 如果有自定义别名则返回，否则返回默认格式
    if (alias && alias.trim().length > 0) {
      return alias;
    }
    return `${providerName} ${slotIndex + 1}`;
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
        Text('API 链接')
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
          Text('API 密钥')
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
          Text('模型名称')
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
        .margin({ bottom: 16 })
      }

      // Alias (别名) - 所有 API 都支持
      Column({ space: 8 }) {
        Text('别名')
          .fontSize(14)
          .fontColor('#666666')
          .fontWeight(FontWeight.Medium)
          .alignSelf(ItemAlign.Start)

        TextInput({ placeholder: '自定义显示名称（可选）', text: this.editingAlias })
          .height(48)
          .backgroundColor('#F5F5F5')
          .borderRadius(12)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.editingAlias = value;
          })

        Text('别名将在配置页“选择 API”卡片中显示')
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
          .alignSelf(ItemAlign.Start)
      }
      .width('100%')
      .margin({ bottom: 24 })

      // 验证并保存按钮
      Button(this.isTestingConnection ? '正在验证...' : '验证并保存')
        .width('100%')
        .height(52)
        .backgroundColor((this.isConfigValid && !this.isTestingConnection) ? THEMES[this.themeColorIndex].primaryColor : '#CCCCCC')
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

  // 获取当前窗口实例
  private async getMainWindow(): Promise<window.Window | null> {
    try {
      return await window.getLastWindow(getContext(this));
    } catch (err) {
      console.error('ApiConfigPage: Failed to get window', err);
      return null;
    }
  }

  // 页面出现时应用设置
  async aboutToAppear(): Promise<void> {
    // 初始化 sidebar 指示器位置
    this.indicatorTop = this.getMenuItemY(this.selectedMenu);
    this.previousMenu = this.selectedMenu;
    this.sidebarIndicatorInitialized = true;

    const mainWindow = await this.getMainWindow();
    if (!mainWindow) return;

    try {
      // 保存当前窗口状态
      const props = mainWindow.getWindowProperties();
      this.previousPrivacyMode = props.isPrivacyMode;

      // 根据设置应用隐私模式
      if (this.apiConfigPrivacyMode) {
        await mainWindow.setWindowPrivacyMode(true);
        console.info('ApiConfigPage: Privacy mode enabled');
      }
    } catch (err) {
      console.error('ApiConfigPage: Failed to apply window settings', err);
    }
  }

  // 页面消失时恢复设置
  async aboutToDisappear(): Promise<void> {
    const mainWindow = await this.getMainWindow();
    if (!mainWindow) return;

    try {
      // 恢复之前的隐私模式状态
      if (this.apiConfigPrivacyMode && !this.previousPrivacyMode) {
        await mainWindow.setWindowPrivacyMode(false);
        console.info('ApiConfigPage: Privacy mode restored to off');
      }
    } catch (err) {
      console.error('ApiConfigPage: Failed to restore window settings', err);
    }
  }

  build() {
    HdsNavigation() {
      Stack() {
        SideBarContainer(SideBarContainerType.Overlay) {
          // Side Panel
          Stack({ alignContent: Alignment.TopStart }) {
            // Selection Indicator
            Column()
              .width(6)
              .height(this.indicatorHeight)
              .backgroundColor(THEMES[this.themeColorIndex].primaryColor)
              .borderRadius(3)
              .position({ x: 0, y: this.indicatorTop })
              .hitTestBehavior(HitTestMode.None) // Allow clicks to pass through to buttons

            Column() {
              Blank().height(80);

              Text('提示词')
                .fontSize(12)
                .fontColor($r('sys.color.font_on_secondary'))
                .margin({ left: 16, bottom: 8, top: 4 })
                .height(20)

              // Menu Item: Prompt
              MenuButton({
                label: '翻译提示词',
                iconName: 'Prompt',
                menuType: ApiMenuType.Prompt,
                isSelected: this.selectedMenu === ApiMenuType.Prompt,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                isSource: this.activeMenuId === ApiMenuType.Prompt,
                isIlluminated: this.activeMenuId !== -1, // Illuminated if ANY button is touched
                onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.Prompt; }) },
                onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
                onClickAction: () => { this.animateIndicator(ApiMenuType.Prompt); this.onSelectMenu(ApiMenuType.Prompt); }
              });

              // Menu Item: Polish Prompt (润色提示词)
              MenuButton({
                label: '润色提示词',
                iconName: 'Polish',
                menuType: ApiMenuType.PolishPrompt,
                isSelected: this.selectedMenu === ApiMenuType.PolishPrompt,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                isSource: this.activeMenuId === ApiMenuType.PolishPrompt,
                isIlluminated: this.activeMenuId !== -1,
                onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.PolishPrompt; }) },
                onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
                onClickAction: () => { this.animateIndicator(ApiMenuType.PolishPrompt); this.onSelectMenu(ApiMenuType.PolishPrompt); }
              });

              // Menu Item: Glossary
              MenuButton({
                label: '术语库',
                iconName: 'Glossary',
                menuType: ApiMenuType.Glossary,
                isSelected: this.selectedMenu === ApiMenuType.Glossary,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                isSource: this.activeMenuId === ApiMenuType.Glossary,
                isIlluminated: this.activeMenuId !== -1,
                onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.Glossary; }) },
                onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
                onClickAction: () => { this.animateIndicator(ApiMenuType.Glossary); this.onSelectMenu(ApiMenuType.Glossary); }
              });

              Text('提供商')
                .fontSize(12)
                .fontColor($r('sys.color.font_on_secondary'))
                .margin({ left: 16, bottom: 8, top: 12 })
                .height(20)

              // Menu Item: OpenAI
              MenuButton({
                label: 'OpenAI',
                iconName: 'OpenAI',
                menuType: ApiMenuType.OpenAI,
                isSelected: this.selectedMenu === ApiMenuType.OpenAI,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                isSource: this.activeMenuId === ApiMenuType.OpenAI,
                isIlluminated: this.activeMenuId !== -1,
                onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.OpenAI; }) },
                onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
                onClickAction: () => { this.animateIndicator(ApiMenuType.OpenAI); this.onSelectMenu(ApiMenuType.OpenAI); }
              });

              // Menu Item 3: DeepL
              MenuButton({
                label: 'DeepL',
                iconName: 'DeepL',
                menuType: ApiMenuType.DeepL,
                isSelected: this.selectedMenu === ApiMenuType.DeepL,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                isSource: this.activeMenuId === ApiMenuType.DeepL,
                isIlluminated: this.activeMenuId !== -1,
                onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.DeepL; }) },
                onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
                onClickAction: () => { this.animateIndicator(ApiMenuType.DeepL); this.onSelectMenu(ApiMenuType.DeepL); }
              });

              // Menu Item 4: Ollama
              MenuButton({
                label: 'Ollama',
                iconName: 'Ollama',
                menuType: ApiMenuType.Ollama,
                isSelected: this.selectedMenu === ApiMenuType.Ollama,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                isSource: this.activeMenuId === ApiMenuType.Ollama,
                isIlluminated: this.activeMenuId !== -1,
                onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.Ollama; }) },
                onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
                onClickAction: () => { this.animateIndicator(ApiMenuType.Ollama); this.onSelectMenu(ApiMenuType.Ollama); }
              });

              // Menu Item 5: Doubao
              MenuButton({
                label: 'Doubao',
                iconName: 'Doubao',
                menuType: ApiMenuType.Doubao,
                isSelected: this.selectedMenu === ApiMenuType.Doubao,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                isSource: this.activeMenuId === ApiMenuType.Doubao,
                isIlluminated: this.activeMenuId !== -1,
                onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.Doubao; }) },
                onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
                onClickAction: () => { this.animateIndicator(ApiMenuType.Doubao); this.onSelectMenu(ApiMenuType.Doubao); }
              });

              Blank().height(16);
            }
            .justifyContent(FlexAlign.Start)
            .alignItems(HorizontalAlign.Start);
          }
          .backgroundBlurStyle(BlurStyle.BACKGROUND_REGULAR)
          .backgroundColor(this.isDarkMode ?  '#408c8c8c' : THEMES[this.themeColorIndex].tertiaryColor)
          .padding({ left: 4, right: 4, top: 24, bottom: 24 })
          .alignContent(Alignment.TopStart)

          // Content Panel
          this.ContentPanel()
        }
        .sideBarWidth('200vp')
        .minContentWidth('360vp')
        .autoHide(true)
        .showSideBar($$this.isSideBarShown)
        .sideBarPosition(SideBarPosition.Start)
        .showControlButton(false)
        .width('100%')
        .height('100%')

        // Popup Anchor (Invisible)
        // Positioning estimation: Right margin (~12) + Sidebar Button (~40) + Gap (~8) + Target Button (~40)
        if (this.selectedMenu === ApiMenuType.OpenAI) {
          Row()
            .width(48)
            .height(48)
            .position({ right: 108, top: 38 }) // Adjusted for typical toolbar layout
            .hitTestBehavior(HitTestMode.None) // Let clicks pass through to the real button below
            .bindPopup(this.showOpenAIWarningPopup, {
              message: 'OpenAI 在中国大陆、中国香港特别行政区和中国澳门特别行政区似乎不提供服务。请确认您能够访问该服务，并仔细阅读和遵守服务提供商的使用条款。',
              placementOnTop: false,
              showInSubWindow: false,
              onStateChange: (e) => {
                if (!e.isVisible) {
                  this.showOpenAIWarningPopup = false;
                }
              },
              messageOptions: {
                textColor: Color.White
              },
              enableArrow: false,
              backgroundBlurStyle: BlurStyle.BACKGROUND_THIN,
              transition: TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.FastOutSlowIn })
            })
        }
      }
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
              iconColor: $r('sys.color.icon_on_tertiary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_on_tertiary')
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
          value: this.getNavigationMenuItems()
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

      Blank().height(30)

      // 可滚动的配置内容
      Stack({ alignContent: Alignment.Bottom }) {
        Scroll() {
          Column() {
            if (this.selectedMenu === ApiMenuType.Prompt) {
              PromptContent({
                promptText: this.promptText,
                onUpdatePrompt: this.onUpdatePrompt,
                getConfigTextAreaHeight: this.getConfigTextAreaHeight,
                themeColorIndex: this.themeColorIndex
                // Pass only what is needed or create a sub-struct if complex
              } as ApiConfigPageProps);
              // Note: For simplicity in this example, passing specific props to sub-builders
              // In a real app, converting sub-builders to @Component structs is better.
            } else if (this.selectedMenu === ApiMenuType.PolishPrompt) {
              // 润色提示词配置
              this.RenderPolishPromptConfig();
            } else {
              if (this.selectedMenu === ApiMenuType.OpenAI) {
                this.RenderProviderHeader('OpenAI', this.getCurrentSlotAlias(), $r('app.media.OpenAI'));
                this.RenderOpenAiConfig();
              } else if (this.selectedMenu === ApiMenuType.DeepL) {
                this.RenderProviderHeader('DeepL', this.getCurrentSlotAlias(), $r('app.media.DeepL'));
                this.RenderDeepLConfig();
              } else if (this.selectedMenu === ApiMenuType.Ollama) {
                this.RenderProviderHeader('Ollama', this.getCurrentSlotAlias(), $r('app.media.Ollama'));
                this.RenderOllamaConfig();
              } else if (this.selectedMenu === ApiMenuType.Doubao) {
                this.RenderProviderHeader('Doubao', this.getCurrentSlotAlias(), $r('app.media.Doubao'));
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
          .padding({ bottom: 80 })
        }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      // 点击内容区域时关闭侧边栏
      if (this.isSideBarShown) {
        animateTo({
          duration: 300,
          curve: Curve.EaseInOut
        }, () => {
          this.isSideBarShown = false;
        });
      }
    })
  }

  // 悬浮的密钥槽位切换器
  @Builder
  RenderFloatingKeySlotSwitcher() {
    if (this.selectedMenu === ApiMenuType.OpenAI) {
      KeySlotSwitcher({
        currentSlotIndex: this.openAiKeySlots.currentSlotIndex,
        totalSlots: MAX_KEY_SLOTS,
        hasApiKey: this.openAiApiKey.length > 0,
        providerName: 'OpenAI',
        aliases: [
          this.openAiKeySlots.slots[0]?.alias || '',
          this.openAiKeySlots.slots[1]?.alias || '',
          this.openAiKeySlots.slots[2]?.alias || ''
        ],
        onSwitchSlot: (index: number) => this.onSwitchOpenAiSlot(index),
        onEditSlot: () => this.openKeyEditSheet()
      })
    } else if (this.selectedMenu === ApiMenuType.DeepL) {
      KeySlotSwitcher({
        currentSlotIndex: this.deepLKeySlots.currentSlotIndex,
        totalSlots: MAX_KEY_SLOTS,
        hasApiKey: this.deepLApiKey.length > 0,
        providerName: 'DeepL',
        aliases: [
          this.deepLKeySlots.slots[0]?.alias || '',
          this.deepLKeySlots.slots[1]?.alias || '',
          this.deepLKeySlots.slots[2]?.alias || ''
        ],
        onSwitchSlot: (index: number) => this.onSwitchDeepLSlot(index),
        onEditSlot: () => this.openKeyEditSheet()
      })
    } else if (this.selectedMenu === ApiMenuType.Ollama) {
      KeySlotSwitcher({
        currentSlotIndex: this.ollamaKeySlots.currentSlotIndex,
        totalSlots: MAX_KEY_SLOTS,
        hasApiKey: this.ollamaApiUrl.length > 0,
        providerName: 'Ollama',
        aliases: [
          this.ollamaKeySlots.slots[0]?.alias || '',
          this.ollamaKeySlots.slots[1]?.alias || '',
          this.ollamaKeySlots.slots[2]?.alias || ''
        ],
        onSwitchSlot: (index: number) => this.onSwitchOllamaSlot(index),
        onEditSlot: () => this.openKeyEditSheet()
      })
    } else if (this.selectedMenu === ApiMenuType.Doubao) {
      KeySlotSwitcher({
        currentSlotIndex: this.doubaoKeySlots.currentSlotIndex,
        totalSlots: MAX_KEY_SLOTS,
        hasApiKey: this.doubaoApiKey.length > 0,
        providerName: 'Doubao',
        aliases: [
          this.doubaoKeySlots.slots[0]?.alias || '',
          this.doubaoKeySlots.slots[1]?.alias || '',
          this.doubaoKeySlots.slots[2]?.alias || ''
        ],
        onSwitchSlot: (index: number) => this.onSwitchDoubaoSlot(index),
        onEditSlot: () => this.openKeyEditSheet()
      })
    }
  }

  @Builder
  RenderProviderHeader(title: string, alias: string, icon?: ResourceStr) {
    Column() {
      if (icon) {
        Image(icon)
          .width(48)
          .height(48)
          .margin({ bottom: 8 })
          .fillColor(Color.White)
      }
      // 只显示提供商名称
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
        .backgroundColor(Color.Transparent)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('API Key').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.openAiApiKey ? '••••••••••••' : '未配置' })
        .backgroundColor(Color.Transparent)
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('Model').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.openAiModel || '未配置' })
        .backgroundColor(Color.Transparent)
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(3))
        .maxLines(4)
        .textAlign(TextAlign.Start)
        .enabled(false);
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
  }

  @Builder
  RenderDeepLConfig() {
    Column() {
      Text('API Url').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.deepLApiUrl })
        .backgroundColor(Color.Transparent)
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('API Key').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.deepLApiKey ? '••••••••••••' : '未配置' })
        .backgroundColor(Color.Transparent)
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false);
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
  }

  @Builder
  RenderOllamaConfig() {
    Column() {
      Text('API Url').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.ollamaApiUrl || '未配置' })
        .backgroundColor(Color.Transparent)
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('Model').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.ollamaModel || '未配置' })
        .backgroundColor(Color.Transparent)
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(3))
        .maxLines(4)
        .textAlign(TextAlign.Start)
        .enabled(false);
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
  }

  @Builder
  RenderDoubaoConfig() {
    Column() {
      Text('API Url').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.doubaoApiUrl })
        .backgroundColor(Color.Transparent)
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('API Key').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.doubaoApiKey ? '••••••••••••' : '未配置' })
        .backgroundColor(Color.Transparent)
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('Model').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.doubaoModel || '未配置' })
        .backgroundColor(Color.Transparent)
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(3))
        .maxLines(4)
        .textAlign(TextAlign.Start)
        .enabled(false);
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
  }

  @Builder
  RenderPolishPromptConfig() {
    Column() {
      Image($r('app.media.Polish'))
        .width(48)
        .height(48)
        .margin({ bottom: 8 })
        .fillColor(Color.White)
      Text('润色提示词')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 12 })
        .fontColor(Color.White);
      
      Text('设置润色文本时使用的提示词。请确保提示词包含 {text}，代表待润色的文本。')
        .fontSize(14)
        .backgroundColor(Color.Transparent)
        .fontColor($r('sys.color.font_on_secondary'))
        .margin({ bottom: 12 });

      TextArea({ text: this.polishPromptText,
        placeholder: '你是一个专业的文本润色助手。请对以下文本进行润色优化，使其更加通顺、专业、易读。\n\n要求：\n1. 保持原文的核心意思不变\n2. 优化语法和表达方式\n3. 直接输出润色后的文本，不要添加任何解释\n4. 永远不要更换提供的文本的原始语言，即英语文本依然润色为英语文本 \n\n原文：\n{text}'
      })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(12))
        .maxLines(20)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => this.onUpdatePolishPrompt(value))
        .placeholderColor($r('sys.color.font_on_secondary'));
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
  }

  @Builder
  RenderGlossaryConfig() {
    Column() {
      Image($r('app.media.Glossary'))
        .width(48)
        .height(48)
        .margin({ bottom: 8 })
        .fillColor(Color.White)
      Text('术语库').fontSize(20).fontWeight(FontWeight.Bold).margin({ bottom: 12 }).fontColor(Color.White);
      Text('每行输入一个术语对，格式为：原文 = 译文，例如：\nHarmonyOS = 鸿蒙\nAI = 人工智能')
        .fontSize(14)
        .backgroundColor(Color.Transparent)
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
    .borderRadius(12)
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
    Text('翻译提示词')
      .fontColor(Color.White)
      .fontSize(20)
      .fontWeight(FontWeight.Bold)
      .margin({ bottom: 12 });

    Text('请确保提示词包含 {0} 与 [abc]。{0} 代表目标语言，[abc] 代表原始文本。')
      .fontSize(14)
      .backgroundColor(Color.Transparent)
      .fontColor($r('sys.color.font_on_secondary'))
      .margin({ bottom: 12 });

    TextArea({ text: props.promptText })
      .fontColor(Color.White)
      .width('100%')
      .height(props.getConfigTextAreaHeight(12))
      .maxLines(60)
      .textAlign(TextAlign.Start)
      .onChange((value: string) => props.onUpdatePrompt(value));
  }
  .width('100%')
  .padding(12)
  .borderRadius(12)
}