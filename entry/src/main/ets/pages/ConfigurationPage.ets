import { hdsEffect, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { AuthUtil, LogUtil, ToastUtil } from '@pura/harmony-utils';
import { userAuth } from '@kit.UserAuthenticationKit';

const TITLE_BAR_HEIGHT_MINI: number = 84;
const FACE_AUTH_SUCCESS_CODE: number = userAuth.UserAuthResultCode.SUCCESS;

@Component
export struct ConfigurationPage {
  // Props
  apiOptions: string[] = [];
  @Prop selectedApiIndex: number = 0;
  languageOptions: string[] = [];
  languageDisplayOptions: string[] = [];
  @Prop selectedLanguageIndex: number = 0;

  // Callbacks
  onCycleApi: () => void = () => {};
  onCycleLanguage: () => void = () => {};
  onOpenApiSettings: () => void = () => {};

  @State activeBtn: number = 0;

  @State button1Scale: number = 1.0;
  @State button2Scale: number = 1.0;
  @State button3Scale: number = 1.0;

  private getLanguageLabels(): string[] {
    if (this.languageDisplayOptions.length > 0) {
      return this.languageDisplayOptions;
    }
    return this.languageOptions;
  }

  build() {
    HdsNavigation() {
      Scroll() {
        Column() {
          Blank().height(TITLE_BAR_HEIGHT_MINI);

          Column() {
            Text('选择与配置')
              .fontColor(Color.White)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 8 });

            Row() {
              // --- BUTTON 1 ---
              Button(this.apiOptions[this.selectedApiIndex])
                .backgroundColor("#e63c1464")
                .width('100%')
                .scale({ x: this.button1Scale, y: this.button1Scale })
                .visualEffect(new hdsEffect.HdsEffectBuilder()
                  .pointLight({
                    sourceType: this.activeBtn === 1
                      ? hdsEffect.PointLightSourceType.BRIGHT
                      : hdsEffect.PointLightSourceType.NONE,
                    illuminatedType: this.activeBtn !== 0
                      ? hdsEffect.PointLightIlluminatedType.BORDER
                      : hdsEffect.PointLightIlluminatedType.NONE
                  })
                  .buildEffect())
                .onTouch((event: TouchEvent) => {
                  if (event.type === TouchType.Down) {
                    this.pressButton(1); // Pass ID 1
                    this.activeBtn = 1;
                  } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                    this.leaveButton(1); // Pass ID 1
                    this.activeBtn = 0;
                  }
                })
                .onClick(() => this.onCycleApi());
            }
            .width('100%')
            .padding(4)
            .margin({ bottom: 12 })
            .borderRadius(12)
            .backgroundColor(Color.Transparent);

            Text(`当前选择API: ${this.apiOptions[this.selectedApiIndex]}`)
              .fontSize(12)
              .fontColor(Color.Gray)
              .margin({ bottom: 12 });

            Row() {
              // --- BUTTON 2 ---
              Button('配置API')
                .backgroundColor("#e63c1464")
                .width('100%')
                .scale({ x: this.button2Scale, y: this.button2Scale })
                .visualEffect(new hdsEffect.HdsEffectBuilder()
                  .pointLight({
                    sourceType: this.activeBtn === 2
                      ? hdsEffect.PointLightSourceType.BRIGHT
                      : hdsEffect.PointLightSourceType.NONE,
                    illuminatedType: this.activeBtn !== 0
                      ? hdsEffect.PointLightIlluminatedType.BORDER
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
                .onClick(() => {
                  AuthUtil.onStart({
                    authType: [userAuth.UserAuthType.FACE],
                    authTrustLevel: userAuth.AuthTrustLevel.ATL3,
                    title: '请验证人脸',
                    showTip: true
                  }, (result: userAuth.UserAuthResult) => {
                    const authPassed: boolean = !!result && result.result === FACE_AUTH_SUCCESS_CODE;
                    if (authPassed) {
                      this.onOpenApiSettings();
                      return;
                    }
                    ToastUtil.showToast('Voot 现在无法验证您的人脸');
                  });
                })
            }
            .width('100%')
            .padding(4)
            .margin({ bottom: 24 })
            .borderRadius(12)
            .backgroundColor(Color.Transparent);
          }
          .width('100%')
          .margin({ bottom: 24 });

          Column() {
            Text('目标语言')
              .fontColor(Color.White)
              .fontSize(16)
              .margin({ bottom: 8 });

            Row() {
              // --- BUTTON 3 ---
              Button(this.getLanguageLabels()[this.selectedLanguageIndex])
                .backgroundColor("#e63c1464")
                .width('100%')
                .scale({ x: this.button3Scale, y: this.button3Scale })
                .visualEffect(new hdsEffect.HdsEffectBuilder()
                  .pointLight({
                    sourceType: this.activeBtn === 3
                      ? hdsEffect.PointLightSourceType.BRIGHT
                      : hdsEffect.PointLightSourceType.NONE,
                    illuminatedType: this.activeBtn !== 0
                      ? hdsEffect.PointLightIlluminatedType.BORDER
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
                .onClick(() => this.onCycleLanguage());
            }
            .width('100%')
            .padding(4)
            .borderRadius(12)
            .backgroundColor(Color.Transparent);

            Text(`当前目标语言: ${this.getLanguageLabels()[this.selectedLanguageIndex]}`)
              .fontSize(12)
              .fontColor(Color.Gray)
              .margin({ top: 4 });
          }
          .width('100%');
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 16, bottom: 24 });
      }
      .scrollable(ScrollDirection.Vertical);
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
        }
      },
      content: {
        title: { mainTitle: '配置' },
      },
      avoidLayoutSafeArea: true
    })
  }

  pressButton(btnId: number) {
    animateTo({
      duration: 300,
      curve: Curve.EaseIn
    }, () => {
      if (btnId === 1) this.button1Scale = 0.95;
      if (btnId === 2) this.button2Scale = 0.95;
      if (btnId === 3) this.button3Scale = 0.95;
    })
  }

  leaveButton(btnId: number) {
    animateTo({
      duration: 300,
      curve: Curve.EaseOut
    }, () => {
      if (btnId === 1) this.button1Scale = 1.0;
      if (btnId === 2) this.button2Scale = 1.0;
      if (btnId === 3) this.button3Scale = 1.0;
    })
  }
}