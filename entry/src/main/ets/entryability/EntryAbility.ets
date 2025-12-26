import UIAbility from '@ohos.app.ability.UIAbility';
import { Configuration } from '@ohos.app.ability.Configuration';
import window from '@ohos.window';
import type Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import wantAgent, { WantAgent } from '@ohos.app.ability.wantAgent';
import { BusinessError } from '@ohos.base';
import rpc from '@ohos.rpc';

import formBindingData from '@ohos.app.form.formBindingData';
import formProvider from '@ohos.app.form.formProvider';
import formInfo from '@ohos.app.form.formInfo';
import { TokenUsageStorage } from '../storage/TokenUsageStorage';
import { OnboardingStorage } from '../storage/OnboardingStorage';
import { ContinuityState, CONTINUITY_KEY, SubtitleStyleConfig } from '../services/ContinuityService';

// 扩展流转状态，包含翻译状态与当前Tab信息
interface ContinuityStateExtended extends ContinuityState {
  isTranslating?: boolean;
  currentTab?: number;
  // 实时朗读状态
  isRealtimeReading?: boolean;
  // PiP 悬浮窗状态
  isPipEnabled?: boolean;
  // 字幕样式配置
  subtitleConfig?: SubtitleStyleConfig;
}

export default class EntryAbility extends UIAbility {
  // 用于流转时恢复页面状态
  private storage: LocalStorage = new LocalStorage();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info('[EntryAbility] onCreate, launchReason: ' + launchParam.launchReason);
    
    // Initialize color mode
    AppStorage.setOrCreate('currentColorMode', this.context.config.colorMode);
    
    this.startContinuousTask();
    this.handleWidgetAction(want);

    // 检查是否是从流转恢复（冷启动）
    if (launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION) {
      console.info('[EntryAbility] Launched via CONTINUATION (cold start)');
      this.restoreContinuityState(want);
      // 设置为可迁移状态，保证迁移连续性
      this.context.setMissionContinueState(AbilityConstant.ContinueState.ACTIVE, (result) => {
        console.info('[EntryAbility] setMissionContinueState ACTIVE result: ' + JSON.stringify(result));
      });
    } else if (want.parameters && want.parameters[CONTINUITY_KEY]) {
      // 通过 startAbility 跨端启动时，也尝试恢复状态
      console.info('[EntryAbility] Launched via startAbility with continuity data');
      this.restoreContinuityState(want);
      this.context.setMissionContinueState(AbilityConstant.ContinueState.ACTIVE, (result) => {
        console.info('[EntryAbility] setMissionContinueState ACTIVE result: ' + JSON.stringify(result));
      });
    }

    // Register Callee listeners for Widget actions
    try {
      this.callee.on('togglePip', (data: rpc.MessageSequence) => {
        console.info('[EntryAbility] Callee: togglePip');
        AppStorage.setOrCreate('widgetPipToggle', Date.now());
        return null;
      });

      this.callee.on('toggleRealtimeReading', (data: rpc.MessageSequence) => {
        console.info('[EntryAbility] Callee: toggleRealtimeReading');
        AppStorage.setOrCreate('widgetRealtimeReadingToggle', Date.now());
        return null;
      });
    } catch (e) {
      console.error('[EntryAbility] Failed to register callee: ' + JSON.stringify(e));
    }
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    console.info('[EntryAbility] onConfigurationUpdate, colorMode: ' + newConfig.colorMode);
    AppStorage.setOrCreate('currentColorMode', newConfig.colorMode);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info('[EntryAbility] onNewWant, launchReason: ' + launchParam.launchReason);
    this.handleWidgetAction(want);
    
