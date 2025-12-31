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

import { hdsEffect, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import promptAction from '@ohos.promptAction';
import { THEMES } from '../model/Theme';
import { ContinuityService, DeviceInfo } from '../services/ContinuityService';
import { common } from '@kit.AbilityKit';

const TITLE_BAR_HEIGHT_MINI: number = 94;

@Component
export struct TranslationPage {
  // Props
  @Prop @Watch('onIsListeningChange') isListening: boolean = false;
  @Prop isAsrReady: boolean = false;
  @Prop originalDemoText: string = "";
  @Prop translatedDemoText: string = "";
  @Prop isTranslating: boolean = false;
  @Prop currentApiLabel: string = '';
  @Prop currentLanguageLabel: string = '';
  @Prop hasContinuityContent: boolean = false;
  @Prop isLightEffectBright: boolean = true;
  @Prop isDarkMode: boolean = true;
  @StorageLink('themeColorIndex') @Watch('onThemeColorChange') themeColorIndex: number = 0;

  // Callbacks
  onToggleCaptioning: () => void = () => {};
  onTranslateDemo: () => void = () => {};
  onOriginalTextChange: (value: string) => void = () => {};
  onTranslatedTextChange: (value: string) => void = () => {};
  onContinuityTransfer: (device?: DeviceInfo) => void = () => {};
  onOpenHistory: () => void = () => {};

  // State for Lighting Effect
  // 0 = None, 1 = Mic Button, 2 = Translate Button
  @State activeBtn: number = 0;

  @State button1Scale: number = 1.0;
  @State button2Scale: number = 1.0;

  @State btn1BgColor: ResourceColor = THEMES[this.themeColorIndex].secondaryColor;
  @State btn1TextColor: ResourceColor = Color.White;
  @State btn2BgColor: ResourceColor = THEMES[this.themeColorIndex].secondaryColor;
  @State btn2TextColor: ResourceColor = Color.White;

  @State button3Scale: number = 1.0;
  @State btn3BgColor: ResourceColor = Color.White;
  @State btn3TextColor: ResourceColor = THEMES[this.themeColorIndex].secondaryColor;

  // Device selection states
  @State showDeviceDialog: boolean = false;
  @State deviceList: DeviceInfo[] = [];

  helpDialogController: CustomDialogController = new CustomDialogController({
    builder: ContinuityHelpDialog(),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  })

  onThemeColorChange() {
    if (this.isListening) {
      this.btn1BgColor = Color.White;
      this.btn1TextColor = THEMES[this.themeColorIndex].primaryColor;
    } else {
      this.btn1BgColor = THEMES[this.themeColorIndex].secondaryColor;
      this.btn1TextColor = Color.White;
    }
    this.btn2BgColor = THEMES[this.themeColorIndex].secondaryColor;
    this.btn2TextColor = Color.White;
    this.btn3BgColor = Color.White;
    this.btn3TextColor = THEMES[this.themeColorIndex].primaryColor;
  }

  onIsListeningChange() {
    animateTo({
      duration: 100,
      curve: Curve.EaseOut
    }, () => {
      if (this.isListening) {
        this.btn1BgColor = Color.White;
        this.btn1TextColor = THEMES[this.themeColorIndex].primaryColor;
      } else {
        this.btn1BgColor = THEMES[this.themeColorIndex].secondaryColor;
        this.btn1TextColor = Color.White;
      }
    })
  }

  // Device discovery and selection methods
  private async startDeviceDiscovery(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const service = ContinuityService.getInstance();
      const initialized = await service.init(ctx);

      if (!initialized) {
        promptAction.showToast({ message: '无法初始化设备管理服务，请前往设置开启发现设备权限' });
        return;
      }

      this.deviceList = service.getTrustedDevices();

      service.setOnDeviceFoundCallback((device: DeviceInfo) => {
        const exists = this.deviceList.some(d => d.deviceId === device.deviceId);
        if (!exists) {
          this.deviceList.push(device);
        }
      });

      service.setOnDeviceLostCallback((deviceId: string) => {
        this.deviceList = this.deviceList.filter(d => d.deviceId !== deviceId);
      });

      service.startDiscovering();
      this.showDeviceDialog = true;

    } catch (err) {
      console.error('[TranslationPage] startDeviceDiscovery error: ' + JSON.stringify(err));
      promptAction.showToast({ message: '流转失败: ' + JSON.stringify(err) });
    }
  }

  private selectDevice(device: DeviceInfo): void {
    this.showDeviceDialog = false;
    ContinuityService.getInstance().stopDiscovering();
    // Delegate to parent for actual transfer with selected device
    this.onContinuityTransfer(device);
  }

  private getDeviceTypeLabel(type: number | string): string {
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
                  .backgroundColor(THEMES[this.themeColorIndex].primaryColor)
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
        .backgroundColor(THEMES[this.themeColorIndex].primaryColor)
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
    HdsNavigation() {
      Scroll() {
        Column() {
          Blank().height(TITLE_BAR_HEIGHT_MINI);

          if (this.currentApiLabel || this.currentLanguageLabel) {
            Row() {
              if (this.currentApiLabel) {
                Column() {
                  Text('当前选择 API')
                    .fontSize(12)
                    .fontColor($r('sys.color.font_on_secondary'))
                    .margin({ bottom: 4 });
                  Text(this.currentApiLabel)
                    .fontSize(14)
                    .fontColor(Color.White)
                    .fontWeight(FontWeight.Medium);
                }
                .backgroundColor(THEMES[this.themeColorIndex].secondaryColor)
                .padding({ left: 12, right: 12, top: 12, bottom: 12 })
                .borderRadius(24)
                .layoutWeight(1)
                .visualEffect(new hdsEffect.HdsEffectBuilder()
                  .pointLight({
                    illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
                  })
                  .buildEffect())
                .margin({ right: this.currentLanguageLabel ? 8 : 0 });
              }

              if (this.currentLanguageLabel) {
                Column() {
                  Text('当前目标语言')
                    .fontSize(12)
                    .fontColor($r('sys.color.font_on_secondary'))
                    .margin({ bottom: 4 });
                  Text(this.currentLanguageLabel)
                    .fontSize(14)
                    .fontColor(Color.White)
                    .fontWeight(FontWeight.Medium);
                }
                .padding({ left: 12, right: 12, top: 12, bottom: 12 })
                .backgroundColor(THEMES[this.themeColorIndex].secondaryColor)
                .borderRadius(24)
                .layoutWeight(1)
                .visualEffect(new hdsEffect.HdsEffectBuilder()
                  .pointLight({
                    illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
                  })
                  .buildEffect())
                .margin({ left: this.currentApiLabel ? 8 : 0 });
              }
            }
            .width('100%')
            .margin({ bottom: 16 });
          }

          Row() {
            Button() {
              Row() {
                SymbolGlyph(this.isListening ? $r('sys.symbol.record_circle') : $r('sys.symbol.play_fill'))
                  .fontSize(18)
                  .fontColor([this.btn1TextColor])
                  .margin({ right: 8 })
                Text(this.isListening ? '关闭麦克风' : '开启麦克风')
                  .fontSize(16)
                  .fontColor(this.btn1TextColor)
              }
            }
              .width('100%')
              .height(40)
              .backgroundColor(this.btn1BgColor)
              .scale({ x: this.button1Scale, y: this.button1Scale })
              .enabled(this.isAsrReady || !this.isListening)
              .visualEffect(new hdsEffect.HdsEffectBuilder()
                .pointLight({
                  sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
                    (this.activeBtn === 1 || this.isListening
                    ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
                    : hdsEffect.PointLightSourceType.NONE),
                  illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
                })
                .buildEffect())
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.pressButton(1); // Pass ID 1
                  animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 1; });
                } else if (event.type === TouchType.Up) {
                  this.leaveButton(1, true); // Pass ID 1, isUp=true
                  animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
                } else if (event.type === TouchType.Cancel) {
                  this.leaveButton(1, false); // Pass ID 1, isUp=false
                  animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
                }
              })
              .onClick(() => this.onToggleCaptioning());
          }
          .width('100%')
          .padding(4)
          .margin({ bottom: 16 })
          .borderRadius(12)
          .backgroundColor(Color.Transparent);

          Column() {
            Text('原始文本')
              .fontSize(14)
              .fontColor(this.isDarkMode ? Color.White : Color.Black)
              .opacity(0.6)
              .margin({ bottom: 8, left: 4 });

            Column() {
              TextArea({ text: this.originalDemoText })
                .width('100%')
                .height('100%')
                .fontColor(this.isDarkMode ? Color.White : Color.Black)
                .fontSize(16)
                .backgroundColor(Color.Transparent)
                .borderRadius(0)
                .onChange((value: string) => this.onOriginalTextChange(value))
                .onFocus(() => {
                  animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 4; });
                })
                .onBlur(() => {
                  animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
                })
            }
            .width('100%')
            .height(160)
            .padding(8)
            .backgroundColor(THEMES[this.themeColorIndex].secondaryColor)
            .borderRadius(24)
            .visualEffect(new hdsEffect.HdsEffectBuilder()
              .pointLight({
                sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
                  (this.activeBtn === 4
                  ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
                  : hdsEffect.PointLightSourceType.NONE),
                illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
              })
              .buildEffect())
          }
          .width('100%')
          .margin({ bottom: 16 });

          Row() {
            Button(this.isTranslating ? '翻译中' : '使用 API 翻译')
              .layoutWeight(2)
              .height(40)
              .backgroundColor(this.btn2BgColor)
              .fontColor(this.btn2TextColor)
              .scale({ x: this.button2Scale, y: this.button2Scale })
              .enabled(!this.isTranslating)
              .margin({ right: 8 })
              .visualEffect(new hdsEffect.HdsEffectBuilder()
                .pointLight({
                  sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
                    (this.activeBtn === 2
                    ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
                    : hdsEffect.PointLightSourceType.NONE),
                  illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
                })
                .buildEffect())
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.pressButton(2); // Pass ID 2
                  animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 2; });
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.leaveButton(2); // Pass ID 2
                  animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
                }
              })
              .onClick(() => this.onTranslateDemo());

            Button() {
              Row() {
                SymbolGlyph($r('sys.symbol.arrow_2_circlepath'))
                  .fontSize(18)
                  .fontColor([this.btn3TextColor])
                  .margin({ right: 8 })
                Text('流转')
                  .fontSize(16)
                  .fontColor(this.btn3TextColor)
              }
            }
            .layoutWeight(1)
            .height(40)
            .backgroundColor(this.btn3BgColor)
            .scale({ x: this.button3Scale, y: this.button3Scale })
            .visualEffect(new hdsEffect.HdsEffectBuilder()
              .pointLight({
                sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
                  (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT),
                illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
              })
              .buildEffect())
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.pressButton(3); // Pass ID 3
                animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 3; });
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.leaveButton(3); // Pass ID 3
                animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
              }
            })
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
            .onClick(() => this.startDeviceDiscovery())
          }
          .width('100%')
          .padding(4)
          .margin({ bottom: 16 })
          .borderRadius(12)
          .backgroundColor(Color.Transparent);

          Column() {
            Text('翻译文本')
              .fontSize(14)
              .fontColor(this.isDarkMode ? Color.White : Color.Black)
              .opacity(0.6)
              .margin({ bottom: 8, left: 4 });

            Column() {
              TextArea({ text: this.translatedDemoText })
                .width('100%')
                .height('100%')
                .fontColor(this.isDarkMode ? Color.White : Color.Black)
                .fontSize(16)
                .backgroundColor(Color.Transparent)
                .borderRadius(0)
                .onChange((value: string) => this.onTranslatedTextChange(value))
                .onFocus(() => {
                  animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 5; });
                })
                .onBlur(() => {
                  animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
                })
            }
            .width('100%')
            .height(160)
            .padding(8)
            .backgroundColor(THEMES[this.themeColorIndex].secondaryColor)
            .borderRadius(24)
            .visualEffect(new hdsEffect.HdsEffectBuilder()
              .pointLight({
                sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
                  (this.activeBtn === 5
                  ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
                  : hdsEffect.PointLightSourceType.NONE),
                illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
              })
              .buildEffect())

            Row() {
              SymbolGlyph($r('sys.symbol.AI'))
                .fontSize(14)
                .fontColor([$r('sys.color.font_on_secondary')])
                .margin({ right: 4 })
              Text('翻译文本由 AI 生成，请谨慎辨别')
                .fontSize(12)
                .fontColor($r('sys.color.font_on_secondary'))
            }
            .margin({ top: 8 })
            .alignSelf(ItemAlign.End)
          }
          .width('100%');
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 16, bottom: 24 });
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
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
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: Color.White
            }
          }
        }
      },
      content: {
        title: {
          mainTitle: '翻译'
        },
        menu: {
          value: [
            {
              content: {
                label: '解释',
                icon: $r('sys.symbol.questionmark_circle'),
                isEnabled: true,
                action: () => {
                  animateTo({
                    duration: 300,
                    curve: Curve.Smooth
                  }, () => {
                    this.helpDialogController.open();
                  });
                }
              }
            },
            {
              content: {
                label: '历史',
                icon: $r('sys.symbol.clock_arrow_2_circlepath'),
                isEnabled: true,
                action: () => {
                  this.onOpenHistory();
                }
              }
            }
          ]
        },
      },
      avoidLayoutSafeArea: true
    })
  }

  pressButton(btnId: number) {
    animateTo({
      duration: 100,
      curve: Curve.EaseIn
    }, () => {
      if (btnId === 1) {
        this.button1Scale = 0.95;
        this.btn1BgColor = Color.White;
        this.btn1TextColor = THEMES[this.themeColorIndex].primaryColor;
      }
      if (btnId === 2) {
        this.button2Scale = 0.95;
        this.btn2BgColor = Color.White;
        this.btn2TextColor = THEMES[this.themeColorIndex].primaryColor;
      }
      if (btnId === 3) {
        this.button3Scale = 0.95;
        this.btn3BgColor = THEMES[this.themeColorIndex].primaryColor;
        this.btn3TextColor = Color.White;
      }
    })
  }

  leaveButton(btnId: number, isUp: boolean = true) {
    animateTo({
      duration: 100,
      curve: Curve.EaseOut
    }, () => {
      if (btnId === 1) {
        this.button1Scale = 1.0;
        if (this.isListening) {
          this.btn1BgColor = Color.White;
          this.btn1TextColor = THEMES[this.themeColorIndex].primaryColor;
        } else {
          this.btn1BgColor = THEMES[this.themeColorIndex].secondaryColor;
          this.btn1TextColor = Color.White;
        }
      }
      if (btnId === 2) {
        this.button2Scale = 1.0;
        this.btn2BgColor = THEMES[this.themeColorIndex].secondaryColor;
        this.btn2TextColor = Color.White;
      }
      if (btnId === 3) {
        this.button3Scale = 1.0;
        this.btn3BgColor = Color.White;
        this.btn3TextColor = THEMES[this.themeColorIndex].primaryColor;
      }
    })
  }
}

