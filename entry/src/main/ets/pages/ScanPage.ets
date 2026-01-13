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

import { hdsEffect, HdsNavigation, HdsNavigationTitleMode, HdsNavigationAttribute } from '@kit.UIDesignKit';
import { DocType, DocumentScanner, DocumentScannerConfig, SaveOption, FilterId, ShootingMode } from '@kit.VisionKit';
import promptAction from '@ohos.promptAction';
import http from '@ohos.net.http';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import display from '@ohos.display';
import { textRecognition } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { THEMES } from '../model/Theme';
import { TokenUsageStorage } from '../storage/TokenUsageStorage';
import { HistoryStorage } from '../storage/HistoryStorage';
import router from '@ohos.router';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileUri } from '@kit.CoreFileKit';
import { buffer } from '@kit.ArkTS';

const TITLE_BAR_HEIGHT_MINI: number = 94;

// API相关接口
interface ChatMessage {
  role: string;
  content: string;
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

interface DeepLTranslation {
  text: string;
}

interface DeepLResponse {
  translations: DeepLTranslation[];
}

@Component
export struct ScanPage {
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
  @Prop deepLApiUrl: string = 'https://api-free.deepl.com/v2/translate';
  @Prop deepLApiKey: string = '';
  @Prop ollamaApiUrl: string = 'http://localhost:11434/api/chat';
  @Prop ollamaModel: string = 'llama3';
  @Prop doubaoApiUrl: string = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
  @Prop doubaoApiKey: string = '';
  @Prop doubaoModel: string = 'doubao-pro-32k';
  @Prop targetLanguage: string = 'Chinese';
  @Prop promptText: string = '';
  @Prop isHistoryOpen: boolean = false;
  onOpenHistory: () => void = () => {};

  // 扫描状态
  @State isScanning: boolean = false;
  @State scannedImageUris: string[] = [];
  @State recognizedText: string = '';
  @State translatedText: string = '';
  @State isRecognizing: boolean = false;
  @State isTranslating: boolean = false;
  @State activeBtn: number = 0;
  // 握持弹窗临时关闭状态
  @State isHandPopupDismissed: boolean = false;
  @State currentStep: number = 0; // 0: 初始, 1: 扫描中, 2: 识别结果, 3: 翻译结果
  @State isLandscape: boolean = false;
  @State previewImageUri: string = '';
  
  // 按钮状态
  @State scanBtnScale: number = 1.0;
  @State scanBtnBgColor: ResourceColor = THEMES[this.themeColorIndex].secondaryColor;
  @State scanBtnTextColor: ResourceColor = Color.White;

  @State translateBtnScale: number = 1.0;
  @State translateBtnBgColor: ResourceColor = THEMES[this.themeColorIndex].secondaryColor;
  @State translateBtnTextColor: ResourceColor = Color.White;

  @State shareBtnScale: number = 1.0;
  @State shareBtnBgColor: ResourceColor = Color.White;
  @State shareBtnTextColor: ResourceColor = THEMES[this.themeColorIndex].primaryColor;

  // 文档扫描配置
  private docScanConfig: DocumentScannerConfig | null = null;
  @State isScannerAvailable: boolean = true;

  aboutToAppear() {
    this.scanBtnBgColor = THEMES[this.themeColorIndex].secondaryColor;
    this.translateBtnBgColor = THEMES[this.themeColorIndex].secondaryColor;
    this.shareBtnTextColor = THEMES[this.themeColorIndex].primaryColor;

    // 安全初始化文档扫描器配置
    try {
      this.docScanConfig = new DocumentScannerConfig();
      // 配置文档扫描器
      this.docScanConfig.supportType = [DocType.DOC];
      this.docScanConfig.isGallerySupported = true;
      this.docScanConfig.editTabs = [];
      this.docScanConfig.maxShotCount = 5;
      this.docScanConfig.defaultFilterId = FilterId.ORIGINAL;
      this.docScanConfig.defaultShootingMode = ShootingMode.MANUAL;
      this.docScanConfig.isShareable = false;
      this.docScanConfig.originalUris = [];
      this.isScannerAvailable = true;
    } catch (err) {
      console.error('ScanPage: DocumentScannerConfig not available on this device', err);
      this.isScannerAvailable = false;
    }

    try {
      const displayClass = display.getDefaultDisplaySync();
      // 宽度大于高度，或宽度超过600vp（折叠屏展开/平板竖屏）
      const widthVp = px2vp(displayClass.width);
      this.isLandscape = displayClass.width > displayClass.height || widthVp >= 600;
    } catch (exception) {
      console.error('Failed to obtain the default display object. Code: ' + JSON.stringify(exception));
    }
  }

