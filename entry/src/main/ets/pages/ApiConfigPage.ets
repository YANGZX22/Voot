import { hdsEffect, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode } from '@kit.UIDesignKit';

const TITLE_BAR_HEIGHT_MINI: number = 84;

export enum ApiMenuType {
  Prompt = 0,
  Glossary,
  OpenAI,
  DeepL,
  Ollama,
  Doubao
}

// NOTE: Interface kept for type safety, but implementation will use component props
export interface ApiConfigPageProps {
  selectedMenu: ApiMenuType;
  promptText: string;
  openAiApiUrl: string;
  openAiApiKey: string;
  openAiModel: string;
  deepLApiUrl: string;
  deepLApiKey: string;
  ollamaApiUrl: string;
  ollamaModel: string;
  doubaoApiUrl: string;
  doubaoApiKey: string;
  doubaoModel: string;
  glossary: string;
  onBack: () => void;
  onSelectMenu: (menu: ApiMenuType) => void;
  onUpdatePrompt: (value: string) => void;
  onUpdateOpenAiApiUrl: (value: string) => void;
  onUpdateOpenAiApiKey: (value: string) => void;
  onUpdateOpenAiModel: (value: string) => void;
  onUpdateDeepLApiUrl: (value: string) => void;
  onUpdateDeepLApiKey: (value: string) => void;
  onUpdateOllamaApiUrl: (value: string) => void;
  onUpdateOllamaModel: (value: string) => void;
  onUpdateDoubaoApiUrl: (value: string) => void;
  onUpdateDoubaoApiKey: (value: string) => void;
  onUpdateDoubaoModel: (value: string) => void;
  onUpdateGlossary: (value: string) => void;
  getConfigTextAreaHeight: (rows: number) => number;
}

// --- 1. Menu Button Component with Effects ---
@Component
struct MenuButton {
  @Prop label: string;
  @Prop menuType: ApiMenuType;
  @Prop isSelected: boolean;
  @Prop isLightEffectBright: boolean = true;
  @Prop isDarkMode: boolean = true;

  // Lighting Props
  @Prop isSource: boolean;      // True if THIS button is touched
  @Prop isIlluminated: boolean; // True if ANY button is touched

  // Callbacks
  onClickAction: () => void = () => {};
  onTouchStart: () => void = () => {};
  onTouchEnd: () => void = () => {};

  build() {
    Button() {
      Row() {
        Image($r('app.media.'+ this.label))
          .width(20)
          .height(20)
          .fillColor(Color.White)

        Text(" " + this.label)
          .layoutWeight(1)
          .fontSize(15)
          .fontWeight(this.isSelected ? FontWeight.Medium : FontWeight.Normal);

        if (this.isSelected) {
          Text('·')
            .fontColor(Color.White)
            .fontSize(20)
            .fontWeight(FontWeight.Bold);
        }
      }
      .width('100%');
    }
    .type(ButtonType.Capsule)
    .fontColor(Color.White)
    .width('100%')
    .height(44)
    .padding({ left: 12, right: 12 })
    .margin({ bottom: 8 })
    .backgroundColor(Color.Transparent)
    .borderRadius(12)
    .border({ width: 0 })
    // --- APPLY VISUAL EFFECT HERE ---
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
          (this.isSource
          ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
          : hdsEffect.PointLightSourceType.NONE),
        illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE :
          (this.isIlluminated
          ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
          : hdsEffect.PointLightIlluminatedType.NONE)
      })
      .buildEffect())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.onTouchStart();
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.onTouchEnd();
      }
    })
    .onClick(() => this.onClickAction());
  }
}

@Component
export struct ApiConfigPage {
  // Props
  @Prop selectedMenu: ApiMenuType = ApiMenuType.Prompt;
  @Prop promptText: string = "";
  @Prop openAiApiUrl: string = "";
  @Prop openAiApiKey: string = "";
  @Prop openAiModel: string = "";
  @Prop deepLApiUrl: string = "";
  @Prop deepLApiKey: string = "";
  @Prop ollamaApiUrl: string = "";
  @Prop ollamaModel: string = "";
  @Prop doubaoApiUrl: string = "";
  @Prop doubaoApiKey: string = "";
  @Prop doubaoModel: string = "";
  @Prop glossary: string = "";
  @Prop isLightEffectBright: boolean = true;
  @Prop isDarkMode: boolean = true;

