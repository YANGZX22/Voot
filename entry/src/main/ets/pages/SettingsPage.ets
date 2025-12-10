import { hdsEffect, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { webview } from '@kit.ArkWeb';
import { PolicySheetType, PolicySheetContent, getPolicySheetConfig } from '../components/PolicySheet';

const TITLE_BAR_HEIGHT_MINI: number = 84;
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

@Component
export struct SettingsPage {
  // Props

  // Callbacks

  // Struct


  // State for Lighting Effect
  // 0 = None, 1 = Mic Button, 2 = Translate Button

  @State activeBtn: number = 0;

  @State button1Scale: number = 1.0;
  @State button2Scale: number = 1.0;
  @State subtitlesEnabled: boolean = false;
  @State liveWindowEnabled: boolean = false;
  @State isPolicySheetOpen: boolean = false;
  @State currentPolicySheet: PolicySheetType = PolicySheetType.Privacy;

  private subtitlesDialogController?: CustomDialogController;
  private liveWindowDialogController?: CustomDialogController;
  private policyWebController: webview.WebviewController = new webview.WebviewController();

  private resolveDialogController(key: ToggleKey): CustomDialogController {
    if (key === 'subtitles') {
      if (!this.subtitlesDialogController) {
        this.subtitlesDialogController = new CustomDialogController({
          builder: CustomDialogSubtitle({
            title: '字幕功能即将上线',
            message: '字幕还在准备中，敬请期待。',
            onDismiss: () => this.handleDialogDismiss('subtitles')
          })
        });
      }
      return this.subtitlesDialogController as CustomDialogController;
    }

    if (!this.liveWindowDialogController) {
      this.liveWindowDialogController = new CustomDialogController({
        builder: CustomDialogLiveWindows({
          title: '实况窗暂不可用',
          message: '我们正在申请实况窗权限，感谢理解。',
          onDismiss: () => this.handleDialogDismiss('liveWindow')
        })
      });
    }
    return this.liveWindowDialogController as CustomDialogController;
  }

  private showDialog(key: ToggleKey): void {
    this.resolveDialogController(key).open();
  }

  private handleDialogDismiss(key: ToggleKey): void {
    if (key === 'subtitles') {
      this.subtitlesEnabled = false;
    }
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


  build() {
    HdsNavigation() {
      Scroll() {
        Column() {
          Blank().height(TITLE_BAR_HEIGHT_MINI);

          Text('进阶功能')
            .fontColor(Color.White)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 8 });

          Row() {
            Blank().width(12)

            Text('开启字幕').fontColor(Color.White)

            Blank()

            Toggle({
              type: ToggleType.Switch,
              isOn: this.subtitlesEnabled
            }).onChange((isOn: boolean) => {
              this.subtitlesEnabled = isOn;
              if (isOn) {
                this.showDialog('subtitles');
              }
            })

            Blank().width(12)
          }
          .width('100%')
          .height(60)
          .padding(4)
          .margin({ bottom: 12 })
          .borderRadius(24)
          .backgroundColor('#cc3c1464')
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER
            })
            .buildEffect())

          Row() {
            Blank().width(12)

            Text('开启实况窗').fontColor(Color.White)

            Blank()

            Toggle({
              type: ToggleType.Switch,
              isOn: this.liveWindowEnabled
            })
              .onChange((isOn: boolean) => {
                this.liveWindowEnabled = isOn;
                if (isOn) {
                  this.showDialog('liveWindow');
                }
              })

            Blank().width(12)
          }
          .width('100%')
          .height(60)
          .padding(4)
          .margin({ bottom: 12 })
          .borderRadius(24)
          .backgroundColor('#cc3c1464')
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER
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
            .onClick(() => this.openPolicySheet(PolicySheetType.Terms))

          }
          .width('100%')
          .height(60)
          .padding(4)
          .margin({ bottom: 12 })
          .borderRadius(24)
          .backgroundColor('#cc3c1464')
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER
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
              .onClick(() => this.openPolicySheet(PolicySheetType.Privacy))

          }
          .width('100%')
          .height(60)
          .padding(4)
          .margin({ bottom: 12 })
          .borderRadius(24)
          .backgroundColor('#cc3c1464')
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER
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
              .onClick(() => this.openPolicySheet(PolicySheetType.About))

          }
          .width('100%')
          .height(60)
          .padding(4)
          .margin({ bottom: 12 })
          .borderRadius(24)
          .backgroundColor('#cc3c1464')
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER
            })
            .buildEffect())
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 16, bottom: 24 });
      }
    }
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
      PolicySheetContent(getPolicySheetConfig(this.currentPolicySheet), this.policyWebController, () => {
        this.closePolicySheet();
      }), {
      detents: [SheetSize.MEDIUM, SheetSize.FIT_CONTENT , SheetSize.LARGE],
      dragBar: true,
      backgroundColor: '#e63c1464',
      blurStyle: BlurStyle.BACKGROUND_REGULAR,
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