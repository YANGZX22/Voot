import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';

/**
 * ASR 模型类型枚举
 */
export enum AsrModelType {
  MOONSHINE_EN = 'moonshine_en',           // Moonshine 英语模型（内置）
  SENSE_VOICE_MULTI = 'sense_voice_multi'  // SenseVoice 多语言模型（需下载）
}

/**
 * ASR 模型信息
 */
export interface AsrModelInfo {
  type: AsrModelType;
  name: string;                    // 显示名称
  languages: string[];             // 支持的语言代码
  languageDisplayNames: string[];  // 支持的语言显示名称
  isBuiltin: boolean;              // 是否内置
  downloadUrl: string;             // 下载 URL（如果需要下载）
  folderName: string;              // rawfile 中的文件夹名
  fileSizeMB: number;              // 文件大小（MB）
}

/**
 * ASR 模型配置
 */
export interface AsrModelConfig {
  currentModel: AsrModelType;             // 当前使用的模型
  senseVoiceDownloaded: boolean;          // SenseVoice 模型是否已下载
  selectedSourceLanguage: string;         // 选中的原始语言代码
}

/**
 * 预定义的 ASR 模型信息
 */
export const ASR_MODELS: Record<AsrModelType, AsrModelInfo> = {
  [AsrModelType.MOONSHINE_EN]: {
    type: AsrModelType.MOONSHINE_EN,
    name: 'Moonshine (英语)',
    languages: ['en'],
    languageDisplayNames: ['英语'],
    isBuiltin: true,
    downloadUrl: '',
    folderName: 'sherpa-onnx-moonshine-tiny-en-int8',
    fileSizeMB: 0
  },
  [AsrModelType.SENSE_VOICE_MULTI]: {
    type: AsrModelType.SENSE_VOICE_MULTI,
    name: 'SenseVoice (中英日韩粤)',
    languages: ['zh', 'en', 'ja', 'ko', 'yue'],
    languageDisplayNames: ['中文', '英语', '日语', '韩语', '粤语'],
    isBuiltin: false,
    downloadUrl: 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17.tar.bz2',
    folderName: 'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17',
    fileSizeMB: 228
  }
};

/**
 * 根据语言代码获取显示名称
 */
export function getLanguageDisplayName(langCode: string): string {
  const langMap: Record<string, string> = {
    'zh': '中文',
    'en': '英语',
    'ja': '日语',
    'ko': '韩语',
    'yue': '粤语'
  };
  return langMap[langCode] ?? langCode;
}

/**
 * 原始语言选项结果
 */
export interface SourceLanguageResult {
  codes: string[];
  displays: string[];
}

/**
 * 获取当前可用的原始语言选项
 */
export function getAvailableSourceLanguages(config: AsrModelConfig): SourceLanguageResult {
  const result: SourceLanguageResult = {
    codes: [],
    displays: []
  };
  if (config.senseVoiceDownloaded && config.currentModel === AsrModelType.SENSE_VOICE_MULTI) {
    result.codes = ASR_MODELS[AsrModelType.SENSE_VOICE_MULTI].languages;
    result.displays = ASR_MODELS[AsrModelType.SENSE_VOICE_MULTI].languageDisplayNames;
  } else {
    result.codes = ASR_MODELS[AsrModelType.MOONSHINE_EN].languages;
    result.displays = ASR_MODELS[AsrModelType.MOONSHINE_EN].languageDisplayNames;
  }
  return result;
}

/**
 * ASR 模型存储管理类
 */
export class AsrModelStorage {
  private static readonly PREF_FILE: string = 'voot_asr_model';
  private static readonly CONFIG_KEY: string = 'asr_model_config';
  private static prefs: preferences.Preferences | undefined;

  private static async getPrefs(ctx: common.UIAbilityContext): Promise<preferences.Preferences> {
    if (!AsrModelStorage.prefs) {
      AsrModelStorage.prefs = await preferences.getPreferences(ctx, AsrModelStorage.PREF_FILE);
    }
    return AsrModelStorage.prefs as preferences.Preferences;
  }

  /**
   * 获取默认配置
   */
  static getDefaultConfig(): AsrModelConfig {
    return {
      currentModel: AsrModelType.MOONSHINE_EN,
      senseVoiceDownloaded: false,
      selectedSourceLanguage: 'en'
    };
  }

