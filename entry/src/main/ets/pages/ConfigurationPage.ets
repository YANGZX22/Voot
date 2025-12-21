import { hdsEffect, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { AuthUtil, LogUtil, ToastUtil } from '@pura/harmony-utils';
import { userAuth } from '@kit.UserAuthenticationKit';
import userIAM_userAuth from '@ohos.userIAM.userAuth';

const TITLE_BAR_HEIGHT_MINI: number = 110;
const AUTH_SUCCESS_CODE: number = userAuth.UserAuthResultCode.SUCCESS

@Component
struct ConfigCard {
  title: string = '';
  @Prop content: string = '';
  btnId: number = 0;
  isSymbol: boolean = false;
  callback: () => void = () => {};
  onInfoClick?: () => void = undefined;
  
  @Link activeBtn: number;
  @State scaleValue: number = 1.0;
  @State bgColor: ResourceColor = "#e63c1464";
  @State textColor: ResourceColor = Color.White;

  build() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(16)
          .fontColor(Color.White)
        
        if (this.onInfoClick) {
          SymbolGlyph($r('sys.symbol.info_circle'))
            .fontSize(18)
            .fontColor([Color.White])
            .margin({ left: 6 })
            .onClick(() => {
              if (this.onInfoClick) {
                this.onInfoClick();
              }
            })
        }
      }
      .margin({ bottom: 16 })
      
      Button() {
        if (this.isSymbol) {
           SymbolGlyph($r('sys.symbol.face'))
             .fontSize(24)
             .fontColor([this.textColor])
             .fontWeight(FontWeight.Normal)
        } else {
          Text(this.content)
            .fontSize(14)
            .fontColor(this.textColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .type(ButtonType.Capsule)
      .borderRadius(12)
      .backgroundColor(this.bgColor)
      .width('100%')
      .height(50)
      .onClick(() => {
        if (this.callback) this.callback();
      })
      .scale({ 
        x: this.scaleValue,
        y: this.scaleValue
      })
      .onTouch((event: TouchEvent) => {
        this.handleTouch(event);
      })
      .visualEffect(new hdsEffect.HdsEffectBuilder()
        .pointLight({
          sourceType: this.activeBtn === this.btnId
            ? hdsEffect.PointLightSourceType.BRIGHT
            : hdsEffect.PointLightSourceType.NONE,
          illuminatedType: this.activeBtn !== 0
            ? hdsEffect.PointLightIlluminatedType.BORDER
            : hdsEffect.PointLightIlluminatedType.NONE
        })
        .buildEffect())
    }
    .backgroundColor('#803c1464')
    .width('100%')
    .height('100%')
    .padding(16)
    .borderRadius(30)
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER
      })
      .buildEffect())
    .justifyContent(FlexAlign.Center)
  }

  handleTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.pressButton();
      this.activeBtn = this.btnId;
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.leaveButton();
      this.activeBtn = 0;
    }
  }

  pressButton(): void {
    animateTo({
      duration: 100,
      curve: Curve.EaseIn
    }, () => {
      this.scaleValue = 0.95;
      this.bgColor = Color.White;
      this.textColor = "#e63c1464";
    })
  }

  leaveButton(): void {
    animateTo({
      duration: 100,
      curve: Curve.EaseOut
    }, () => {
      this.scaleValue = 1.0;
      this.bgColor = "#e63c1464";
      this.textColor = Color.White;
    })
  }
}

@Component
export struct ConfigurationPage {
  // Props
  apiOptions: string[] = [];
  @Prop selectedApiIndex: number = 0;
  languageOptions: string[] = [];
  languageDisplayOptions: string[] = [];
  @Prop selectedLanguageIndex: number = 0;
  intervalOptions: string[] = [];
  @Prop selectedIntervalIndex: number = 0;
  contextsOptions: string[] = [];
  @Prop selectedContextsIndex: number = 0;

  // Callbacks
  onCycleApi: () => void = () => {};
  onCycleLanguage: () => void = () => {};
  onOpenApiSettings: () => void = () => {};
  onSelectInterval: (index: number) => void = () => {};
  onSelectContexts: (index: number) => void = () => {};

