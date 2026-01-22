import router from '@ohos.router';
import font from '@ohos.font';

@Entry
@Component
struct ApiExplanationPage {
  @State gradientAngle: number = 0;
  
  // Animation states for staggered entrance
  @State cardOpacity1: number = 0;
  @State cardScale1: number = 0.9;
  @State cardOpacity2: number = 0;
  @State cardScale2: number = 0.9;
  @State cardOpacity3: number = 0;
  @State cardScale3: number = 0.9;

  aboutToAppear() {
    try {
      font.registerFont({
        familyName: 'JetBrainsMono',
        familySrc: $rawfile('font/JetBrainsMono-Regular-2.ttf')
      })
    } catch (e) {
      console.error('Register font failed:', e)
    }
  }

  onPageShow() {
    // Staggered animation
    animateTo({ duration: 600, curve: Curve.EaseOut, delay: 100 }, () => {
      this.cardOpacity1 = 1;
      this.cardScale1 = 1;
    });
    
    animateTo({ duration: 600, curve: Curve.EaseOut, delay: 200 }, () => {
      this.cardOpacity2 = 1;
      this.cardScale2 = 1;
    });

     animateTo({ duration: 600, curve: Curve.EaseOut, delay: 300 }, () => {
      this.cardOpacity3 = 1;
      this.cardScale3 = 1;
    });
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

      // Content
      Column() {
        Blank().height(16)

        // Header with Back Button
        Row() {
          Button() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(30)
              .fontColor([Color.White])
          }
          .width(40)
          .height(40)
          .type(ButtonType.Circle)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => {
            router.back();
          })

          Text('API 参数填写说明')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          
          // Spacer to balance the back button
          Blank().width(40)
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)
        .margin({ top: 32 }) // Status bar spacing

        Scroll() {
          Column({ space: 24 }) {
            // Intro Text
            Text('大部分 API 提供商都会提供类似以下的 cURL （OpenAI 兼容性 REST 请求）调用示例，您可以根据该示例填写 Voot 的配置。')
              .fontSize(16)
              .fontColor('#CCFFFFFF') // Lighter white/gray for dark background
              .lineHeight(24)
              .opacity(this.cardOpacity1)
              .scale({ x: this.cardScale1, y: this.cardScale1 })

            // Code Block Card
            Column() {
              Scroll() {
                Text("curl https://.../v1/chat/completions \\\n" +
  "-H \"Content-Type: application/json\" \\\n" +
  "-H \"Authorization: Bearer YOUR_API_KEY\" \\\n" +
  "-d '{\n" +
  "  \"model\": \"YOUR_MODEL_NAME\",\n" +
  "  \"messages\": [\n" +
  "    {\n" +
  "      \"role\": \"user\",\n" +
  "      \"content\": \"你好\"\n" +
  "    }\n" +
  "  ],\n" +
  "  \"max_tokens\": 1000\n" +
  "}'\n")
                  .fontSize(14)
                  .fontColor('#E6E6E6')
                  .fontFamily('JetBrainsMono')
                  .copyOption(CopyOptions.LocalDevice)
                  .constraintSize({ minWidth: '100%' })
              }
              .width('100%')
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Auto)
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('sys.color.mask_fourth')) // Semi-transparent black
            .borderRadius(12)
            .alignItems(HorizontalAlign.Start)
            .border({ width: 1, color: '#1AFFFFFF' })
            .opacity(this.cardOpacity2)
            .scale({ x: this.cardScale2, y: this.cardScale2 })

            // Parameter Breakdown Card
            Column({ space: 16 }) {
              this.ParamItem(
                'API 地址 (URL)', 
                'https://.../v1/chat/completions',
                '对应 curl 命令中的 URL 部分。通常以 /v1/chat/completions 结尾。'
              )

              this.ParamItem(
                'API 密钥 (Key)', 
                'YOUR_API_KEY',
                '对应 Authorization 标头中 Bearer 之后的部分。'
              )

              this.ParamItem(
                '模型名称 (Model)', 
                'YOUR_MODEL_NAME',
                '对应 JSON 数据体中 model 字段的值。'
              )
            }
            .opacity(this.cardOpacity3)
            .scale({ x: this.cardScale3, y: this.cardScale3 })
          }
          .padding(24)
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  ParamItem(title: string, value: string, desc: string) {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
      
      Text(value)
        .fontSize(14)
        .fontColor('#d8bfd8') // Light purple
        .backgroundColor('#663c1464') // Darker purple bg
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(4)
        .fontFamily('JetBrainsMono')
      
      Text(desc)
        .fontSize(14)
        .fontColor('#AAFFFFFF')
        .lineHeight(20)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor('#22FFFFFF') // Semi-transparent white
    .borderRadius(12)
    .backdropBlur(10) // Frosted glass effect
  }
}
