import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

// 每个API模型的密钥槽位配置（最多3个）
export interface ApiKeySlot {
  apiUrl: string;
  apiKey: string;
  model: string;
  alias?: string; // 用户自定义别名
}

// 多密钥槽位配置
export interface MultiKeySlots {
  slots: ApiKeySlot[];        // 最多3个槽位
  currentSlotIndex: number;   // 当前选中的槽位索引 (0-2)
}

export const MAX_KEY_SLOTS: number = 3;

// 创建默认的多密钥槽位
export function createDefaultMultiKeySlots(defaultUrl: string, defaultKey: string, defaultModel: string, defaultAlias?: string): MultiKeySlots {
  const result: MultiKeySlots = {
    slots: [
      { apiUrl: defaultUrl, apiKey: defaultKey, model: defaultModel, alias: defaultAlias },
      { apiUrl: defaultUrl, apiKey: '', model: defaultModel, alias: undefined },
      { apiUrl: defaultUrl, apiKey: '', model: defaultModel, alias: undefined }
    ],
    currentSlotIndex: 0
  };
  return result;
}

export interface ApiConfigSnapshot {
  promptText: string;
  polishPromptText: string; // 润色提示词
  // OpenAI 多密钥槽位
  openAiKeySlots: MultiKeySlots;
  // DeepL 多密钥槽位
  deepLKeySlots: MultiKeySlots;
  // Ollama 多密钥槽位
  ollamaKeySlots: MultiKeySlots;
  // Doubao 多密钥槽位
  doubaoKeySlots: MultiKeySlots;
  // 兼容旧版本的单密钥字段（用于迁移）
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
  selectedApiIndex: number;
  selectedLanguageIndex: number;
  intervalIndex: number;
  contextsIndex: number;
  temperatureIndex: number;
  maxTokensIndex: number;
  subtitleFontSize: number;
  subtitleFontColor: string;
  subtitleBackgroundColor: string;
  subtitleHeight: number;
  glossary: string;
  // 主题模式: 0 = 浅色, 1 = 深色, 2 = 跟随系统
  themeMode: number;
  // VAD Sensitivity
  vadSensitivityIndex: number;
  // Min Match Length
  minMatchLenIndex: number;
}

export interface PartialApiConfigSnapshot {
  promptText?: string;
  polishPromptText?: string; // 润色提示词
  // 多密钥槽位
  openAiKeySlots?: MultiKeySlots;
  deepLKeySlots?: MultiKeySlots;
  ollamaKeySlots?: MultiKeySlots;
  doubaoKeySlots?: MultiKeySlots;
  // 兼容旧版本
  openAiApiUrl?: string;
  openAiApiKey?: string;
  openAiModel?: string;
  deepLApiUrl?: string;
  deepLApiKey?: string;
  ollamaApiUrl?: string;
  ollamaModel?: string;
  doubaoApiUrl?: string;
  doubaoApiKey?: string;
  doubaoModel?: string;
  selectedApiIndex?: number;
  selectedLanguageIndex?: number;
  intervalIndex?: number;
  contextsIndex?: number;
  maxTokensIndex?: number;
  temperatureIndex?: number;
  subtitleFontSize?: number;
  subtitleFontColor?: string;
  subtitleBackgroundColor?: string;
  subtitleHeight?: number;
  glossary?: string;
  // 主题模式
  themeMode?: number;
  vadSensitivityIndex?: number;
  minMatchLenIndex?: number;
}

export class ApiConfigStorage {
  private static readonly PREF_FILE: string = 'voot_api_config';
  private static readonly SNAPSHOT_KEY: string = 'api_config_snapshot';
  private static prefs: preferences.Preferences | undefined;

  private static async getPrefs(ctx: common.UIAbilityContext): Promise<preferences.Preferences> {
    if (!ApiConfigStorage.prefs) {
      ApiConfigStorage.prefs = await preferences.getPreferences(ctx, ApiConfigStorage.PREF_FILE);
    }
    return ApiConfigStorage.prefs as preferences.Preferences;
  }

  static async loadSnapshot(
    ctx: common.UIAbilityContext,
    defaults: ApiConfigSnapshot
  ): Promise<ApiConfigSnapshot> {
    const prefs = await ApiConfigStorage.getPrefs(ctx);
    const serialized: string = (await prefs.get(ApiConfigStorage.SNAPSHOT_KEY, '')) as string;
    if (!serialized || serialized.length === 0) {
      await ApiConfigStorage.saveSnapshot(ctx, defaults);
      return defaults;
    }

    try {
      const candidate: PartialApiConfigSnapshot = JSON.parse(serialized) as PartialApiConfigSnapshot;
      return ApiConfigStorage.mergeWithDefaults(candidate, defaults);
    } catch (error) {
      console.error('[ApiConfigStorage] Failed to parse snapshot: ' + JSON.stringify(error));
      await ApiConfigStorage.saveSnapshot(ctx, defaults);
      return defaults;
    }
  }