  // Callbacks (Initialized to empty functions)
  onBack: () => void = () => {};
  onSelectMenu: (menu: ApiMenuType) => void = () => {};
  onUpdatePrompt: (value: string) => void = () => {};
  onUpdateOpenAiApiUrl: (value: string) => void = () => {};
  onUpdateOpenAiApiKey: (value: string) => void = () => {};
  onUpdateOpenAiModel: (value: string) => void = () => {};
  onUpdateDeepLApiUrl: (value: string) => void = () => {};
  onUpdateDeepLApiKey: (value: string) => void = () => {};
  onUpdateOllamaApiUrl: (value: string) => void = () => {};
  onUpdateOllamaModel: (value: string) => void = () => {};
  onUpdateDoubaoApiUrl: (value: string) => void = () => {};
  onUpdateDoubaoApiKey: (value: string) => void = () => {};
  onUpdateDoubaoModel: (value: string) => void = () => {};
  onUpdateGlossary: (value: string) => void = () => {};
  // Helper for TextArea height
  getConfigTextAreaHeight: (rows: number) => number = (rows: number) => rows * 20;

  // --- STATE FOR LIGHTING EFFECT ---
  // Tracks which menu ID is currently being touched. -1 means none.
  @State activeMenuId: number = -1;
  // State for sidebar visibility
  @State isSideBarShown: boolean = false;

