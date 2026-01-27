/**
 * @file Phone Number Verification with SMS
 * @status Aborted
 */
import { router, promptAction } from '@kit.ArkUI'
import util from '@ohos.util';
import http from '@ohos.net.http';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { OnboardingStorage } from '../storage/OnboardingStorage';
import common from '@ohos.app.ability.common';

interface TestAccount {
  phone: string;
  pass: string;
}

// 短信 API 响应
interface SmsResponse {
  code: number;
  msg: string;
  request_id?: string;
}

@CustomDialog
struct PasswordDialog {
  controller: CustomDialogController
  confirm: (password: string) => void = () => {}
  @State password: string = ''

  build() {
    Column() {
      Text('请输入测试账号密码')
        .fontColor($r('sys.color.font_primary'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 16 })
      
      TextInput({ placeholder: '密码', text: this.password })
        .type(InputType.Password)
        .height(48)
        .borderRadius(8)
        .fontColor($r('sys.color.font_primary'))
        .onChange((val) => this.password = val)
        .margin({ bottom: 24 })
      
      Row() {
        Button('取消')
          .onClick(() => this.controller.close())
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .fontColor('#666666')
          .layoutWeight(1)
          .margin({ right: 12 })
        
        Button('确认')
          .onClick(() => {
            this.confirm(this.password)
            this.controller.close()
          })
          .backgroundColor('#3c1464')
          .layoutWeight(1)
      }
      .width('100%')
    }
    .padding(24)
    .backgroundColor($r('sys.color.background_primary'))
    .borderRadius(16)
    .width(300)
  }
}

@Entry
@Component
struct VerifyPage {
  @State phonenumber: string = ''
  @State verifyCode: string = ''
  @State gradientAngle: number = 0
  @State testAccount: TestAccount | null = null
  private smsApiUrl: string = ''
  @State isSendingCode: boolean = false
  @State isVerifying: boolean = false
  @State countdown: number = 0
  @State sentCode: string = '' // 存储发送的验证码
  private countdownTimer: number = -1

