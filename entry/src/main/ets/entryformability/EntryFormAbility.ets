import FormExtensionAbility from '@ohos.app.form.FormExtensionAbility';
import formBindingData from '@ohos.app.form.formBindingData';
import formInfo from '@ohos.app.form.formInfo';
import formProvider from '@ohos.app.form.formProvider';
import Want from '@ohos.app.ability.Want';
import { TokenUsageStorage } from '../storage/TokenUsageStorage';

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want) {
    const formData: Record<string, Object> = {
      'totalTokens': '...',
      'chartPoints': [[0, 100], [100, 100]]
    };
    
    if (want.parameters && want.parameters['ohos.extra.param.key.form_identity']) {
      const formId = want.parameters['ohos.extra.param.key.form_identity'] as string;
      setTimeout(() => {
        this.updateFormData(formId);
      }, 100);
    }

    return formBindingData.createFormBindingData(formData);
  }

  onCastToNormal(formId: string) {
  }

  onUpdate(formId: string) {
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
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  async updateFormData(formId: string) {
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
      'totalTokens': total.toString(),
      'chartPoints': points,
      'dailyTotals': dailyTotals,
      'dateLabels': dateLabels
    };
    
    const bindingData = formBindingData.createFormBindingData(formData);
    await formProvider.updateForm(formId, bindingData);
  }
}