    // 检查是否是热启动的流转恢复
    if (launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION) {
      console.info('[EntryAbility] onNewWant via CONTINUATION (hot start)');
      this.restoreContinuityState(want);
      // 热启动时也需要设置为可迁移状态
      this.context.setMissionContinueState(AbilityConstant.ContinueState.ACTIVE, (result) => {
        console.info('[EntryAbility] setMissionContinueState ACTIVE result: ' + JSON.stringify(result));
      });
    } else if (want.parameters && want.parameters[CONTINUITY_KEY]) {
      // 通过 startAbility 跨端启动时，也尝试恢复状态
      console.info('[EntryAbility] onNewWant via startAbility with continuity data');
      this.restoreContinuityState(want);
      this.context.setMissionContinueState(AbilityConstant.ContinueState.ACTIVE, (result) => {
        console.info('[EntryAbility] setMissionContinueState ACTIVE result: ' + JSON.stringify(result));
      });
    }
  }

  private handleWidgetAction(want: Want): void {
    // Handle command from form event
    if (want.parameters && want.parameters['command']) {
      const command = want.parameters['command'] as string;
      if (command === 'togglePip') {
        AppStorage.setOrCreate('widgetPipToggle', Date.now());
        console.info('[EntryAbility] Widget command: togglePip');
      } else if (command === 'toggleReadAloud') {
        AppStorage.setOrCreate('widgetRealtimeReadingToggle', Date.now());
        console.info('[EntryAbility] Widget command: toggleReadAloud');
      }
    }

    // Check if form identity is passed (from router with form info)
    if (want.parameters && want.parameters[formInfo.FormParam.IDENTITY_KEY] !== undefined) {
      const formId = want.parameters[formInfo.FormParam.IDENTITY_KEY].toString();
      console.info('[EntryAbility] Router from widget, formId: ' + formId);
      // Update this specific widget
      this.updateFormById(formId);
    }
    
    // Handle params from router action
    if (want.parameters && want.parameters['params']) {
      try {
        const paramsStr = want.parameters['params'] as string;
        const params = JSON.parse(paramsStr) as Record<string, string>;
        const widgetAction = params['widgetAction'];
        
        if (widgetAction === 'toggleMic') {
          AppStorage.setOrCreate('widgetMicToggle', Date.now());
          console.info('[EntryAbility] Widget action: toggleMic');
        } else if (widgetAction === 'toggleRealtimeReading' || widgetAction === 'toggleReadAloud') {
          AppStorage.setOrCreate('widgetRealtimeReadingToggle', Date.now());
          console.info('[EntryAbility] Widget action: toggleRealtimeReading');
        } else if (widgetAction === 'togglePip') {
          AppStorage.setOrCreate('widgetPipToggle', Date.now());
          console.info('[EntryAbility] Widget action: togglePip');
        } else if (widgetAction === 'refreshTokenCard') {
          // Refresh all token cards when user taps to enter app
          console.info('[EntryAbility] Widget action: refreshTokenCard');
          // Update will happen in onForeground
        }
        
        // If formId is passed, update that specific widget
        if (params['formId']) {
          const formId = params['formId'];
          console.info('[EntryAbility] Router from widget params, formId: ' + formId);
          this.updateFormById(formId);
        }
      } catch (e) {
        console.error('[EntryAbility] handleWidgetAction error: ' + JSON.stringify(e));
      }
    }
  }

  private async updateFormById(formId: string): Promise<void> {
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
          const modelUsage = allUsage[model] as Record<string, number>;
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
        'formId': formId,
        'totalTokens': total.toString(),
        'chartPoints': points,
        'dailyTotals': dailyTotals,
        'dateLabels': dateLabels
      };
      
      const bindingData = formBindingData.createFormBindingData(formData);
      await formProvider.updateForm(formId, bindingData);
      console.info('[EntryAbility] updateFormById success: ' + formId);
    } catch (e) {
      console.error('[EntryAbility] updateFormById failed: ' + JSON.stringify(e));
    }
  }

  onDestroy(): void {
    console.info('[EntryAbility] onDestroy');
    this.stopContinuousTask();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('[EntryAbility] onWindowStageCreate');

    // Save windowStage for later use (e.g. creating subwindows)
    AppStorage.setOrCreate('windowStage', windowStage);

    // 根据是否首次启动决定加载页面
    this.loadInitialPage(windowStage);
  }

  /**
   * 根据引导状态决定加载哪个页面
   */
  private async loadInitialPage(windowStage: window.WindowStage): Promise<void> {
    try {
      const isFirstLaunch = await OnboardingStorage.isFirstLaunch(this.context);
      const targetPage = isFirstLaunch ? 'pages/WelcomePage' : 'pages/Index';
      console.info('[EntryAbility] loadInitialPage: isFirstLaunch=' + isFirstLaunch + ', targetPage=' + targetPage);

      windowStage.loadContent(targetPage, (err, data) => {
        if (err && err.code !== 0) {
          console.error('[EntryAbility] loadContent failed: ' + JSON.stringify(err));
          return;
        }

        // 开启全屏沉浸式导航模式
        const win = windowStage.getMainWindowSync()
        win.setWindowLayoutFullScreen(true)

        // 获取顶部规避区域，并记录到 AppStorage 中
        const top = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
          .topRect
        AppStorage.setOrCreate<number>('safeTop', px2vp(top.height))
        // 获取底部规避区域，并记录到 AppStorage 中
        const bottom = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
          .bottomRect
        AppStorage.setOrCreate<number>('safeBottom', px2vp(bottom.height))

        console.info('[EntryAbility] loadContent success: ' + targetPage);
      });
    } catch (error) {
      console.error('[EntryAbility] loadInitialPage error: ' + JSON.stringify(error));
      // 出错时默认加载 Index
      windowStage.loadContent('pages/Index', (err, data) => {
        if (err && err.code !== 0) {
          console.error('[EntryAbility] loadContent fallback failed: ' + JSON.stringify(err));
          return;
        }
        const win = windowStage.getMainWindowSync()
        win.setWindowLayoutFullScreen(true)
        const top = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect
        AppStorage.setOrCreate<number>('safeTop', px2vp(top.height))
        const bottom = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect
        AppStorage.setOrCreate<number>('safeBottom', px2vp(bottom.height))
      });
    }
  }

  onWindowStageDestroy(): void {
    console.info('[EntryAbility] onWindowStageDestroy');
  }

  /**
   * 流转恢复时恢复窗口（官方推荐方式）
   * 当应用通过流转启动时，系统会调用此方法恢复窗口状态
   */
  onWindowStageRestore(windowStage: window.WindowStage): void {
    console.info('[EntryAbility] onWindowStageRestore - Restoring from continuation');

    // 保存 windowStage
    AppStorage.setOrCreate('windowStage', windowStage);

    // 使用 restoreWindowStage 恢复页面
    // 注意：此方法必须在同步接口中调用
    windowStage.loadContent('pages/Index', this.storage, (err, data) => {
      if (err && err.code !== 0) {
        console.error('[EntryAbility] onWindowStageRestore loadContent failed: ' + JSON.stringify(err));
        return;
      }

      // 开启全屏沉浸式导航模式
      const win = windowStage.getMainWindowSync();
      win.setWindowLayoutFullScreen(true);

      // 获取规避区域
      const top = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect;
      AppStorage.setOrCreate<number>('safeTop', px2vp(top.height));
      const bottom = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect;
      AppStorage.setOrCreate<number>('safeBottom', px2vp(bottom.height));

      console.info('[EntryAbility] onWindowStageRestore loadContent success');
    });
  }

  onForeground(): void {
    console.info('[EntryAbility] onForeground');
    // Update widgets when app comes to foreground
    TokenUsageStorage.getInstance().init(this.context).then(() => {
      TokenUsageStorage.getInstance().updateAllForms();
    }).catch((err: BusinessError) => {
      console.error('[EntryAbility] Failed to update forms: ' + JSON.stringify(err));
    });
  }

  onBackground(): void {
    console.info('[EntryAbility] onBackground');
  }

  /**
   * 跨端流转 - 保存状态
   * 当用户发起流转时，系统会调用此方法保存当前状态
   */
  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    console.info('[EntryAbility] onContinue called');

    try {
      // 从 AppStorage 获取当前状态
      const isListening = AppStorage.get<boolean>('voot_is_listening') || false;
      const isTranslating = AppStorage.get<boolean>('voot_is_translating') || false;
      const originalText = AppStorage.get<string>('voot_original_text') || '';
      const translatedText = AppStorage.get<string>('voot_translated_text') || '';
      const sessionId = AppStorage.get<number>('voot_session_id') || -1;
      const fullOriginalText = AppStorage.get<string>('voot_full_original_text') || '';
      const fullTranslatedText = AppStorage.get<string>('voot_full_translated_text') || '';
      const apiConfig = AppStorage.get<string>('voot_api_config_json') || '{}';
      const currentTab = AppStorage.get<number>('voot_current_tab') ?? 1;
      // 新增：获取实时朗读和 PiP 状态
      const isRealtimeReading = AppStorage.get<boolean>('voot_is_realtime_reading') || false;
      const isPipEnabled = AppStorage.get<boolean>('voot_is_pip_enabled') || false;
      // 新增：获取字幕样式配置
      const subtitleConfigJson = AppStorage.get<string>('voot_subtitle_config') || '{}';
      let subtitleConfig: SubtitleStyleConfig | undefined;
      try {
        const parsed = JSON.parse(subtitleConfigJson) as SubtitleStyleConfig;
        if (parsed.fontSize !== undefined) {
          subtitleConfig = parsed;
        }
      } catch (e) {
        console.warn('[EntryAbility] Failed to parse subtitle config');
      }

      // 构建流转状态
      const continuityState: ContinuityStateExtended = {
        isListening,
        isTranslating,
        originalText,
        translatedText,
        sessionId,
        fullOriginalText,
        fullTranslatedText,
        apiConfig,
        timestamp: Date.now(),
        currentTab,
        // 新增字段
        isRealtimeReading,
        isPipEnabled,
        subtitleConfig
      };

      // 保存到 wantParam
      wantParam[CONTINUITY_KEY] = JSON.stringify(continuityState);
      console.info('[EntryAbility] onContinue state saved: ' + 
        'isListening=' + isListening + 
        ', isRealtimeReading=' + isRealtimeReading +
        ', isPipEnabled=' + isPipEnabled +
        ', originalTextLen=' + originalText.length +
        ', translatedTextLen=' + translatedText.length);

      return AbilityConstant.OnContinueResult.AGREE;
    } catch (err) {
      console.error('[EntryAbility] onContinue error: ' + JSON.stringify(err));
      return AbilityConstant.OnContinueResult.REJECT;
    }
  }

  /**
   * 从流转恢复状态
   */
  private restoreContinuityState(want: Want): void {
    console.info('[EntryAbility] restoreContinuityState called');

    try {
      if (!want.parameters || !want.parameters[CONTINUITY_KEY]) {
        console.info('[EntryAbility] No continuity data found; params keys: ' + Object.keys(want.parameters || {}).join(','));
        return;
      }

      const stateJson = want.parameters[CONTINUITY_KEY] as string;
      const state = JSON.parse(stateJson) as ContinuityStateExtended;

      console.info('[EntryAbility] Restoring continuity state: ' +
        'isListening=' + state.isListening +
        ', isRealtimeReading=' + (state.isRealtimeReading ?? false) +
        ', isPipEnabled=' + (state.isPipEnabled ?? false) +
        ', originalTextLen=' + state.originalText.length +
        ', timestamp=' + state.timestamp);

      // 保存到 AppStorage，供 Index.ets 恢复
      AppStorage.setOrCreate('voot_continuity_restored', true);
      AppStorage.setOrCreate('voot_continuity_state', stateJson);

      // 直接设置一些状态，让页面可以立即显示
      AppStorage.setOrCreate('voot_original_text', state.originalText);
      AppStorage.setOrCreate('voot_translated_text', state.translatedText);
      AppStorage.setOrCreate('voot_is_listening', state.isListening);
      AppStorage.setOrCreate('voot_is_translating', state.isTranslating ?? false);
      AppStorage.setOrCreate('voot_current_tab', state.currentTab ?? 1);
      // 新增：恢复实时朗读和 PiP 状态
      AppStorage.setOrCreate('voot_is_realtime_reading', state.isRealtimeReading ?? false);
      AppStorage.setOrCreate('voot_is_pip_enabled', state.isPipEnabled ?? false);
      // 新增：恢复字幕样式配置
      if (state.subtitleConfig) {
        AppStorage.setOrCreate('voot_subtitle_config', JSON.stringify(state.subtitleConfig));
      }

    } catch (err) {
      console.error('[EntryAbility] restoreContinuityState error: ' + JSON.stringify(err));
    }
  }

  private startContinuousTask() {
    let wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: "com.zixiao.voot",
          abilityName: "EntryAbility"
        }
      ],
      operationType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };

    wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: WantAgent) => {
      backgroundTaskManager.startBackgroundRunning(this.context,
        backgroundTaskManager.BackgroundMode.AUDIO_RECORDING, wantAgentObj).then(() => {
        console.info("[EntryAbility] Operation startBackgroundRunning succeeded");
      }).catch((err: BusinessError) => {
        console.error("[EntryAbility] Operation startBackgroundRunning failed Cause: " + JSON.stringify(err));
      });
    });
  }

  private stopContinuousTask() {
    backgroundTaskManager.stopBackgroundRunning(this.context).then(() => {
      console.info("[EntryAbility] Operation stopBackgroundRunning succeeded");
    }).catch((err: BusinessError) => {
      console.error("[EntryAbility] Operation stopBackgroundRunning failed Cause: " + JSON.stringify(err));
    });
  }
}