  onThemeColorChange() {
    this.scanBtnBgColor = THEMES[this.themeColorIndex].secondaryColor;
    this.translateBtnBgColor = THEMES[this.themeColorIndex].secondaryColor;
    this.shareBtnTextColor = THEMES[this.themeColorIndex].primaryColor;
  }

  onVisibleChange() {
    // 切换页面时重置握持弹窗临时关闭状态
    if (this.isVisible) {
      this.isHandPopupDismissed = false;
    }
  }
  
  // 开始扫描
  startScan() {
    if (!this.isScannerAvailable || !this.docScanConfig) {
      promptAction.showToast({ message: '文档扫描功能在模拟器设备上不可用' });
      return;
    }
    this.isScanning = true;
    this.currentStep = 1;
    this.scannedImageUris = [];
    this.recognizedText = '';
    this.translatedText = '';
  }

  // 处理扫描结果
  async handleScanResult(code: number, saveType: SaveOption, uris: string[]) {
    console.info(`[ScanPage] Scan result code: ${code}, saveType: ${saveType}, uris count: ${uris.length}`);

    if (code === -1) {
      // 用户取消
      this.isScanning = false;
      this.currentStep = 0;
      return;
    }

    if (uris.length > 0) {
      this.scannedImageUris = uris;
      this.isScanning = false;

      // 自动开始OCR识别
      await this.recognizeText();
    } else {
      this.isScanning = false;
      this.currentStep = 0;
      promptAction.showToast({ message: '未获取到扫描图片' });
    }
  }

  // OCR 文字识别
  async recognizeText() {
    if (this.scannedImageUris.length === 0) {
      promptAction.showToast({ message: '请先扫描文档' });
      return;
    }

    this.isRecognizing = true;
    this.currentStep = 2;
    let allText = '';

    try {
      for (const uri of this.scannedImageUris) {
        console.info(`[ScanPage] Recognizing text from: ${uri}`);

        // 从文件 URI 加载图片
        const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
        const imageSource = image.createImageSource(file.fd);
        const pixelMap = await imageSource.createPixelMap();
        fs.closeSync(file);

        // 使用 CoreVisionKit 进行文字识别
        const visionInfo: textRecognition.VisionInfo = {
          pixelMap: pixelMap
        };

        const result = await textRecognition.recognizeText(visionInfo, {
          isDirectionDetectionSupported: true
        });

        // 释放 pixelMap
        pixelMap.release();

        if (result && result.value) {
          allText += result.value + '\n\n';
        }
      }

      this.recognizedText = allText.trim();

      if (this.recognizedText.length === 0) {
        promptAction.showToast({ message: '未识别到文字' });
      } else {
        promptAction.showToast({ message: `识别完成，共 ${this.recognizedText.length} 字` });
      }
    } catch (error) {
      console.error('[ScanPage] OCR error: ' + JSON.stringify(error));
      promptAction.showToast({ message: 'OCR识别失败' });
    } finally {
      this.isRecognizing = false;
    }
  }

  // 翻译识别的文字
  async translateText() {
    if (!this.recognizedText.trim()) {
      promptAction.showToast({ message: '没有可翻译的文字' });
      return;
    }

    this.isTranslating = true;
    this.currentStep = 3;

    try {
      const systemPrompt = this.promptText.replace('{0}', this.targetLanguage) ||
        `Translate the following text to ${this.targetLanguage}. Output only the translation, no explanations.`;

      let translatedResult = '';

      if (this.selectedApiIndex === 1) {
        // DeepL
        translatedResult = await this.callDeepL(this.recognizedText);
      } else if (this.selectedApiIndex === 0) {
        // OpenAI
        translatedResult = await this.callOpenAI({
          apiUrl: this.openAiApiUrl,
          apiKey: this.openAiApiKey,
          model: this.openAiModel
        }, systemPrompt, this.recognizedText);
      } else if (this.selectedApiIndex === 2) {
        // Ollama
        translatedResult = await this.callOllama({
          apiUrl: this.ollamaApiUrl,
          model: this.ollamaModel
        }, systemPrompt, this.recognizedText);
      } else if (this.selectedApiIndex === 3) {
        // Doubao
        translatedResult = await this.callDoubao({
          apiUrl: this.doubaoApiUrl,
          apiKey: this.doubaoApiKey,
          model: this.doubaoModel
        }, systemPrompt, this.recognizedText);
      }

      this.translatedText = translatedResult;
      
      // 保存到历史记录
      this.saveToHistory();
      
      promptAction.showToast({ message: '翻译完成' });
    } catch (error) {
      const errorMsg = (error instanceof Error) ? error.message : String(error);
      console.error('[ScanPage] Translation error: ' + errorMsg);
      promptAction.showToast({ message: '翻译失败: ' + errorMsg });
    } finally {
      this.isTranslating = false;
    }
  }

