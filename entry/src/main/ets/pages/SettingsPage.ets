import { hdsEffect, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { CapsuleSegmentButtonV2, SegmentButtonV2Items, ColorMetrics, SymbolGlyphModifier } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import common from '@ohos.app.ability.common';
import { Want } from '@kit.AbilityKit';
import bundleManager from '@ohos.bundle.bundleManager';
import { PolicySheetType, PolicySheetContent, getPolicySheetConfig } from '../components/PolicySheet';
import { OnboardingStorage } from '../storage/OnboardingStorage';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { THEMES, Theme } from '../model/Theme';
import { AuthUtil } from '@pura/harmony-utils';
import userIAM_userAuth from '@ohos.userIAM.userAuth';
import { BusinessError } from '@kit.BasicServicesKit';

const TITLE_BAR_HEIGHT_MINI: number = 94;
const SETTINGS_SECTION_COUNT: number = 8;
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
  @Prop isLightEffectBright: boolean = true
  @State lightIntensity: number = 0;

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
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        animateTo({ duration: 300, curve: "cubic-bezier(0.33, 0, 0.67, 1)" }, () => {
          this.lightIntensity = this.isLightEffectBright ? 1 : 0.3;
        });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        animateTo({ duration: 200, curve: Curve.Linear }, () => {
          this.lightIntensity = 0;
        });
      }
    })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT,
        options: {
          color: Color.White,
          intensity: this.isDarkMode ? 0 : this.lightIntensity,
          height: 200
        }
      })
      .buildEffect())
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
        .arrowModifier(new SymbolGlyphModifier($r('sys.symbol.arrowtriangle_down_fill')).fontColor([Color.White]))
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

@CustomDialog
struct ExitVerificationDialog {
  controller: CustomDialogController
  onConfirm: () => void = () => {}

  build() {
    Column() {
      Text('退出验证')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.Black)
        .margin({ bottom: 12 })
      
      Text('确定要退出验证吗？退出后将无法使用部分功能，直到重新验证。')
        .fontSize(16)
        .fontColor('#666666')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 24 })
        .lineHeight(24)

      Row() {
        Button('取消')
          .type(ButtonType.Capsule)
          .backgroundColor('#F5F5F5')
          .fontColor('#666666')
          .layoutWeight(1)
          .margin({ right: 12 })
          .onClick(() => {
            this.controller.close()
          })

        Button('退出')
          .type(ButtonType.Capsule)
          .backgroundColor('#FF0000')
          .fontColor(Color.White)
          .layoutWeight(1)
          .onClick(() => {
            this.controller.close()
            this.onConfirm()
          })
      }
      .width('100%')
    }
    .width(300)
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius(24)
  }
}

@Component
export struct SettingsPage {
  // Props
  @Prop @Watch('onVisibleChange') isVisible: boolean = false;
  @Prop isLeftHand: boolean = false;
  @Prop isRightHand: boolean = false;
  @Prop isPoseDetectionSupported: boolean = true;
  @Link isRealtimeReadingEnabled: boolean;
  @Prop @Watch('onPipEnabledChange') isPipSubtitleEnabled: boolean = false; // PiP 字幕开关状态
  @Prop isPipAvailable: boolean = true; // PiP 是否可用
  @Link subtitleFontSize: number;
  @Link subtitleFontColor: string;
  @Link subtitleBackgroundColor: string;
  @Link subtitleHeight: number;
  @Link isLightEffectBright: boolean;
  @Link themeMode: number;  // 0 = 浅色, 1 = 深色, 2 = 跟随系统
  @Prop isDarkMode: boolean = true;  // 计算后的暗色模式状态（用于光效）

  // 握持弹窗临时关闭状态
  @State isHandPopupDismissed: boolean = false;

  // 智感握姿提示 Popup
  @State showPoseDetectionTip: boolean = false;

  // 隔空手势提示 Popup
  @State showAirGestureTip: boolean = false;

  // 本地动画状态变量
  @State showSubtitleStyle: boolean = false;
  @State showGestureActions: boolean = false;

  // Theme Color
  @StorageLink('themeColorIndex') @Watch('onThemeColorChange') themeColorIndex: number = 0;
  @StorageLink('isNumberVerified') isVerified: boolean = false;

