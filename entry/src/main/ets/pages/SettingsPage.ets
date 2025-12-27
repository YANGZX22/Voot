import { hdsEffect, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { CapsuleSegmentButtonV2, SegmentButtonV2Items, ColorMetrics } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import common from '@ohos.app.ability.common';
import bundleManager from '@ohos.bundle.bundleManager';
import { PolicySheetType, PolicySheetContent, getPolicySheetConfig } from '../components/PolicySheet';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

const TITLE_BAR_HEIGHT_MINI: number = 94;
type ToggleKey = 'subtitles' | 'liveWindow';

@CustomDialog
struct CustomDialogSubtitle {
  controller: CustomDialogController
  title: string = '';
  message: string = '';
  confirmText: string = '我知道了';
  onDismiss: () => void = () => {};

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
        .backgroundColor("#e63c1464")
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
        .backgroundColor("#e63c1464")
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

  // Predefined colors
  private colors: string[] = ['#FFFFFF', '#000000', '#FF0000', '#00FF00', '#0000FF', '#FFFF00', '#00FFFF', '#FF00FF', '#3c1464']

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
          .onChange((value: number) => {
            this.fontSize = value
          })
          .selectedColor('#3c1464')
          .layoutWeight(1)
        Text(this.fontSize.toFixed(0))
          .width(40)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .margin({ bottom: 15 })

      // Subtitle Height
      Row() {
        Text('字幕高度')
        Slider({ value: this.subtitleHeight, min: 10, max: 30, step: 1 })
          .onChange((value: number) => {
            this.subtitleHeight = value
          })
          .selectedColor('#3c1464')
          .layoutWeight(1)
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
        .backgroundColor('#3c1464')
        .width('80%')
    }
    .padding(24)
    .backgroundColor(Color.Transparent)
    .borderRadius(24)
    .width('90%')
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
      }
    }),
    alignment: DialogAlignment.Center,
  })


  // State for Lighting Effect
  // 0 = None, 1 = Mic Button, 2 = Translate Button

  @State activeBtn: number = 0;

  @State button1Scale: number = 1.0;
  @State appVersion: string = '';

  async aboutToAppear() {
    try {
      let bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      this.appVersion = bundleInfo.versionName;
    } catch (error) {
      console.error('Failed to get bundle info:', error);
    }
  }

  @State button2Scale: number = 1.0;
  @State liveWindowEnabled: boolean = false;
  @State isPolicySheetOpen: boolean = false;
  @State currentPolicySheet: PolicySheetType = PolicySheetType.Privacy;

  // New state for Settings button
  @State settingsBtnScale: number = 1.0;
  @State settingsBtnBgColor: ResourceColor = '#3c1464';
  @State settingsBtnTextColor: ResourceColor = Color.White;
  @State isSettingsBtnActive: boolean = false;

  // State for Dark Mode button
  @State darkModeBtnScale: number = 1.0;
  @State isDarkModeBtnActive: boolean = false;

  // State for Terms button
  @State termsBtnScale: number = 1.0;
  @State isTermsBtnActive: boolean = false;

  // State for Privacy button
  @State privacyBtnScale: number = 1.0;
  @State isPrivacyBtnActive: boolean = false;

  // State for About button
  @State aboutBtnScale: number = 1.0;
  @State isAboutBtnActive: boolean = false;

  private liveWindowDialogController?: CustomDialogController;
  private policyWebController: webview.WebviewController = new webview.WebviewController();

  private handleDialogDismiss(key: ToggleKey): void {
    if (key === 'liveWindow') {
      this.liveWindowEnabled = false;
    }
  }

  private openPolicySheet(sheet: PolicySheetType): void {
    this.currentPolicySheet = sheet;
    this.policyWebController = new webview.WebviewController();
    this.isPolicySheetOpen = true;
  }

  private closePolicySheet(): void {
    this.isPolicySheetOpen = false;
  }

  private pressSettingsButton(): void {
    animateTo({ duration: 250, curve: Curve.EaseIn }, () => {
      this.isSettingsBtnActive = true;
      this.settingsBtnScale = 0.9;
      this.settingsBtnBgColor = Color.White;
      this.settingsBtnTextColor = '#3c1464';
    });
  }

  private releaseSettingsButton(): void {
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.isSettingsBtnActive = false;
      this.settingsBtnScale = 1.0;
      this.settingsBtnBgColor = '#3c1464';
      this.settingsBtnTextColor = Color.White;
    });
  }

  private pressButtonEffect(btnId: number): void {
    animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
      if (btnId === 1) { this.isDarkModeBtnActive = true; this.darkModeBtnScale = 0.9; }
      if (btnId === 2) { this.isTermsBtnActive = true; this.termsBtnScale = 0.9; }
      if (btnId === 3) { this.isPrivacyBtnActive = true; this.privacyBtnScale = 0.9; }
      if (btnId === 4) { this.isAboutBtnActive = true; this.aboutBtnScale = 0.9; }
    });
  }

  private releaseButtonEffect(btnId: number): void {
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      if (btnId === 1) { this.isDarkModeBtnActive = false; this.darkModeBtnScale = 1.0; }
      if (btnId === 2) { this.isTermsBtnActive = false; this.termsBtnScale = 1.0; }
      if (btnId === 3) { this.isPrivacyBtnActive = false; this.privacyBtnScale = 1.0; }
      if (btnId === 4) { this.isAboutBtnActive = false; this.aboutBtnScale = 1.0; }
    });
  }

  build() {
    HdsNavigation() {
      Scroll() {
        Column() {
          Blank().height(TITLE_BAR_HEIGHT_MINI);

          Text('字幕')
            .fontColor(Color.White)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 8 });

          // PiP 字幕开关
          Row() {
            Blank().width(12)
            Column() {
              Text('画中画字幕').fontColor(Color.White).alignSelf(ItemAlign.Start)
              Text('在应用外也可显示翻译')
                .fontColor('#80FFFFFF')
                .fontSize(12)
                .alignSelf(ItemAlign.Start)
            }

            Blank()

            Toggle({
              type: ToggleType.Switch,
              isOn: this.isPipSubtitleEnabled
            })
            .selectedColor('#3c1464')
            .enabled(this.isPipAvailable)
            .onChange((isOn: boolean) => {
              this.onTogglePipSubtitle(isOn);
            })

            Blank().width(12)
          }
          .width('100%')
          .height(70)
          .padding(4)
          .margin({ bottom: 12 })
          .borderRadius(24)
          .backgroundColor(this.isPipAvailable ? '#803c1464' : '#403c1464')
          .opacity(this.isPipAvailable ? 1.0 : 0.6)
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            })
            .buildEffect())

          Row() {
            Blank().width(12)

            Text('字幕样式').fontColor(Color.White)

            Blank()

            Button('设置')
              .type(ButtonType.Capsule)
              .backgroundColor(this.settingsBtnBgColor)
              .fontColor(this.settingsBtnTextColor)
              .height(30)
              .scale({ x: this.settingsBtnScale, y: this.settingsBtnScale })
              .visualEffect(new hdsEffect.HdsEffectBuilder()
                .pointLight({
                  sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
                    (this.isSettingsBtnActive ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT) : hdsEffect.PointLightSourceType.NONE),
                  illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE :
                    (this.isSettingsBtnActive ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT : hdsEffect.PointLightIlluminatedType.NONE)
                })
                .buildEffect())
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.pressSettingsButton();
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.releaseSettingsButton();
                }
              })
              .onClick(() => {
                this.dialogController.open()
              })

            Blank().width(12)
          }
          .width('100%')
          .height(60)
          .padding(4)
          .margin({ bottom: 12 })
          .borderRadius(24)
          .backgroundColor('#803c1464')
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            })
            .buildEffect())

          Blank().height(12)

          Row() {
            Text('传译')
              .fontColor(Color.White)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)

            SymbolGlyph($r('sys.symbol.info_circle'))
              .fontSize(16)
              .fontColor([Color.White])
              .margin({ left: 4 })
              .onClick(() => {
                AlertDialog.show({
                  title: '传译说明',
                  message: '开启实时朗读开关后，当翻译成功时传译器会自动打开。\n',
                  confirm: {
                    value: '我知道了',
                    fontColor: '#3c1464',
                    action: () => {}
                  }
                })
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ bottom: 8 })

          Row() {
            Blank().width(12)
            Text('实时朗读').fontColor(Color.White)

            Blank()

            Toggle({
              type: ToggleType.Switch,
              isOn: this.isRealtimeReadingEnabled
            })
            .selectedColor('#3c1464')
            .onChange((isOn: boolean) => {
              this.isRealtimeReadingEnabled = isOn;
              this.onToggleRealtimeReading();
            })

            Blank().width(12)
          }
          .width('100%')
          .height(60)
          .padding(4)
          .margin({ bottom: 12 })
          .borderRadius(24)
          .backgroundColor('#803c1464')
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            })
            .buildEffect())

          Blank().height(12)

          Text('外观')
            .fontColor(Color.White)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 8 });

          Row() {
            Blank().width(12)
            Column() {
              Text('主题模式').fontColor(Color.White).alignSelf(ItemAlign.Start)
              Text('深色模式下光效被禁用')
                .fontColor('#80FFFFFF')
                .fontSize(12)
                .alignSelf(ItemAlign.Start)
            }

            Blank()

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
              itemSelectedBackgroundColor: ColorMetrics.rgba(60, 20, 100, 1),
            })
            .width(150)

            Blank().width(12)
          }
          .width('100%')
          .height(70)
          .padding(4)
          .margin({ bottom: 12 })
          .borderRadius(24)
          .backgroundColor('#803c1464')
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            })
            .buildEffect())

          Row() {
            Blank().width(12)
            Text('光效亮度').fontColor(this.isDarkMode ? '#80FFFFFF' : Color.White)

            Blank()

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
              itemSelectedBackgroundColor: ColorMetrics.rgba(60, 20, 100, 1),
              // buttonBackgroundEffect: {radius: 24}
            })
            .width(100)
            .enabled(!this.isDarkMode)
            .opacity(this.isDarkMode ? 0.5 : 1.0)

            Blank().width(12)
          }
          .width('100%')
          .height(60)
          .padding(4)
          .margin({ bottom: 12 })
          .borderRadius(24)
          .backgroundColor('#803c1464')
          .opacity(this.isDarkMode ? 0.5 : 1.0)
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            })
            .buildEffect())

          Blank().height(12)

          Text('基本信息')
            .fontColor(Color.White)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 8 });

          Row() {
            Blank().width(12)

            Text('用户协议').fontColor(Color.White)

            Blank()

            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph($r('sys.symbol.arrow_right')).fontColor(["#3c1464"])
            }
            .width(30)
            .height(30)
            .margin(20)
            .backgroundColor(Color.White)
            .scale({ x: this.termsBtnScale, y: this.termsBtnScale })
            .visualEffect(new hdsEffect.HdsEffectBuilder()
              .pointLight({
                sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
                  (this.isTermsBtnActive ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT) : hdsEffect.PointLightSourceType.NONE),
                illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE :
                  (this.isTermsBtnActive ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT : hdsEffect.PointLightIlluminatedType.NONE)
              })
              .buildEffect())
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.pressButtonEffect(2);
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.releaseButtonEffect(2);
              }
            })
            .onClick(() => this.openPolicySheet(PolicySheetType.Terms))

          }
          .width('100%')
          .height(60)
          .padding(4)
          .margin({ bottom: 12 })
          .borderRadius(24)
          .backgroundColor('#803c1464')
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            })
            .buildEffect())

          Row() {
            Blank().width(12)

            Text('隐私政策').fontColor(Color.White)

            Blank()

            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph($r('sys.symbol.arrow_right')).fontColor(["#3c1464"])
            }
              .width(30)
              .height(30)
              .margin(20)
              .backgroundColor(Color.White)
              .scale({ x: this.privacyBtnScale, y: this.privacyBtnScale })
              .visualEffect(new hdsEffect.HdsEffectBuilder()
                .pointLight({
                  sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
                    (this.isPrivacyBtnActive ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT) : hdsEffect.PointLightSourceType.NONE),
                  illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE :
                    (this.isPrivacyBtnActive ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT : hdsEffect.PointLightIlluminatedType.NONE)
                })
                .buildEffect())
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.pressButtonEffect(3);
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.releaseButtonEffect(3);
                }
              })
              .onClick(() => this.openPolicySheet(PolicySheetType.Privacy))

          }
          .width('100%')
          .height(60)
          .padding(4)
          .margin({ bottom: 12 })
          .borderRadius(24)
          .backgroundColor('#803c1464')
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            })
            .buildEffect())

          Row() {
            Blank().width(12)

            Text('关于').fontColor(Color.White)

            Blank()

            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph($r('sys.symbol.arrow_right')).fontColor(["#3c1464"])
            }
              .width(30)
              .height(30)
              .margin(20)
              .backgroundColor(Color.White)
              .scale({ x: this.aboutBtnScale, y: this.aboutBtnScale })
              .visualEffect(new hdsEffect.HdsEffectBuilder()
                .pointLight({
                  sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
                    (this.isAboutBtnActive ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT) : hdsEffect.PointLightSourceType.NONE),
                  illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE :
                    (this.isAboutBtnActive ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT : hdsEffect.PointLightIlluminatedType.NONE)
                })
                .buildEffect())
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.pressButtonEffect(4);
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.releaseButtonEffect(4);
                }
              })
              .onClick(() => this.openPolicySheet(PolicySheetType.About))

          }
          .width('100%')
          .height(60)
          .padding(4)
          .margin({ bottom: 12 })
          .borderRadius(24)
          .backgroundColor('#803c1464')
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            })
            .buildEffect())
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 16, bottom: 70 });
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
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
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
      }, getContext(this) as common.UIAbilityContext), {
      detents: [SheetSize.FIT_CONTENT, SheetSize.MEDIUM, SheetSize.LARGE],
      dragBar: true,
      backgroundColor: Color.Transparent,
      blurStyle: BlurStyle.BACKGROUND_THIN,
      enableOutsideInteractive: true,
    })
  }

  pressButton(btnId: number) {
    animateTo({
      duration: 300,
      curve: Curve.EaseIn
    }, () => {
      if (btnId === 1) this.button1Scale = 0.95;
      if (btnId === 2) this.button2Scale = 0.95;
    })
  }

  leaveButton(btnId: number) {
    animateTo({
      duration: 300,
      curve: Curve.EaseOut
    }, () => {
      if (btnId === 1) this.button1Scale = 1.0;
      if (btnId === 2) this.button2Scale = 1.0;
    })
  }
}