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
import display from '@ohos.display';

const TITLE_BAR_HEIGHT_MINI: number = 94;

@Component
export struct TranslationPage {
  // Props
  @Prop @Watch('onVisibleChange') isVisible: boolean = false;
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
  @Prop isLeftHand: boolean = false;
  @Prop isRightHand: boolean = false;
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

  // 握持弹窗临时关闭状态
  @State isHandPopupDismissed: boolean = false;

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

  // 响应式布局状态
  @State isLandscape: boolean = false;

  helpDialogController: CustomDialogController = new CustomDialogController({
    builder: ContinuityHelpDialog(),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  })

  aboutToAppear() {
    try {
      const displayClass = display.getDefaultDisplaySync();
      // 宽度大于高度，或宽度超过600vp（折叠屏展开/平板竖屏）
      const widthVp = px2vp(displayClass.width);
      this.isLandscape = displayClass.width > displayClass.height || widthVp >= 600;
    } catch (exception) {
      console.error('Failed to obtain the default display object. Code: ' + JSON.stringify(exception));
    }
  }

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

  onVisibleChange() {
    // 切换页面时重置握持弹窗临时关闭状态
    if (this.isVisible) {
      this.isHandPopupDismissed = false;
    }
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
      case 'PC': return $r('sys.symbol.computer');
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

      Text('暂仅支持 HarmonyOS 6 及以上的手机与平板流转')
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
      Stack({ alignContent: Alignment.TopStart }) {
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
            .margin({ bottom: 12 });
          }

          if (!this.isLandscape) {
            Row() {
              Button() {
                Row() {
                  SymbolGlyph(this.isListening ? $r('sys.symbol.square') : $r('sys.symbol.mic'))
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
            .margin({ bottom: 12 })
            .borderRadius(12)
            .backgroundColor(Color.Transparent);
          }

          // 文本区域 - 响应式布局
          if (this.isLandscape) {
            // 宽屏模式：左文本框-中间圆形按钮-右文本框
            Row({ space: 0 }) {
              Column() {
                this.OriginalTextPanel()
              }
              .layoutWeight(1)
              .height('100%')

              // 中间操作按钮栏
              Flex({
                direction: FlexDirection.Column,
                justifyContent: FlexAlign.Center,
                alignItems: ItemAlign.Center
              }) {
                // 开启/关闭麦克风
                Row() {
                  SymbolGlyph(this.isListening ? $r('sys.symbol.square') : $r('sys.symbol.mic'))
                    .fontSize(18)
                    .fontColor([this.btn1TextColor])
                }
                .width(44)
                .height(44)
                .justifyContent(FlexAlign.Center)
                .backgroundColor(this.btn1BgColor)
                .borderRadius(22)
                .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
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

                Blank().height(12)

                // 开始翻译按钮
                Row() {
                  if (this.isTranslating) {
                    LoadingProgress()
                      .width(18)
                      .height(18)
                      .color(this.btn2TextColor)
                  } else {
                    SymbolGlyph($r('sys.symbol.translate'))
                      .fontSize(18)
                      .fontColor([this.btn2TextColor])
                  }
                }
                .width(44)
                .height(44)
                .justifyContent(FlexAlign.Center)
                .backgroundColor(this.btn2BgColor)
                .borderRadius(22)
                .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
                .scale({ x: this.button2Scale, y: this.button2Scale })
                .enabled(!this.isTranslating)
                .opacity(!this.isTranslating ? 1.0 : 0.5)
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
                    this.pressButton(2);
                    animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 2; });
                  } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                    this.leaveButton(2);
                    animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
                  }
                })
                .onClick(() => this.onTranslateDemo())

                Blank().height(12)

                // 流转按钮
                Row() {
                  SymbolGlyph($r('sys.symbol.superdevice'))
                    .fontSize(18)
                    .fontColor([this.btn3TextColor])
                }
                .width(44)
                .height(44)
                .justifyContent(FlexAlign.Center)
                .backgroundColor(this.btn3BgColor)
                .borderRadius(22)
                .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
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
                    this.pressButton(3);
                    animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 3; });
                  } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                    this.leaveButton(3);
                    animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
                  }
                })
                .onClick(() => this.startDeviceDiscovery())
              }
              .height('100%')
              .padding(12)
              .backgroundColor(Color.Transparent)

              Column() {
                this.TranslatedTextPanel()
              }
              .layoutWeight(1)
              .height('100%')
            }
            .width('100%')
            .layoutWeight(1)
          } else {
            // 窄屏模式：原文 -> 按钮 -> 译文
            Column() {
              this.OriginalTextPanel()
            }
            .width('100%')
            .layoutWeight(1)
            .margin({ bottom: 12 });

            Row() {
              Button() {
                Row() {
                  if (this.isTranslating) {
                    LoadingProgress()
                      .width(16)
                      .height(16)
                      .color(this.btn2TextColor)
                      .margin({ right: 8 })
                  }
                  Text(this.isTranslating ? '翻译中' : '开始翻译')
                    .fontSize(16)
                    .fontColor(this.btn2TextColor)
                }
              }
              .layoutWeight(2)
              .height(40)
              .backgroundColor(this.btn2BgColor)
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
                  this.pressButton(2);
                  animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 2; });
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.leaveButton(2);
                  animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
                }
              })
              .onClick(() => this.onTranslateDemo());

              Button() {
                Row() {
                  SymbolGlyph($r('sys.symbol.superdevice'))
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
                  this.pressButton(3);
                  animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 3; });
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.leaveButton(3);
                  animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
                }
              })
              .onClick(() => this.startDeviceDiscovery())
            }
            .width('100%')
            .padding(4)
            .margin({ bottom: 12 })
            .borderRadius(12)
            .backgroundColor(Color.Transparent);

            Column() {
              this.TranslatedTextPanel()
            }
            .width('100%')
            .layoutWeight(1);
          }
        }
        .height('100%')
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 16, bottom: 70 })
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          const width = newValue.width as number;
          const height = newValue.height as number;
          this.isLandscape = width > height || width >= 600;
        });
      }
      .scrollable(ScrollDirection.None)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      if ((this.isLeftHand || this.isRightHand) && !this.isHandPopupDismissed) {
        Column({ space: 16 }) {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph(this.isListening ? $r('sys.symbol.square') : $r('sys.symbol.mic'))
              .fontSize(24)
              .fontColor((this.isListening || this.activeBtn === 1 || this.activeBtn === 11) ? [THEMES[this.themeColorIndex].primaryColor] : [Color.White])
          }
          .width(48)
          .height(48)
          .backgroundColor((this.isListening || this.activeBtn === 1 || this.activeBtn === 11) ? Color.White : THEMES[this.themeColorIndex].secondaryColor)
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
            this.onToggleCaptioning();
          })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 11; });
              this.pressButton(1);
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
              this.leaveButton(1);
            }
          })

          Button({ type: ButtonType.Circle }) {
            if (this.isTranslating) {
              LoadingProgress()
                .width(24)
                .height(24)
                .color((this.activeBtn === 2 || this.activeBtn === 12) ? THEMES[this.themeColorIndex].primaryColor : Color.White)
            } else {
              SymbolGlyph($r('sys.symbol.translate'))
                .fontSize(24)
                .fontColor((this.activeBtn === 2 || this.activeBtn === 12) ? [THEMES[this.themeColorIndex].primaryColor] : [Color.White])
            }
          }
          .width(48)
          .height(48)
          .backgroundColor((this.activeBtn === 2 || this.activeBtn === 12) ? Color.White : THEMES[this.themeColorIndex].secondaryColor)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
          .enabled(!this.isTranslating)
          .opacity(this.isTranslating ? 0.7 : 1.0)
          .stateStyles({
            pressed: {
              .scale({ x: 0.95, y: 0.95 })
            },
            normal: {
              .scale({ x: 1.0, y: 1.0 })
            }
          })
          .onClick(() => {
            this.onTranslateDemo();
          })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 12; });
              this.pressButton(2);
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
              this.leaveButton(2);
            }
          })

          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.superdevice'))
              .fontSize(24)
              .fontColor((this.activeBtn === 3 || this.activeBtn === 13) ? [Color.White] : [THEMES[this.themeColorIndex].primaryColor])
          }
          .width(48)
          .height(48)
          .backgroundColor((this.activeBtn === 3 || this.activeBtn === 13) ? THEMES[this.themeColorIndex].primaryColor : Color.White)
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
            this.startDeviceDiscovery();
          })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 13; });
              this.pressButton(3);
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
              this.leaveButton(3);
            }
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
    }
    .mode(NavigationMode.Stack)
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

  @Builder
  OriginalTextPanel() {
    Column() {
      Row() {
        Text('原文')
          .fontSize(13)
          .fontColor($r('sys.color.font_on_secondary'))
          .fontWeight(FontWeight.Medium)
        
        Blank()
        
        if (this.originalDemoText.length > 0) {
          Text(`${this.originalDemoText.length} 字`)
            .fontSize(12)
            .fontColor($r('sys.color.font_on_secondary'))
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      TextArea({ text: this.originalDemoText, placeholder: '请输入或录入需要翻译的文本...' })
        .width('100%')
        .height('100%')
        .fontColor(Color.White)
        .placeholderColor($r('sys.color.font_on_secondary'))
        .fontSize(15)
        .lineHeight(24)
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .padding({ left: 16, right: 16, bottom: 16 })
        .onChange((value: string) => this.onOriginalTextChange(value))
        .onFocus(() => {
          animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 4; });
        })
        .onBlur(() => {
          animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
        })
    }
    .width('100%')
    .height('100%')
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

  @Builder
  TranslatedTextPanel() {
    Column() {
      Row() {
        Text('译文')
          .fontSize(13)
          .fontColor($r('sys.color.font_on_secondary'))
          .fontWeight(FontWeight.Medium)
        
        Blank()
        
        if (this.translatedDemoText.length > 0) {
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.AI'))
              .fontSize(14)
              .fontColor([$r('sys.color.font_on_secondary')])
            Text('AI 生成')
              .fontSize(12)
              .fontColor($r('sys.color.font_on_secondary'))
          }
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Stack() {
        TextArea({ text: this.translatedDemoText })
          .width('100%')
          .height('100%')
          .fontColor(Color.White)
          .placeholderColor($r('sys.color.font_on_secondary'))
          .fontSize(15)
          .lineHeight(24)
          .backgroundColor(Color.Transparent)
          .borderRadius(0)
          .padding({ left: 16, right: 16, bottom: 16 })
          .onChange((value: string) => this.onTranslatedTextChange(value))
          .onFocus(() => {
            animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 5; });
          })
          .onBlur(() => {
            animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
          })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
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
            SymbolGlyph($r('sys.symbol.superdevice'))
              .fontSize(18)
              .fontColor([Color.White])
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor(THEMES[this.themeColorIndex].primaryColor)
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
