import { hdsEffect, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { AuthUtil, LogUtil, ToastUtil } from '@pura/harmony-utils';
import { userAuth } from '@kit.UserAuthenticationKit';
import userIAM_userAuth from '@ohos.userIAM.userAuth';
import { TokenUsageChart } from '../components/TokenUsageChart';

const TITLE_BAR_HEIGHT_MINI: number = 110;
const AUTH_SUCCESS_CODE: number = userAuth.UserAuthResultCode.SUCCESS

@Component
struct ConfigCard {
  title: string = '';
  @Prop content: string = '';
  btnId: number = 0;
  isSymbol: boolean = false;
  @Prop isLightEffectBright: boolean = true;
  @Prop isDarkMode: boolean = true;
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
          sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
            (this.activeBtn === this.btnId
            ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
            : hdsEffect.PointLightSourceType.NONE),
          illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE :
            (this.activeBtn !== 0
            ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            : hdsEffect.PointLightIlluminatedType.NONE)
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
        illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
      })
      .buildEffect())
    .justifyContent(FlexAlign.Center)
  }

  handleTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.pressButton();
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.leaveButton();
    }
  }

  pressButton(): void {
    animateTo({
      duration: 200,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.activeBtn = this.btnId;
      this.scaleValue = 0.95;
      this.bgColor = Color.White;
      this.textColor = "#e63c1464";
    })
  }

  leaveButton(): void {
    animateTo({
      duration: 200,
      curve: Curve.EaseOut
    }, () => {
      this.activeBtn = 0;
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
  @Prop currentModelName: string = '';
  languageOptions: string[] = [];
  languageDisplayOptions: string[] = [];
  @Prop selectedLanguageIndex: number = 0;
  intervalOptions: string[] = [];
  @Prop selectedIntervalIndex: number = 0;
  contextsOptions: string[] = [];
  @Prop selectedContextsIndex: number = 0;
  temperatureOptions: string[] = [];
  @Prop selectedTemperatureIndex: number = 0;
  maxTokensOptions: string[] = [];
  @Prop selectedMaxTokensIndex: number = 0;
  @Prop @Watch('onVisibleChange') isVisible: boolean = false;
  @Prop isLightEffectBright: boolean = true;
  @Prop isDarkMode: boolean = true;

  // Callbacks
  onCycleApi: () => void = () => {};
  onCycleLanguage: () => void = () => {};
  onOpenApiSettings: () => void = () => {};
  onSelectInterval: (index: number) => void = () => {};
  onSelectContexts: (index: number) => void = () => {};
  onSelectTemperature: (index: number) => void = () => {};
  onSelectMaxTokens: (index: number) => void = () => {};

  @State activeBtn: number = 0;

  // Animation states
  @State cardScales: number[] = [0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9];
  @State cardOpacities: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

  // New states for disclaimer card
  @State disclaimerScale: number = 1.0;
  @State disclaimerBgColor: ResourceColor = '#803c1464';
  @State disclaimerTextColor: ResourceColor = Color.White;
  @State disclaimerSubTextColor: ResourceColor = '#CCFFFFFF';

  private animationTimeouts: number[] = [];

  aboutToAppear() {
    if (this.isVisible) {
      this.playAnimations();
    }
  }

  aboutToDisappear() {
    this.clearAnimationTimeouts();
  }

  onVisibleChange() {
    if (this.isVisible) {
      this.resetAnimations();
      this.playAnimations();
    } else {
      this.clearAnimationTimeouts();
    }
  }

  resetAnimations() {
    this.clearAnimationTimeouts();
    for (let i = 0; i < 10; i++) {
      this.cardScales[i] = 0.8;
      this.cardOpacities[i] = 0;
    }
  }

  playAnimations() {
    for (let i = 0; i < 10; i++) {
      let id = setTimeout(() => {
        animateTo({
          duration: 300,
          curve: Curve.FastOutSlowIn
        }, () => {
          this.cardScales[i] = 1.0;
          this.cardOpacities[i] = 1.0;
        })
      }, i * 50);
      this.animationTimeouts.push(id);
    }
  }

  clearAnimationTimeouts() {
    this.animationTimeouts.forEach(id => clearTimeout(id));
    this.animationTimeouts = [];
  }

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
          .opacity(this.cardOpacities[0])
          .scale({ x: this.disclaimerScale * this.cardScales[0], y: this.disclaimerScale * this.cardScales[0] })
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              sourceType: this.activeBtn === 99 ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT) : hdsEffect.PointLightSourceType.NONE,
              illuminatedType: this.activeBtn !== 0 ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT : hdsEffect.PointLightIlluminatedType.NONE
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

          TokenUsageChart({
            modelName: this.currentModelName || this.apiOptions[this.selectedApiIndex],
            activeBtn: $activeBtn,
            isLightEffectBright: this.isLightEffectBright
          })
          .opacity(this.cardOpacities[1])
          .scale({ x: this.cardScales[1], y: this.cardScales[1] })

          Grid() {
            GridItem() {
              ConfigCard({
                title: '选择 API',
                content: this.apiOptions[this.selectedApiIndex],
                btnId: 1,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => this.onCycleApi(),
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '选择 API 说明',
                    message: '点击切换可用的翻译 / LLM 服务：OpenAI、DeepL、Ollama、Doubao。选择后请在“配置API”里填写对应地址、（模型）和密钥。\nDoubao 并非仅限于“豆包”，支持广义HTTP请求大模型。',
                    confirm: {
                      value: '我知道了',
                      fontColor: '#3c1464',
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[2])
            .scale({ x: this.cardScales[2], y: this.cardScales[2] })

            GridItem() {
              ConfigCard({
                title: '配置 API',
                content: '',
                btnId: 2,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => this.handleConfigApi(),
                isSymbol: true,
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '配置 API 说明',
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
            .opacity(this.cardOpacities[3])
            .scale({ x: this.cardScales[3], y: this.cardScales[3] })

            GridItem() {
              ConfigCard({
                title: '原始语言',
                content: '英语',
                btnId: 3,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => {
                  // ToastUtil.showToast('当前仅支持英语作为原始语言 😭');
                },
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '原始语言说明',
                    message: '暂时仅支持英语。',
                    confirm: {
                      value: '我知道了',
                      fontColor: '#3c1464',
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[4])
            .scale({ x: this.cardScales[4], y: this.cardScales[4] })

            GridItem() {
              ConfigCard({
                title: '目标语言',
                content: this.getLanguageLabels()[this.selectedLanguageIndex],
                btnId: 4,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => this.onCycleLanguage(),
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '目标语言说明',
                    message: '翻译结果将输出为目标语言，点击切换下一个语言。',
                    confirm: {
                      value: '我知道了',
                      fontColor: '#3c1464',
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[5])
            .scale({ x: this.cardScales[5], y: this.cardScales[5] })

            GridItem() {
              ConfigCard({
                title: '间隔',
                content: this.intervalOptions[this.selectedIntervalIndex],
                btnId: 5,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => this.showTextPicker(this.intervalOptions, this.selectedIntervalIndex, this.onSelectInterval),
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '间隔说明',
                    message: '设置两次翻译请求之间的最小时间间隔（秒），同时也作为传译的时间间隔。\n较短的间隔能提供更实时的反馈，但会消耗更多 Token。\n默认间隔推荐为5。',
                    confirm: {
                      value: '我知道了',
                      fontColor: '#3c1464',
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[6])
            .scale({ x: this.cardScales[6], y: this.cardScales[6] })

            GridItem() {
              ConfigCard({
                title: '上下文',
                content: this.contextsOptions[this.selectedContextsIndex],
                btnId: 6,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => this.showTextPicker(this.contextsOptions, this.selectedContextsIndex, this.onSelectContexts),
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '上下文说明',
                    message: '设置发送给翻译模型的历史对话轮数。\n更多的上下文有助于模型理解语境，提高翻译准确度，但会消耗更多 Token。\n默认上下文推荐为3。',
                    confirm: {
                      value: '我知道了',
                      fontColor: '#3c1464',
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[7])
            .scale({ x: this.cardScales[7], y: this.cardScales[7] })

            GridItem() {
              ConfigCard({
                title: '温度',
                content: this.temperatureOptions[this.selectedTemperatureIndex],
                btnId: 7,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => this.showTextPicker(this.temperatureOptions, this.selectedTemperatureIndex, this.onSelectTemperature),
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '温度说明',
                    message: '控制模型输出的随机性。\n较低的值（如0.2）使输出更集中和确定。较高的值（如0.8）使输出更随机和多样。\n默认温度推荐为0.3，且不建议过大。',
                    confirm: {
                      value: '我知道了',
                      fontColor: '#3c1464',
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[8])
            .scale({ x: this.cardScales[8], y: this.cardScales[8] })

            GridItem() {
              ConfigCard({
                title: '最大 Token',
                content: this.maxTokensOptions[this.selectedMaxTokensIndex],
                btnId: 8,
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => this.showTextPicker(this.maxTokensOptions, this.selectedMaxTokensIndex, this.onSelectMaxTokens),
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '最大 Token 说明',
                    message: '设置模型单次回复生成的最大 Token 数量。\n较小的值（如128）适合简短回复，响应更快。较大的值（如512）允许更长的回复，但可能增加延迟。\n默认最大 Token 推荐为256。',
                    confirm: {
                      value: '我知道了',
                      fontColor: '#3c1464',
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[9])
            .scale({ x: this.cardScales[9], y: this.cardScales[9] })
          }
          .columnsTemplate('1fr 1fr')
          .rowsTemplate('1fr 1fr 1fr 1fr')
          .columnsGap(10)
          .rowsGap(10)
          .padding({ left: 24, right: 24 })
          .height(560)
        }
        .width('100%')
        .padding({ bottom: 100 })
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
        }
      },
      content: {
        title: { mainTitle: '配置' },
      },
      avoidLayoutSafeArea: true
    })
  }
}
