import { hdsEffect, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { CapsuleSegmentButtonV2, SegmentButtonV2Items, ColorMetrics } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import common from '@ohos.app.ability.common';
import bundleManager from '@ohos.bundle.bundleManager';
import { PolicySheetType, PolicySheetContent, getPolicySheetConfig } from '../components/PolicySheet';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { THEMES, Theme } from '../model/Theme';

const TITLE_BAR_HEIGHT_MINI: number = 94;
const SETTINGS_SECTION_COUNT: number = 6;
type ToggleKey = 'subtitles' | 'liveWindow';

@CustomDialog
struct CustomDialogSubtitle {
  controller: CustomDialogController
  title: string = '';
  message: string = '';
  confirmText: string = '我知道了';
  onDismiss: () => void = () => {};
  @StorageLink('themeColorIndex') themeColorIndex: number = 0;

  build() {
    Column() {
      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })
      Text(this.message)
        .fontSize(15)
        .fontColor(Color.Grey)
        .textAlign(TextAlign.Center)
        .margin({ bottom: 20 })
      Button(this.confirmText)
        .type(ButtonType.Capsule)
        .backgroundColor(THEMES[this.themeColorIndex].primaryColor)
        .onClick(() => {
          this.controller.close();
          this.onDismiss();
        })
        .width('80%')
    }
    .width(280)
    .padding(24)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Color.Transparent)
    .borderRadius(24)
  }

}

@CustomDialog
struct CustomDialogLiveWindows {
  controller: CustomDialogController
  title: string = '';
  message: string = '';
  confirmText: string = '我知道了';
  onDismiss: () => void = () => {};
  @StorageLink('themeColorIndex') themeColorIndex: number = 0;

  build() {
    Column() {
      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })
      Text(this.message)
        .fontSize(15)
        .fontColor(Color.Grey)
        .textAlign(TextAlign.Center)
        .margin({ bottom: 20 })
      Button(this.confirmText)
        .type(ButtonType.Capsule)
        .backgroundColor(THEMES[this.themeColorIndex].primaryColor)
        .onClick(() => {
          this.controller.close();
          this.onDismiss();
        })
        .width('80%')
    }
    .width(280)
    .padding(24)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Color.Transparent)
    .borderRadius(24)
  }
}

@CustomDialog
struct SubtitleStyleDialog {
  controller: CustomDialogController
  @Link fontSize: number
  @Link fontColor: string
  @Link subtitleBackgroundColor: string
  @Link subtitleHeight: number
  onConfirm: () => void = () => {}
  onChange: () => void = () => {}
  @StorageLink('themeColorIndex') themeColorIndex: number = 0;

  // Predefined colors - Modern Palette
  private colors: string[] = [
    '#FFFFFF', // White
    '#1A1A1A', // Soft Black
    '#3c1464', // Voot Purple
    '#ED3A55', // Huawei Brand Red
    '#2ED573', // Emerald Green
    '#0A59F7', // Huawei Brand Blue
    '#FFA502', // Orange
    '#747D8C', // Grey
    '#5352ED'  // Indigo
  ]

  build() {
    Column() {
      Text('字幕样式设置')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 20 })

