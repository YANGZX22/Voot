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

import router from '@ohos.router';
import { Session } from '../model/Session';
import { HistoryStorage } from '../storage/HistoryStorage';
import { ApiConfigStorage, ApiConfigSnapshot, createDefaultMultiKeySlots } from '../storage/ApiConfigStorage';
import { TokenUsageStorage } from '../storage/TokenUsageStorage';
import { ApiMenuType } from './ApiConfigPage';
import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { ComponentContent } from '@kit.ArkUI';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';


interface LlmConfig {
  apiUrl: string;
  apiKey?: string;
  model: string;
}

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

const DEFAULT_CONFIG: ApiConfigSnapshot = {
  promptText: 'You are a helpful assistant.',
  openAiKeySlots: createDefaultMultiKeySlots('https://api.openai.com', '', 'gpt-3.5-turbo'),
  deepLKeySlots: createDefaultMultiKeySlots('https://api-free.deepl.com/v2/translate', '', ''),
  ollamaKeySlots: createDefaultMultiKeySlots('http://localhost:11434', '', ''),
  doubaoKeySlots: createDefaultMultiKeySlots('https://ark.cn-beijing.volces.com', '', ''),
  openAiApiUrl: 'https://api.openai.com',
  openAiApiKey: '',
  openAiModel: 'gpt-3.5-turbo',
  deepLApiUrl: 'https://api-free.deepl.com/v2/translate',
  deepLApiKey: '',
  ollamaApiUrl: 'http://localhost:11434',
  ollamaModel: '',
  doubaoApiUrl: 'https://ark.cn-beijing.volces.com',
  doubaoApiKey: '',
  doubaoModel: '',
  selectedApiIndex: 0,
  selectedLanguageIndex: 0,
  intervalIndex: 1,
  contextsIndex: 0,
  temperatureIndex: 1,
  maxTokensIndex: 1,
  subtitleFontSize: 18,
  subtitleFontColor: '#FFFFFF',
  subtitleBackgroundColor: '#80000000',
  subtitleHeight: 20,
  glossary: 'HarmonyOS = 鸿蒙',
  themeMode: 2  // 默认跟随系统
};

@Entry
@Component
struct SessionDetailPage {
  @State session: Session | undefined = undefined;
  @State isSummarizing: boolean = false;

  async aboutToAppear() {
    const params = router.getParams() as Record<string, number>;
    const sessionId = params['sessionId'];
    this.session = await HistoryStorage.getInstance().getSessionById(sessionId);
  }

