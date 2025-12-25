import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

export interface ApiConfigSnapshot {
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
}

export interface PartialApiConfigSnapshot {
  promptText?: string;
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
    sanitized.openAiApiUrl = ApiConfigStorage.pickString(candidate.openAiApiUrl, defaults.openAiApiUrl);
    sanitized.openAiApiKey = ApiConfigStorage.pickString(candidate.openAiApiKey, defaults.openAiApiKey);
    sanitized.openAiModel = ApiConfigStorage.pickString(candidate.openAiModel, defaults.openAiModel);
    sanitized.deepLApiUrl = ApiConfigStorage.pickString(candidate.deepLApiUrl, defaults.deepLApiUrl);
    sanitized.deepLApiKey = ApiConfigStorage.pickString(candidate.deepLApiKey, defaults.deepLApiKey);
    sanitized.ollamaApiUrl = ApiConfigStorage.pickString(candidate.ollamaApiUrl, defaults.ollamaApiUrl);
    sanitized.ollamaModel = ApiConfigStorage.pickString(candidate.ollamaModel, defaults.ollamaModel);
    sanitized.doubaoApiUrl = ApiConfigStorage.pickString(candidate.doubaoApiUrl, defaults.doubaoApiUrl);
    sanitized.doubaoApiKey = ApiConfigStorage.pickString(candidate.doubaoApiKey, defaults.doubaoApiKey);
    sanitized.doubaoModel = ApiConfigStorage.pickString(candidate.doubaoModel, defaults.doubaoModel);
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
    return sanitized;
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
      glossary: snapshot.glossary
    };
  }
}