  // 保存到历史记录
  async saveToHistory() {
    if (!this.recognizedText || !this.translatedText) return;

    try {
      let savedImageUri = '';
      // 如果有图片，保存第一张图片到应用沙箱
      if (this.scannedImageUris.length > 0) {
        const srcUri = this.scannedImageUris[0];
        const context = getContext(this) as common.UIAbilityContext;
        const filesDir = context.filesDir;
        const fileName = `scan_${Date.now()}.jpg`;
        const destPath = `${filesDir}/${fileName}`;
        const destUri = `file://${destPath}`;

        // 复制文件
        const srcFile = fs.openSync(srcUri, fs.OpenMode.READ_ONLY);
        const destFile = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        
        const bufSize = 4096;
        const buffer = new ArrayBuffer(bufSize);
        let len = 0;
        let position = 0;
        
        while ((len = fs.readSync(srcFile.fd, buffer, { offset: position })) > 0) {
          fs.writeSync(destFile.fd, buffer, { length: len });
          position += len;
        }
        
        fs.closeSync(srcFile);
        fs.closeSync(destFile);
        
        savedImageUri = destUri;
      }

      await HistoryStorage.getInstance().createScanSession(
        this.recognizedText.substring(0, 20) + (this.recognizedText.length > 20 ? '...' : ''),
        this.recognizedText,
        this.translatedText,
        savedImageUri
      );
    } catch (error) {
      console.error('[ScanPage] Save history error: ' + JSON.stringify(error));
    }
  }

  // DeepL 翻译
  async callDeepL(text: string): Promise<string> {
    const httpRequest = http.createHttp();
    const targetLangMap: Record<string, string> = {
      'Chinese': 'ZH',
      'English': 'EN',
      'Spanish': 'ES',
      'French': 'FR',
      'Japanese': 'JA'
    };

    // 检查 API Key 是否配置
    if (!this.deepLApiKey || this.deepLApiKey.trim() === '') {
      throw new Error('DeepL API Key 未配置，请在配置页面设置');
    }

    const apiUrl = this.deepLApiUrl || 'https://api-free.deepl.com/v2/translate';
    const targetLang = targetLangMap[this.targetLanguage] || 'ZH';

    console.info(`[ScanPage] DeepL request - URL: ${apiUrl}, targetLang: ${targetLang}`);

    try {
      const response = await httpRequest.request(apiUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `DeepL-Auth-Key ${this.deepLApiKey}`
        },
        extraData: JSON.stringify({
          text: [text],
          target_lang: targetLang
        }),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000
      });

      console.info(`[ScanPage] DeepL response code: ${response.responseCode}`);