  @State activeBtn: number = 0;

  // New states for disclaimer card
  @State disclaimerScale: number = 1.0;
  @State disclaimerBgColor: ResourceColor = '#803c1464';
  @State disclaimerTextColor: ResourceColor = Color.White;
  @State disclaimerSubTextColor: ResourceColor = '#CCFFFFFF';

  private getLanguageLabels(): string[] {
    if (this.languageDisplayOptions.length > 0) {
      return this.languageDisplayOptions;
    }
    return this.languageOptions;
  }

  private showTextPicker(options: string[], selected: number, onSelect: (index: number) => void): void {
    TextPickerDialog.show({
      range: options,
      selected: selected,
      onAccept: (value: TextPickerResult) => {
        onSelect(value.index as number);
      },
      cancelButtonStyle: { fontColor: '#3c1464' },
      acceptButtonStyle: { fontColor: '#3c1464' },
      selectedTextStyle: { color: '#3c1464' }
    })
  }

  pressDisclaimer(): void {
    animateTo({ duration: 100, curve: Curve.EaseIn }, () => {
      this.disclaimerScale = 0.95;
      this.disclaimerBgColor = Color.White;
      this.disclaimerTextColor = '#3c1464';
      this.disclaimerSubTextColor = '#CC3c1464';
    });
  }

