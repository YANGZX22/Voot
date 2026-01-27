import { hdsEffect, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode, HdsActionBar, ActionBarButton, ActionBarStyle } from '@kit.UIDesignKit';
import { MultiKeySlots, MAX_KEY_SLOTS } from '../storage/ApiConfigStorage';
import http from '@ohos.net.http';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { ColorMetrics, curves } from '@kit.ArkUI';
import { THEMES } from '../model/Theme';
import window from '@ohos.window';
import common from '@ohos.app.ability.common';
import { Want } from '@kit.AbilityKit';

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
  ScanPrompt,
  Glossary,
  OpenAI,
  Gemini,
  DeepL,
  Ollama,
  Doubao,
  Huawei
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
          baseIcon: this.hasApiKey ? $r('sys.symbol.square_and_pencil') : $r('sys.symbol.plus'),
          onClick: () => {
            this.onEditSlot();
          },
          backgroundColor: ColorMetrics.resourceColor(THEMES[this.themeColorIndex].primaryColor),
          hoverTips: this.hasApiKey ? '编辑槽位 ' + (this.currentSlotIndex + 1).toString() : '添加密钥'
        }),
        actionBarStyle: new ActionBarStyle({
          isPrimaryIconChanged: false
        }),
        isExpand: true,
        $isExpand: () => { /* 不折叠 */ }
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
  geminiKeySlots: MultiKeySlots;
  deepLKeySlots: MultiKeySlots;
  ollamaKeySlots: MultiKeySlots;
  doubaoKeySlots: MultiKeySlots;
  huaweiKeySlots: MultiKeySlots;
  // 兼容旧版单密钥字段
  openAiApiUrl: string;
  openAiApiKey: string;
  openAiModel: string;
  geminiApiUrl: string;
  geminiApiKey: string;
  geminiModel: string;
  deepLApiUrl: string;
  deepLApiKey: string;
  ollamaApiUrl: string;
  ollamaModel: string;
  doubaoApiUrl: string;
  doubaoApiKey: string;
  doubaoModel: string;
  huaweiApiUrl: string;
  huaweiApiKey: string;
  huaweiModel: string;
  glossary: string;
  onBack: () => void;
  onSelectMenu: (menu: ApiMenuType) => void;
  onUpdatePrompt: (value: string) => void;
  // 槽位切换回调
  onSwitchOpenAiSlot: (index: number) => void;
  onSwitchGeminiSlot: (index: number) => void;
  onSwitchDeepLSlot: (index: number) => void;
  onSwitchOllamaSlot: (index: number) => void;
  onSwitchDoubaoSlot: (index: number) => void;
  onSwitchHuaweiSlot: (index: number) => void;
  // 更新槽位内容回调
  onUpdateOpenAiApiUrl: (value: string) => void;
  onUpdateOpenAiApiKey: (value: string) => void;
  onUpdateOpenAiModel: (value: string) => void;
  onUpdateGeminiApiUrl: (value: string) => void;
  onUpdateGeminiApiKey: (value: string) => void;
  onUpdateGeminiModel: (value: string) => void;
  onUpdateDeepLApiUrl: (value: string) => void;
  onUpdateDeepLApiKey: (value: string) => void;
  onUpdateOllamaApiUrl: (value: string) => void;
  onUpdateOllamaModel: (value: string) => void;
  onUpdateDoubaoApiUrl: (value: string) => void;
  onUpdateDoubaoApiKey: (value: string) => void;
  onUpdateDoubaoModel: (value: string) => void;
  onUpdateHuaweiApiUrl: (value: string) => void;
  onUpdateHuaweiApiKey: (value: string) => void;
  onUpdateHuaweiModel: (value: string) => void;
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
  @Prop scanPromptText: string = ""; // 扫描提示词
  // 多密钥槽位
  @Prop openAiKeySlots: MultiKeySlots = { slots: [], currentSlotIndex: 0 };
  @Prop geminiKeySlots: MultiKeySlots = { slots: [], currentSlotIndex: 0 };
  @Prop deepLKeySlots: MultiKeySlots = { slots: [], currentSlotIndex: 0 };
  @Prop ollamaKeySlots: MultiKeySlots = { slots: [], currentSlotIndex: 0 };
  @Prop doubaoKeySlots: MultiKeySlots = { slots: [], currentSlotIndex: 0 };
  @Prop huaweiKeySlots: MultiKeySlots = { slots: [], currentSlotIndex: 0 };
  // 兼容旧版字段
  @Prop openAiApiUrl: string = "";
  @Prop openAiApiKey: string = "";
  @Prop openAiModel: string = "";
  @Prop geminiApiUrl: string = "";
  @Prop geminiApiKey: string = "";
  @Prop geminiModel: string = "";
  @Prop deepLApiUrl: string = "";
  @Prop deepLApiKey: string = "";
  @Prop ollamaApiUrl: string = "";
  @Prop ollamaModel: string = "";
  @Prop doubaoApiUrl: string = "";
  @Prop doubaoApiKey: string = "";
  @Prop doubaoModel: string = "";
  @Prop huaweiApiUrl: string = "";
  @Prop huaweiApiKey: string = "";
  @Prop huaweiModel: string = "";
  // Alias 字段（用于显示用户自定义别名）
  @Prop openAiAlias: string = "";
  @Prop geminiAlias: string = "";
  @Prop deepLAlias: string = "";
  @Prop ollamaAlias: string = "";
  @Prop doubaoAlias: string = "";
  @Prop huaweiAlias: string = "";
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
  onUpdateScanPrompt: (value: string) => void = () => {}; // 扫描提示词更新回调
  // 槽位切换回调
  onSwitchOpenAiSlot: (index: number) => void = () => {};
  onSwitchGeminiSlot: (index: number) => void = () => {};
  onSwitchDeepLSlot: (index: number) => void = () => {};
  onSwitchOllamaSlot: (index: number) => void = () => {};
  onSwitchDoubaoSlot: (index: number) => void = () => {};
  onSwitchHuaweiSlot: (index: number) => void = () => {};
  // 更新内容回调
  onUpdateOpenAiApiUrl: (value: string) => void = () => {};
  onUpdateOpenAiApiKey: (value: string) => void = () => {};
  onUpdateOpenAiModel: (value: string) => void = () => {};
  onUpdateGeminiApiUrl: (value: string) => void = () => {};
  onUpdateGeminiApiKey: (value: string) => void = () => {};
  onUpdateGeminiModel: (value: string) => void = () => {};
  onUpdateDeepLApiUrl: (value: string) => void = () => {};
  onUpdateDeepLApiKey: (value: string) => void = () => {};
  onUpdateOllamaApiUrl: (value: string) => void = () => {};
  onUpdateOllamaModel: (value: string) => void = () => {};
  onUpdateDoubaoApiUrl: (value: string) => void = () => {};
  onUpdateDoubaoApiKey: (value: string) => void = () => {};
  onUpdateDoubaoModel: (value: string) => void = () => {};
  onUpdateHuaweiApiUrl: (value: string) => void = () => {};
  onUpdateHuaweiApiKey: (value: string) => void = () => {};
  onUpdateHuaweiModel: (value: string) => void = () => {};
  // Alias 更新回调
  onUpdateOpenAiAlias: (value: string) => void = () => {};
  onUpdateGeminiAlias: (value: string) => void = () => {};
  onUpdateDeepLAlias: (value: string) => void = () => {};
  onUpdateOllamaAlias: (value: string) => void = () => {};
  onUpdateDoubaoAlias: (value: string) => void = () => {};
  onUpdateHuaweiAlias: (value: string) => void = () => {};
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
    
    if (menu < 4) {
      return baseOffset + menu * itemHeight;
    } else {
      return baseOffset + 4 * itemHeight + groupGap + (menu - 4) * itemHeight;
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
    
    // OpenAI 警告
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

    // Gemini 警告
    if (this.selectedMenu === ApiMenuType.Gemini) {
      let item: NavMenuItem = {
        content: {
          label: '服务可用性警告',
          icon: $r('sys.symbol.exclamationmark_circle'),
          isEnabled: true,
          action: () => {
            this.showGeminiWarningPopup = true;
          }
        }
      };
      items.push(item);
    }

    // DeepL 警告
    if (this.selectedMenu === ApiMenuType.DeepL) {
      let item: NavMenuItem = {
        content: {
          label: '服务可用性警告',
          icon: $r('sys.symbol.exclamationmark_circle'),
          isEnabled: true,
          action: () => {
            this.showDeepLWarningPopup = true;
          }
        }
      };
      items.push(item);
    }

    // "更多"菜单 (仅在 API 提供商页面显示)
    if (this.selectedMenu === ApiMenuType.OpenAI ||
        this.selectedMenu === ApiMenuType.Gemini ||
        this.selectedMenu === ApiMenuType.DeepL ||
        this.selectedMenu === ApiMenuType.Ollama ||
        this.selectedMenu === ApiMenuType.Doubao ||
        this.selectedMenu === ApiMenuType.Huawei) {
      let item: NavMenuItem = {
        content: {
          label: '更多',
          icon: $r('sys.symbol.dot_grid_2x2'),
          isEnabled: true,
          action: () => {
            this.openSheet('moreMenu');
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


  // 半模态弹窗
  @State sheetType: 'keyEdit' | 'moreMenu' | 'editConsoleUrl' | 'none' = 'none';
  @State isSheetOpen: boolean = false;
  private isSheetTransitioning: boolean = false; // 防止快速切换导致的竞态条件
  @State editingApiUrl: string = '';
  @State editingApiKey: string = '';
  @State editingModel: string = '';
  @State editingAlias: string = '';  // 别名编辑状态
  @State isTestingConnection: boolean = false;
  @State isConfigValid: boolean = false;

  // 安全地打开 sheet
  private openSheet(type: 'keyEdit' | 'moreMenu' | 'editConsoleUrl'): void {
    if (this.isSheetTransitioning) {
      return; // 正在切换中，忽略请求
    }
    
    if (this.isSheetOpen) {
      // 如果已经打开，先关闭再打开新的
      this.isSheetTransitioning = true;
      this.isSheetOpen = false;
      setTimeout(() => {
        this.sheetType = type;
        this.isSheetOpen = true;
        this.isSheetTransitioning = false;
      }, 350); // 等待关闭动画完成
    } else {
      this.sheetType = type;
      this.isSheetOpen = true;
    }
  }

  // 安全地关闭 sheet
  private closeSheet(): void {
    if (this.isSheetTransitioning) {
      return;
    }
    this.isSheetOpen = false;
  }

  // 安全地切换 sheet 类型（不关闭 sheet）
  private switchSheetType(type: 'keyEdit' | 'moreMenu' | 'editConsoleUrl'): void {
    if (this.isSheetTransitioning) {
      return;
    }
    this.sheetType = type;
  }

  // OpenAI 警告弹窗状态
  @State showOpenAIWarningPopup: boolean = false;
  // Gemini 警告弹窗状态
  @State showGeminiWarningPopup: boolean = false;
  // DeepL 警告弹窗状态
  @State showDeepLWarningPopup: boolean = false;

  // 控制台URL编辑状态
  @State editingConsoleUrl: string = '';

  // 各API提供商的默认控制台URL
  private static readonly DEFAULT_CONSOLE_URLS: Record<string, string> = {
    'OpenAI': 'https://platform.openai.com/',
    'Gemini': 'https://aistudio.google.com/',
    'DeepL': 'https://www.deepl.com/your-account/keys',
    'Ollama': 'http://localhost:11434',
    'Doubao': 'https://console.volcengine.com/ark',
    'Huawei': 'https://console.huaweicloud.com/modelarts/'
  };

  // 用户自定义的控制台URL
  @StorageLink('consoleUrl_OpenAI') consoleUrlOpenAI: string = 'https://platform.openai.com/';
  @StorageLink('consoleUrl_Gemini') consoleUrlGemini: string = 'https://aistudio.google.com/';
  @StorageLink('consoleUrl_DeepL') consoleUrlDeepL: string = 'https://www.deepl.com/your-account/keys';
  @StorageLink('consoleUrl_Ollama') consoleUrlOllama: string = 'http://localhost:11434';
  @StorageLink('consoleUrl_Doubao') consoleUrlDoubao: string = 'https://console.volcengine.com/ark';
  @StorageLink('consoleUrl_Huawei') consoleUrlHuawei: string = 'https://console.huaweicloud.com/modelarts/';

  // 获取当前API提供商名称
  private getCurrentProviderName(): string {
    switch (this.selectedMenu) {
      case ApiMenuType.OpenAI: return 'OpenAI';
      case ApiMenuType.Gemini: return 'Gemini';
      case ApiMenuType.DeepL: return 'DeepL';
      case ApiMenuType.Ollama: return 'Ollama';
      case ApiMenuType.Doubao: return 'Doubao';
      case ApiMenuType.Huawei: return 'Huawei';
      default: return '';
    }
  }

  // 获取当前API提供商的控制台URL
  private getCurrentConsoleUrl(): string {
    switch (this.selectedMenu) {
      case ApiMenuType.OpenAI: return this.consoleUrlOpenAI;
      case ApiMenuType.Gemini: return this.consoleUrlGemini;
      case ApiMenuType.DeepL: return this.consoleUrlDeepL;
      case ApiMenuType.Ollama: return this.consoleUrlOllama;
      case ApiMenuType.Doubao: return this.consoleUrlDoubao;
      case ApiMenuType.Huawei: return this.consoleUrlHuawei;
      default: return '';
    }
  }

  // 设置当前API提供商的控制台URL
  private setCurrentConsoleUrl(url: string): void {
    switch (this.selectedMenu) {
      case ApiMenuType.OpenAI: this.consoleUrlOpenAI = url; break;
      case ApiMenuType.Gemini: this.consoleUrlGemini = url; break;
      case ApiMenuType.DeepL: this.consoleUrlDeepL = url; break;
      case ApiMenuType.Ollama: this.consoleUrlOllama = url; break;
      case ApiMenuType.Doubao: this.consoleUrlDoubao = url; break;
      case ApiMenuType.Huawei: this.consoleUrlHuawei = url; break;
    }
  }

  // 打开控制台
  private openConsoleInBrowser(): void {
    const consoleUrl = this.getCurrentConsoleUrl();
    if (consoleUrl.length > 0) {
      try {
        const context = getContext(this) as common.UIAbilityContext;
        const want: Want = {
          action: 'ohos.want.action.viewData',
          uri: consoleUrl
        };
        context.startAbility(want);
      } catch (err) {
        console.error('Failed to open console URL:', JSON.stringify(err));
        promptAction.showToast({ message: '无法打开浏览器' });
      }
    }
  }

  // 检查当前槽位是否有密钥
  private getCurrentSlotHasKey(): boolean {
    switch (this.selectedMenu) {
      case ApiMenuType.OpenAI:
        return this.openAiApiKey.length > 0;
      case ApiMenuType.Gemini:
        return this.geminiApiKey.length > 0;
      case ApiMenuType.DeepL:
        return this.deepLApiKey.length > 0;
      case ApiMenuType.Ollama:
        return this.ollamaApiUrl.length > 0;
      case ApiMenuType.Doubao:
        return this.doubaoApiKey.length > 0;
      case ApiMenuType.Huawei:
        return this.huaweiApiKey.length > 0;
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
      case ApiMenuType.Gemini:
        this.editingApiUrl = this.geminiApiUrl;
        this.editingApiKey = this.geminiApiKey;
        this.editingModel = this.geminiModel;
        this.editingAlias = this.geminiKeySlots.slots[this.geminiKeySlots.currentSlotIndex]?.alias || `Gemini ${this.geminiKeySlots.currentSlotIndex + 1}`;
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
      case ApiMenuType.Huawei:
        this.editingApiUrl = this.huaweiApiUrl;
        this.editingApiKey = this.huaweiApiKey;
        this.editingModel = this.huaweiModel;
        this.editingAlias = this.huaweiKeySlots.slots[this.huaweiKeySlots.currentSlotIndex]?.alias || `Huawei ${this.huaweiKeySlots.currentSlotIndex + 1}`;
        break;
    }
    this.validateEditingConfig();
    this.openSheet('keyEdit');
  }

  // 验证编辑中的配置
  private validateEditingConfig(): void {
    let isValid = true;
    if (!this.editingApiUrl) isValid = false;

    switch (this.selectedMenu) {
      case ApiMenuType.OpenAI:
      case ApiMenuType.Gemini:
      case ApiMenuType.Doubao:
      case ApiMenuType.Huawei:
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

      if (this.selectedMenu === ApiMenuType.OpenAI ||
          this.selectedMenu === ApiMenuType.Gemini ||
          this.selectedMenu === ApiMenuType.Doubao ||
          this.selectedMenu === ApiMenuType.Huawei) {
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
      if ((this.selectedMenu === ApiMenuType.OpenAI ||
           this.selectedMenu === ApiMenuType.Gemini ||
           this.selectedMenu === ApiMenuType.Doubao ||
           this.selectedMenu === ApiMenuType.Huawei) &&
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
      case ApiMenuType.Gemini:
        this.onUpdateGeminiApiUrl(this.editingApiUrl);
        this.onUpdateGeminiApiKey(this.editingApiKey);
        this.onUpdateGeminiModel(this.editingModel);
        this.onUpdateGeminiAlias(this.editingAlias);
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
      case ApiMenuType.Huawei:
        this.onUpdateHuaweiApiUrl(this.editingApiUrl);
        this.onUpdateHuaweiApiKey(this.editingApiKey);
        this.onUpdateHuaweiModel(this.editingModel);
        this.onUpdateHuaweiAlias(this.editingAlias);
        break;
    }

    this.closeSheet();
    promptAction.showToast({
      message: '密钥配置已保存',
      duration: 2000
    });
  }

  // 获取当前 API 类型名称
  private getCurrentApiName(): string {
    switch (this.selectedMenu) {
      case ApiMenuType.OpenAI: return 'OpenAI';
      case ApiMenuType.Gemini: return 'Gemini';
      case ApiMenuType.DeepL: return 'DeepL';
      case ApiMenuType.Ollama: return 'Ollama';
      case ApiMenuType.Doubao: return 'Doubao';
      case ApiMenuType.Huawei: return 'Huawei';
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
      case ApiMenuType.Gemini:
        slotIndex = this.geminiKeySlots.currentSlotIndex;
        alias = this.geminiKeySlots.slots[slotIndex]?.alias || '';
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
      case ApiMenuType.Huawei:
        slotIndex = this.huaweiKeySlots.currentSlotIndex;
        alias = this.huaweiKeySlots.slots[slotIndex]?.alias || '';
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
           this.selectedMenu === ApiMenuType.Gemini ||
           this.selectedMenu === ApiMenuType.DeepL ||
           this.selectedMenu === ApiMenuType.Doubao ||
           this.selectedMenu === ApiMenuType.Huawei;
  }

  // 是否需要 Model
  private needsModel(): boolean {
    return this.selectedMenu === ApiMenuType.OpenAI ||
           this.selectedMenu === ApiMenuType.Gemini ||
           this.selectedMenu === ApiMenuType.Ollama ||
           this.selectedMenu === ApiMenuType.Doubao ||
           this.selectedMenu === ApiMenuType.Huawei;
  }

  // 密钥编辑弹窗内容
  @Builder
  KeyEditSheetContent() {
    Column() {
      // 标题
      Text(this.getCurrentSlotHasKey() ? '编辑 ' + this.getCurrentApiName() + ' 密钥' : '添加 ' + this.getCurrentApiName() + ' 密钥')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_on_primary'))
        .margin({ bottom: 8 })

      // API URL
      Column({ space: 8 }) {
        Text('API 链接')
          .fontSize(14)
          .fontColor($r('sys.color.font_on_secondary'))
          .fontWeight(FontWeight.Medium)
          .alignSelf(ItemAlign.Start)

        TextInput({ placeholder: '请输入 API URL', text: this.editingApiUrl })
          .height(48)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .fontColor($r('sys.color.font_on_primary'))
          .placeholderColor($r('sys.color.font_on_tertiary'))
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
            .fontColor($r('sys.color.font_on_secondary'))
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)

          TextInput({ placeholder: '请输入 API Key', text: this.editingApiKey })
            .height(48)
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .fontColor($r('sys.color.font_on_primary'))
            .placeholderColor($r('sys.color.font_on_tertiary'))
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
            .fontColor($r('sys.color.font_on_secondary'))
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)

          TextInput({ placeholder: '请输入模型名称', text: this.editingModel })
            .height(48)
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .fontColor($r('sys.color.font_on_primary'))
            .placeholderColor($r('sys.color.font_on_tertiary'))
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

      // Alias (别名)
      Column({ space: 8 }) {
        Text('别名')
          .fontSize(14)
          .fontColor($r('sys.color.font_on_secondary'))
          .fontWeight(FontWeight.Medium)
          .alignSelf(ItemAlign.Start)

        TextInput({ placeholder: '自定义显示名称（可选）', text: this.editingAlias })
          .height(48)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .fontColor($r('sys.color.font_on_primary'))
          .placeholderColor($r('sys.color.font_on_tertiary'))
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
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .fontColor($r('sys.color.font_on_primary'))
        .type(ButtonType.Capsule)
        .fontSize(16)
        .margin({ top: 12 })
        .onClick(() => {
          this.closeSheet();
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

              // Menu Item: Scan Prompt (扫描提示词)
              MenuButton({
                label: '扫描提示词',
                iconName: 'scan',
                menuType: ApiMenuType.ScanPrompt,
                isSelected: this.selectedMenu === ApiMenuType.ScanPrompt,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                isSource: this.activeMenuId === ApiMenuType.ScanPrompt,
                isIlluminated: this.activeMenuId !== -1,
                onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.ScanPrompt; }) },
                onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
                onClickAction: () => { this.animateIndicator(ApiMenuType.ScanPrompt); this.onSelectMenu(ApiMenuType.ScanPrompt); }
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

              // Menu Item: Gemini
              MenuButton({
                label: 'Gemini',
                iconName: 'Gemini',
                menuType: ApiMenuType.Gemini,
                isSelected: this.selectedMenu === ApiMenuType.Gemini,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                isSource: this.activeMenuId === ApiMenuType.Gemini,
                isIlluminated: this.activeMenuId !== -1,
                onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.Gemini; }) },
                onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
                onClickAction: () => { this.animateIndicator(ApiMenuType.Gemini); this.onSelectMenu(ApiMenuType.Gemini); }
              });

              // Menu Item: DeepL
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

              // Menu Item: Ollama
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

              // Menu Item: Doubao
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

              // Menu Item: Huawei
              MenuButton({
                label: 'Huawei',
                iconName: 'Huawei',
                menuType: ApiMenuType.Huawei,
                isSelected: this.selectedMenu === ApiMenuType.Huawei,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                isSource: this.activeMenuId === ApiMenuType.Huawei,
                isIlluminated: this.activeMenuId !== -1,
                onTouchStart: () => { animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeMenuId = ApiMenuType.Huawei; }) },
                onTouchEnd: () => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeMenuId = -1; }) },
                onClickAction: () => { this.animateIndicator(ApiMenuType.Huawei); this.onSelectMenu(ApiMenuType.Huawei); }
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

        // Gemini Popup Anchor (Invisible)
        if (this.selectedMenu === ApiMenuType.Gemini) {
          Row()
            .width(48)
            .height(48)
            .position({ right: 108, top: 38 })
            .hitTestBehavior(HitTestMode.None)
            .bindPopup(this.showGeminiWarningPopup, {
              message: 'Gemini 在中国大陆、中国香港特别行政区和中国澳门特别行政区似乎不提供服务。请确认您能够访问该服务，并仔细阅读和遵守服务提供商的使用条款。',
              placementOnTop: false,
              showInSubWindow: false,
              onStateChange: (e) => {
                if (!e.isVisible) {
                  this.showGeminiWarningPopup = false;
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

        // DeepL Popup Anchor (Invisible)
        if (this.selectedMenu === ApiMenuType.DeepL) {
          Row()
            .width(48)
            .height(48)
            .position({ right: 108, top: 38 })
            .hitTestBehavior(HitTestMode.None)
            .bindPopup(this.showDeepLWarningPopup, {
              message: 'DeepL 在中国大陆可能存在网络限制。请确认您能够访问该服务，并仔细阅读和遵守服务提供商的使用条款。',
              placementOnTop: false,
              showInSubWindow: false,
              onStateChange: (e) => {
                if (!e.isVisible) {
                  this.showDeepLWarningPopup = false;
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
    .bindSheet($$this.isSheetOpen, this.UnifiedSheetContent(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: false,
      title: (): void => this.SheetTitleBuilder(),
      onDisappear: () => {
        this.isSheetOpen = false;
        // Don't reset sheetType to avoid race condition with rapid re-open
      },
      enableOutsideInteractive: false,
      backgroundColor: Color.Transparent,
      blurStyle: BlurStyle.BACKGROUND_THIN,
      onWillDismiss: (dismissAction: DismissSheetAction) => {
        // 只允许下拉和关闭按钮关闭，阻止点击遮罩层关闭
        if (dismissAction.reason === DismissReason.PRESS_BACK ||
            dismissAction.reason === DismissReason.SLIDE_DOWN ||
            dismissAction.reason === DismissReason.CLOSE_BUTTON) {
          dismissAction.dismiss();
        }
        // 点击遮罩层 (TOUCH_OUTSIDE) 不关闭
      }
    })
  }

  // 获取sheet标题
  private getSheetTitle(): string {
    switch (this.sheetType) {
      case 'keyEdit':
        return this.getCurrentSlotHasKey() ? '编辑密钥' : '添加密钥';
      case 'moreMenu':
        return '更多选项';
      case 'editConsoleUrl':
        return '编辑控制台网页';
      default:
        return '';
    }
  }

  // 自定义 Sheet 标题 Builder
  @Builder
  SheetTitleBuilder() {
    Row() {
      // 左侧占位，保持标题居中
      Blank()
        .layoutWeight(1)
      
      // 居中标题
      Text(this.getSheetTitle())
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
      
      // 右侧关闭按钮区域
      Row() {
        Blank()
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([Color.White])
        }
        .type(ButtonType.Circle)
        .width(40)
        .height(40)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .onClick(() => {
          this.closeSheet();
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 8 })
  }

  // 统一Sheet内容
  @Builder
  UnifiedSheetContent() {
    if (this.sheetType === 'keyEdit') {
      this.KeyEditSheetContent()
    } else if (this.sheetType === 'moreMenu') {
      this.MoreMenuSheetContent()
    } else if (this.sheetType === 'editConsoleUrl') {
      this.ConsoleUrlEditSheetContent()
    } else {
      // Fallback content to ensure sheet has size even if type is none (shouldn't happen with fix)
      Column().height(100).width('100%')
    }
  }

  // "更多"菜单内容
  @Builder
  MoreMenuSheetContent() {
    Column() {
      // 打开控制台
      Row() {
        SymbolGlyph($r('sys.symbol.worldclock'))
          .fontSize(22)
          .fontColor([$r('sys.color.icon_on_primary')])
        Text('打开控制台网页')
          .fontSize(16)
          .fontColor($r('sys.color.font_on_primary'))
          .margin({ left: 12 })
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.icon_on_tertiary')])
      }
      .width('90%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.closeSheet();
        this.openConsoleInBrowser();
      })

      Divider()
        .width('90%')
        .height(0.5)
        .color($r('sys.color.comp_divider'))

      // 编辑控制台网页
      Row() {
        SymbolGlyph($r('sys.symbol.square_and_pencil'))
          .fontSize(22)
          .fontColor([$r('sys.color.icon_on_primary')])
        Text('编辑控制台网页')
          .fontSize(16)
          .fontColor($r('sys.color.font_on_primary'))
          .margin({ left: 12 })
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.icon_on_tertiary')])
      }
      .width('90%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.editingConsoleUrl = this.getCurrentConsoleUrl();
        this.switchSheetType('editConsoleUrl');
      })

      Divider()
        .width('90%')
        .height(0.5)
        .color($r('sys.color.comp_divider'))

      // 如何填写
      Row() {
        SymbolGlyph($r('sys.symbol.key_induction'))
          .fontSize(22)
          .fontColor([$r('sys.color.icon_on_primary')])
        Text('如何填写该页面')
          .fontSize(16)
          .fontColor($r('sys.color.font_on_primary'))
          .margin({ left: 12 })
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.icon_on_tertiary')])
      }
      .width('90%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.closeSheet();
        router.pushUrl({ url: 'pages/ApiExplanationPage' });
      })

      // 取消按钮
      Button('取消')
        .type(ButtonType.Normal)
        .fontColor($r('sys.color.font_on_primary'))
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(20)
        .width('90%')
        .height(44)
        .margin({ top: 16 })
        .onClick(() => {
          this.closeSheet();
        })
    }
    .width('100%')
    .padding({ top: 8, bottom: 24 })
  }

  // 编辑控制台网页的Sheet内容
  @Builder
  ConsoleUrlEditSheetContent() {
    Column() {
      Text(`${this.getCurrentProviderName()} 控制台网页地址`)
        .fontSize(14)
        .fontColor($r('sys.color.font_on_secondary'))
        .alignSelf(ItemAlign.Start)
        .margin({ left: 16, top: 16, bottom: 8 })

      TextInput({ text: this.editingConsoleUrl, placeholder: '请输入控制台网页地址' })
        .type(InputType.URL)
        .fontColor($r('sys.color.font_on_primary'))
        .onChange((value: string) => {
          this.editingConsoleUrl = value;
        })
        .width('90%')
        .height(48)
        .borderRadius(20)
        .margin({ left: 16, right: 16 })
        .padding({ left: 16, right: 16 })

      Row() {
        Button('取消')
          .type(ButtonType.Normal)
          .fontColor($r('sys.color.font_on_primary'))
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(20)
          .height(40)
          .layoutWeight(1)
          .margin({ right: 8 })
          .onClick(() => {
            this.switchSheetType('moreMenu');
          })

        Button('保存')
          .type(ButtonType.Normal)
          .fontColor(Color.White)
          .backgroundColor(THEMES[this.themeColorIndex].primaryColor)
          .borderRadius(20)
          .height(40)
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            this.setCurrentConsoleUrl(this.editingConsoleUrl);
            this.closeSheet();
            promptAction.showToast({ message: '控制台网页已保存' });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 24, bottom: 24 })
    }
    .width('100%')
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
            } else if (this.selectedMenu === ApiMenuType.ScanPrompt) {
              // 扫描提示词配置
              this.RenderScanPromptConfig();
            } else {
              if (this.selectedMenu === ApiMenuType.OpenAI) {
                this.RenderProviderHeader('OpenAI', this.getCurrentSlotAlias(), $r('app.media.OpenAI'));
                this.RenderOpenAiConfig();
              } else if (this.selectedMenu === ApiMenuType.Gemini) {
                this.RenderProviderHeader('Gemini', this.getCurrentSlotAlias(), $r('app.media.Gemini'));
                this.RenderGeminiConfig();
              } else if (this.selectedMenu === ApiMenuType.DeepL) {
                this.RenderProviderHeader('DeepL', this.getCurrentSlotAlias(), $r('app.media.DeepL'));
                this.RenderDeepLConfig();
              } else if (this.selectedMenu === ApiMenuType.Ollama) {
                this.RenderProviderHeader('Ollama', this.getCurrentSlotAlias(), $r('app.media.Ollama'));
                this.RenderOllamaConfig();
              } else if (this.selectedMenu === ApiMenuType.Doubao) {
                this.RenderProviderHeader('Doubao', this.getCurrentSlotAlias(), $r('app.media.Doubao'));
                this.RenderDoubaoConfig();
              } else if (this.selectedMenu === ApiMenuType.Huawei) {
                this.RenderProviderHeader('Huawei', this.getCurrentSlotAlias(), $r('app.media.Huawei'));
                this.RenderHuaweiConfig();
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
            this.selectedMenu === ApiMenuType.Gemini ||
            this.selectedMenu === ApiMenuType.DeepL ||
            this.selectedMenu === ApiMenuType.Ollama ||
            this.selectedMenu === ApiMenuType.Doubao ||
            this.selectedMenu === ApiMenuType.Huawei) {
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
    } else if (this.selectedMenu === ApiMenuType.Gemini) {
      KeySlotSwitcher({
        currentSlotIndex: this.geminiKeySlots.currentSlotIndex,
        totalSlots: MAX_KEY_SLOTS,
        hasApiKey: this.geminiApiKey.length > 0,
        providerName: 'Gemini',
        aliases: [
          this.geminiKeySlots.slots[0]?.alias || '',
          this.geminiKeySlots.slots[1]?.alias || '',
          this.geminiKeySlots.slots[2]?.alias || ''
        ],
        onSwitchSlot: (index: number) => this.onSwitchGeminiSlot(index),
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
    } else if (this.selectedMenu === ApiMenuType.Huawei) {
      KeySlotSwitcher({
        currentSlotIndex: this.huaweiKeySlots.currentSlotIndex,
        totalSlots: MAX_KEY_SLOTS,
        hasApiKey: this.huaweiApiKey.length > 0,
        providerName: 'Huawei',
        aliases: [
          this.huaweiKeySlots.slots[0]?.alias || '',
          this.huaweiKeySlots.slots[1]?.alias || '',
          this.huaweiKeySlots.slots[2]?.alias || ''
        ],
        onSwitchSlot: (index: number) => this.onSwitchHuaweiSlot(index),
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
  RenderGeminiConfig() {
    Column() {
      Text('API Url').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.geminiApiUrl })
        .fontColor(Color.White)
        .backgroundColor(Color.Transparent)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('API Key').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.geminiApiKey ? '••••••••••••' : '未配置' })
        .backgroundColor(Color.Transparent)
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('Model').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.geminiModel || '未配置' })
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
  RenderHuaweiConfig() {
    Column() {
      Text('API Url').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.huaweiApiUrl })
        .backgroundColor(Color.Transparent)
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('API Key').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.huaweiApiKey ? '••••••••••••' : '未配置' })
        .backgroundColor(Color.Transparent)
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .enabled(false)
        .margin({ bottom: 12 });

      Text('Model').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.huaweiModel || '未配置' })
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
  RenderScanPromptConfig() {
    Column() {
      Image($r('app.media.scan'))
        .width(48)
        .height(48)
        .margin({ bottom: 8 })
        .fillColor(Color.White)
      Text('扫描提示词')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 12 })
        .fontColor(Color.White);
      
      Text('请确保提示词包含 {0} 与 [abc]。{0} 代表目标语言，[abc] 代表待翻译的文本。')
        .fontSize(14)
        .backgroundColor(Color.Transparent)
        .fontColor($r('sys.color.font_on_secondary'))
        .margin({ bottom: 12 });

      TextArea({ text: this.scanPromptText,
        placeholder: '请将以下文本翻译成 {0}。只输出翻译结果，不要添加任何解释。\n\n原文：\n[abc]'
      })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(12))
        .maxLines(20)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => this.onUpdateScanPrompt(value))
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