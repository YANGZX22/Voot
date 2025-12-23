import FormExtensionAbility from '@ohos.app.form.FormExtensionAbility';
import formBindingData from '@ohos.app.form.formBindingData';
import formInfo from '@ohos.app.form.formInfo';
import formProvider from '@ohos.app.form.formProvider';
import Want from '@ohos.app.ability.Want';
import { TokenUsageStorage } from '../storage/TokenUsageStorage';
import preferences from '@ohos.data.preferences';

const FORM_IDS_KEY = 'form_ids';
const PREF_FILE = 'voot_forms';

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    console.info('[EntryFormAbility] onAddForm');
    
    let formId = '';
    if (want.parameters && want.parameters[formInfo.FormParam.IDENTITY_KEY]) {
      formId = want.parameters[formInfo.FormParam.IDENTITY_KEY] as string;
      // Store formId for later updates (async, but we don't await)
      this.addFormId(formId);
    }

    const formData: Record<string, Object> = {
      'formId': formId,
      'totalTokens': '...',
      'chartPoints': [[0, 100], [100, 100]],
      'dailyTotals': [0, 0, 0, 0, 0, 0, 0],
      'dateLabels': ['', '', '', '', '', '', '']
    };
    
    if (formId) {
      setTimeout(() => {
        this.updateFormData(formId);
      }, 100);
    }

    return formBindingData.createFormBindingData(formData);
  }

  onCastToNormal(formId: string) {
  }

  // Called by system for interval-based updates (every 30 min when updateDuration = 1)
  onUpdateForm(formId: string) {
    console.info('[EntryFormAbility] onUpdateForm: ' + formId);
    this.updateFormData(formId);
  }

  onUpdate(formId: string) {
    console.info('[EntryFormAbility] onUpdate: ' + formId);
    this.updateFormData(formId);
  }

  onChangeFormVisibility(newStatus: Record<string, number>) {
    const keys = Object.keys(newStatus);
    for (const key of keys) {
      if (newStatus[key] === 1) {
        this.updateFormData(key);
      }
    }
  }

  onFormEvent(formId: string, message: string) {
    // Handle control card commands - the card uses postCardAction with router
    // which will be handled by EntryAbility.handleWidgetAction
    // Here we just update the form data for non-command events
    this.updateFormData(formId);
  }

  onRemoveForm(formId: string) {
    console.info('[EntryFormAbility] onRemoveForm: ' + formId);
    this.removeFormId(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  // Helper to add formId to persistent storage
  private async addFormId(formId: string): Promise<void> {
    try {
      const pref = await preferences.getPreferences(this.context, PREF_FILE);
      const idsStr = await pref.get(FORM_IDS_KEY, '[]') as string;
      const ids: string[] = JSON.parse(idsStr);
      if (!ids.includes(formId)) {
        ids.push(formId);
        await pref.put(FORM_IDS_KEY, JSON.stringify(ids));
        await pref.flush();
        console.info('[EntryFormAbility] addFormId success: ' + formId);
      }
    } catch (e) {
      console.error('[EntryFormAbility] addFormId failed: ' + JSON.stringify(e));
    }
  }

  // Helper to remove formId from persistent storage
  private async removeFormId(formId: string): Promise<void> {
    try {
      const pref = await preferences.getPreferences(this.context, PREF_FILE);
      const idsStr = await pref.get(FORM_IDS_KEY, '[]') as string;
      let ids: string[] = JSON.parse(idsStr);
      ids = ids.filter((id: string) => id !== formId);
      await pref.put(FORM_IDS_KEY, JSON.stringify(ids));
      await pref.flush();
      console.info('[EntryFormAbility] removeFormId success: ' + formId);
    } catch (e) {
      console.error('[EntryFormAbility] removeFormId failed: ' + JSON.stringify(e));
    }
  }

  // Get all stored formIds
  public static async getFormIds(context: Context): Promise<string[]> {
    try {
      const pref = await preferences.getPreferences(context, PREF_FILE);
      const idsStr = await pref.get(FORM_IDS_KEY, '[]') as string;
      return JSON.parse(idsStr) as string[];
    } catch (e) {
      console.error('[EntryFormAbility] getFormIds failed: ' + JSON.stringify(e));
      return [];
    }
  }

  async updateFormData(formId: string) {
    console.info('[EntryFormAbility] updateFormData start: ' + formId);
    try {
      const storage = TokenUsageStorage.getInstance();
      await storage.init(this.context);
      const total = await storage.getSevenDayTotalUsage();
    
    const allUsage = await storage.getAllUsage();
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
    // Map to 0-100 coordinate space for line chart
    const points = dailyTotals.map((val: number, index: number): number[] => {
        const x = (index / 6) * 100;
        const y = 100 - (val / max) * 80; // Leave some padding at bottom
        return [x, y];
    });

    const formData: Record<string, Object> = {
      'formId': formId,
      'totalTokens': total.toString(),
      'chartPoints': points,
      'dailyTotals': dailyTotals,
      'dateLabels': dateLabels
    };
    
    const bindingData = formBindingData.createFormBindingData(formData);
    await formProvider.updateForm(formId, bindingData);
    console.info('[EntryFormAbility] updateFormData success: ' + formId);
    } catch (e) {
      console.error('[EntryFormAbility] updateFormData failed: ' + JSON.stringify(e));
    }
  }
}