  build() {
    HdsNavigation() {
      Column() {
        Blank().height(TITLE_BAR_HEIGHT_MINI);

        SideBarContainer(SideBarContainerType.Embed) {
          // --- Side Panel (Menu) ---
          Stack({ alignContent: Alignment.TopStart }) {
            // Selection Indicator
            Column()
              .width('100%')
              .height(44)
              .backgroundColor("#bf3c1464")
              .borderRadius(22)
              .border({ width: 1, color: Color.Gray })
              .margin({ top: 24 }) // Match the initial Blank height
              .translate({ y: this.selectedMenu * 52 }) // 44 (height) + 8 (margin)
              .animation({ duration: 300, curve: Curve.EaseInOut })
              .hitTestBehavior(HitTestMode.None) // Allow clicks to pass through to buttons

            Column() {
              Blank().height(24);

              // Menu Item 1: Prompt
            MenuButton({
              label: 'Prompt',
              menuType: ApiMenuType.Prompt,
              isSelected: this.selectedMenu === ApiMenuType.Prompt,
              isLightEffectBright: this.isLightEffectBright,
              isDarkMode: this.isDarkMode,
              isSource: this.activeMenuId === ApiMenuType.Prompt,
              isIlluminated: this.activeMenuId !== -1, // Illuminated if ANY button is touched
              onTouchStart: () => { this.activeMenuId = ApiMenuType.Prompt; },
              onTouchEnd: () => { this.activeMenuId = -1; },
              onClickAction: () => this.onSelectMenu(ApiMenuType.Prompt)
            });

            // Menu Item 6: Glossary
            MenuButton({
              label: 'Glossary',
              menuType: ApiMenuType.Glossary,
              isSelected: this.selectedMenu === ApiMenuType.Glossary,
              isLightEffectBright: this.isLightEffectBright,
              isDarkMode: this.isDarkMode,
              isSource: this.activeMenuId === ApiMenuType.Glossary,
              isIlluminated: this.activeMenuId !== -1,
              onTouchStart: () => { this.activeMenuId = ApiMenuType.Glossary; },
              onTouchEnd: () => { this.activeMenuId = -1; },
              onClickAction: () => this.onSelectMenu(ApiMenuType.Glossary)
            });

            // Menu Item 2: OpenAI
            MenuButton({
              label: 'OpenAI',
              menuType: ApiMenuType.OpenAI,
              isSelected: this.selectedMenu === ApiMenuType.OpenAI,
              isLightEffectBright: this.isLightEffectBright,
              isDarkMode: this.isDarkMode,
              isSource: this.activeMenuId === ApiMenuType.OpenAI,
              isIlluminated: this.activeMenuId !== -1,
              onTouchStart: () => { this.activeMenuId = ApiMenuType.OpenAI; },
              onTouchEnd: () => { this.activeMenuId = -1; },
              onClickAction: () => this.onSelectMenu(ApiMenuType.OpenAI)
            });

            // Menu Item 3: DeepL
            MenuButton({
              label: 'DeepL',
              menuType: ApiMenuType.DeepL,
              isSelected: this.selectedMenu === ApiMenuType.DeepL,
              isLightEffectBright: this.isLightEffectBright,
              isDarkMode: this.isDarkMode,
              isSource: this.activeMenuId === ApiMenuType.DeepL,
              isIlluminated: this.activeMenuId !== -1,
              onTouchStart: () => { this.activeMenuId = ApiMenuType.DeepL; },
              onTouchEnd: () => { this.activeMenuId = -1; },
              onClickAction: () => this.onSelectMenu(ApiMenuType.DeepL)
            });

            // Menu Item 4: Ollama
            MenuButton({
              label: 'Ollama',
              menuType: ApiMenuType.Ollama,
              isSelected: this.selectedMenu === ApiMenuType.Ollama,
              isLightEffectBright: this.isLightEffectBright,
              isDarkMode: this.isDarkMode,
              isSource: this.activeMenuId === ApiMenuType.Ollama,
              isIlluminated: this.activeMenuId !== -1,
              onTouchStart: () => { this.activeMenuId = ApiMenuType.Ollama; },
              onTouchEnd: () => { this.activeMenuId = -1; },
              onClickAction: () => this.onSelectMenu(ApiMenuType.Ollama)
            });

            // Menu Item 5: Doubao
            MenuButton({
              label: 'Doubao',
              menuType: ApiMenuType.Doubao,
              isSelected: this.selectedMenu === ApiMenuType.Doubao,
              isLightEffectBright: this.isLightEffectBright,
              isDarkMode: this.isDarkMode,
              isSource: this.activeMenuId === ApiMenuType.Doubao,
              isIlluminated: this.activeMenuId !== -1,
              onTouchStart: () => { this.activeMenuId = ApiMenuType.Doubao; },
              onTouchEnd: () => { this.activeMenuId = -1; },
              onClickAction: () => this.onSelectMenu(ApiMenuType.Doubao)
            });

            Blank().height(16);
          }
          .width('100%')
          // .padding({ left: 4, right: 4, top: 24, bottom: 24 }) // Moved padding to Stack
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start);
          }
          .width('100%')
          .padding({ left: 4, right: 4, top: 24, bottom: 24 })
          .alignContent(Alignment.TopStart)

          // --- Content Panel ---
          this.ContentPanel()
        }
        .sideBarWidth('160vp')
        .minContentWidth('360vp')
        .autoHide(true)
        .showSideBar($$this.isSideBarShown)
        .sideBarPosition(SideBarPosition.Start)
        .showControlButton(false)
        .width('100%')
        .layoutWeight(1);
      }
      .width('100%')
      .height('100%')
      .padding({ left: 0, right:0, top: 12, bottom: 0 })
      .backgroundColor(Color.Transparent);
    }
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(false)
    .titleBar({
      style: {
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
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
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: Color.White
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: Color.White
            }
          }
        }
      },
      content: {
        title: {
          mainTitle: '配置 API',
        },
        menu: {
          value: [{
            content: {
              label: this.isSideBarShown ? '关闭侧边栏' : '打开侧边栏',
              icon: this.isSideBarShown ? $r('sys.symbol.open_sidebar') : $r('sys.symbol.close_sidebar'),
              isEnabled: true,
              action: () => {
                animateTo({
                  duration: 500,
                  curve: Curve.EaseInOut
                }, () => {
                  this.isSideBarShown = !this.isSideBarShown;
                });
              }
            }
          }]
        },
        backIcon: {
          label: 'Back',
          action: () => this.onBack()
        }
      },
      avoidLayoutSafeArea: true
    })
  }

  // Helper Builder for the content panel to keep build() clean
  @Builder
  ContentPanel() {
    Column() {
      Scroll() {
        Column() {
          if (this.selectedMenu === ApiMenuType.Prompt) {
            PromptContent({
              promptText: this.promptText,
              onUpdatePrompt: this.onUpdatePrompt,
              getConfigTextAreaHeight: this.getConfigTextAreaHeight
              // Pass only what is needed or create a sub-struct if complex
            } as ApiConfigPageProps);
            // Note: For simplicity in this example, passing specific props to sub-builders
            // In a real app, converting sub-builders to @Component structs is better.
          } else {
            if (this.selectedMenu === ApiMenuType.OpenAI) {
              this.RenderProviderHeader('OpenAI', $r('app.media.OpenAI'));
              this.RenderOpenAiConfig();
            } else if (this.selectedMenu === ApiMenuType.DeepL) {
              this.RenderProviderHeader('DeepL', $r('app.media.DeepL'));
              this.RenderDeepLConfig();
            } else if (this.selectedMenu === ApiMenuType.Ollama) {
              this.RenderProviderHeader('Ollama', $r('app.media.Ollama'));
              this.RenderOllamaConfig();
            } else if (this.selectedMenu === ApiMenuType.Doubao) {
              this.RenderProviderHeader('Doubao', $r('app.media.Doubao'));
              this.RenderDoubaoConfig();
            } else if (this.selectedMenu === ApiMenuType.Glossary) {
              this.RenderGlossaryConfig();
            }
          }
        }
        .width('100%');
      }
      .scrollable(ScrollDirection.Vertical)
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    // .padding({ left: 0, right: 24, top: 24, bottom: 32 });
  }

  @Builder
  RenderProviderHeader(title: string, icon?: ResourceStr) {
    Column() {
      if (icon) {
        Image(icon)
          .width(48)
          .height(48)
          .margin({ bottom: 8 })
          .fillColor(Color.White)
      }
      Text(title)
        .fontColor(Color.White)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 16 })
    }
    .alignItems(HorizontalAlign.Center)
    .width('100%')
  }

  @Builder
  RenderOpenAiConfig() {
    Column() {
      Text('API Url').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.openAiApiUrl })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => this.onUpdateOpenAiApiUrl(value))
        .margin({ bottom: 12 });

      Text('API Key').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.openAiApiKey })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => this.onUpdateOpenAiApiKey(value))
        .margin({ bottom: 12 });

      Text('Model').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.openAiModel })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(3))
        .maxLines(4)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => this.onUpdateOpenAiModel(value));
    }
    .width('100%')
    .padding(12)
    .borderRadius(12);
  }

  @Builder
  RenderDeepLConfig() {
    Column() {
      Text('API Url').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.deepLApiUrl })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => this.onUpdateDeepLApiUrl(value))
        .margin({ bottom: 12 });

      Text('API Key').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.deepLApiKey })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => this.onUpdateDeepLApiKey(value));
    }
    .width('100%')
    .padding(12)
    .borderRadius(12);
  }

  @Builder
  RenderOllamaConfig() {
    Column() {
      Text('API Url').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.ollamaApiUrl })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => this.onUpdateOllamaApiUrl(value))
        .margin({ bottom: 12 });

      Text('Model').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.ollamaModel })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(3))
        .maxLines(4)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => this.onUpdateOllamaModel(value));
    }
    .width('100%')
    .padding(12)
    .borderRadius(12);
  }

  @Builder
  RenderDoubaoConfig() {
    Column() {
      Text('API Url').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.doubaoApiUrl })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => this.onUpdateDoubaoApiUrl(value))
        .margin({ bottom: 12 });

      Text('API Key').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.doubaoApiKey })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(4))
        .maxLines(6)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => this.onUpdateDoubaoApiKey(value))
        .margin({ bottom: 12 });

      Text('Model').fontSize(14).margin({ bottom: 4 }).fontColor(Color.White);
      TextArea({ text: this.doubaoModel })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(3))
        .maxLines(4)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => this.onUpdateDoubaoModel(value));
    }
    .width('100%')
    .padding(12)
    .borderRadius(12);
  }

  @Builder
  RenderGlossaryConfig() {
    Column() {
      Image($r('app.media.Glossary'))
        .width(48)
        .height(48)
        .margin({ bottom: 8 })
        .fillColor(Color.White)
      Text('术语库 (Glossary)').fontSize(20).fontWeight(FontWeight.Bold).margin({ bottom: 12 }).fontColor(Color.White);
      Text('每行输入一个术语对，格式为：原文=译文\n例如：\nHarmonyOS=鸿蒙\nAI=人工智能')
        .fontSize(14)
        .fontColor(Color.Gray)
        .margin({ bottom: 12 });

      TextArea({ text: this.glossary })
        .fontColor(Color.White)
        .width('100%')
        .height(this.getConfigTextAreaHeight(10))
        .maxLines(20)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => this.onUpdateGlossary(value));
    }
    .width('100%')
    .padding(12)
    .borderRadius(12);
  }
}