      // Font Size
      Row() {
        Text('字体大小')
        Slider({ value: this.fontSize, min: 10, max: 50, step: 1 })
          .selectedColor(THEMES[this.themeColorIndex].primaryColor)
          .layoutWeight(1)
          .onChange((value: number) => {
            this.fontSize = value
            this.onChange()
          })
        Text(this.fontSize.toFixed(0))
          .width(40)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .margin({ bottom: 15 })

      // Subtitle Height
      Row() {
        Text('字幕高度')
        Slider({ value: this.subtitleHeight, min: 5, max: 30, step: 1 })
          .selectedColor(THEMES[this.themeColorIndex].primaryColor)
          .layoutWeight(1)
          .onChange((value: number) => {
            this.subtitleHeight = value
            this.onChange()
          })
        Text(this.subtitleHeight.toFixed(0))
          .width(40)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .margin({ bottom: 15 })

      // Font Color
      Column() {
        Text('字体颜色')
          .width('100%')
          .margin({ bottom: 8 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.colors, (color: string) => {
            Circle({ width: 30, height: 30 })
              .fill(color)
              .stroke(this.fontColor === color ? Color.Blue : Color.Gray)
              .strokeWidth(this.fontColor === color ? 2 : 1)
              .margin(5)
              .onClick(() => {
                this.fontColor = color
                this.onChange()
              })
          })
        }
      }
      .width('100%')
      .margin({ bottom: 15 })

      // Background Color
      Column() {
        Text('背景颜色')
          .width('100%')
          .margin({ bottom: 8 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.colors, (color: string) => {
            Circle({ width: 30, height: 30 })
              .fill(color)
              .stroke(this.subtitleBackgroundColor === color ? Color.Blue : Color.Gray)
              .strokeWidth(this.subtitleBackgroundColor === color ? 2 : 1)
              .margin(5)
              .onClick(() => {
                this.subtitleBackgroundColor = color
                this.onChange()
              })
          })
        }
      }
      .width('100%')
      .margin({ bottom: 20 })

      Button('确定')
        .onClick(() => {
          this.onConfirm()
          this.controller.close()
        })
        .backgroundColor(THEMES[this.themeColorIndex].primaryColor)
        .width('80%')
    }
    .padding(24)
    .backgroundColor(Color.Transparent)
    .borderRadius(24)
    .width('90%')
  }
}

@Component
struct SettingsItem {
  @Prop title: string
  @Prop subtitle: string = ''
  @Builder emptyBuilder() {}
  @BuilderParam rightContent: () => void = this.emptyBuilder
  @Prop hasArrow: boolean = false
  onClickItem: () => void = () => {}
  @StorageLink('themeColorIndex') themeColorIndex: number = 0
  @Prop isDarkMode: boolean = false

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .alignSelf(ItemAlign.Start)
        
        if (this.subtitle) {
          Text(this.subtitle)
            .fontSize(12)
            .fontColor($r('sys.color.font_on_secondary'))
            .margin({ top: 4 })
            .alignSelf(ItemAlign.Start)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.rightContent) {
        this.rightContent()
      }

      if (this.hasArrow) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(20)
          .fontColor([$r('sys.color.icon_on_primary')])
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      if (this.onClickItem) {
        this.onClickItem();
      }
    })
  }
}

@Component
struct SettingsGroup {
  @Prop title: string
  @Prop icon: Resource
  @Link isOpen: boolean
  @BuilderParam content: () => void
  @StorageLink('themeColorIndex') themeColorIndex: number = 0
  @Prop isDarkMode: boolean = false

  build() {
    Column() {
      // Header
      Row() {
        Row({ space: 12 }) {
          Stack({ alignContent: Alignment.Center }) {
            Circle({ width: 32, height: 32 })
              .fill(THEMES[this.themeColorIndex].primaryColor)
              .opacity(this.isOpen ? 0.35 : 0.22)
            SymbolGlyph(this.icon)
              .fontSize(16)
              .fontColor([Color.White])
          }
          .width(32)
          .height(32)

          Text(this.title)
            .fontColor(Color.White)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
        }
        
        Blank()
        
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(16)
          .fontColor([Color.White])
          .rotate({ angle: this.isOpen ? 180 : 0 })
          .animation({ duration: 300, curve: Curve.FastOutSlowIn })
      }
      .width('100%')
      .height(64)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
          this.isOpen = !this.isOpen;
        })
      })

      // Content
      if (this.isOpen) {
        Column() {
          this.content()
        }
        .width('100%')
        .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.FastOutSlowIn }).combine(TransitionEffect.translate({ y: -10 })))
      }
    }
    .width('100%')
    .backgroundColor(this.isDarkMode ? '#1A000000' : THEMES[this.themeColorIndex].tertiaryColor)
    .borderRadius(24)
    .clip(true)
    .margin({ bottom: 16 })
    .border({ width: 1, color: this.isDarkMode ? '#26FFFFFF' : '#40FFFFFF' })
    .shadow({ radius: 20, color: '#1A000000', offsetX: 0, offsetY: 8 })
  }
}

@Component
struct GestureActionRow {
  @Prop title: string
  @Prop value: string
  onChange: (val: string) => void = () => {}
  @StorageLink('themeColorIndex') themeColorIndex: number = 0
  @Prop isDarkMode: boolean = false

  getActionIndex(val: string): number {
    switch(val) {
      case 'none': return 0;
      case 'record': return 1;
      case 'subtitle': return 2;
      case 'translate': return 3;
      default: return 0;
    }
  }