  onThemeColorChange() {
    this.settingsBtnBgColor = THEMES[this.themeColorIndex].primaryColor;
  }

  onVisibleChange() {
    // 切换页面时重置握持弹窗临时关闭状态
    if (this.isVisible) {
      this.isHandPopupDismissed = false;
    }
  }

  onPipEnabledChange() {
    animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
      this.showSubtitleStyle = this.isPipSubtitleEnabled;
    });
  }

  // Air Gestures Settings
  @StorageLink('airGesturesEnabled') @Watch('onAirGesturesChange') airGesturesEnabled: boolean = false;

  onAirGesturesChange() {
    animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
      this.showGestureActions = this.airGesturesEnabled;
    });
  }
  @StorageLink('airGestureUpAction') airGestureUpAction: string = 'record';
  @StorageLink('airGestureDownAction') airGestureDownAction: string = 'translate';
  @StorageLink('poseDetectionEnabled') poseDetectionEnabled: boolean = false;

  // API Config Page Settings
  @StorageLink('apiConfigRequireScreenLock') apiConfigRequireScreenLock: boolean = true;
  @StorageLink('apiConfigPrivacyMode') apiConfigPrivacyMode: boolean = true;

  // 屏幕锁定选项可用状态
  @State isScreenLockAvailable: boolean = true;

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

  exitDialogController: CustomDialogController = new CustomDialogController({
    builder: ExitVerificationDialog({
      onConfirm: () => {
        AppStorage.setOrCreate('isNumberVerified', false);
        OnboardingStorage.setNumberVerified(getContext(this) as common.UIAbilityContext, false);
        router.pushUrl({
          url: 'pages/WelcomePage',
          params: { targetStep: 3 }
        });
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true,
    backgroundColor: 'transparent'
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

    // 检测屏幕锁定选项是否可用
    this.checkScreenLockAvailability();

    // 初始化展开状态（无动画）
    this.showSubtitleStyle = this.isPipSubtitleEnabled;
    this.showGestureActions = this.airGesturesEnabled;

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
  @State isVerifiedSectionOpen: boolean = false;
  @State isSubtitleSectionOpen: boolean = true;
  @State isTranslateSectionOpen: boolean = true;
  @State isGestureSectionOpen: boolean = false;
  @State isApiConfigSectionOpen: boolean = false;
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
          Circle({ width: 36, height: 36 })
            .fill($r('sys.color.comp_background_tertiary'))

          SymbolGlyph($r('sys.symbol.paintpalette_fill'))
            .fontSize(28)
            .fontColor([[ '#3c1464', '#ED3A55', '#0A59F7', '#FF6699' ][index] || theme.primaryColor])
            .scale({ x: this.themeColorIndex === index ? 1.0 : 0.85, y: this.themeColorIndex === index ? 1.0 : 0.85 })
          
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
        .border({ width: 2, color: this.themeColorIndex === index ? Color.White : Color.Transparent })
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

    if (this.showSubtitleStyle) {
      Column() {
        SettingsItem({
          title: '字幕样式',
          hasArrow: true,
          onClickItem: () => {
            this.dialogController.open()
          }
        })
      }
      .width('100%')
      .clip(true)
      .transition(
        TransitionEffect.OPACITY.combine(
          TransitionEffect.translate({ y: -10 })
        ).animation({ duration: 300, curve: Curve.FastOutSlowIn })
      )
    }
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
      title: '隔空手势',
      subtitle: '上下挥手控制录音/字幕/传译'
    }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.info_circle'))
          .fontSize(18)
          .fontColor([$r('sys.color.font_on_secondary')])
          .bindPopup(this.showAirGestureTip, {
            message: '需要先在系统设置中“系统-快捷启动和手势-隔空滑动屏幕”开启该功能',
            placementOnTop: true,
            showInSubWindow: false,
            onStateChange: (e) => {
              if (!e.isVisible) {
                this.showAirGestureTip = false;
              }
            },
            messageOptions: {
              textColor: Color.White
            },
            backgroundBlurStyle: BlurStyle.BACKGROUND_REGULAR,
            transition: TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.FastOutSlowIn })
          })
          .onClick(() => {
            this.showAirGestureTip = !this.showAirGestureTip;
          })

        Toggle({ type: ToggleType.Switch, isOn: this.airGesturesEnabled })
          .selectedColor(THEMES[this.themeColorIndex].primaryColor)
          .onChange((isOn: boolean) => {
            this.airGesturesEnabled = isOn;
          })
      }
    }
  }

  @Builder
  PoseDetectionToggleItem() {
    if (this.isPoseDetectionSupported) {
      SettingsItem({
        title: '智感握姿',
        subtitle: '根据左右手握机姿势弹出快捷按钮'
      }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.info_circle'))
            .fontSize(18)
            .fontColor([$r('sys.color.font_on_secondary')])
            .bindPopup(this.showPoseDetectionTip, {
              message: '如有遮挡内容，可向屏幕边缘滑动暂时关闭',
              placementOnTop: true,
              showInSubWindow: false,
              onStateChange: (e) => {
                if (!e.isVisible) {
                  this.showPoseDetectionTip = false;
                }
              },
              messageOptions: {
                textColor: Color.White
              },
              backgroundBlurStyle: BlurStyle.BACKGROUND_REGULAR,
              transition: TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.FastOutSlowIn })
            })
            .onClick(() => {
              this.showPoseDetectionTip = !this.showPoseDetectionTip;
            })

          Toggle({ type: ToggleType.Switch, isOn: this.poseDetectionEnabled })
            .selectedColor(THEMES[this.themeColorIndex].primaryColor)
            .onChange((isOn: boolean) => {
              this.poseDetectionEnabled = isOn;
            })
        }
      }
    } else {
      SettingsItem({
        title: '智感握姿',
        subtitle: '您的设备不支持智感握姿功能，点击了解更多',
        hasArrow: true,
        onClickItem: () => {
          const context = getContext(this) as common.UIAbilityContext;
          const want: Want = {
            action: 'ohos.want.action.viewData',
            uri: 'https://consumer.huawei.com/cn/support/content/zh-cn16075323/'
          };
          context.startAbility(want);
        }
      })
    }
  }

  // 检测屏幕锁定选项是否可用
  private checkScreenLockAvailability(): void {
    try {
      const faceStatus = AuthUtil.getAvailableStatus(userIAM_userAuth.UserAuthType.FACE, userIAM_userAuth.AuthTrustLevel.ATL1);
      const fingerStatus = AuthUtil.getAvailableStatus(userIAM_userAuth.UserAuthType.FINGERPRINT, userIAM_userAuth.AuthTrustLevel.ATL2);
      const pinStatus = AuthUtil.getAvailableStatus(userIAM_userAuth.UserAuthType.PIN, userIAM_userAuth.AuthTrustLevel.ATL2);
      
      // 如果任一屏幕锁定方式可用，则认为屏幕锁定可用
      this.isScreenLockAvailable = faceStatus.status || fingerStatus.status || pinStatus.status;
      
      // 如果屏幕锁定不可用，自动关闭该设置
      if (!this.isScreenLockAvailable && this.apiConfigRequireScreenLock) {
        this.apiConfigRequireScreenLock = false;
      }
    } catch (err) {
      console.error('SettingsPage: Failed to check screen lock availability', err);
      this.isScreenLockAvailable = false;
    }
  }

  @Builder
  ApiConfigItems() {
    SettingsItem({
      title: '屏幕锁定选项',
      subtitle: this.isScreenLockAvailable ? '进入配置 API 页面前需验证屏幕锁定选项' : '您似乎没有屏幕锁定选项'
    }) {
      Toggle({ type: ToggleType.Switch, isOn: this.apiConfigRequireScreenLock })
        .selectedColor(THEMES[this.themeColorIndex].primaryColor)
        .enabled(this.isScreenLockAvailable)
        .opacity(this.isScreenLockAvailable ? 1.0 : 0.5)
        .onChange((isOn: boolean) => {
          if (!this.isScreenLockAvailable && isOn) {
            promptAction.showToast({ message: '请先在系统设置中配置屏幕锁定选项（PIN、指纹或人脸识别）' });
            return;
          }
          this.apiConfigRequireScreenLock = isOn;
        })
    }
    SettingsItem({
      title: '设为隐私页面',
      subtitle: '进入配置 API 页面后禁止截屏和录屏'
    }) {
      Toggle({ type: ToggleType.Switch, isOn: this.apiConfigPrivacyMode })
        .selectedColor(THEMES[this.themeColorIndex].primaryColor)
        .onChange((isOn: boolean) => {
          this.apiConfigPrivacyMode = isOn;
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

            // Verified Section
            Column() {
              SettingsGroup({
                title: this.isVerified ? '已验证' : '未验证手机号码',
                icon: this.isVerified ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.exclamationmark_circle'),
                isOpen: $isVerifiedSectionOpen,
                isDarkMode: this.isDarkMode,
                isLightEffectBright: this.isLightEffectBright
              }) {
                if (this.isVerified) {
                  SettingsItem({
                    title: '退出验证',
                    subtitle: '退出后将无法使用部分功能，需重新验证手机号码',
                    hasArrow: true,
                    onClickItem: () => {
                      this.exitDialogController.open();
                    }
                  })
                } else {
                  SettingsItem({
                    title: '去验证',
                    subtitle: '如果您处于中国大陆地区，请验证手机号码来满足政府部门监管要求',
                    hasArrow: true,
                    onClickItem: () => {
                      router.pushUrl({
                        url: 'pages/WelcomePage',
                        params: { targetStep: 3 }
                      });
                    }
                  })
                }
              }
            }
            .opacity(this.sectionOpacities[0])
            .offset({ y: this.sectionOffsets[0] })

            // Subtitle Section
            Column() {
              SettingsGroup({
                title: '字幕',
                icon: $r('sys.symbol.AI_subtitles'),
                isOpen: $isSubtitleSectionOpen,
                isDarkMode: this.isDarkMode,
                isLightEffectBright: this.isLightEffectBright
              }) {
                this.PipToggleItem()
              }
            }
            .opacity(this.sectionOpacities[1])
            .offset({ y: this.sectionOffsets[1] })

            // Translate Section
            Column() {
              SettingsGroup({
                title: '传译',
                icon: $r('sys.symbol.voice_convert_text'),
                isOpen: $isTranslateSectionOpen,
                isDarkMode: this.isDarkMode,
                isLightEffectBright: this.isLightEffectBright
              }) {
                this.RealtimeReadingItem()
              }
            }
            .opacity(this.sectionOpacities[2])
            .offset({ y: this.sectionOffsets[2] })

            // Gesture Section
            Column() {
              SettingsGroup({
                title: '手势',
                icon: $r('sys.symbol.hand_raised_hexagon'),
                isOpen: $isGestureSectionOpen,
                isDarkMode: this.isDarkMode,
                isLightEffectBright: this.isLightEffectBright
              }) {
                this.AirGestureToggleItem()

                if (this.showGestureActions) {
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
                  .width('100%')
                  .padding({ left: 12, right: 12 })
                  .clip(true)
                  .transition(
                    TransitionEffect.OPACITY.combine(
                      TransitionEffect.translate({ y: -10 })
                    ).animation({ duration: 300, curve: Curve.FastOutSlowIn })
                  )
                }

                this.PoseDetectionToggleItem()
              }
            }
            .opacity(this.sectionOpacities[3])
            .offset({ y: this.sectionOffsets[3] })

            // API Config Page Section
            Column() {
              SettingsGroup({
                title: '安全',
                icon: $r('sys.symbol.safe_box'),
                isOpen: $isApiConfigSectionOpen,
                isDarkMode: this.isDarkMode,
                isLightEffectBright: this.isLightEffectBright
              }) {
                this.ApiConfigItems()
              }
            }
            .opacity(this.sectionOpacities[4])
            .offset({ y: this.sectionOffsets[4] })

            // Appearance Section
            Column() {
              SettingsGroup({
                title: '外观',
                icon: $r('sys.symbol.brush'),
                isOpen: $isAppearanceSectionOpen,
                isDarkMode: this.isDarkMode,
                isLightEffectBright: this.isLightEffectBright
              }) {
                this.AppearanceItems()
              }
            }
            .opacity(this.sectionOpacities[5])
            .offset({ y: this.sectionOffsets[5] })

            // Info Section
            Column() {
              SettingsGroup({
                title: '基本信息',
                icon: $r('sys.symbol.info_circle'),
                isOpen: $isInfoSectionOpen,
                isDarkMode: this.isDarkMode,
                isLightEffectBright: this.isLightEffectBright
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
            .opacity(this.sectionOpacities[6])
            .offset({ y: this.sectionOffsets[6] })

            // FAQ Section
            Column() {
              SettingsGroup({
                title: '常见问题',
                icon: $r('sys.symbol.questionmark_circle'),
                isOpen: $isFaqSectionOpen,
                isDarkMode: this.isDarkMode,
                isLightEffectBright: this.isLightEffectBright
              }) {
                SettingsItem({
                  title: '为什么 Voot 备案了服务器？',
                  subtitle: '应部分国家或地区的监管要求，联网类应用可能需要进行服务器备案。但 Voot 不部署面向用户的集中式数据服务器；备案仅用于满足合规或者上架要求。应用的数据处理仍在本地完成，或仅在您发起请求时与您配置的第三方 API 直接通信。'
                })
                SettingsItem({
                  title: '在 Voot 保存的密钥怎么保证安全？',
                  subtitle: '您的 API 密钥仅存储在您设备的本地安全存储区中，绝不会上传到我们的服务器。应用仅在向服务商发起请求时使用密钥。'
                })
                SettingsItem({
                  title: '我们如何接受政府组织对 AI 的监管？',
                  subtitle: 'Voot 严格遵守当地法律法规。作为工具提供方，我们不提供内置的 AI 模型服务，用户需自行确保所使用的第三方 API 服务符合相关监管要求。'
                })
              }
            }
            .opacity(this.sectionOpacities[7])
            .offset({ y: this.sectionOffsets[7] })

            Blank().height(70)
          }
          .opacity(this.pageOpacity)
          .offset({ y: this.pageOffsetY })
          .scale({ x: this.pageScale, y: this.pageScale })
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 70 })
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

      // 握持快捷按钮
      if ((this.isLeftHand || this.isRightHand) && !this.isHandPopupDismissed) {
        Column({ space: 16 }) {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.AI_subtitles'))
              .fontSize(24)
              .fontColor(this.isPipSubtitleEnabled ? [THEMES[this.themeColorIndex].primaryColor] : [Color.White])
          }
          .width(48)
          .height(48)
          .backgroundColor(this.isPipSubtitleEnabled ? Color.White : THEMES[this.themeColorIndex].secondaryColor)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
          .stateStyles({
            pressed: {
              .scale({ x: 0.95, y: 0.95 })
            },
            normal: {
              .scale({ x: 1.0, y: 1.0 })
            }
          })
          .onClick(() => {
            this.onTogglePipSubtitle(!this.isPipSubtitleEnabled);
          })

          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.voice_convert_text'))
              .fontSize(24)
              .fontColor(this.isRealtimeReadingEnabled ? [THEMES[this.themeColorIndex].primaryColor] : [Color.White])
          }
          .width(48)
          .height(48)
          .backgroundColor(this.isRealtimeReadingEnabled ? Color.White : THEMES[this.themeColorIndex].secondaryColor)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
          .stateStyles({
            pressed: {
              .scale({ x: 0.95, y: 0.95 })
            },
            normal: {
              .scale({ x: 1.0, y: 1.0 })
            }
          })
          .onClick(() => {
            this.isRealtimeReadingEnabled = !this.isRealtimeReadingEnabled;
            this.onToggleRealtimeReading();
          })
        }
        .width(64)
        .padding(8)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .border({ width: 1.5, color: THEMES[this.themeColorIndex].tertiaryColor })
        .backdropBlur(20)
        .borderRadius(40)
        .position({ x: this.isLeftHand ? 0 : '100%', y: '30%' })
        .markAnchor({ x: this.isLeftHand ? 0 : '100%', y: 0 })
        .translate({ x: this.isLeftHand ? 16 : -16 })
        .alignItems(HorizontalAlign.Center)
        .transition(
          TransitionEffect.move(this.isLeftHand ? TransitionEdge.START : TransitionEdge.END)
            .animation({ duration: 300, curve: Curve.EaseOut })
        )
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal, distance: 5 })
            .onActionEnd((event: GestureEvent) => {
              // 左手时左滑关闭，右手时右滑关闭
              if ((this.isLeftHand && event.offsetX < -20) ||
                  (this.isRightHand && event.offsetX > 20)) {
                animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
                  this.isHandPopupDismissed = true;
                });
              }
            })
        )
      }
    }
    .width('100%')
    .height('100%')
  }
}
