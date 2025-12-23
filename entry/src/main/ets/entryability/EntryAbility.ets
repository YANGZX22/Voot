import UIAbility from '@ohos.app.ability.UIAbility';
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

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info('[EntryAbility] onCreate');
    this.startContinuousTask();
    this.handleWidgetAction(want);

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

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info('[EntryAbility] onNewWant');
    this.handleWidgetAction(want);
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

    windowStage.loadContent('pages/Index', (err, data) => {
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

      console.info('[EntryAbility] loadContent success');
    });
  }

  onWindowStageDestroy(): void {
    console.info('[EntryAbility] onWindowStageDestroy');
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