  getActionLabel(val: string): string {
    switch(val) {
      case 'none': return '无';
      case 'record': return '开关录音';
      case 'subtitle': return '开关字幕';
      case 'translate': return '开关传译';
      default: return '无';
    }
  }

  getActionValue(index: number): string {
    switch(index) {
      case 0: return 'none';
      case 1: return 'record';
      case 2: return 'subtitle';
      case 3: return 'translate';
      default: return 'none';
    }
  }

  build() {
    Row() {
      Text(this.title)
        .fontColor(Color.White)
        .fontSize(14)
      Blank()

      Select([
        { value: '无', icon: $r('sys.symbol.xmark') },
        { value: '开关录音', icon: $r('sys.symbol.mic') },
        { value: '开关字幕', icon: $r('sys.symbol.doc_text') },
        { value: '开关传译', icon: $r('sys.symbol.mic') }
      ])
        .selected(this.getActionIndex(this.value))
        .value(this.getActionLabel(this.value))
        .font({ size: 14, weight: FontWeight.Medium })
        .fontColor(Color.White)
        .selectedOptionFont({ size: 14, weight: FontWeight.Medium })
        .optionFont({ size: 14, weight: FontWeight.Medium })
        .backgroundColor(THEMES[this.themeColorIndex].secondaryColor)
        .onSelect((index: number) => {
          this.onChange(this.getActionValue(index));
        })
        .selectedOptionBgColor(THEMES[this.themeColorIndex].secondaryColor)
        .selectedOptionFontColor($r('sys.color.font_on_primary'))
        .menuBackgroundBlurStyle(BlurStyle.Thin)

    }
    .width('100%')
    .height(56)
    .padding({ left: 12, right: 12 })
    .borderRadius(18)
    .backgroundColor(THEMES[this.themeColorIndex].tertiaryColor)
    .margin({ bottom: 8 })
  }
}

@Component
export struct SettingsPage {
  // Props
  @Link isRealtimeReadingEnabled: boolean;
  @Prop isPipSubtitleEnabled: boolean = false; // PiP 字幕开关状态
  @Prop isPipAvailable: boolean = true; // PiP 是否可用
  @Link subtitleFontSize: number;
  @Link subtitleFontColor: string;
  @Link subtitleBackgroundColor: string;
  @Link subtitleHeight: number;
  @Link isLightEffectBright: boolean;
  @Link themeMode: number;  // 0 = 浅色, 1 = 深色, 2 = 跟随系统
  @Prop isDarkMode: boolean = true;  // 计算后的暗色模式状态（用于光效）

  // Theme Color
  @StorageLink('themeColorIndex') @Watch('onThemeColorChange') themeColorIndex: number = 0;

  onThemeColorChange() {
    this.settingsBtnBgColor = THEMES[this.themeColorIndex].primaryColor;
  }

  // Air Gestures Settings
  @StorageLink('airGesturesEnabled') airGesturesEnabled: boolean = false;
  @StorageLink('airGestureUpAction') airGestureUpAction: string = 'record';
  @StorageLink('airGestureDownAction') airGestureDownAction: string = 'translate';

  // Callbacks
  onTogglePipSubtitle: (isOn: boolean) => void = () => {}; // PiP 字幕切换回调
  onToggleRealtimeReading: () => void = () => {};
  onStyleChange: () => void = () => {};
  onThemeModeChange: (mode: number) => void = () => {};

  // Struct
  dialogController: CustomDialogController = new CustomDialogController({
    builder: SubtitleStyleDialog({
      fontSize: $subtitleFontSize,
      fontColor: $subtitleFontColor,
      subtitleBackgroundColor: $subtitleBackgroundColor,
      subtitleHeight: $subtitleHeight,
      onConfirm: () => {
        this.onStyleChange();
      },
      onChange: () => {
        this.onStyleChange();
      }
    }),
    alignment: DialogAlignment.Center,
  })

  @State appVersion: string = '';
  @State pageOpacity: number = 0;
  @State pageOffsetY: number = 18;
  @State pageScale: number = 0.98;
  @State backgroundAngle: number = 150;
  @State sectionOpacities: number[] = new Array(SETTINGS_SECTION_COUNT).fill(0);
  @State sectionOffsets: number[] = new Array(SETTINGS_SECTION_COUNT).fill(16);