  static async saveSnapshot(ctx: common.UIAbilityContext, snapshot: ApiConfigSnapshot): Promise<void> {
    const prefs = await ApiConfigStorage.getPrefs(ctx);
    await prefs.put(ApiConfigStorage.SNAPSHOT_KEY, JSON.stringify(snapshot));
    await prefs.flush();
  }

  private static mergeWithDefaults(
    candidate: PartialApiConfigSnapshot | undefined,
    defaults: ApiConfigSnapshot
  ): ApiConfigSnapshot {
    const sanitized: ApiConfigSnapshot = ApiConfigStorage.cloneSnapshot(defaults);
    if (!candidate) {
      return sanitized;
    }

    sanitized.promptText = ApiConfigStorage.pickString(candidate.promptText, defaults.promptText);
    sanitized.polishPromptText = ApiConfigStorage.pickString(candidate.polishPromptText, defaults.polishPromptText);
    
    // 处理多密钥槽位（支持旧版本迁移）
    sanitized.openAiKeySlots = ApiConfigStorage.migrateKeySlots(
      candidate.openAiKeySlots,
      candidate.openAiApiUrl,
      candidate.openAiApiKey,
      candidate.openAiModel,
      defaults.openAiKeySlots
    );
    sanitized.deepLKeySlots = ApiConfigStorage.migrateKeySlots(
      candidate.deepLKeySlots,
      candidate.deepLApiUrl,
      candidate.deepLApiKey,
      '', // DeepL 没有 model
      defaults.deepLKeySlots
    );
    sanitized.ollamaKeySlots = ApiConfigStorage.migrateKeySlots(
      candidate.ollamaKeySlots,
      candidate.ollamaApiUrl,
      '', // Ollama 没有 apiKey
      candidate.ollamaModel,
      defaults.ollamaKeySlots
    );
    sanitized.doubaoKeySlots = ApiConfigStorage.migrateKeySlots(
      candidate.doubaoKeySlots,
      candidate.doubaoApiUrl,
      candidate.doubaoApiKey,
      candidate.doubaoModel,
      defaults.doubaoKeySlots
    );
    
    // 兼容字段（从当前槽位同步）
    const openAiSlot = sanitized.openAiKeySlots.slots[sanitized.openAiKeySlots.currentSlotIndex];
    sanitized.openAiApiUrl = openAiSlot?.apiUrl ?? defaults.openAiApiUrl;
    sanitized.openAiApiKey = openAiSlot?.apiKey ?? defaults.openAiApiKey;
    sanitized.openAiModel = openAiSlot?.model ?? defaults.openAiModel;
    
    const deepLSlot = sanitized.deepLKeySlots.slots[sanitized.deepLKeySlots.currentSlotIndex];
    sanitized.deepLApiUrl = deepLSlot?.apiUrl ?? defaults.deepLApiUrl;
    sanitized.deepLApiKey = deepLSlot?.apiKey ?? defaults.deepLApiKey;
    
    const ollamaSlot = sanitized.ollamaKeySlots.slots[sanitized.ollamaKeySlots.currentSlotIndex];
    sanitized.ollamaApiUrl = ollamaSlot?.apiUrl ?? defaults.ollamaApiUrl;
    sanitized.ollamaModel = ollamaSlot?.model ?? defaults.ollamaModel;
    
    const doubaoSlot = sanitized.doubaoKeySlots.slots[sanitized.doubaoKeySlots.currentSlotIndex];
    sanitized.doubaoApiUrl = doubaoSlot?.apiUrl ?? defaults.doubaoApiUrl;
    sanitized.doubaoApiKey = doubaoSlot?.apiKey ?? defaults.doubaoApiKey;
    sanitized.doubaoModel = doubaoSlot?.model ?? defaults.doubaoModel;
    
    sanitized.subtitleFontSize = ApiConfigStorage.pickNumber(candidate.subtitleFontSize, defaults.subtitleFontSize);
    sanitized.subtitleFontColor = ApiConfigStorage.pickString(candidate.subtitleFontColor, defaults.subtitleFontColor);
    sanitized.subtitleBackgroundColor = ApiConfigStorage.pickString(candidate.subtitleBackgroundColor, defaults.subtitleBackgroundColor);
    sanitized.subtitleHeight = ApiConfigStorage.pickNumber(candidate.subtitleHeight, defaults.subtitleHeight);
    sanitized.selectedApiIndex = ApiConfigStorage.pickNumber(candidate.selectedApiIndex, defaults.selectedApiIndex);
    sanitized.selectedLanguageIndex = ApiConfigStorage.pickNumber(candidate.selectedLanguageIndex, defaults.selectedLanguageIndex);
    sanitized.intervalIndex = ApiConfigStorage.pickNumber(candidate.intervalIndex, defaults.intervalIndex);
    sanitized.contextsIndex = ApiConfigStorage.pickNumber(candidate.contextsIndex, defaults.contextsIndex);
    sanitized.maxTokensIndex = ApiConfigStorage.pickNumber(candidate.maxTokensIndex, defaults.maxTokensIndex);
    sanitized.temperatureIndex = ApiConfigStorage.pickNumber(candidate.temperatureIndex, defaults.temperatureIndex);
    sanitized.glossary = ApiConfigStorage.pickString(candidate.glossary, defaults.glossary);
    sanitized.themeMode = ApiConfigStorage.pickNumber(candidate.themeMode, defaults.themeMode);
    return sanitized;
  }
  