      if (response.responseCode === 200) {
        const resultStr = response.result as string;
        console.info(`[ScanPage] DeepL response: ${resultStr.substring(0, 200)}`);
        const data = JSON.parse(resultStr) as DeepLResponse;
        if (data.translations && data.translations.length > 0) {
          return data.translations[0].text || '';
        }
        throw new Error('DeepL 返回空翻译结果');
      } else if (response.responseCode === 403) {
        throw new Error('DeepL API Key 无效或已过期');
      } else if (response.responseCode === 429) {
        throw new Error('DeepL 请求过于频繁，请稍后再试');
      } else if (response.responseCode === 456) {
        throw new Error('DeepL 配额已用尽');
      } else {
        const errorBody = response.result as string;
        console.error(`[ScanPage] DeepL error response: ${errorBody}`);
        throw new Error(`DeepL HTTP ${response.responseCode}`);
      }
    } finally {
      httpRequest.destroy();
    }
  }

  // OpenAI 翻译
  async callOpenAI(config: LlmConfig, systemPrompt: string, userMessage: string): Promise<string> {
    const httpRequest = http.createHttp();
    const url = config.apiUrl || 'https://api.openai.com/v1/chat/completions';

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
            { role: 'system', content: systemPrompt } as ChatMessage,
            { role: 'user', content: userMessage } as ChatMessage
          ],
          stream: false
        }),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000
      });

      if (response.responseCode === 200) {
        const data = JSON.parse(response.result as string) as ChatCompletionResponse;
        if (data.usage && data.usage.total_tokens > 0) {
          TokenUsageStorage.getInstance().addTokenUsage('OpenAI', data.usage.total_tokens);
        }
        return data.choices[0]?.message?.content || '';
      }
      throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
    } finally {
      httpRequest.destroy();
    }
  }

  // Ollama 翻译
  async callOllama(config: LlmConfig, systemPrompt: string, userMessage: string): Promise<string> {
    const httpRequest = http.createHttp();
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
        if (data.eval_count || data.prompt_eval_count) {
          const totalTokens = (data.eval_count || 0) + (data.prompt_eval_count || 0);
          TokenUsageStorage.getInstance().addTokenUsage('Ollama', totalTokens);
        }
        return data.message?.content || '';
      }
      throw new Error(`HTTP ${response.responseCode}`);
    } finally {
      httpRequest.destroy();
    }
  }

  // Doubao 翻译
  async callDoubao(config: LlmConfig, systemPrompt: string, userMessage: string): Promise<string> {
    const httpRequest = http.createHttp();
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
        if (data.usage && data.usage.total_tokens > 0) {
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
    if (!this.translatedText && !this.recognizedText) {
      promptAction.showToast({ message: '暂无内容可分享' });
      return;
    }

    const shareContent = this.translatedText
      ? `【原文】\n${this.recognizedText}\n\n【译文】\n${this.translatedText}\n\n—— 由 AI 生成`
      : `【识别文本】\n${this.recognizedText}`;

    try {
      const sharedData: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.PLAIN_TEXT,
        title: '扫描翻译结果',
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
        this.scanBtnScale = 0.95;
        this.scanBtnBgColor = Color.White;
        this.scanBtnTextColor = THEMES[this.themeColorIndex].primaryColor;
      }
      if (btnId === 2) {
        this.translateBtnScale = 0.95;
        this.translateBtnBgColor = Color.White;
        this.translateBtnTextColor = THEMES[this.themeColorIndex].primaryColor;
      }
      if (btnId === 3) {
        this.shareBtnScale = 0.95;
        this.shareBtnBgColor = THEMES[this.themeColorIndex].primaryColor;
        this.shareBtnTextColor = Color.White;
      }
    });
  }

  releaseButton(btnId: number) {
    animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
      if (btnId === 1) {
        this.scanBtnScale = 1.0;
        this.scanBtnBgColor = THEMES[this.themeColorIndex].secondaryColor;
        this.scanBtnTextColor = Color.White;
      }
      if (btnId === 2) {
        this.translateBtnScale = 1.0;
        this.translateBtnBgColor = THEMES[this.themeColorIndex].secondaryColor;
        this.translateBtnTextColor = Color.White;
      }
      if (btnId === 3) {
        this.shareBtnScale = 1.0;
        this.shareBtnBgColor = Color.White;
        this.shareBtnTextColor = THEMES[this.themeColorIndex].primaryColor;
      }
    });
  }

  async saveToGallery(uri: string) {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
      const bundleName = context.applicationInfo.name;
      
      let srcFilePath: string;
      let srcFileUri: string;
      
      // Check if the URI is already in the sandbox files directory
      if (uri.includes('/files/scan_') || uri.includes(context.filesDir)) {
        // Already saved in sandbox, extract path
        if (uri.startsWith('file://')) {
          srcFilePath = uri.replace(/^file:\/\/[^/]*/, '');
        } else {
          srcFilePath = uri;
        }
        srcFileUri = `file://${bundleName}${srcFilePath}`;
      } else {
        // Temporary URI from DocumentScanner, need to copy to sandbox first
        const timestamp = new Date().getTime();
        const destPath = `${context.filesDir}/temp_save_${timestamp}.jpg`;
        
        // Copy the image to sandbox
        const srcFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
        const destFile = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        const fileStat = fs.statSync(srcFile.fd);
        const buf = new ArrayBuffer(fileStat.size);
        fs.readSync(srcFile.fd, buf);
        fs.writeSync(destFile.fd, buf);
        fs.closeSync(srcFile);
        fs.closeSync(destFile);
        
        srcFilePath = destPath;
        srcFileUri = `file://${bundleName}${destPath}`;
      }
      
      const srcFileUris: Array<string> = [srcFileUri];
      
      console.info('srcFileUri: ' + srcFileUri);
      
      const photoCreationConfigs: Array<photoAccessHelper.PhotoCreationConfig> = [
        {
          title: `scan_${new Date().getTime()}`,
          fileNameExtension: 'jpg',
          photoType: photoAccessHelper.PhotoType.IMAGE,
        }
      ];
      
      const desFileUris: Array<string> = await phAccessHelper.showAssetsCreationDialog(srcFileUris, photoCreationConfigs);
      
      if (desFileUris.length > 0) {
        const desFile = fs.openSync(desFileUris[0], fs.OpenMode.WRITE_ONLY);
        const srcFile = fs.openSync(srcFilePath, fs.OpenMode.READ_ONLY);
        
        // Read from source
        const fileStat = fs.statSync(srcFile.fd);
        const buf = new ArrayBuffer(fileStat.size);
        fs.readSync(srcFile.fd, buf);
        
        // Write to dest
        fs.writeSync(desFile.fd, buf);
        
        fs.closeSync(srcFile);
        fs.closeSync(desFile);
        promptAction.showToast({ message: '已保存到相册' });
      }
    } catch (error) {
      console.error('Save image failed:', JSON.stringify(error));
      promptAction.showToast({ message: '保存失败: ' + JSON.stringify(error) });
    }
  }

  @Builder
  ImagePreviewOverlay() {
    if (this.previewImageUri) {
      Stack() {
        // Background mask
        Rect()
          .width('100%')
          .height('100%')
          .fill(Color.Black)
          .opacity(0.9)
          .onClick(() => {
            animateTo({ duration: 200 }, () => {
              this.previewImageUri = '';
            })
          })

        // Image
        Image(this.previewImageUri)
          .objectFit(ImageFit.Contain)
          .width('100%')
          .height('100%')
          .onClick(() => {
            animateTo({ duration: 200 }, () => {
              this.previewImageUri = '';
            })
          })

        // Save button
        Column() {
          SymbolGlyph($r('sys.symbol.save'))
            .fontSize(20)
            .fontColor([Color.White])
        }
        .position({ x: '70%', y: 60 })
        .onClick(() => {
          this.saveToGallery(this.previewImageUri);
        })

        // Close button
        Column() {
          SymbolGlyph($r('sys.symbol.xmark_circle'))
            .fontSize(20)
            .fontColor([Color.White])
        }
        .position({ x: '85%', y: 60 })
        .onClick(() => {
          animateTo({ duration: 200 }, () => {
            this.previewImageUri = '';
          })
        })
      }
      .width('100%')
      .height('100%')
      .zIndex(9999)
      .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
    }
  }

  @Builder
  ScannerView() {
    Column() {
      if (this.isScannerAvailable && this.docScanConfig) {
        DocumentScanner({
          scannerConfig: this.docScanConfig,
          onResult: (code: number, saveType: SaveOption, uris: string[]) => {
            this.handleScanResult(code, saveType, uris);
          }
        })
          .width('100%')
          .height('100%')
      } else {
        Column() {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
            .fontSize(48)
            .fontColor([Color.White])
            .margin({ bottom: 16 })
          Text('文档扫描功能不可用')
            .fontSize(18)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 8 })
          Text('模拟器设备不支持文档扫描功能')
            .fontSize(14)
            .fontColor($r('sys.color.font_on_secondary'))
            .textAlign(TextAlign.Center)
            .margin({ bottom: 24 })
          Button('返回')
            .type(ButtonType.Capsule)
            .backgroundColor(THEMES[this.themeColorIndex].primaryColor)
            .onClick(() => {
              this.isScanning = false;
              this.currentStep = 0;
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  RecognizedTextPanel() {
    Column() {
      Row() {
        Text('识别文本')
          .fontSize(13)
          .fontColor($r('sys.color.font_on_secondary'))
          .fontWeight(FontWeight.Medium)

        Blank()

        if (this.isRecognizing) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color($r('sys.color.font_on_secondary'))
        } else if (this.recognizedText.length > 0) {
          Text(`${this.recognizedText.length} 字`)
            .fontSize(12)
            .fontColor($r('sys.color.font_on_secondary'))
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Scroll() {
        Text(this.recognizedText || '正在识别文字...')
          .fontSize(15)
          .fontColor(this.recognizedText ? Color.White : $r('sys.color.font_on_secondary'))
          .lineHeight(24)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width(this.isLandscape ? '45%' : '100%')
    .layoutWeight(1)
    .backgroundColor(THEMES[this.themeColorIndex].secondaryColor)
    .borderRadius(24)
    .margin(this.isLandscape ? { bottom: 0 } : { bottom: 12 })
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
  TranslatedTextPanel() {
    Column() {
      Row() {
        Text('翻译结果')
          .fontSize(13)
          .fontColor($r('sys.color.font_on_secondary'))
          .fontWeight(FontWeight.Medium)

        Blank()

        if (this.isTranslating) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color($r('sys.color.font_on_secondary'))
        } else if (this.translatedText.length > 0) {
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

      Scroll() {
        Text(this.translatedText || '点击下方翻译按钮开始翻译...')
          .fontSize(15)
          .fontColor(this.translatedText ? Color.White : $r('sys.color.font_on_secondary'))
          .lineHeight(24)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width(this.isLandscape ? '45%' : '100%')
    .layoutWeight(1)
    .backgroundColor(THEMES[this.themeColorIndex].secondaryColor)
    .borderRadius(24)
    .margin(this.isLandscape ? { bottom: 0 } : { bottom: 12 })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
          (this.activeBtn === 5
            ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
            : hdsEffect.PointLightSourceType.NONE),
        illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
      })
      .buildEffect())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 5; });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
      }
    })
  }

  @Builder
  OperationBar() {
    Flex({
      direction: FlexDirection.Column,
      justifyContent: FlexAlign.Center,
      alignItems: ItemAlign.Center
    }) {
      // 重新扫描按钮
      Row() {
        SymbolGlyph($r('sys.symbol.camera'))
          .fontSize(18)
          .fontColor([this.scanBtnTextColor])
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.scanBtnBgColor)
      .borderRadius(22)
      .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
      .scale({ x: this.scanBtnScale, y: this.scanBtnScale })
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
        this.startScan();
      })

      Blank().height(12)

      // 翻译按钮
      Row() {
        if (this.isTranslating) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(this.translateBtnTextColor)
        } else {
          SymbolGlyph($r('sys.symbol.translate'))
            .fontSize(18)
            .fontColor([this.translateBtnTextColor])
        }
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.translateBtnBgColor)
      .borderRadius(22)
      .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
      .scale({ x: this.translateBtnScale, y: this.translateBtnScale })
      .enabled(!this.isTranslating && this.recognizedText.length > 0)
      .opacity((!this.isTranslating && this.recognizedText.length > 0) ? 1.0 : 0.5)
      .visualEffect(new hdsEffect.HdsEffectBuilder()
        .pointLight({
          sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
            (this.activeBtn === 2
            ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
            : hdsEffect.PointLightSourceType.NONE),
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
        this.translateText();
      })

      Blank().height(12)

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
      .enabled(this.recognizedText.length > 0 || this.translatedText.length > 0)
      .opacity((this.recognizedText.length > 0 || this.translatedText.length > 0) ? 1.0 : 0.5)
      .visualEffect(new hdsEffect.HdsEffectBuilder()
        .pointLight({
          sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
            (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT),
          illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
        })
        .buildEffect())
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 3; });
          this.pressButton(3);
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
          this.releaseButton(3);
        }
      })
      .onClick(() => {
        this.shareResult();
      })
    }
    .height('100%')
    .padding(12)
    .backgroundColor(Color.Transparent)
  }

  @Builder
  ResultView() {
    Column() {
      Blank().height(TITLE_BAR_HEIGHT_MINI)

      // 扫描的图片预览
      if (this.scannedImageUris.length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.scannedImageUris, (uri: string, index: number) => {
              Image(uri)
                .width(80)
                .height(100)
                .objectFit(ImageFit.Cover)
                .borderRadius(12)
                .shadow({ radius: 4, color: 'rgba(0,0,0,0.2)', offsetY: 2 })
                .onClick(() => {
                  animateTo({ duration: 200 }, () => {
                    this.previewImageUri = uri;
                  })
                })
            })
          }
          .padding({ left: 16, right: 16 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(120)
        .margin({ bottom: 16 })
      }

      // 文本区域和操作按钮
      if (this.isLandscape) {
        // 横向布局：左文本框-中间圆形按钮-右文本框
        Row({ space: 0 }) {
          this.RecognizedTextPanel()
          this.OperationBar()
          this.TranslatedTextPanel()
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 10, right: 10, bottom: 70 })
      } else {
        // 纵向布局
        Column() {
          this.RecognizedTextPanel()
          this.TranslatedTextPanel()
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })

        // 底部操作按钮（仅纵向布局）
        Row({ space: 12 }) {
          // 重新扫描
          Row() {
            SymbolGlyph($r('sys.symbol.camera'))
              .fontSize(18)
              .fontColor([this.scanBtnTextColor])
            Text('重新扫描')
              .fontSize(14)
              .fontColor(this.scanBtnTextColor)
              .fontWeight(FontWeight.Medium)
              .margin({ left: 6 })
          }
          .height(44)
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.scanBtnBgColor)
          .borderRadius(22)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
          .scale({ x: this.scanBtnScale, y: this.scanBtnScale })
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
              this.activeBtn = 1;
              this.pressButton(1);
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.activeBtn = 0;
              this.releaseButton(1);
            }
          })
          .onClick(() => {
            this.startScan();
          })

          // 翻译按钮
          Row() {
            if (this.isTranslating) {
              LoadingProgress()
                .width(18)
                .height(18)
                .color(this.translateBtnTextColor)
            } else {
              SymbolGlyph($r('sys.symbol.translate'))
                .fontSize(18)
                .fontColor([this.translateBtnTextColor])
            }
            Text(this.isTranslating ? '翻译中...' : '翻译')
              .fontSize(14)
              .fontColor(this.translateBtnTextColor)
              .fontWeight(FontWeight.Medium)
              .margin({ left: 6 })
          }
          .height(44)
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.translateBtnBgColor)
          .borderRadius(22)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
          .scale({ x: this.translateBtnScale, y: this.translateBtnScale })
          .enabled(!this.isTranslating && this.recognizedText.length > 0)
          .opacity((!this.isTranslating && this.recognizedText.length > 0) ? 1.0 : 0.5)
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
                (this.activeBtn === 2
                  ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
                  : hdsEffect.PointLightSourceType.NONE),
              illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            })
            .buildEffect())
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.activeBtn = 2;
              this.pressButton(2);
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.activeBtn = 0;
              this.releaseButton(2);
            }
          })
          .onClick(() => {
            this.translateText();
          })

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
          .enabled(this.recognizedText.length > 0 || this.translatedText.length > 0)
          .opacity((this.recognizedText.length > 0 || this.translatedText.length > 0) ? 1.0 : 0.5)
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              sourceType: (this.isDarkMode || this.isHistoryOpen) ? hdsEffect.PointLightSourceType.NONE :
                (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT),
              illuminatedType: (this.isDarkMode || this.isHistoryOpen) ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            })
            .buildEffect())
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.activeBtn = 3;
              this.pressButton(3);
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.activeBtn = 0;
              this.releaseButton(3);
            }
          })
          .onClick(() => {
            this.shareResult();
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 70 })
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((oldArea: Area, newArea: Area) => {
      const width = newArea.width as number;
      const height = newArea.height as number;
      // 宽度大于高度，或宽度超过600vp（折叠屏展开/平板竖屏）
      this.isLandscape = width > height || width >= 600;
    })
  }

  @Builder
  InitialView() {
    Column() {
      Blank().height(TITLE_BAR_HEIGHT_MINI)

      Column() {
        SymbolGlyph($r('sys.symbol.camera'))
          .fontSize(80)
          .fontColor([$r('sys.color.icon_on_primary')])
          .margin({ bottom: 24 })

        Text('扫描文档')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ bottom: 12 })

        Text('拍摄或选择文档图片，自动识别文字并翻译')
          .fontSize(14)
          .fontColor($r('sys.color.font_on_secondary'))
          .textAlign(TextAlign.Center)
          .margin({ bottom: 40 })

        Row() {
          SymbolGlyph($r('sys.symbol.camera'))
            .fontSize(20)
            .fontColor([this.scanBtnTextColor])
          Text('开始扫描')
            .fontSize(16)
            .fontColor(this.scanBtnTextColor)
            .fontWeight(FontWeight.Medium)
            .margin({ left: 8 })
        }
        .height(52)
        .padding({ left: 32, right: 32 })
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.scanBtnBgColor)
        .borderRadius(26)
        .shadow({ radius: 12, color: 'rgba(0,0,0,0.3)', offsetY: 6 })
        .scale({ x: this.scanBtnScale, y: this.scanBtnScale })
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .pointLight({
            sourceType: (this.isDarkMode || this.isHistoryOpen) ? hdsEffect.PointLightSourceType.NONE :
              (this.activeBtn === 1
                ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
                : hdsEffect.PointLightSourceType.NONE),
            illuminatedType: (this.isDarkMode || this.isHistoryOpen) ? hdsEffect.PointLightIlluminatedType.NONE : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
          })
          .buildEffect())
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.activeBtn = 1;
            this.pressButton(1);
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.activeBtn = 0;
            this.releaseButton(1);
          }
        })
        .onClick(() => {
          this.startScan();
        })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 32, right: 32, bottom: 100 })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      if (this.isScanning) {
        // 扫描视图
        this.ScannerView()
      } else if (this.scannedImageUris.length > 0) {
        // 结果视图
        HdsNavigation() {
          this.ResultView()
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
              mainTitle: '扫描'
            },
            menu: {
              value: [
                {
                  content: {
                    label: '历史',
                    icon: $r('sys.symbol.clock_arrow_2_circlepath'),
                    isEnabled: true,
                    action: () => {
                      this.onOpenHistory();
                    }
                  }
                }
              ]
            }
          },
          avoidLayoutSafeArea: true
        })
      } else {
        // 初始视图
        HdsNavigation() {
          this.InitialView()
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
                backgroundColor: Color.Transparent,
              },
              contentStyle: {
                titleStyle: {
                  mainTitleColor: Color.White,
                },
                menuStyle: {
                  backgroundColor: $r('sys.color.comp_background_tertiary'),
                  iconColor: Color.White
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
              mainTitle: '扫描'
            },
            menu: {
              value: [
                {
                  content: {
                    label: '历史',
                    icon: $r('sys.symbol.clock_arrow_2_circlepath'),
                    isEnabled: true,
                    action: () => {
                      this.onOpenHistory();
                    }
                  }
                }
              ]
            }
          },
          avoidLayoutSafeArea: true
        })
      }

      // 侧边悬浮按钮 - 无扫描结果时只显示开始扫描
      if ((this.isLeftHand || this.isRightHand) && this.recognizedText.length === 0 && !this.isHandPopupDismissed) {
        Column({ space: 16 }) {
          // 开始扫描按钮
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.camera'))
              .fontSize(24)
              .fontColor((this.activeBtn === 1 || this.activeBtn === 11) ? [THEMES[this.themeColorIndex].primaryColor] : [this.scanBtnTextColor])
          }
          .width(48)
          .height(48)
          .backgroundColor((this.activeBtn === 1 || this.activeBtn === 11) ? Color.White : this.scanBtnBgColor)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
          .stateStyles({
            pressed: {
              .scale({ x: 0.95, y: 0.95 })
            },
            normal: {
              .scale({ x: 1.0, y: 1.0 })
            }
          })
          .onClick(() => {
            this.startScan();
          })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 11; });
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
        .border({ width: 1.5, color: THEMES[this.themeColorIndex].tertiaryColor })
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

      // 侧边悬浮按钮 - 有扫描结果时显示三个按钮
      if ((this.isLeftHand || this.isRightHand) && this.recognizedText.length > 0 && !this.isHandPopupDismissed) {
        Column({ space: 16 }) {
           // 重新扫描按钮
          Button({ type: ButtonType.Circle }) {
             SymbolGlyph($r('sys.symbol.camera'))
              .fontSize(24)
              .fontColor((this.activeBtn === 1 || this.activeBtn === 11) ? [THEMES[this.themeColorIndex].primaryColor] : [this.scanBtnTextColor])
          }
          .width(48)
          .height(48)
          .backgroundColor((this.activeBtn === 1 || this.activeBtn === 11) ? Color.White : this.scanBtnBgColor)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
          .stateStyles({
            pressed: {
              .scale({ x: 0.95, y: 0.95 })
            },
            normal: {
              .scale({ x: 1.0, y: 1.0 })
            }
          })
          .onClick(() => {
            this.startScan();
          })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 11; });
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
            }
          })

          // 翻译按钮
          Button({ type: ButtonType.Circle }) {
            if (this.isTranslating) {
                LoadingProgress()
                .width(24)
                .height(24)
                .color((this.activeBtn === 2 || this.activeBtn === 12) ? THEMES[this.themeColorIndex].primaryColor : this.translateBtnTextColor)
            } else {
                SymbolGlyph($r('sys.symbol.translate'))
                  .fontSize(24)
                  .fontColor((this.activeBtn === 2 || this.activeBtn === 12) ? [THEMES[this.themeColorIndex].primaryColor] : [this.translateBtnTextColor])
            }
          }
          .width(48)
          .height(48)
          .backgroundColor((this.activeBtn === 2 || this.activeBtn === 12) ? Color.White : this.translateBtnBgColor)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
          .stateStyles({
            pressed: {
              .scale({ x: 0.95, y: 0.95 })
            },
            normal: {
              .scale({ x: 1.0, y: 1.0 })
            }
          })
          .enabled(!this.isTranslating)
          .opacity(!this.isTranslating ? 1.0 : 0.5)
          .onClick(() => {
            this.translateText();
          })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 12; });
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
            }
          })

          // 分享按钮
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.share'))
              .fontSize(24)
              .fontColor((this.activeBtn === 3 || this.activeBtn === 13) ? [Color.White] : [this.shareBtnTextColor])
          }
          .width(48)
          .height(48)
          .backgroundColor((this.activeBtn === 3 || this.activeBtn === 13) ? THEMES[this.themeColorIndex].primaryColor : this.shareBtnBgColor)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
          .stateStyles({
            pressed: {
              .scale({ x: 0.95, y: 0.95 })
            },
            normal: {
              .scale({ x: 1.0, y: 1.0 })
            }
          })
          .onClick(() => {
            this.shareResult();
          })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = 13; });
              this.pressButton(3);
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
              this.releaseButton(3);
            }
          })
        }
        .width(64)
        .padding(8)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .border({ width: 1.5, color: THEMES[this.themeColorIndex].tertiaryColor })
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
      
      this.ImagePreviewOverlay()
    }
    .width('100%')
    .height('100%')
  }
}