  async aboutToAppear() {
    this.settingsBtnBgColor = THEMES[this.themeColorIndex].primaryColor;
    this.pageOpacity = 0;
    this.pageOffsetY = 18;
    this.pageScale = 0.98;
    this.backgroundAngle = 150;
    this.sectionOpacities = new Array(SETTINGS_SECTION_COUNT).fill(0);
    this.sectionOffsets = new Array(SETTINGS_SECTION_COUNT).fill(16);

    setTimeout(() => {
      animateTo({ duration: 320, curve: Curve.FastOutSlowIn }, () => {
        this.pageOpacity = 1;
        this.pageOffsetY = 0;
        this.pageScale = 1.0;
      });
    }, 40);

    for (let i = 0; i < SETTINGS_SECTION_COUNT; i++) {
      setTimeout(() => {
        animateTo({ duration: 280, curve: Curve.FastOutSlowIn }, () => {
          this.sectionOpacities[i] = 1;
          this.sectionOffsets[i] = 0;
        });
      }, 120 + i * 70);
    }
    try {
      let bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      this.appVersion = bundleInfo.versionName;
    } catch (error) {
      console.error('Failed to get bundle info:', error);
    }
  }

  @State liveWindowEnabled: boolean = false;
  @State isPolicySheetOpen: boolean = false;
  @State currentPolicySheet: PolicySheetType = PolicySheetType.Privacy;

  // New state for Settings button
  @State settingsBtnScale: number = 1.0;
  @State settingsBtnBgColor: ResourceColor = '#3c1464';
  @State settingsBtnTextColor: ResourceColor = Color.White;
  @State isSettingsBtnActive: boolean = false;

  // Section expand states
  @State isSubtitleSectionOpen: boolean = true;
  @State isTranslateSectionOpen: boolean = true;
  @State isGestureSectionOpen: boolean = false;
  @State isAppearanceSectionOpen: boolean = false;
  @State isInfoSectionOpen: boolean = false;
  @State isFaqSectionOpen: boolean = false;

  private policyWebController: webview.WebviewController = new webview.WebviewController();

  private openPolicySheet(sheet: PolicySheetType): void {
    this.currentPolicySheet = sheet;
    this.policyWebController = new webview.WebviewController();
    this.isPolicySheetOpen = true;
  }

  private closePolicySheet(): void {
    this.isPolicySheetOpen = false;
  }

