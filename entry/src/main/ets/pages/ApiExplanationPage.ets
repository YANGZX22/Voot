import router from '@ohos.router';
import font from '@ohos.font';
import { curves } from '@kit.ArkUI';

@Entry
@Component
struct ApiExplanationPage {
  @State gradientAngle: number = 0;
  @State currentPage: number = 0;
  private swiperController: SwiperController = new SwiperController();
  
  // 记录页面是否已播放过动画
  private page1Animated: boolean = false;
  private page2Animated: boolean = false;
  
  // Animation states for staggered spring entrance (from bottom to top)
  @State cardOpacity1: number = 0;
  @State cardOffsetY1: number = 60;
  @State cardOpacity2: number = 0;
  @State cardOffsetY2: number = 60;
  // 参数项动画状态（地址、密钥、模型）
  @State paramOpacity1: number = 0;
  @State paramOffsetY1: number = 60;
  @State paramOpacity2: number = 0;
  @State paramOffsetY2: number = 60;
  @State paramOpacity3: number = 0;
  @State paramOffsetY3: number = 60;

  // Page 2 (Gemini) animation states
  @State geminiCardOpacity1: number = 0;
  @State geminiCardOffsetY1: number = 60;
  @State geminiCardOpacity2: number = 0;
  @State geminiCardOffsetY2: number = 60;
  @State geminiParamOpacity1: number = 0;
  @State geminiParamOffsetY1: number = 60;
  @State geminiParamOpacity2: number = 0;
  @State geminiParamOffsetY2: number = 60;

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
    if (!this.page1Animated) {
      this.playPage1Animation();
    }
  }

  private playPage1Animation() {
    if (this.page1Animated) return;
    this.page1Animated = true;

    // Staggered spring animation (from bottom to top)
    setTimeout(() => {
      animateTo({ duration: 500, curve: curves.springMotion(0.6, 0.9) }, () => {
        this.cardOpacity1 = 1;
        this.cardOffsetY1 = 0;
      });
    }, 100);
    
    setTimeout(() => {
      animateTo({ duration: 500, curve: curves.springMotion(0.6, 0.9) }, () => {
        this.cardOpacity2 = 1;
        this.cardOffsetY2 = 0;
      });
    }, 200);

    // 参数项依次弹出（地址、密钥、模型）
    setTimeout(() => {
      animateTo({ duration: 500, curve: curves.springMotion(0.6, 0.9) }, () => {
        this.paramOpacity1 = 1;
        this.paramOffsetY1 = 0;
      });
    }, 300);

    setTimeout(() => {
      animateTo({ duration: 500, curve: curves.springMotion(0.6, 0.9) }, () => {
        this.paramOpacity2 = 1;
        this.paramOffsetY2 = 0;
      });
    }, 400);

    setTimeout(() => {
      animateTo({ duration: 500, curve: curves.springMotion(0.6, 0.9) }, () => {
        this.paramOpacity3 = 1;
        this.paramOffsetY3 = 0;
      });
    }, 500);
  }

  private playPage2Animation() {
    if (this.page2Animated) return;
    this.page2Animated = true;

    // Staggered spring animation
    setTimeout(() => {
      animateTo({ duration: 500, curve: curves.springMotion(0.6, 0.9) }, () => {
        this.geminiCardOpacity1 = 1;
        this.geminiCardOffsetY1 = 0;
      });
    }, 100);
    
    setTimeout(() => {
      animateTo({ duration: 500, curve: curves.springMotion(0.6, 0.9) }, () => {
        this.geminiCardOpacity2 = 1;
        this.geminiCardOffsetY2 = 0;
      });
    }, 200);

    setTimeout(() => {
      animateTo({ duration: 500, curve: curves.springMotion(0.6, 0.9) }, () => {
        this.geminiParamOpacity1 = 1;
        this.geminiParamOffsetY1 = 0;
      });
    }, 300);

    setTimeout(() => {
      animateTo({ duration: 500, curve: curves.springMotion(0.6, 0.9) }, () => {
        this.geminiParamOpacity2 = 1;
        this.geminiParamOffsetY2 = 0;
      });
    }, 400);
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

        // Swiper for multiple pages
        Swiper(this.swiperController) {
          // Page 1: OpenAI Compatible API
          this.OpenAIPage()
          // Page 2: Gemini API
          this.GeminiPage()
        }
        .index(this.currentPage)
        .layoutWeight(1)
        .width('100%')
        .loop(false)
        .onChange((index: number) => {
          this.currentPage = index;
          if (index === 0 && !this.page1Animated) {
            this.playPage1Animation();
          } else if (index === 1 && !this.page2Animated) {
            this.playPage2Animation();
          }
        })
        .indicatorStyle({
          bottom: 32,
          color: $r('sys.color.comp_background_secondary'),
          selectedColor: Color.White,
        })
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  OpenAIPage() {
    Scroll() {
      Column({ space: 24 }) {
        // Title
        Text('OpenAI 兼容接口')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .alignSelf(ItemAlign.Start)
          .opacity(this.cardOpacity1)
          .offset({ y: this.cardOffsetY1 })

        // Intro Text
        Text('大部分 API 提供商都会提供类似以下的 cURL （或 OpenAI 兼容性 REST 请求）调用示例，您可以根据该示例填写 Voot 的配置。')
          .fontSize(16)
          .fontColor($r('sys.color.font_on_secondary'))
          .lineHeight(24)
          .opacity(this.cardOpacity1)
          .offset({ y: this.cardOffsetY1 })

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
        .backgroundColor($r('sys.color.mask_fourth'))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)
        .border({ width: 1, color: '#1AFFFFFF' })
        .opacity(this.cardOpacity2)
        .offset({ y: this.cardOffsetY2 })

        // Parameter Breakdown Cards
        Column({ space: 16 }) {
          Column() {
            this.ParamItem(
              'API 地址 (URL)', 
              'https://.../v1/chat/completions',
              '对应 curl 命令中的 URL 部分。通常以 /v1/chat/completions 结尾。'
            )
          }
          .opacity(this.paramOpacity1)
          .offset({ y: this.paramOffsetY1 })

          Column() {
            this.ParamItem(
              'API 密钥 (Key)', 
              'YOUR_API_KEY',
              '对应 Authorization 标头中 Bearer 之后的部分。'
            )
          }
          .opacity(this.paramOpacity2)
          .offset({ y: this.paramOffsetY2 })

          Column() {
            this.ParamItem(
              '模型名称 (Model)', 
              'YOUR_MODEL_NAME',
              '对应 JSON 数据体中 model 字段的值。'
            )
          }
          .opacity(this.paramOpacity3)
          .offset({ y: this.paramOffsetY3 })
        }

        // 底部留白，确保沉浸式效果
        Blank().height(48)
      }
      .padding(24)
    }
  }

  @Builder
  GeminiPage() {
    Scroll() {
      Column({ space: 24 }) {
        // Title
        Text('Gemini API')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .alignSelf(ItemAlign.Start)
          .opacity(this.geminiCardOpacity1)
          .offset({ y: this.geminiCardOffsetY1 })

        // Intro Text
        Text('我们也支持 Google Gemini 的原生 API。您可以从 Google AI Studio 获取 API 密钥，并按以下格式填写配置。')
          .fontSize(16)
          .fontColor($r('sys.color.font_on_secondary'))
          .lineHeight(24)
          .opacity(this.geminiCardOpacity1)
          .offset({ y: this.geminiCardOffsetY1 })

        // Code Block Card
        Column() {
          Scroll() {
            Text("curl \"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=YOUR_API_KEY\" \\\n" +
"-H \"Content-Type: application/json\" \\\n" +
"-d '{\n" +
"  \"contents\": [\n" +
"    {\n" +
"      \"parts\": [\n" +
"        { \"text\": \"你好\" }\n" +
"      ]\n" +
"    }\n" +
"  ]\n" +
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
        .backgroundColor($r('sys.color.mask_fourth'))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)
        .border({ width: 1, color: '#1AFFFFFF' })
        .opacity(this.geminiCardOpacity2)
        .offset({ y: this.geminiCardOffsetY2 })

        // Parameter Breakdown Cards
        Column({ space: 16 }) {
          Column() {
            this.ParamItem(
              'API 密钥 (Key)', 
              'YOUR_API_KEY',
              '对应 URL 中 key= 之后的部分。可在 Google AI Studio 中创建。'
            )
          }
          .opacity(this.geminiParamOpacity1)
          .offset({ y: this.geminiParamOffsetY1 })

          Column() {
            this.ParamItem(
              '模型名称 (Model)', 
              'gemini-2.0-flash',
              '对应 URL 中 models/ 之后、冒号之前的部分。常用模型：gemini-2.0-flash、gemini-1.5-pro 等。'
            )
          }
          .opacity(this.geminiParamOpacity2)
          .offset({ y: this.geminiParamOffsetY2 })
        }

        // 底部留白，确保沉浸式效果
        Blank().height(48)
      }
      .padding(24)
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
        .fontColor($r('sys.color.font_on_secondary'))
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
