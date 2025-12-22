import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import formProvider from '@ohos.app.form.formProvider';
import formBindingData from '@ohos.app.form.formBindingData';

export interface DailyTokenUsage {
  date: string; // YYYY-MM-DD
  count: number;
}

export type ModelTokenUsage = Record<string, number>; // Date -> Count
export type AllTokenUsage = Record<string, ModelTokenUsage>; // Model -> Date -> Count

export class TokenUsageStorage {
  private static readonly PREF_FILE: string = 'voot_token_usage';
  private static readonly USAGE_KEY: string = 'usage_data';
  private static instance: TokenUsageStorage;
  private pref?: preferences.Preferences;
  private context?: common.Context;

  private constructor() {}

  public static getInstance(): TokenUsageStorage {
    if (!TokenUsageStorage.instance) {
      TokenUsageStorage.instance = new TokenUsageStorage();
    }
    return TokenUsageStorage.instance;
  }

  public async init(context: common.Context): Promise<void> {
    this.context = context;
    this.pref = await preferences.getPreferences(context, TokenUsageStorage.PREF_FILE);
    AppStorage.setOrCreate('TokenUsage_Ready', true);
  }

  public async addTokenUsage(model: string, tokens: number): Promise<void> {
    if (!this.pref) return;

    // Use local date to avoid timezone issues splitting "today" into two days
    const date = new Date();
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const today = `${year}-${month}-${day}`;

    const allUsage = await this.getAllUsage();
    
    if (!allUsage[model]) {
      allUsage[model] = {};
    }
    
    if (!allUsage[model][today]) {
      allUsage[model][today] = 0;
    }

    allUsage[model][today] += tokens;

    await this.pref.put(TokenUsageStorage.USAGE_KEY, JSON.stringify(allUsage));
    await this.pref.flush();
    
    // Notify listeners via AppStorage if needed, or just rely on the component re-fetching
    // For reactivity, we can set an AppStorage variable
    AppStorage.setOrCreate(`TokenUsage_${model}`, allUsage[model]);
    AppStorage.setOrCreate('TokenUsage_LastUpdate', Date.now());
    
    // Update all widget cards
    this.updateAllForms();
  }

  public async updateAllForms(): Promise<void> {
    try {
      const total = await this.getSevenDayTotalUsage();
      const allUsage = await this.getAllUsage();
      const today = new Date();
      const dailyTotals: number[] = [];
      
      const dateLabels: string[] = [];
      for (let i = 6; i >= 0; i--) {
        const d = new Date(today);
        d.setDate(today.getDate() - i);
        const year = d.getFullYear();
        const month = (d.getMonth() + 1).toString().padStart(2, '0');
        const day = d.getDate().toString().padStart(2, '0');
        const dateStr = `${year}-${month}-${day}`;
        dateLabels.push(`${d.getMonth() + 1}/${d.getDate()}`);
        
        let dayTotal = 0;
        const models = Object.keys(allUsage);
        for (const model of models) {
          const modelUsage = allUsage[model];
          if (modelUsage && modelUsage[dateStr]) {
            dayTotal += modelUsage[dateStr];
          }
        }
        dailyTotals.push(dayTotal);
      }
      
      const max = Math.max(...dailyTotals, 10);
      const points = dailyTotals.map((val: number, index: number): number[] => {
        const x = (index / 6) * 100;
        const y = 100 - (val / max) * 80;
        return [x, y];
      });

      const formData: Record<string, Object> = {
        'totalTokens': total.toString(),
        'chartPoints': points,
        'dailyTotals': dailyTotals,
        'dateLabels': dateLabels
      };
      
      const bindingData = formBindingData.createFormBindingData(formData);
      await formProvider.updateForm('*', bindingData);
    } catch (e) {
      // Ignore errors if no forms exist
    }
  }

  public async getAllUsage(): Promise<AllTokenUsage> {
    if (!this.pref) return {};
    const jsonStr = await this.pref.get(TokenUsageStorage.USAGE_KEY, '{}') as string;
    try {
      return JSON.parse(jsonStr) as AllTokenUsage;
    } catch (e) {
      return {};
    }
  }

  public async getModelUsage(model: string): Promise<ModelTokenUsage> {
    const all = await this.getAllUsage();
    return all[model] || {};
  }

  public async getSevenDayTotalUsage(): Promise<number> {
    const all = await this.getAllUsage();
    let total = 0;
    const today = new Date();
    const datesToCheck: string[] = [];
    
    for (let i = 0; i < 7; i++) {
      const d = new Date(today);
      d.setDate(today.getDate() - i);
      const year = d.getFullYear();
      const month = (d.getMonth() + 1).toString().padStart(2, '0');
      const day = d.getDate().toString().padStart(2, '0');
      datesToCheck.push(`${year}-${month}-${day}`);
    }

    const models = Object.keys(all);
    for (const model of models) {
      const usage = all[model];
      for (const date of datesToCheck) {
        if (usage[date]) {
          total += usage[date];
        }
      }
    }
    return total;
  }
}
