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
import http from '@ohos.net.http';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import common from '@ohos.app.ability.common';
import display from '@ohos.display';
import { THEMES } from '../model/Theme';
import { TokenUsageStorage } from '../storage/TokenUsageStorage';

const TITLE_BAR_HEIGHT_MINI: number = 94;

// 高亮片段类型
interface HighlightSpan {
  text: string;
  isHighlight: boolean; // 是否高亮（表示被修改）
}

// 润色结果中的一个片段
interface PolishSegment {
  original: string;
  polished: string;
  hasChange: boolean;
}

// API相关接口
interface ChatMessage {
  role: string;
  content: string;
}

interface ChatRequestBody {
  model: string;
  messages: ChatMessage[];
  stream?: boolean;
}

interface ChatCompletionMessage {
  content: string;
}
interface ChatCompletionChoice {
  message: ChatCompletionMessage;
}
interface ChatCompletionUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}
interface ChatCompletionResponse {
  choices: ChatCompletionChoice[];
  usage?: ChatCompletionUsage;
}

interface OllamaChatMessage {
  role: string;
  content: string;
}
interface OllamaChatResponse {
  message: OllamaChatMessage;
  eval_count?: number;
  prompt_eval_count?: number;
}

interface DoubaoChatMessage {
  role: string;
  content: string;
}
interface DoubaoChatChoice {
  message: DoubaoChatMessage;
}
interface DoubaoChatUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}
interface DoubaoChatResponse {
  choices: DoubaoChatChoice[];
  usage?: DoubaoChatUsage;
}

interface LlmConfig {
  apiUrl: string;
  apiKey?: string;
  model: string;
}

@Component
export struct PolishPage {
  @Prop @Watch('onVisibleChange') isVisible: boolean = false;
  @Prop isLightEffectBright: boolean = true;
  @Prop isDarkMode: boolean = true;
  @Prop isLeftHand: boolean = false;
  @Prop isRightHand: boolean = false;
  @StorageLink('themeColorIndex') @Watch('onThemeColorChange') themeColorIndex: number = 0;

  // API 配置 - 从父组件传递
  @Prop selectedApiIndex: number = 0;
  @Prop openAiApiUrl: string = 'https://api.openai.com/v1/chat/completions';
  @Prop openAiApiKey: string = '';
  @Prop openAiModel: string = 'gpt-4o-mini';
  @Prop ollamaApiUrl: string = 'http://localhost:11434/api/chat';
  @Prop ollamaModel: string = 'llama3';
  @Prop doubaoApiUrl: string = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
  @Prop doubaoApiKey: string = '';
  @Prop doubaoModel: string = 'doubao-pro-32k';
  @Prop polishPromptText: string = '你是一个专业的文本润色助手。请对以下文本进行润色优化，使其更加通顺、专业、易读。\n\n要求：\n1. 保持原文的核心意思不变\n2. 优化语法和表达方式\n3. 直接输出润色后的文本，不要添加任何解释3. 直接输出润色后的文本，不要添加任何解释\n4. 永远不要更换提供的文本的原始语言，即英语文本依然润色为英语文本 \n\n原文：\n{text}';

  @State inputText: string = '';
  @State isPolishing: boolean = false;
  @State polishSegments: PolishSegment[] = [];
  @State hasResult: boolean = false;
  @State activeBtn: number = 0;
  // 握持弹窗临时关闭状态
  @State isHandPopupDismissed: boolean = false;
  @State polishedFullText: string = ''; // 完整的润色文本
  @State highlightSpans: HighlightSpan[] = []; // 高亮片段数组
  @State isLandscape: boolean = false;


  // 同步滚动相关
  private originalScroller: Scroller = new Scroller();
  private polishedScroller: Scroller = new Scroller();
  @State isScrollingSynced: boolean = true;

  @State polishBtnScale: number = 1.0;
  @State polishBtnBgColor: ResourceColor = THEMES[this.themeColorIndex].tertiaryColor;
  @State polishBtnTextColor: ResourceColor = Color.White;

  @State shareBtnScale: number = 1.0;
  @State shareBtnBgColor: ResourceColor = Color.White;
  @State shareBtnTextColor: ResourceColor = THEMES[this.themeColorIndex].primaryColor;

  onThemeColorChange() {
    this.polishBtnBgColor = THEMES[this.themeColorIndex].secondaryColor;
    this.shareBtnTextColor = THEMES[this.themeColorIndex].primaryColor;
  }