  build() {
    Stack() {
      Image($r('app.media.app_background_pic'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      HdsNavigation() {
        Scroll() {
          Column() {
            // Spacer for titlebar
            Column().height(94)

            if (this.session) {
              // Summary Section
              if (this.session.summary) {
                Column() {
                  Row() {
                    Text('AI 总结')
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Color.White)
                    Text('AI生成')
                      .fontSize(12)
                      .fontColor(Color.White)
                      .backgroundColor('#33FFFFFF')
                      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                      .borderRadius(10)
                      .margin({ left: 8 })
                    Blank()
                    Button(this.isSummarizing ? '正在重新生成...' : '重新生成')
                      .fontSize(12)
                      .height(28)
                      .backgroundColor('#33FFFFFF')
                      .fontColor(Color.White)
                      .enabled(!this.isSummarizing)
                      .onClick(() => {
                        this.generateSummary();
                      })
                  }
                  .width('100%')
                  .margin({ bottom: 8 })
                  Text(this.session.summary)
                    .fontSize(16)
                    .lineHeight(24)
                    .fontColor(Color.White)
                    .backgroundColor('#33FFFFFF')
                    .padding(12)
                    .borderRadius(8)
                    .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .margin({ bottom: 24 })
              } else {
                Button(this.isSummarizing ? '正在生成总结...' : '生成 AI 总结')
                  .width('100%')
                  .margin({ bottom: 24 })
                  .enabled(!this.isSummarizing)
                  .backgroundColor('#33FFFFFF')
                  .fontColor(Color.White)
                  .onClick(() => {
                    this.generateSummary();
                  })
              }

              // Original Text
              Text('原文')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .margin({ bottom: 8 })
                .width('100%')
              Text(this.session.originalText)
                .fontSize(16)
                .lineHeight(24)
                .fontColor('#CCCCCC')
                .margin({ bottom: 24 })
                .width('100%')

              // Translated Text
              if (this.session.translatedText) {
                Row() {
                  Text('译文')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                  Text('AI生成')
                    .fontSize(12)
                    .fontColor(Color.White)
                    .backgroundColor('#33FFFFFF')
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .borderRadius(10)
                    .margin({ left: 8 })
                }
                .width('100%')
                .margin({ bottom: 8 })
                Text(this.session.translatedText)
                  .fontSize(16)
                  .lineHeight(24)
                  .fontColor('#CCCCCC')
                  .margin({ bottom: 24 })
                  .width('100%')
              }
            }
          }
          .padding(16)
          .width('100%')
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .height('100%')
      }
      .mode(NavigationMode.Stack)
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(false)
      .minContentWidth('100%')
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
            mainTitle: '详情',
          },
          menu: {
            value: [{
              content: {
                label: '导出',
                icon: $r('sys.symbol.share'),
                isEnabled: true,
                action: () => {
                  this.showExportDialog();
                }
              }
            }]
          },
          // backIcon: {
          //   label: 'backButton',
          //   icon: $r('sys.symbol.backward_fill'),
          //   isEnabled: true,
          // }
        },
        avoidLayoutSafeArea: true
      })
    }
    .width('100%')
    .height('100%')
  }

  async generateSummary() {
    if (!this.session || !this.session.originalText) return;
    this.isSummarizing = true;

    try {
      const context = getContext(this) as common.UIAbilityContext;
      const config = await ApiConfigStorage.loadSnapshot(context, DEFAULT_CONFIG);
      const prompt = `请用与以下内容相同的语言进行简要总结，直接输出总结内容，不要添加任何前缀或解释，内容为：\n\n${this.session.originalText}`;
      
      let summary = '';
      
      let apiType = ApiMenuType.OpenAI;
      switch (config.selectedApiIndex) {
        case 0: apiType = ApiMenuType.OpenAI; break;
        case 1: apiType = ApiMenuType.DeepL; break;
        case 2: apiType = ApiMenuType.Ollama; break;
        case 3: apiType = ApiMenuType.Doubao; break;
      }

      if (apiType === ApiMenuType.OpenAI) {
        summary = await this.callOpenAI({ apiUrl: config.openAiApiUrl, apiKey: config.openAiApiKey, model: config.openAiModel }, prompt);
      } else if (apiType === ApiMenuType.DeepL) {
        summary = "DeepL 仅为翻译模型，不支持大语言模型的总结功能，尝试在配置页面切换其他模型";
      } else if (apiType === ApiMenuType.Ollama) {
        summary = await this.callOllama({ apiUrl: config.ollamaApiUrl, model: config.ollamaModel }, prompt);
      } else if (apiType === ApiMenuType.Doubao) {
        summary = await this.callDoubao({ apiUrl: config.doubaoApiUrl, apiKey: config.doubaoApiKey, model: config.doubaoModel }, prompt);
      }

      if (summary) {
        await HistoryStorage.getInstance().updateSummary(this.session.id, summary);
        this.session.summary = summary; // Update UI
      }
    } catch (e) {
      let errorMsg: string;
      if (e instanceof Error) {
        errorMsg = e.message;
      } else if (typeof e === 'object' && e !== null) {
        errorMsg = JSON.stringify(e);
      } else {
        errorMsg = String(e);
      }
      promptAction.showToast({ message: '总结失败: ' + errorMsg });
    } finally {
      this.isSummarizing = false;
    }
  }

  async callOpenAI(config: LlmConfig, prompt: string): Promise<string> {
    const httpRequest = http.createHttp();
    try {
      const message: ChatMessage = { role: 'user', content: prompt };
      const requestBody: ChatRequestBody = {
        model: config.model,
        messages: [message]
      };
      const body = JSON.stringify(requestBody);

      let apiUrl = config.apiUrl.replace(/\/+$/, ''); 
      if (!apiUrl.endsWith('/v1/chat/completions')) {
        apiUrl = apiUrl + '/v1/chat/completions';
      }
      const response = await httpRequest.request(apiUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${config.apiKey}`
        },
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 60000
      });
      
      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as ChatCompletionResponse;
        // 记录 Token 使用量到统计和卡片
        if (result.usage && result.usage.total_tokens) {
          TokenUsageStorage.getInstance().addTokenUsage('OpenAI', result.usage.total_tokens);
        }
        return result.choices[0].message.content;
      }
      throw new Error('HTTP ' + response.responseCode + ': ' + response.result);
    } finally {
      httpRequest.destroy();
    }
  }

  async callOllama(config: LlmConfig, prompt: string): Promise<string> {
    const httpRequest = http.createHttp();
    try {
      const message: ChatMessage = { role: 'user', content: prompt };
      const requestBody: ChatRequestBody = {
        model: config.model,
        messages: [message],
        stream: false
      };
      const body = JSON.stringify(requestBody);
      const response = await httpRequest.request(config.apiUrl + '/api/chat', {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 120000
      });
      
      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as OllamaChatResponse;
        // 记录 Token 使用量到统计和卡片
        if (result.eval_count || result.prompt_eval_count) {
          const total = (result.eval_count || 0) + (result.prompt_eval_count || 0);
          TokenUsageStorage.getInstance().addTokenUsage('Ollama', total);
        }
        return result.message.content;
      }
      throw new Error('HTTP ' + response.responseCode + ': ' + response.result);
    } finally {
      httpRequest.destroy();
    }
  }

  async callDoubao(config: LlmConfig, prompt: string): Promise<string> {
    const httpRequest = http.createHttp();
    try {
      const message: ChatMessage = { role: 'user', content: prompt };
      const requestBody: ChatRequestBody = {
        model: config.model,
        messages: [message]
      };
      const body = JSON.stringify(requestBody);
      const response = await httpRequest.request(config.apiUrl + '/api/v3/chat/completions', {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${config.apiKey}`
        },
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 60000
      });
      
      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as DoubaoChatResponse;
        // 记录 Token 使用量到统计和卡片
        if (result.usage && result.usage.total_tokens) {
          TokenUsageStorage.getInstance().addTokenUsage('Doubao', result.usage.total_tokens);
        }
        return result.choices[0].message.content;
      }
      throw new Error('HTTP ' + response.responseCode + ': ' + response.result);
    } finally {
      httpRequest.destroy();
    }
  }

  showExportDialog() {
    promptAction.showActionMenu({
      title: '导出',
      buttons: [
        { text: '华为分享', color: '#000000' },
        { text: '导出为 Markdown', color: '#000000' },
        { text: '导出为 TXT', color: '#000000' }
      ]
    }, async (err, data) => {
      if (err) return;
      if (data.index === 0) {
        this.shareToSystem();
      } else if (data.index === 1) {
        await this.exportFile('md');
      } else if (data.index === 2) {
        await this.exportFile('txt');
      }
    });
  }

  private shareToSystem(): void {
    if (!this.session) {
      promptAction.showToast({ message: '没有可分享的内容' });
      return;
    }

    let shareContent = `${this.session.title}\n`;
    shareContent += `时间: ${new Date(this.session.startTime).toLocaleString()}\n\n`;

    if (this.session.summary) {
      shareContent += `【AI总结（AI生成）】\n${this.session.summary}\n\n`;
    }

    shareContent += `【原文】\n${this.session.originalText}\n\n`;

    if (this.session.translatedText) {
      shareContent += `【译文（AI生成）】\n${this.session.translatedText}`;
    }

    try {
      const sharedData: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.PLAIN_TEXT,
        title: this.session.title,
        content: shareContent
      });

      const controller: systemShare.ShareController = new systemShare.ShareController(sharedData);

      controller.on('dismiss', () => {
        console.info('Share panel closed');
      });

      // UIAbilityContext
      const context = getContext(this) as common.UIAbilityContext;

      controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      }).then(() => {
        console.info('ShareController show success.');
      }).catch((error: BusinessError) => {
        console.error(`ShareController show error. code: ${error.code}, message: ${error.message}`);
        promptAction.showToast({ message: '分享失败: ' + error.message });
      });
    } catch (e) {
      console.error('Share error: ' + JSON.stringify(e));
      promptAction.showToast({ message: '分享失败' });
    }
  }

  async exportFile(type: 'md' | 'txt') {
    if (!this.session) return;

    const exportedAt = new Date().toISOString();
    const metaJson = JSON.stringify({
      voot_ai_generated: true,
      fields: ['summary', 'translation'],
      exported_at: exportedAt
    });
    const metaHeader = type === 'md'
      ? `<!-- VOOT_META ${metaJson} -->\n\n`
      : `VOOT_META ${metaJson}\n\n`;
    
    let content = '';
    if (type === 'md') {
      content = `# ${this.session.title}\n\n`;
      content += `Time: ${new Date(this.session.startTime).toLocaleString()}\n\n`;
      if (this.session.summary) {
        content += `## Summary (AI-generated)\n${this.session.summary}\n\n`;
      }
      content += `## Original\n${this.session.originalText}\n\n`;
      content += `## Translation (AI-generated)\n${this.session.translatedText}\n`;
    } else {
      content = `${this.session.title}\n`;
      content += `Time: ${new Date(this.session.startTime).toLocaleString()}\n\n`;
      if (this.session.summary) {
        content += `SUMMARY (AI-generated):\n${this.session.summary}\n\n`;
      }
      content += `ORIGINAL:\n${this.session.originalText}\n\n`;
      content += `TRANSLATION (AI-generated):\n${this.session.translatedText}\n`;
    }

    content = metaHeader + content;

    try {
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [`${this.session.title}.${type}`];
      const documentViewPicker = new picker.DocumentViewPicker();
      const documentSaveResult = await documentViewPicker.save(documentSaveOptions);
      
      if (documentSaveResult && documentSaveResult.length > 0) {
        const uri = documentSaveResult[0];
        const file = await fs.open(uri, fs.OpenMode.READ_WRITE);
        await fs.write(file.fd, content);
        await fs.close(file.fd);
        promptAction.showToast({ message: '导出成功' });
      }
    } catch (e) {
      promptAction.showToast({ message: '导出失败: ' + JSON.stringify(e) });
    }
  }
}
