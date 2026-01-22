import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

/**
 * 政策版本号配置接口
 */
interface PolicyVersions {
  PRIVACY: number;
  TERMS: number;
}

/**
 * 政策版本号配置
 * 当更新隐私政策或用户协议时，只需要修改这里的版本号
 */
export const POLICY_VERSIONS: PolicyVersions = {
  PRIVACY: 1,  // 隐私政策版本号（更新隐私政策时递增此值）
  TERMS: 1     // 用户协议版本号（更新用户协议时递增此值）
};

/**
 * 政策更新检查结果
 */
export interface PolicyUpdateResult {
  needsPrivacyUpdate: boolean;
  needsTermsUpdate: boolean;
}

/**
 * 引导流程存储类
 * 管理欢迎引导和配置引导的完成状态
 */
export class OnboardingStorage {
  private static readonly PREF_FILE: string = 'voot_onboarding';
  private static readonly KEY_COMPLETED: string = 'welcome_completed';
  private static readonly KEY_SETUP_COMPLETED: string = 'setup_completed';
  private static readonly KEY_NUMBER_VERIFIED: string = 'number_verified';
  private static readonly KEY_VERIFIED_PHONE: string = 'verified_phone';
  private static readonly KEY_ACCEPTED_PRIVACY_VERSION: string = 'accepted_privacy_version';
  private static readonly KEY_ACCEPTED_TERMS_VERSION: string = 'accepted_terms_version';
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
   * 检查号码是否已验证
   * @param ctx UI Ability Context
   * @returns true 表示已验证
   */
  static async isNumberVerified(ctx: common.UIAbilityContext): Promise<boolean> {
    const prefs = await OnboardingStorage.getPrefs(ctx);
    return (await prefs.get(OnboardingStorage.KEY_NUMBER_VERIFIED, false)) as boolean;
  }

  /**
   * 设置号码验证状态
   * @param ctx UI Ability Context
   * @param verified 是否已验证
   */
  static async setNumberVerified(ctx: common.UIAbilityContext, verified: boolean): Promise<void> {
    const prefs = await OnboardingStorage.getPrefs(ctx);
    await prefs.put(OnboardingStorage.KEY_NUMBER_VERIFIED, verified);
    await prefs.flush();
  }

  /**
   * 获取已验证的手机号码
   * @param ctx UI Ability Context
   * @returns 已验证的手机号码，未验证时返回空字符串
   */
  static async getVerifiedPhone(ctx: common.UIAbilityContext): Promise<string> {
    const prefs = await OnboardingStorage.getPrefs(ctx);
    return (await prefs.get(OnboardingStorage.KEY_VERIFIED_PHONE, '')) as string;
  }

  /**
   * 设置已验证的手机号码
   * @param ctx UI Ability Context
   * @param phone 手机号码（完整11位）
   */
  static async setVerifiedPhone(ctx: common.UIAbilityContext, phone: string): Promise<void> {
    const prefs = await OnboardingStorage.getPrefs(ctx);
    await prefs.put(OnboardingStorage.KEY_VERIFIED_PHONE, phone);
    await prefs.flush();
  }

  /**
   * 清除已验证的手机号码
   * @param ctx UI Ability Context
   */
  static async clearVerifiedPhone(ctx: common.UIAbilityContext): Promise<void> {
    const prefs = await OnboardingStorage.getPrefs(ctx);
    await prefs.put(OnboardingStorage.KEY_VERIFIED_PHONE, '');
    await prefs.flush();
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

  /**
   * 检查政策是否有更新需要用户重新确认
   * @param ctx UI Ability Context
   * @returns PolicyUpdateResult 指示哪些政策需要更新
   */
  static async checkPolicyUpdates(ctx: common.UIAbilityContext): Promise<PolicyUpdateResult> {
    const prefs = await OnboardingStorage.getPrefs(ctx);
    const acceptedPrivacyVersion = (await prefs.get(OnboardingStorage.KEY_ACCEPTED_PRIVACY_VERSION, 0)) as number;
    const acceptedTermsVersion = (await prefs.get(OnboardingStorage.KEY_ACCEPTED_TERMS_VERSION, 0)) as number;
    
    return {
      needsPrivacyUpdate: acceptedPrivacyVersion < POLICY_VERSIONS.PRIVACY,
      needsTermsUpdate: acceptedTermsVersion < POLICY_VERSIONS.TERMS
    };
  }

  /**
   * 标记用户已接受最新的隐私政策
   * @param ctx UI Ability Context
   */
  static async acceptPrivacyPolicy(ctx: common.UIAbilityContext): Promise<void> {
    const prefs = await OnboardingStorage.getPrefs(ctx);
    await prefs.put(OnboardingStorage.KEY_ACCEPTED_PRIVACY_VERSION, POLICY_VERSIONS.PRIVACY);
    await prefs.flush();
  }

  /**
   * 标记用户已接受最新的用户协议
   * @param ctx UI Ability Context
   */
  static async acceptTermsOfService(ctx: common.UIAbilityContext): Promise<void> {
    const prefs = await OnboardingStorage.getPrefs(ctx);
    await prefs.put(OnboardingStorage.KEY_ACCEPTED_TERMS_VERSION, POLICY_VERSIONS.TERMS);
    await prefs.flush();
  }

  /**
   * 标记用户已接受所有最新政策（用于首次引导完成时）
   * @param ctx UI Ability Context
   */
  static async acceptAllPolicies(ctx: common.UIAbilityContext): Promise<void> {
    const prefs = await OnboardingStorage.getPrefs(ctx);
    await prefs.put(OnboardingStorage.KEY_ACCEPTED_PRIVACY_VERSION, POLICY_VERSIONS.PRIVACY);
    await prefs.put(OnboardingStorage.KEY_ACCEPTED_TERMS_VERSION, POLICY_VERSIONS.TERMS);
    await prefs.flush();
  }
}