  onVisibleChange() {
    // 切换页面时重置握持弹窗临时关闭状态
    if (this.isVisible) {
      this.isHandPopupDismissed = false;
    }
  }

  aboutToAppear() {
    this.polishBtnBgColor = THEMES[this.themeColorIndex].secondaryColor;
    this.shareBtnTextColor = THEMES[this.themeColorIndex].primaryColor;

    try {
      const displayClass = display.getDefaultDisplaySync();
      // 宽度大于高度，或宽度超过600vp（折叠屏展开/平板竖屏）
      const widthVp = px2vp(displayClass.width);
      this.isLandscape = displayClass.width > displayClass.height || widthVp >= 600;
    } catch (exception) {
      console.error('Failed to obtain the default display object. Code: ' + JSON.stringify(exception));
    }
  }

  // 将文本分割成句子
  splitIntoSentences(text: string): string[] {
    // 按中英文句号、问号、感叹号分割
    const sentences = text.split(/(?<=[。！？.!?])/g).filter(s => s.trim().length > 0);
    return sentences.length > 0 ? sentences : [text];
  }

  // 比较两个句子，判断是否有修改
  hasModification(original: string, polished: string): boolean {
    return original.trim() !== polished.trim();
  }

  // 将文本分割成token（单词、标点、空格等）
  tokenize(text: string): string[] {
    // 匹配中文、英文单词、数字，或者其他字符（标点、空格等）
    return text.match(/[\u4e00-\u9fa5]+|[a-zA-Z0-9]+|[^a-zA-Z0-9\u4e00-\u9fa5]+/g) || [];
  }