  // 迁移旧版本单密钥到多密钥槽位
  private static migrateKeySlots(
    newSlots: MultiKeySlots | undefined,
    oldUrl: string | undefined,
    oldKey: string | undefined,
    oldModel: string | undefined,
    defaults: MultiKeySlots
  ): MultiKeySlots {
    // 如果已有新格式数据，直接使用
    if (newSlots && newSlots.slots && newSlots.slots.length > 0) {
      // 确保有3个槽位
      while (newSlots.slots.length < MAX_KEY_SLOTS) {
        newSlots.slots.push({
          apiUrl: defaults.slots[0]?.apiUrl ?? '',
          apiKey: '',
          model: defaults.slots[0]?.model ?? ''
        });
      }
      return newSlots;
    }
    
    // 旧版本迁移：将旧数据放到第一个槽位
    const result: MultiKeySlots = {
      slots: [],
      currentSlotIndex: 0
    };
    
    // 第一个槽位使用旧数据（如果有）或默认值
    result.slots.push({
      apiUrl: oldUrl ?? defaults.slots[0]?.apiUrl ?? '',
      apiKey: oldKey ?? defaults.slots[0]?.apiKey ?? '',
      model: oldModel ?? defaults.slots[0]?.model ?? ''
    });
    
    // 其余槽位使用默认URL和model，key为空
    for (let i = 1; i < MAX_KEY_SLOTS; i++) {
      result.slots.push({
        apiUrl: defaults.slots[0]?.apiUrl ?? '',
        apiKey: '',
        model: defaults.slots[0]?.model ?? ''
      });
    }
    
    return result;
  }

  private static pickString(value: string | undefined, fallback: string): string {
    return value !== undefined ? value : fallback;
  }

  private static pickNumber(value: number | undefined, fallback: number): number {
    return value !== undefined ? value : fallback;
  }

  private static pickBoolean(value: boolean | undefined, fallback: boolean): boolean {
    return value !== undefined ? value : fallback;
  }

  private static cloneSnapshot(snapshot: ApiConfigSnapshot): ApiConfigSnapshot {
    return {
      promptText: snapshot.promptText,
      polishPromptText: snapshot.polishPromptText,
      openAiKeySlots: ApiConfigStorage.cloneMultiKeySlots(snapshot.openAiKeySlots),
      deepLKeySlots: ApiConfigStorage.cloneMultiKeySlots(snapshot.deepLKeySlots),
      ollamaKeySlots: ApiConfigStorage.cloneMultiKeySlots(snapshot.ollamaKeySlots),
      doubaoKeySlots: ApiConfigStorage.cloneMultiKeySlots(snapshot.doubaoKeySlots),
      openAiApiUrl: snapshot.openAiApiUrl,
      openAiApiKey: snapshot.openAiApiKey,
      openAiModel: snapshot.openAiModel,
      deepLApiUrl: snapshot.deepLApiUrl,
      deepLApiKey: snapshot.deepLApiKey,
      ollamaApiUrl: snapshot.ollamaApiUrl,
      ollamaModel: snapshot.ollamaModel,
      doubaoApiUrl: snapshot.doubaoApiUrl,
      doubaoApiKey: snapshot.doubaoApiKey,
      doubaoModel: snapshot.doubaoModel,
      selectedApiIndex: snapshot.selectedApiIndex,
      selectedLanguageIndex: snapshot.selectedLanguageIndex,
      intervalIndex: snapshot.intervalIndex,
      contextsIndex: snapshot.contextsIndex,
      maxTokensIndex: snapshot.maxTokensIndex,
      temperatureIndex: snapshot.temperatureIndex,
      subtitleFontSize: snapshot.subtitleFontSize,
      subtitleFontColor: snapshot.subtitleFontColor,
      subtitleBackgroundColor: snapshot.subtitleBackgroundColor,
      subtitleHeight: snapshot.subtitleHeight,
      glossary: snapshot.glossary,
      themeMode: snapshot.themeMode,
      vadSensitivityIndex: snapshot.vadSensitivityIndex,
      minMatchLenIndex: snapshot.minMatchLenIndex
    };
  }
  
  private static cloneMultiKeySlots(slots: MultiKeySlots): MultiKeySlots {
    const clonedSlots: ApiKeySlot[] = slots.slots.map((s: ApiKeySlot): ApiKeySlot => {
      const slot: ApiKeySlot = {
        apiUrl: s.apiUrl,
        apiKey: s.apiKey,
        model: s.model,
        alias: s.alias
      };
      return slot;
    });
    const result: MultiKeySlots = {
      slots: clonedSlots,
      currentSlotIndex: slots.currentSlotIndex
    };
    return result;
  }
}