// Global Builder for PromptContent (needed because of the switch case in the previous code)
// Ideally this should also be a @Component or a method inside the class.
@Builder
function PromptContent(props: ApiConfigPageProps) {
  Column() {
    Image($r('app.media.Prompt'))
      .width(48)
      .height(48)
      .margin({ bottom: 8 })
      .fillColor(Color.White)
    Text('Prompt')
      .fontColor(Color.White)
      .fontSize(20)
      .fontWeight(FontWeight.Bold)
      .margin({ bottom: 12 });

    Column() {
      Text('请确保 Prompt (提示词) 包含 {0} 与 [abc]。{0} 代表目标语言，[abc] 代表原始文本。')
        .fontColor(Color.Grey)
        .fontSize(14)
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .margin({ bottom: 16 });

    Column() {
      Text('Prompt Text')
        .fontColor(Color.White)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 8 });

      TextArea({ text: props.promptText })
        .fontColor(Color.White)
        .width('100%')
        .height(props.getConfigTextAreaHeight(6))
        .maxLines(30)
        .textAlign(TextAlign.Start)
        .onChange((value: string) => props.onUpdatePrompt(value));
    }
    .width('100%')
    .padding(12)
    .borderRadius(16);

    Blank().height(24);
  }
  .width('100%');
}