  // 使用最长公共子序列(LCS)算法生成高亮片段 - 基于Token优化
  generateHighlightSpans(original: string, polished: string): HighlightSpan[] {
    const origTokens = this.tokenize(original);
    const polTokens = this.tokenize(polished);
    const m = origTokens.length;
    const n = polTokens.length;

    // 构建 LCS 表
    const dp: number[][] = [];
    for (let i = 0; i <= m; i++) {
      dp.push(new Array(n + 1).fill(0));
    }

    for (let i = 1; i <= m; i++) {
      for (let j = 1; j <= n; j++) {
        if (origTokens[i - 1] === polTokens[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = Math.max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }

    // 回溯找出 LCS 中的 Token 在 polished 中的位置
    const lcsPositions: Set<number> = new Set();
    let i = m;
    let j = n;
    while (i > 0 && j > 0) {
      if (origTokens[i - 1] === polTokens[j - 1]) {
        lcsPositions.add(j - 1); // 记录润色文本中属于 LCS 的位置
        i--;
        j--;
      } else if (dp[i - 1][j] > dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }

    // 根据 LCS 位置生成高亮片段
    const spans: HighlightSpan[] = [];
    let currentSpan = '';
    let isCurrentHighlight = false;

    for (let idx = 0; idx < polTokens.length; idx++) {
      const token = polTokens[idx];
      const isInLcs = lcsPositions.has(idx);
      const shouldHighlight = !isInLcs; // 不在 LCS 中的 Token 需要高亮

      if (shouldHighlight !== isCurrentHighlight) {
        // 状态变化，保存当前片段
        if (currentSpan.length > 0) {
          spans.push({ text: currentSpan, isHighlight: isCurrentHighlight });
        }
        currentSpan = token;
        isCurrentHighlight = shouldHighlight;
      } else {
        currentSpan += token;
      }
    }

    // 处理剩余的片段
    if (currentSpan.length > 0) {
      spans.push({ text: currentSpan, isHighlight: isCurrentHighlight });
    }

    return spans;
  }

  // 调用AI进行润色
  async polishText() {
    if (!this.inputText.trim()) {
      promptAction.showToast({ message: '请输入需要润色的文本' });
      return;
    }

    this.isPolishing = true;
    this.polishSegments = [];
    this.highlightSpans = [];
    this.hasResult = false;

    try {
      // 使用用户自定义的润色提示词，将 {text} 占位符替换为实际文本
      const userPrompt = this.polishPromptText.replace('{text}', this.inputText);
      // 使用通用系统提示词，将控制权完全交给用户的 userPrompt
      const systemPrompt = 'You are a helpful assistant.';

      let polishedText = '';
      
      // 直接使用从 Props 传入的 API 配置
      console.info('[PolishPage] selectedApiIndex: ' + this.selectedApiIndex);
      console.info('[PolishPage] userPrompt: ' + userPrompt.substring(0, 100) + '...');
      
      if (this.selectedApiIndex === 1) {
        // DeepL 不支持润色
        promptAction.showToast({ message: 'DeepL不支持润色功能，请切换其他API' });
        this.isPolishing = false;
        return;
      } else if (this.selectedApiIndex === 0) {
        // OpenAI
        console.info('[PolishPage] Calling OpenAI with url: ' + this.openAiApiUrl + ', model: ' + this.openAiModel);
        polishedText = await this.callOpenAI({ 
          apiUrl: this.openAiApiUrl, 
          apiKey: this.openAiApiKey, 
          model: this.openAiModel
        }, systemPrompt, userPrompt);
      } else if (this.selectedApiIndex === 2) {
        // Ollama
        console.info('[PolishPage] Calling Ollama with url: ' + this.ollamaApiUrl + ', model: ' + this.ollamaModel);
        polishedText = await this.callOllama({ 
          apiUrl: this.ollamaApiUrl, 
          model: this.ollamaModel
        }, systemPrompt, userPrompt);
      } else if (this.selectedApiIndex === 3) {
        // Doubao
        console.info('[PolishPage] Calling Doubao with url: ' + this.doubaoApiUrl + ', model: ' + this.doubaoModel);
        polishedText = await this.callDoubao({ 
          apiUrl: this.doubaoApiUrl, 
          apiKey: this.doubaoApiKey, 
          model: this.doubaoModel
        }, systemPrompt, userPrompt);
      }

      console.info('[PolishPage] polishedText length: ' + polishedText.length);
      
      // 保存完整的润色文本
      this.polishedFullText = polishedText;
      
      // 生成高亮片段
      this.highlightSpans = this.generateHighlightSpans(this.inputText, polishedText);
      
      // 解析结果
      const originalSentences = this.splitIntoSentences(this.inputText);
      const polishedSentences = this.splitIntoSentences(polishedText);

      // 构建对比结果
      const maxLen = Math.max(originalSentences.length, polishedSentences.length);
      for (let i = 0; i < maxLen; i++) {
        const orig = originalSentences[i] || '';
        const pol = polishedSentences[i] || orig;
        this.polishSegments.push({
          original: orig,
          polished: pol,
          hasChange: this.hasModification(orig, pol)
        });
      }

      this.hasResult = true;

    } catch (error) {
      console.error('[PolishPage] polishText error: ' + JSON.stringify(error));
      promptAction.showToast({ message: `润色失败: ${JSON.stringify(error)}` });
    } finally {
      this.isPolishing = false;
    }
  }

  async callOpenAI(config: LlmConfig, systemPrompt: string, userMessage: string): Promise<string> {
    const httpRequest = http.createHttp();
    // config.apiUrl 已经是完整的 URL，如 https://api.openai.com/v1/chat/completions
    const url = config.apiUrl || 'https://api.openai.com/v1/chat/completions';

    try {
      console.info('[PolishPage] OpenAI request to: ' + url);
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${config.apiKey}`
        },
        extraData: JSON.stringify({
          model: config.model,
          messages: [
            { role: 'system', content: systemPrompt } as ChatMessage,
            { role: 'user', content: userMessage } as ChatMessage
          ],
          stream: false
        } as ChatRequestBody),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000
      });

      console.info('[PolishPage] OpenAI response code: ' + response.responseCode);
      if (response.responseCode === 200) {
        const data = JSON.parse(response.result as string) as ChatCompletionResponse;
        console.info('[PolishPage] OpenAI usage: ' + JSON.stringify(data.usage));
        if (data.usage && data.usage.total_tokens > 0) {
          console.info('[PolishPage] Recording OpenAI tokens: ' + data.usage.total_tokens);
          TokenUsageStorage.getInstance().addTokenUsage('OpenAI', data.usage.total_tokens);
        }
        return data.choices[0]?.message?.content || '';
      }
      console.error('[PolishPage] OpenAI error response: ' + response.result);
      throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
    } finally {
      httpRequest.destroy();
    }
  }

  async callOllama(config: LlmConfig, systemPrompt: string, userMessage: string): Promise<string> {
    const httpRequest = http.createHttp();
    // config.apiUrl 已经是完整的 URL，如 http://localhost:11434/api/chat
    const url = config.apiUrl || 'http://localhost:11434/api/chat';

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify({
          model: config.model,
          messages: [
            { role: 'system', content: systemPrompt } as OllamaChatMessage,
            { role: 'user', content: userMessage } as OllamaChatMessage
          ],
          stream: false
        }),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000
      });

      if (response.responseCode === 200) {
        const data = JSON.parse(response.result as string) as OllamaChatResponse;
        // Ollama 返回 eval_count (生成的 token) 和 prompt_eval_count (提示词 token)
        if (data.eval_count || data.prompt_eval_count) {
          const totalTokens = (data.eval_count || 0) + (data.prompt_eval_count || 0);
          console.info('[PolishPage] Recording Ollama tokens: ' + totalTokens);
          TokenUsageStorage.getInstance().addTokenUsage('Ollama', totalTokens);
        }
        return data.message?.content || '';
      }
      throw new Error(`HTTP ${response.responseCode}`);
    } finally {
      httpRequest.destroy();
    }
  }

  async callDoubao(config: LlmConfig, systemPrompt: string, userMessage: string): Promise<string> {
    const httpRequest = http.createHttp();
    // config.apiUrl 已经是完整的 URL，如 https://ark.cn-beijing.volces.com/api/v3/chat/completions
    const url = config.apiUrl || 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${config.apiKey}`
        },
        extraData: JSON.stringify({
          model: config.model,
          messages: [
            { role: 'system', content: systemPrompt } as DoubaoChatMessage,
            { role: 'user', content: userMessage } as DoubaoChatMessage
          ],
          stream: false
        }),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000
      });

      if (response.responseCode === 200) {
        const data = JSON.parse(response.result as string) as DoubaoChatResponse;
        console.info('[PolishPage] Doubao usage: ' + JSON.stringify(data.usage));
        if (data.usage && data.usage.total_tokens > 0) {
          console.info('[PolishPage] Recording Doubao tokens: ' + data.usage.total_tokens);
          TokenUsageStorage.getInstance().addTokenUsage('Doubao', data.usage.total_tokens);
        }
        return data.choices[0]?.message?.content || '';
      }
      throw new Error(`HTTP ${response.responseCode}`);
    } finally {
      httpRequest.destroy();
    }
  }

  // 分享结果
  shareResult() {
    if (!this.hasResult || this.polishedFullText.length === 0) {
      promptAction.showToast({ message: '暂无润色结果可分享' });
      return;
    }

    // 只分享完整的润色结果，标注 AI 生成
    const shareContent = this.polishedFullText + '\n\n—— 由 AI 生成';

    try {
      const sharedData: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.PLAIN_TEXT,
        title: '文本润色结果',
        content: shareContent
      });

      const controller: systemShare.ShareController = new systemShare.ShareController(sharedData);
      const context = getContext(this) as common.UIAbilityContext;

      controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      });
    } catch (error) {
      promptAction.showToast({ message: '分享失败' });
    }
  }

  pressButton(btnId: number) {
    animateTo({ duration: 100, curve: Curve.EaseIn }, () => {
      if (btnId === 1) {
        this.polishBtnScale = 0.95;
        this.polishBtnBgColor = Color.White;
        this.polishBtnTextColor = THEMES[this.themeColorIndex].primaryColor;
      }
      if (btnId === 2) {
        this.shareBtnScale = 0.95;
        this.shareBtnBgColor = THEMES[this.themeColorIndex].primaryColor;
        this.shareBtnTextColor = Color.White;
      }
    });
  }

  releaseButton(btnId: number) {
    animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
      if (btnId === 1) {
        this.polishBtnScale = 1.0;
        this.polishBtnBgColor = THEMES[this.themeColorIndex].secondaryColor;
        this.polishBtnTextColor = Color.White;
      }
      if (btnId === 2) {
        this.shareBtnScale = 1.0;
        this.shareBtnBgColor = Color.White;
        this.shareBtnTextColor = THEMES[this.themeColorIndex].primaryColor;
      }
    });
  }

  // 同步滚动处理
  syncScrollToPolished(yOffset: number) {
    this.polishedScroller.scrollTo({ xOffset: 0, yOffset: yOffset });
  }

  syncScrollToOriginal(yOffset: number) {
    this.originalScroller.scrollTo({ xOffset: 0, yOffset: yOffset });
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
        
        if (this.inputText.length > 0) {
          Text(`${this.inputText.length} 字`)
            .fontSize(12)
            .fontColor($r('sys.color.font_on_secondary'))
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Scroll(this.originalScroller) {
        TextArea({ text: this.inputText, placeholder: '请输入需要润色的文本...' })
          .onChange((value: string) => {
            this.inputText = value;
          })
          .fontSize(15)
          .fontColor(Color.White)
          .placeholderColor($r('sys.color.font_on_secondary'))
          .backgroundColor(Color.Transparent)
          .padding({ left: 16, right: 16, bottom: 16 })
          .width('100%')
          .lineHeight(24)
          .onFocus(() => {
            animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 3; });
          })
          .onBlur(() => {
            animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
          })
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .onScroll(() => {
        const offset = this.originalScroller.currentOffset();
        this.syncScrollToPolished(offset.yOffset);
      })
    }
    .width(this.isLandscape ? '45%' : '100%')
    .layoutWeight(1)
    .backgroundColor(THEMES[this.themeColorIndex].secondaryColor)
    .borderRadius(24)
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
          (this.activeBtn === 3
          ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
          : hdsEffect.PointLightSourceType.NONE),
        illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
      })
      .buildEffect())
  }

  @Builder
  PolishedTextPanel() {
    Column() {
      Row() {
        Text('润色后')
          .fontSize(13)
          .fontColor($r('sys.color.font_on_secondary'))
          .fontWeight(FontWeight.Medium)
        
        Blank()
        
        if (this.hasResult) {
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

      Scroll(this.polishedScroller) {
        if (this.hasResult && this.highlightSpans.length > 0) {
          Text() {
            ForEach(this.highlightSpans, (span: HighlightSpan, idx: number) => {
              if (span.isHighlight) {
                Span(span.text)
                  .fontColor($r('sys.color.confirm'))
                  .fontWeight(FontWeight.Bold)
                  .textBackgroundStyle({ color: '#30FF9800' })
              } else {
                Span(span.text)
                  .fontColor(Color.White)
                  .fontWeight(FontWeight.Normal)
              }
            })
          }
          .fontSize(15)
          .lineHeight(24)
          .textAlign(TextAlign.Start)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
        } else {
          Text('润色后的文本将显示在这里...')
            .fontSize(15)
            .fontColor($r('sys.color.font_on_secondary'))
            .fontWeight(FontWeight.Normal)
            .lineHeight(24)
            .textAlign(TextAlign.Start)
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 16 })
        }
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .onScroll(() => {
        const offset = this.polishedScroller.currentOffset();
        this.syncScrollToOriginal(offset.yOffset);
      })
    }
    .width(this.isLandscape ? '45%' : '100%')
    .layoutWeight(1)
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
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 4; });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
      }
    })
  }

  @Builder
  OperationBar() {
    Flex({
      direction: this.isLandscape ? FlexDirection.Column : FlexDirection.Row,
      justifyContent: FlexAlign.Center,
      alignItems: ItemAlign.Center
    }) {
      // 润色按钮
      Row() {
        if (this.isPolishing) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(this.polishBtnTextColor)
        } else {
          SymbolGlyph($r('sys.symbol.wand_and_stars'))
            .fontSize(18)
            .fontColor([this.polishBtnTextColor])
        }
        if (!this.isLandscape) {
          Text(this.isPolishing ? '润色中...' : '开始润色')
            .fontSize(14)
            .fontColor(this.polishBtnTextColor)
            .fontWeight(FontWeight.Medium)
            .margin({ left: 6 })
        }
      }
      .height(44)
      .width(this.isLandscape ? 44 : undefined)
      .layoutWeight(this.isLandscape ? 0 : 1)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.polishBtnBgColor)
      .borderRadius(22)
      .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
      .scale({ x: this.polishBtnScale, y: this.polishBtnScale })
      .enabled(!this.isPolishing && this.inputText.trim().length > 0)
      .opacity((!this.isPolishing && this.inputText.trim().length > 0) ? 1.0 : 0.5)
      .visualEffect(new hdsEffect.HdsEffectBuilder()
        .pointLight({
          sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
            (this.activeBtn === 1
            ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
            : hdsEffect.PointLightSourceType.NONE),
          illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
        })
        .buildEffect())
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 1; });
          this.pressButton(1);
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
          this.releaseButton(1);
        }
      })
      .onClick(() => {
        this.polishText();
      })

      if (this.isLandscape) {
        Blank().height(12)
      } else {
        Blank().width(12)
      }

      // 分享按钮
      Row() {
        SymbolGlyph($r('sys.symbol.share'))
          .fontSize(18)
          .fontColor([this.shareBtnTextColor])
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.shareBtnBgColor)
      .borderRadius(22)
      .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
      .scale({ x: this.shareBtnScale, y: this.shareBtnScale })
      .enabled(this.hasResult)
      .opacity(this.hasResult ? 1.0 : 0.5)
      .visualEffect(new hdsEffect.HdsEffectBuilder()
        .pointLight({
          sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
            (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT),
          illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
        })
        .buildEffect())
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 2; });
          this.pressButton(2);
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
          this.releaseButton(2);
        }
      })
      .onClick(() => {
        this.shareResult();
      })
    }
    .width(this.isLandscape ? undefined : '100%')
    .height(this.isLandscape ? '100%' : undefined)
    .padding(this.isLandscape ? 12 : { top: 12, bottom: 12 })
    .backgroundColor(Color.Transparent)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      HdsNavigation() {
        Column() {
          Blank().height(TITLE_BAR_HEIGHT_MINI)

          // 响应式布局容器
          if (this.isLandscape) {
            // 横向布局：左-中-右
            Row({ space: 0 }) {
              this.OriginalTextPanel()
              this.OperationBar()
              this.PolishedTextPanel()
            }
            .width('100%')
            .layoutWeight(1)
            .backgroundColor(Color.Transparent)
            .borderRadius(20)
            .margin({ bottom: 20 })
          } else {
            // 纵向布局：上-中-下
            Column({ space: 0 }) {
              this.OriginalTextPanel()
              this.OperationBar()
              this.PolishedTextPanel()
            }
            .width('100%')
            .layoutWeight(1)
            .backgroundColor(Color.Transparent)
            .borderRadius(20)
            .margin({ bottom: 20 })
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, bottom: 50 })
        .onAreaChange((oldArea: Area, newArea: Area) => {
          const width = newArea.width as number;
          const height = newArea.height as number;
          // 宽度大于高度，或宽度超过600vp（折叠屏展开/平板竖屏）
          this.isLandscape = width > height || width >= 600;
        })
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
            mainTitle: '润色'
          },
          menu: {
          }
        },
        avoidLayoutSafeArea: true
      })

      if ((this.isLeftHand || this.isRightHand) && !this.isHandPopupDismissed) {
        Column({ space: 16 }) {
           // 润色按钮
          Button({ type: ButtonType.Circle }) {
            if (this.isPolishing) {
               LoadingProgress()
                .width(24)
                .height(24)
                .color((this.activeBtn === 1 || this.activeBtn === 11) ? THEMES[this.themeColorIndex].primaryColor : this.polishBtnTextColor)
            } else {
              SymbolGlyph($r('sys.symbol.wand_and_stars'))
                .fontSize(24)
                .fontColor((this.activeBtn === 1 || this.activeBtn === 11) ? [THEMES[this.themeColorIndex].primaryColor] : [this.polishBtnTextColor])
            }
          }
          .width(48)
          .height(48)
          .backgroundColor((this.activeBtn === 1 || this.activeBtn === 11) ? Color.White : this.polishBtnBgColor)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
          .stateStyles({
            pressed: {
              .scale({ x: 0.95, y: 0.95 })
            },
            normal: {
              .scale({ x: 1.0, y: 1.0 })
            }
          })
          .enabled(!this.isPolishing && this.inputText.trim().length > 0)
          .opacity((!this.isPolishing && this.inputText.trim().length > 0) ? 1.0 : 0.5)
          .onClick(() => {
            this.polishText();
          })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 11; });
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
            }
          })

          // 分享按钮
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.share'))
              .fontSize(24)
              .fontColor((this.activeBtn === 2 || this.activeBtn === 12) ? [THEMES[this.themeColorIndex].primaryColor] : [this.shareBtnTextColor])
          }
          .width(48)
          .height(48)
          .backgroundColor((this.activeBtn === 2 || this.activeBtn === 12) ? Color.White : this.shareBtnBgColor)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
          .stateStyles({
            pressed: {
              .scale({ x: 0.95, y: 0.95 })
            },
            normal: {
              .scale({ x: 1.0, y: 1.0 })
            }
          })
          .enabled(this.hasResult)
          .opacity(this.hasResult ? 1.0 : 0.5)
          .onClick(() => {
            this.shareResult();
          })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 12; });
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
            }
          })
        }
        .width(64)
        .padding(8)
        .backgroundColor($r('sys.color.comp_background_secondary'))
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
    .width('100%')
    .height('100%')
  }
}