  releaseDisclaimer(): void {
    animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
      this.disclaimerScale = 1.0;
      this.disclaimerBgColor = '#803c1464';
      this.disclaimerTextColor = Color.White;
      this.disclaimerSubTextColor = '#CCFFFFFF';
    });
  }

  handleConfigApi(): void {
    let facestatus = AuthUtil.getAvailableStatus(userIAM_userAuth.UserAuthType.FACE, userIAM_userAuth.AuthTrustLevel.ATL1)
    let fingerstatus = AuthUtil.getAvailableStatus(userIAM_userAuth.UserAuthType.FINGERPRINT, userIAM_userAuth.AuthTrustLevel.ATL2)
    let pinstatus = AuthUtil.getAvailableStatus(userIAM_userAuth.UserAuthType.PIN, userIAM_userAuth.AuthTrustLevel.ATL2)
    if (facestatus.status) {
      AuthUtil.onStart({
        authType: [userAuth.UserAuthType.FACE],
        authTrustLevel: userAuth.AuthTrustLevel.ATL3,
        title: '请验证人脸',
        showTip: true
      }, (result: userAuth.UserAuthResult) => {
        const authPassed: boolean = !!result && result.result === AUTH_SUCCESS_CODE;
        if (authPassed) {
          this.onOpenApiSettings();
          return;
        }
        ToastUtil.showToast('Voot 无法验证您的屏幕锁定选项，请重试 🤧')})
    } else if (!facestatus.status && fingerstatus.status) {
      AuthUtil.onStartEasy(true, (result: userAuth.UserAuthResult) => {
        const authPassed: boolean = !!result && result.result === AUTH_SUCCESS_CODE;
        if (authPassed) {
          this.onOpenApiSettings();
          return;
        }
        ToastUtil.showToast('Voot 无法验证您的屏幕锁定选项，请重试 🤧')})
    } else if (!facestatus.status && !fingerstatus.status && pinstatus.status) {
      AuthUtil.onStartEasy(true, (result: userAuth.UserAuthResult) => {
        const authPassed: boolean = !!result && result.result === AUTH_SUCCESS_CODE;
        if (authPassed) {
          this.onOpenApiSettings();
          return;
        }
        ToastUtil.showToast('Voot 无法验证您的屏幕锁定选项，请重试 🤧')})
    } else {
      this.onOpenApiSettings()
      ToastUtil.showToast('您似乎没有屏幕锁定选项，密钥不受保障 😞')}
  }

  build() {
    HdsNavigation() {
      Scroll() {
        Column() {
          Blank().height(TITLE_BAR_HEIGHT_MINI);

          Column() {
            SymbolGlyph($r('sys.symbol.exclamationmark_shield_fill'))
              .fontSize(24)
              .fontColor([this.disclaimerTextColor])
              .margin({ bottom: 8 })
            Text('Voot 不提供或转售任何 LLM 密钥')
              .fontSize(16)
              .fontColor(this.disclaimerTextColor)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 4 })
              .textAlign(TextAlign.Center)
            Text('您需要使用自己的 API 密钥（OpenAI、DeepL、Ollama、豆包等）')
              .fontSize(12)
              .fontColor(this.disclaimerSubTextColor)
              .lineHeight(16)
              .textAlign(TextAlign.Center)
          }
          .width('calc(100% - 48vp)')
          .height(120)
          .padding(16)
          .margin({ bottom: 10 })
          .backgroundColor(this.disclaimerBgColor)
          .borderRadius(30)
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
          .scale({ x: this.disclaimerScale, y: this.disclaimerScale })
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              sourceType: this.activeBtn === 99 ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.NONE,
              illuminatedType: this.activeBtn !== 0 ? hdsEffect.PointLightIlluminatedType.BORDER : hdsEffect.PointLightIlluminatedType.NONE
            })
            .buildEffect())
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.pressDisclaimer();
              this.activeBtn = 99;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.releaseDisclaimer();
              this.activeBtn = 0;
            }
          })

          Grid() {
            GridItem() {
              ConfigCard({
                title: '选择API',
                content: this.apiOptions[this.selectedApiIndex],
                btnId: 1,
                callback: () => this.onCycleApi(),
                activeBtn: $activeBtn
              })
            }

            GridItem() {
              ConfigCard({
                title: '配置API',
                content: '',
                btnId: 2,
                callback: () => this.handleConfigApi(),
                isSymbol: true,
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '需要使用您的屏幕锁定信息',
                    message: '使用您的屏幕锁定信息保护您的密钥。',
                    confirm: {
                      value: '我知道了',
                      fontColor: '#3c1464',
                      action: () => {}
                    }
                  })
                }
              })
            }

            GridItem() {
              ConfigCard({
                title: '原始语言',
                content: '英语',
                btnId: 3,
                callback: () => {
                  // ToastUtil.showToast('当前仅支持英语作为原始语言 😭');
                },
                activeBtn: $activeBtn
              })
            }

            GridItem() {
              ConfigCard({
                title: '目标语言',
                content: this.getLanguageLabels()[this.selectedLanguageIndex],
                btnId: 4,
                callback: () => this.onCycleLanguage(),
                activeBtn: $activeBtn
              })
            }

            GridItem() {
              ConfigCard({
                title: '间隔',
                content: this.intervalOptions[this.selectedIntervalIndex],
                btnId: 5,
                callback: () => this.showTextPicker(this.intervalOptions, this.selectedIntervalIndex, this.onSelectInterval),
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '间隔说明',
                    message: '设置两次翻译请求之间的最小时间间隔（秒）。\n较短的间隔能提供更实时的反馈，但会消耗更多Token。',
                    confirm: {
                      value: '我知道了',
                      fontColor: '#3c1464',
                      action: () => {}
                    }
                  })
                }
              })
            }

            GridItem() {
              ConfigCard({
                title: '上下文',
                content: this.contextsOptions[this.selectedContextsIndex],
                btnId: 6,
                callback: () => this.showTextPicker(this.contextsOptions, this.selectedContextsIndex, this.onSelectContexts),
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '上下文说明',
                    message: '设置发送给翻译模型的历史对话轮数。\n更多的上下文有助于模型理解语境，提高翻译准确度，但会消耗更多Token。',
                    confirm: {
                      value: '我知道了',
                      fontColor: '#3c1464',
                      action: () => {}
                    }
                  })
                }
              })
            }
          }
          .columnsTemplate('1fr 1fr')
          .rowsTemplate('1fr 1fr 1fr')
          .columnsGap(10)
          .rowsGap(10)
          .padding({ left: 24, right: 24 })
          .height(420)
        }
        .width('100%')
        .height('100%')
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
}
