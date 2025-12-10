import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

export class OnboardingStorage {
  private static readonly PREF_FILE: string = 'voot_onboarding';
  private static readonly KEY_COMPLETED: string = 'welcome_completed';
  private static prefs?: preferences.Preferences;

  private static async getPrefs(ctx: common.UIAbilityContext): Promise<preferences.Preferences> {
    if (!OnboardingStorage.prefs) {
      OnboardingStorage.prefs = await preferences.getPreferences(ctx, OnboardingStorage.PREF_FILE);
    }
    return OnboardingStorage.prefs as preferences.Preferences;
  }

  static async isFirstLaunch(ctx: common.UIAbilityContext): Promise<boolean> {
    const prefs = await OnboardingStorage.getPrefs(ctx);
    const completed: boolean = (await prefs.get(OnboardingStorage.KEY_COMPLETED, false)) as boolean;
    return !completed;
  }

  static async markCompleted(ctx: common.UIAbilityContext): Promise<void> {
    const prefs = await OnboardingStorage.getPrefs(ctx);
    await prefs.put(OnboardingStorage.KEY_COMPLETED, true);
    await prefs.flush();
  }
}
