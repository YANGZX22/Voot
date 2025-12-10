import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import type Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info('[EntryAbility] onCreate');
  }

  onDestroy(): void {
    console.info('[EntryAbility] onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('[EntryAbility] onWindowStageCreate');

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
  }

  onBackground(): void {
    console.info('[EntryAbility] onBackground');
  }
}