  /**
   * 加载 ASR 模型配置
   */
  static async loadConfig(ctx: common.UIAbilityContext): Promise<AsrModelConfig> {
    const prefs = await AsrModelStorage.getPrefs(ctx);
    const serialized = await prefs.get(AsrModelStorage.CONFIG_KEY, '') as string;

    if (!serialized || serialized.length === 0) {
      const defaultConfig = AsrModelStorage.getDefaultConfig();
      await AsrModelStorage.saveConfig(ctx, defaultConfig);
      return defaultConfig;
    }

    try {
      const config = JSON.parse(serialized) as AsrModelConfig;
      // 验证配置有效性
      if (!config.currentModel) {
        config.currentModel = AsrModelType.MOONSHINE_EN;
      }
      if (config.selectedSourceLanguage === undefined) {
        config.selectedSourceLanguage = 'en';
      }
      return config;
    } catch (e) {
      console.error('[AsrModelStorage] Failed to parse config: ' + JSON.stringify(e));
      const defaultConfig = AsrModelStorage.getDefaultConfig();
      await AsrModelStorage.saveConfig(ctx, defaultConfig);
      return defaultConfig;
    }
  }

  /**
   * 保存 ASR 模型配置
   */
  static async saveConfig(ctx: common.UIAbilityContext, config: AsrModelConfig): Promise<void> {
    const prefs = await AsrModelStorage.getPrefs(ctx);
    await prefs.put(AsrModelStorage.CONFIG_KEY, JSON.stringify(config));
    await prefs.flush();
  }

  /**
   * 设置 SenseVoice 模型下载状态
   */
  static async setSenseVoiceDownloaded(ctx: common.UIAbilityContext, downloaded: boolean): Promise<void> {
    const config = await AsrModelStorage.loadConfig(ctx);
    config.senseVoiceDownloaded = downloaded;
    if (downloaded && config.currentModel === AsrModelType.MOONSHINE_EN) {
      // 下载完成后自动切换到多语言模型
      config.currentModel = AsrModelType.SENSE_VOICE_MULTI;
    }
    await AsrModelStorage.saveConfig(ctx, config);
  }

  /**
   * 设置当前使用的模型
   */
  static async setCurrentModel(ctx: common.UIAbilityContext, model: AsrModelType): Promise<void> {
    const config = await AsrModelStorage.loadConfig(ctx);
    config.currentModel = model;
    await AsrModelStorage.saveConfig(ctx, config);
  }

  /**
   * 设置选中的原始语言
   */
  static async setSelectedSourceLanguage(ctx: common.UIAbilityContext, langCode: string): Promise<void> {
    const config = await AsrModelStorage.loadConfig(ctx);
    config.selectedSourceLanguage = langCode;
    await AsrModelStorage.saveConfig(ctx, config);
  }

  /**
   * 检查 SenseVoice 模型文件是否存在
   * 优先检查下载目录（filesDir），然后检查 rawfile
   */
  static async checkSenseVoiceModelExists(ctx: common.UIAbilityContext): Promise<boolean> {
    const modelFolder = ASR_MODELS[AsrModelType.SENSE_VOICE_MULTI].folderName;
    
    // 首先检查下载目录
    try {
      const downloadedModelDir = `${ctx.filesDir}/${modelFolder}`;
      const modelPath = `${downloadedModelDir}/model.int8.onnx`;
      const tokensPath = `${downloadedModelDir}/tokens.txt`;
      
      // 检查文件是否存在
      fs.accessSync(modelPath);
      fs.accessSync(tokensPath);
      
      // 检查模型文件大小（至少 100MB）
      const stat = fs.statSync(modelPath);
      if (stat.size > 100 * 1024 * 1024) {
        console.info('[AsrModelStorage] Found SenseVoice model in downloads directory');
        return true;
      }
    } catch (e) {
      // 下载目录中不存在，继续检查 rawfile
    }

    // 然后检查 rawfile（开发时内置的模型）
    try {
      const resourceManager = ctx.resourceManager;
      const testPath = `${modelFolder}/tokens.txt`;
      await resourceManager.getRawFileContent(testPath);
      console.info('[AsrModelStorage] Found SenseVoice model in rawfile');
      return true;
    } catch (e) {
      // rawfile 中也不存在
    }

    return false;
  }

  /**
   * 获取 SenseVoice 模型路径
   * 返回下载目录路径（如果存在），否则返回空字符串表示使用 rawfile
   */
  static getDownloadedModelPath(ctx: common.UIAbilityContext): string {
    const modelFolder = ASR_MODELS[AsrModelType.SENSE_VOICE_MULTI].folderName;
    const downloadedModelDir = `${ctx.filesDir}/${modelFolder}`;
    
    try {
      const modelPath = `${downloadedModelDir}/model.int8.onnx`;
      fs.accessSync(modelPath);
      return downloadedModelDir;
    } catch (e) {
      return '';
    }
  }
}
