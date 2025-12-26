import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

/**
 * 引导流程存储类
 * 管理欢迎引导和配置引导的完成状态
 */
export class OnboardingStorage {
  private static readonly PREF_FILE: string = 'voot_onboarding';
  private static readonly KEY_COMPLETED: string = 'welcome_completed';
  private static readonly KEY_SETUP_COMPLETED: string = 'setup_completed';
  private static prefs?: preferences.Preferences;

  private static async getPrefs(ctx: common.UIAbilityContext): Promise<preferences.Preferences> {
    if (!OnboardingStorage.prefs) {
      OnboardingStorage.prefs = await preferences.getPreferences(ctx, OnboardingStorage.PREF_FILE);
    }
    return OnboardingStorage.prefs as preferences.Preferences;
  }

  /**
   * 检查是否是首次启动（未完成整个引导流程）
   * @param ctx UI Ability Context
   * @returns true 表示需要显示引导流程
   */
  static async isFirstLaunch(ctx: common.UIAbilityContext): Promise<boolean> {
    const prefs = await OnboardingStorage.getPrefs(ctx);
    const completed: boolean = (await prefs.get(OnboardingStorage.KEY_COMPLETED, false)) as boolean;
    return !completed;
  }

  /**
   * 标记整个引导流程完成（协议确认 + 配置引导）
   * @param ctx UI Ability Context
   */
  static async markCompleted(ctx: common.UIAbilityContext): Promise<void> {
    const prefs = await OnboardingStorage.getPrefs(ctx);
    await prefs.put(OnboardingStorage.KEY_COMPLETED, true);
    await prefs.put(OnboardingStorage.KEY_SETUP_COMPLETED, true);
    await prefs.flush();
  }

  /**
   * 检查配置引导是否完成
   * @param ctx UI Ability Context
   * @returns true 表示配置引导已完成
   */
  static async isSetupCompleted(ctx: common.UIAbilityContext): Promise<boolean> {
    const prefs = await OnboardingStorage.getPrefs(ctx);
    const completed: boolean = (await prefs.get(OnboardingStorage.KEY_SETUP_COMPLETED, false)) as boolean;
    return completed;
  }

  /**
   * 重置引导状态（用于测试或用户请求重新引导）
   * @param ctx UI Ability Context
   */
  static async resetOnboarding(ctx: common.UIAbilityContext): Promise<void> {
    const prefs = await OnboardingStorage.getPrefs(ctx);
    await prefs.put(OnboardingStorage.KEY_COMPLETED, false);
    await prefs.put(OnboardingStorage.KEY_SETUP_COMPLETED, false);
    await prefs.flush();
  }
}