  passwordDialogController: CustomDialogController = new CustomDialogController({
    builder: PasswordDialog({
      confirm: (pwd: string) => this.verifyTestPassword(pwd)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true,
    backgroundColor: 'transparent'
  })

  async aboutToAppear(): Promise<void> {
    const context = getContext(this);
    const resourceManager = context.resourceManager;
    const textDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    
    // 加载测试账号配置
    try {
      const fileData = await resourceManager.getRawFileContent('test_account.json');
      const jsonStr = textDecoder.decodeWithStream(fileData);
      this.testAccount = JSON.parse(jsonStr);
    } catch (e) {
      console.error('Failed to load test account config', e);
    }
    
    // 加载短信 API 配置
    try {
      const smsData = await resourceManager.getRawFileContent('sms_config.json');
      const smsJson = textDecoder.decodeWithStream(smsData);
      const smsConfig: Record<string, string> = JSON.parse(smsJson);
      if (smsConfig['apiUrl']) {
        this.smsApiUrl = smsConfig['apiUrl'];
      }
    } catch (e) {
      console.error('Failed to load SMS config', e);
    }
  }

  aboutToDisappear(): void {
    if (this.countdownTimer !== -1) {
      clearInterval(this.countdownTimer);
    }
  }

  build() {
    Stack() {
      // Background
      Image($r('app.media.app_background_pic_voot_purple'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .blur(20)

      // Overlay gradient
      Rect()
        .width('100%')
        .height('100%')
        .fill(Color.Transparent)
        .linearGradient({
          angle: this.gradientAngle,
          colors: [['#AA000000', 0.0], ['#663c1464', 1.0]]
        })
        .onAppear(() => {
          animateTo({
            duration: 5000,
            curve: Curve.Linear,
            iterations: -1,
            playMode: PlayMode.Normal
          }, () => {
            this.gradientAngle = 360;
          })
        })

      Column() {
        // Header with Back Button
        Row() {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(30)
              .fontColor([Color.White])
          }
          .width(40)
          .height(40)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => {
            this.quitPage()
          })
          .margin({ right: 16 })

          Text('验证码验证')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ top: 48, left: 24, right: 24 })
        .justifyContent(FlexAlign.Start)

        Column({ space: 20 }) {
          // 手机号输入
          Text('请输入 11 位手机号码')
            .fontSize(18)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
            .alignSelf(ItemAlign.Start)
            .margin({ top: 48 })

          TextInput({ placeholder: '请输入手机号', text: this.phonenumber })
            .height(56)
            .fontSize(18)
            .backgroundColor($r('sys.color.background_tertiary'))
            .placeholderColor($r('sys.color.font_tertiary'))
            .fontColor($r('sys.color.font_primary'))
            .borderRadius(28)
            .padding({ left: 20, right: 20 })
            .type(InputType.PhoneNumber)
            .maxLength(11)
            .onChange((value: string) => {
              this.phonenumber = value.trim()
            })

          // 验证码输入行
          Row({ space: 12 }) {
            TextInput({ placeholder: '请输入验证码', text: this.verifyCode })
              .height(56)
              .fontSize(18)
              .backgroundColor($r('sys.color.background_tertiary'))
              .placeholderColor($r('sys.color.font_tertiary'))
              .fontColor($r('sys.color.font_primary'))
              .borderRadius(28)
              .padding({ left: 20, right: 20 })
              .type(InputType.Number)
              .maxLength(6)
              .layoutWeight(1)
              .onChange((value: string) => {
                this.verifyCode = value.trim()
              })

            Button(this.countdown > 0 ? `${this.countdown}s` : (this.isSendingCode ? '发送中...' : '获取验证码'))
              .height(56)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.canSendCode() ? $r('sys.color.font_primary') : $r('sys.color.font_on_secondary'))
              .backgroundColor(this.canSendCode() ? $r('sys.color.background_tertiary') : $r('sys.color.comp_background_secondary'))
              .borderRadius(28)
              .width(120)
              .enabled(this.canSendCode())
              .onClick(() => {
                this.sendVerifyCode()
              })
          }
          .width('100%')

          // 验证按钮
          Button(this.isVerifying ? '验证中...' : '验证')
            .width('100%')
            .height(56)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_secondary'))
            .backgroundColor($r('sys.color.background_primary'))
            .borderRadius(28)
            .onClick(() => {
              this.doVerify()
            })
            .enabled(this.canVerify())
            .opacity(this.canVerify() ? 1.0 : 0.6)
            .shadow({ radius: 20, color: '#443c1464', offsetY: 8 })
            .margin({ top: 12 })
        }
        .width('90%')
        .constraintSize({ maxWidth: 360 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  private checkPhoneNumber(): boolean {
    // 测试账号后门，跳过格式验证
    if (this.testAccount && this.phonenumber === this.testAccount.phone) {
      return true;
    }
    // 中国大陆手机号：11位，以1开头，第二位为3-9
    const phoneRegex = /^1[3-9]\d{9}$/;
    return phoneRegex.test(this.phonenumber);
  }

  private canSendCode(): boolean {
    return this.checkPhoneNumber() && this.countdown === 0 && !this.isSendingCode
  }

  private canVerify(): boolean {
    return this.checkPhoneNumber() && this.verifyCode.length === 6 && !this.isVerifying && this.sentCode !== ''
  }

  private generateCode(): string {
    // 生成6位随机验证码
    const random = cryptoFramework.createRandom();
    const randomData = random.generateRandomSync(4);
    const view = new DataView(randomData.data.buffer);
    const num = (view.getUint32(0) % 900000) + 100000;
    return num.toString();
  }

  private async sendVerifyCode(): Promise<void> {
    // 测试账号后门
    if (this.testAccount && this.phonenumber === this.testAccount.phone) {
      this.passwordDialogController.open();
      return;
    }

    this.isSendingCode = true;
    
    try {
      // 生成验证码
      const code = this.generateCode();
      
      if (!this.smsApiUrl) {
        throw new Error('SMS API URL not configured');
      }
      
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(this.smsApiUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify({
          code: code,
          number: '5',
          to: this.phonenumber
        }),
        connectTimeout: 10000,
        readTimeout: 10000
      });

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as SmsResponse;
        if (result.code === 200) {
          this.sentCode = code; // 保存发送的验证码
          promptAction.showToast({ message: '验证码已发送' });
          this.startCountdown();
        } else {
          promptAction.showToast({ message: result.msg || '发送失败' });
        }
      } else {
        promptAction.showToast({ message: '网络错误，请重试' });
      }
    } catch (e) {
      console.error('Send SMS error:', JSON.stringify(e));
      promptAction.showToast({ message: '发送失败，请重试' });
    } finally {
      this.isSendingCode = false;
    }
  }

  private startCountdown(): void {
    this.countdown = 60;
    this.countdownTimer = setInterval(() => {
      this.countdown--;
      if (this.countdown <= 0) {
        clearInterval(this.countdownTimer);
        this.countdownTimer = -1;
      }
    }, 1000);
  }

  private async doVerify(): Promise<void> {
    this.isVerifying = true;
    
    try {
      // 本地验证验证码
      if (this.verifyCode === this.sentCode) {
        promptAction.showToast({ message: '验证成功' });
        const context = getContext(this) as common.UIAbilityContext;
        // 保存验证状态
        AppStorage.setOrCreate('isNumberVerified', true);
        await OnboardingStorage.setNumberVerified(context, true);
        // 保存手机号
        AppStorage.setOrCreate('verifiedPhone', this.phonenumber);
        await OnboardingStorage.setVerifiedPhone(context, this.phonenumber);
        this.quitPage();
      } else {
        promptAction.showToast({ message: '验证码错误' });
      }
    } catch (e) {
      console.error('Verify error:', JSON.stringify(e));
      promptAction.showToast({ message: '验证失败，请重试' });
    } finally {
      this.isVerifying = false;
    }
  }

  private verifyTestPassword(pwd: string): void {
    if (this.testAccount && pwd === this.testAccount.pass) {
      promptAction.showToast({ message: '测试账号验证成功' });
      const context = getContext(this) as common.UIAbilityContext;
      // 保存验证状态
      AppStorage.setOrCreate('isNumberVerified', true);
      OnboardingStorage.setNumberVerified(context, true);
      // 保存测试账号手机号
      AppStorage.setOrCreate('verifiedPhone', this.testAccount.phone);
      OnboardingStorage.setVerifiedPhone(context, this.testAccount.phone);
      this.quitPage();
    } else {
      promptAction.showToast({ message: '密码错误' });
    }
  }

  private quitPage() {
    if (this.countdownTimer !== -1) {
      clearInterval(this.countdownTimer);
    }
    router.back()
  }
}