  @Builder
  ThemeListBuilder() {
    Row({ space: 10 }) {
      ForEach(THEMES, (theme: Theme, index: number) => {
        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 28, height: 28 })
            .fill(theme.primaryColor)
            .shadow(this.themeColorIndex === index ? { radius: 12, color: theme.primaryColor, offsetX: 0, offsetY: 4 } : { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 })
            .scale({ x: this.themeColorIndex === index ? 1.0 : 0.85, y: this.themeColorIndex === index ? 1.0 : 0.85 })
            .animation({ duration: 250, curve: Curve.FastOutSlowIn })
          
          if (this.themeColorIndex === index) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(14)
              .fontColor([Color.White])
              .fontWeight(FontWeight.Bold)
          }
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .clip(true)
        .backgroundColor(this.themeColorIndex === index ? '#20FFFFFF' : Color.Transparent)
        .border({ width: this.themeColorIndex === index ? 2 : 0, color: Color.White })
        .animation({ duration: 250, curve: Curve.FastOutSlowIn })
        .onClick(() => {
          animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
            this.themeColorIndex = index;
          })
        })
      })
    }
  }

  @Builder
  PipToggleItem() {
    SettingsItem({
      title: '画中画字幕',
      subtitle: '在应用外也可显示翻译'
    }) {
      Toggle({ type: ToggleType.Switch, isOn: this.isPipSubtitleEnabled })
        .selectedColor(THEMES[this.themeColorIndex].primaryColor)
        .enabled(this.isPipAvailable)
        .onChange((isOn: boolean) => {
          this.onTogglePipSubtitle(isOn);
        })
    }

    SettingsItem({
      title: '字幕样式',
      hasArrow: true,
      onClickItem: () => {
        this.dialogController.open()
      }
    })
  }

  @Builder
  RealtimeReadingItem() {
    SettingsItem({
      title: '实时朗读',
      subtitle: '打开后，翻译成功时传译将自动开启'
    }) {
      Toggle({ type: ToggleType.Switch, isOn: this.isRealtimeReadingEnabled })
        .selectedColor(THEMES[this.themeColorIndex].primaryColor)
        .onChange((isOn: boolean) => {
          this.isRealtimeReadingEnabled = isOn;
          this.onToggleRealtimeReading();
        })
    }
  }

  @Builder
  AirGestureToggleItem() {
    SettingsItem({
      title: '启用隔空手势',
      subtitle: '上下滑动控制录音/字幕/传译'
    }) {
      Toggle({ type: ToggleType.Switch, isOn: this.airGesturesEnabled })
        .selectedColor(THEMES[this.themeColorIndex].primaryColor)
        .onChange((isOn: boolean) => {
          this.airGesturesEnabled = isOn;
        })
    }
  }

  @Builder
  AppearanceItems() {
    SettingsItem({
      title: '主题模式',
      subtitle: '深色模式下光效被禁用'
    }) {
      CapsuleSegmentButtonV2({
        items: new SegmentButtonV2Items([
          { text: '浅色' },
          { text: '深色' },
          { text: '自动' }
        ]),
        selectedIndex: this.themeMode,
        $selectedIndex: (index: number) => {
          this.themeMode = index;
          this.onThemeModeChange(index);
        },
        buttonBackgroundColor: ColorMetrics.resourceColor($r('sys.color.comp_background_tertiary')),
        itemSelectedBackgroundColor: ColorMetrics.resourceColor(THEMES[this.themeColorIndex].primaryColor),
        itemFontColor: ColorMetrics.resourceColor($r('sys.color.font_on_secondary'))
      })
        .width(150)
    }

    SettingsItem({
      title: '全局主题',
      subtitle: THEMES[this.themeColorIndex].name
    }) {
      this.ThemeListBuilder()
    }

    SettingsItem({
      title: '光效亮度',
      subtitle: '按下部分卡片或按钮的点光源效果'
    }) {
      CapsuleSegmentButtonV2({
        items: new SegmentButtonV2Items([
          { text: '明亮' },
          { text: '柔和' }
        ]),
        selectedIndex: this.isLightEffectBright ? 0 : 1,
        $selectedIndex: (index: number) => {
          this.isLightEffectBright = index === 0;
        },
        buttonBackgroundColor: ColorMetrics.resourceColor($r('sys.color.comp_background_tertiary')),
        itemSelectedBackgroundColor: ColorMetrics.resourceColor(THEMES[this.themeColorIndex].primaryColor),
        itemFontColor: ColorMetrics.resourceColor($r('sys.color.font_on_secondary'))
      })
        .width(100)
        .enabled(!this.isDarkMode)
        .opacity(this.isDarkMode ? 0.5 : 1.0)
    }
  }

  build() {
    Stack() {
      HdsNavigation() {
        Scroll() {
          Column() {
            Blank().height(TITLE_BAR_HEIGHT_MINI);

            // Subtitle Section
            Column() {
              SettingsGroup({
                title: '字幕',
                icon: $r('sys.symbol.AI_subtitles'),
                isOpen: $isSubtitleSectionOpen,
                isDarkMode: this.isDarkMode
              }) {
                this.PipToggleItem()
              }
            }
            .opacity(this.sectionOpacities[0])
            .offset({ y: this.sectionOffsets[0] })

            // Translate Section
            Column() {
              SettingsGroup({
                title: '传译',
                icon: $r('sys.symbol.voice_convert_text'),
                isOpen: $isTranslateSectionOpen,
                isDarkMode: this.isDarkMode
              }) {
                this.RealtimeReadingItem()
              }
            }
            .opacity(this.sectionOpacities[1])
            .offset({ y: this.sectionOffsets[1] })

            // Gesture Section
            Column() {
              SettingsGroup({
                title: '隔空手势',
                icon: $r('sys.symbol.hand_raised_hexagon'),
                isOpen: $isGestureSectionOpen,
                isDarkMode: this.isDarkMode
              }) {
                this.AirGestureToggleItem()

                if (this.airGesturesEnabled) {
                  Column() {
                    GestureActionRow({
                      title: '向上挥手',
                      value: this.airGestureUpAction,
                      onChange: (val: string) => { this.airGestureUpAction = val },
                      isDarkMode: this.isDarkMode
                    })
                    GestureActionRow({
                      title: '向下挥手',
                      value: this.airGestureDownAction,
                      onChange: (val: string) => { this.airGestureDownAction = val },
                      isDarkMode: this.isDarkMode
                    })
                  }
                  .padding({ left: 12, right: 12 })
                }
              }
            }
            .opacity(this.sectionOpacities[2])
            .offset({ y: this.sectionOffsets[2] })

            // Appearance Section
            Column() {
              SettingsGroup({
                title: '外观',
                icon: $r('sys.symbol.skin_tone'),
                isOpen: $isAppearanceSectionOpen,
                isDarkMode: this.isDarkMode
              }) {
                this.AppearanceItems()
              }
            }
            .opacity(this.sectionOpacities[3])
            .offset({ y: this.sectionOffsets[3] })

            // Info Section
            Column() {
              SettingsGroup({
                title: '基本信息',
                icon: $r('sys.symbol.info_circle'),
                isOpen: $isInfoSectionOpen,
                isDarkMode: this.isDarkMode
              }) {
                SettingsItem({
                  title: '用户协议',
                  hasArrow: true,
                  onClickItem: () => this.openPolicySheet(PolicySheetType.Terms)
                })
                SettingsItem({
                  title: '隐私政策',
                  hasArrow: true,
                  onClickItem: () => this.openPolicySheet(PolicySheetType.Privacy)
                })
                SettingsItem({
                  title: '关于',
                  hasArrow: true,
                  onClickItem: () => this.openPolicySheet(PolicySheetType.About)
                })
              }
            }
            .opacity(this.sectionOpacities[4])
            .offset({ y: this.sectionOffsets[4] })

            // FAQ Section
            Column() {
              SettingsGroup({
                title: '常见问题',
                icon: $r('sys.symbol.questionmark_circle'),
                isOpen: $isFaqSectionOpen,
                isDarkMode: this.isDarkMode
              }) {
                SettingsItem({
                  title: 'Voot 持有面向用户的集中式服务器吗？',
                  subtitle: '没有。Voot 是一款纯客户端应用，所有数据处理均在本地或直接与您配置的第三方 API 通信，我们不持有任何用户数据服务器。'
                })
                SettingsItem({
                  title: '在 Voot 保存的密钥怎么保证安全？',
                  subtitle: '您的 API 密钥仅存储在您设备的本地安全存储区中，绝不会上传到我们的服务器，我们也不持有服务器。应用仅在向服务商发起请求时使用密钥。'
                })
                SettingsItem({
                  title: '我们如何接受政府组织对 AI 的监管？',
                  subtitle: 'Voot 严格遵守当地法律法规。作为工具提供方，我们不提供内置的 AI 模型服务，用户需自行确保所使用的第三方 API 服务符合相关监管要求。'
                })
              }
            }
            .opacity(this.sectionOpacities[5])
            .offset({ y: this.sectionOffsets[5] })

            Blank().height(70)
          }
          .opacity(this.pageOpacity)
          .offset({ y: this.pageOffsetY })
          .scale({ x: this.pageScale, y: this.pageScale })
          .width('100%')
          .padding({ left: 24, right: 24, top: 16, bottom: 70 })
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }
      .mode(NavigationMode.Stack)
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
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
              backIconStyle: {
                backgroundColor: $r('sys.color.comp_background_tertiary'),
                iconColor: $r('sys.color.icon_primary')
              }
            }
          },
        },
        content: {
          title: { mainTitle: '设置' },
        },
        avoidLayoutSafeArea: true
      })
      .bindSheet(
        $$this.isPolicySheetOpen,
        PolicySheetContent(getPolicySheetConfig(this.currentPolicySheet, this.appVersion), this.policyWebController, () => {
          this.closePolicySheet();
        }, getContext(this) as common.UIAbilityContext, this.themeColorIndex), {
        detents: [SheetSize.FIT_CONTENT, SheetSize.MEDIUM, SheetSize.LARGE],
        dragBar: true,
        backgroundColor: Color.Transparent,
        blurStyle: BlurStyle.BACKGROUND_THIN,
        enableOutsideInteractive: true,
      })
    }
    .width('100%')
    .height('100%')
  }
}