@CustomDialog
struct ContinuityHelpDialog {
  controller: CustomDialogController;
  @StorageLink('themeColorIndex') themeColorIndex: number = 0;

  build() {
    Column() {
      Text('跨端流转说明')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.Black)
        .margin({ top: 24, bottom: 16 })
        .textAlign(TextAlign.Center)

      Column({ space: 12 }) {
        Row({ space: 8 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.person_crop_circle_fill_1'))
              .fontSize(18)
              .fontColor([Color.White])
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor($r('sys.color.brand'))
          .justifyContent(FlexAlign.Center)

          Text('确保两台设备登录同一华为账号')
            .fontSize(14)
            .fontColor('#333333')
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 8 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.wifi'))
              .fontSize(18)
              .fontColor([Color.White])
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor('#FFB800')
          .justifyContent(FlexAlign.Center)

          Text('保持 Wi‑Fi 和蓝牙开启，便于发现设备')
            .fontSize(14)
            .fontColor('#333333')
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 8 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.arrow_2_circlepath'))
              .fontSize(18)
              .fontColor([Color.White])
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor('#3c1684')
          .justifyContent(FlexAlign.Center)

          Text('点击“流转”按钮搜索并选择目标设备')
            .fontSize(14)
            .fontColor('#333333')
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 8 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.checkmark_circle'))
              .fontSize(18)
              .fontColor([Color.White])
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor($r('sys.color.confirm'))
          .justifyContent(FlexAlign.Center)

          Text('同意连接后，字幕与翻译将无缝流转到目标设备')
            .fontSize(14)
            .fontColor('#333333')
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Button('我知道了')
        .width('80%')
        .borderRadius(30)
        .margin({ top: 20, bottom: 16 })
        .backgroundColor(THEMES[this.themeColorIndex].primaryColor)
        .fontColor(Color.White)
        .onClick(() => {
          this.controller.close();
        })
    }
    .width(320)
    .backgroundColor(Color.White)
    .borderRadius(30)
    .alignItems(HorizontalAlign.Center)
  }
}
