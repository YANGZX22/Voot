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

  // Callbacks
  onToggleCaptioning: () => void = () => {};
  onTranslateDemo: () => void = () => {};
  onOriginalTextChange: (value: string) => void = () => {};
  onTranslatedTextChange: (value: string) => void = () => {};
  onContinuityTransfer: () => void = () => {};

  // State for Lighting Effect
  // 0 = None, 1 = Mic Button, 2 = Translate Button
  @State activeBtn: number = 0;

  @State button1Scale: number = 1.0;
  @State button2Scale: number = 1.0;

  @State btn1BgColor: ResourceColor = "#e63c1464";
  @State btn1TextColor: ResourceColor = Color.White;
  @State btn2BgColor: ResourceColor = "#e63c1464";
  @State btn2TextColor: ResourceColor = Color.White;

  @State button3Scale: number = 1.0;
  @State btn3BgColor: ResourceColor = "#e63c1464";
  @State btn3TextColor: ResourceColor = Color.White;

  helpDialogController: CustomDialogController = new CustomDialogController({
    builder: ContinuityHelpDialog(),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  })

  onIsListeningChange() {
    animateTo({
      duration: 100,
      curve: Curve.EaseOut
    }, () => {
      if (this.isListening) {
        this.btn1BgColor = Color.White;
        this.btn1TextColor = "#e63c1464";
      } else {
        this.btn1BgColor = "#e63c1464";
        this.btn1TextColor = Color.White;
      }
    })
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
                  Text('当前选择API')
                    .fontSize(12)
                    .fontColor(Color.Gray)
                    .margin({ bottom: 4 });
                  Text(this.currentApiLabel)
                    .fontSize(14)
                    .fontColor(Color.White)
                    .fontWeight(FontWeight.Medium);
                }
                .backgroundColor('#803c1464')
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
                    .fontColor(Color.Gray)
                    .margin({ bottom: 4 });
                  Text(this.currentLanguageLabel)
                    .fontSize(14)
                    .fontColor(Color.White)
                    .fontWeight(FontWeight.Medium);
                }
                .padding({ left: 12, right: 12, top: 12, bottom: 12 })
                .backgroundColor('#803c1464')
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
                  sourceType: this.activeBtn === 1
                    ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
                    : hdsEffect.PointLightSourceType.NONE,
                  illuminatedType: this.activeBtn !== 0
                    ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
                    : hdsEffect.PointLightIlluminatedType.NONE
                })
                .buildEffect())
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.pressButton(1); // Pass ID 1
                  this.activeBtn = 1;
                } else if (event.type === TouchType.Up) {
                  this.leaveButton(1, true); // Pass ID 1, isUp=true
                  this.activeBtn = 0;
                } else if (event.type === TouchType.Cancel) {
                  this.leaveButton(1, false); // Pass ID 1, isUp=false
                  this.activeBtn = 0;
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
              .fontSize(16)
              .margin({ bottom: 6 });

            TextArea({ text: this.originalDemoText })
              .width('100%')
              .height(160)
              .onChange((value: string) => this.onOriginalTextChange(value));
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
                  sourceType: this.activeBtn === 2
                    ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
                    : hdsEffect.PointLightSourceType.NONE,
                  illuminatedType: this.activeBtn !== 0
                    ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
                    : hdsEffect.PointLightIlluminatedType.NONE
                })
                .buildEffect())
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.pressButton(2); // Pass ID 2
                  this.activeBtn = 2;
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.leaveButton(2); // Pass ID 2
                  this.activeBtn = 0;
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
                sourceType: this.activeBtn === 3
                  ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
                  : hdsEffect.PointLightSourceType.NONE,
                illuminatedType: this.activeBtn !== 0
                  ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
                  : hdsEffect.PointLightIlluminatedType.NONE
              })
              .buildEffect())
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.pressButton(3); // Pass ID 3
                this.activeBtn = 3;
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.leaveButton(3); // Pass ID 3
                this.activeBtn = 0;
              }
            })
            .onClick(() => this.onContinuityTransfer())
          }
          .width('100%')
          .padding(4)
          .margin({ bottom: 16 })
          .borderRadius(12)
          .backgroundColor(Color.Transparent);

          Column() {
            Text('翻译文本')
              .fontSize(16)
              .margin({ bottom: 6 });

            TextArea({ text: this.translatedDemoText })
              .width('100%')
              .height(160)
              .onChange((value: string) => this.onTranslatedTextChange(value));

            Row() {
              SymbolGlyph($r('sys.symbol.info_circle'))
                .fontSize(14)
                .fontColor([Color.Gray])
                .margin({ right: 4 })
              Text('翻译文本由 AI 生成，请谨慎辨别')
                .fontSize(12)
                .fontColor(Color.Gray)
            }
            .margin({ top: 8 })
            .alignSelf(ItemAlign.End)
          }
          .width('100%');
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 16, bottom: 24 });
      }
      .scrollable(ScrollDirection.Vertical);
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
                icon: $r('sys.symbol.info_circle'),
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
        this.btn1TextColor = "#e63c1464";
      }
      if (btnId === 2) {
        this.button2Scale = 0.95;
        this.btn2BgColor = Color.White;
        this.btn2TextColor = "#e63c1464";
      }
      if (btnId === 3) {
        this.button3Scale = 0.95;
        this.btn3BgColor = Color.White;
        this.btn3TextColor = "#e63c1464";
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
          this.btn1TextColor = "#e63c1464";
        } else {
          this.btn1BgColor = "#e63c1464";
          this.btn1TextColor = Color.White;
        }
      }
      if (btnId === 2) {
        this.button2Scale = 1.0;
        this.btn2BgColor = "#e63c1464";
        this.btn2TextColor = Color.White;
      }
      if (btnId === 3) {
        this.button3Scale = 1.0;
        this.btn3BgColor = "#e63c1464";
        this.btn3TextColor = Color.White;
      }
    })
  }
}

@CustomDialog
struct ContinuityHelpDialog {
  controller: CustomDialogController;

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
          .backgroundColor('#FF4D4F')
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
          .backgroundColor('#0c3891')
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
        .backgroundColor('#3c1464')
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
