/**
 * PiP Subtitle Container Component
 *
 * Displays subtitle preview in the main page. When entering PiP mode, content transfers to PiP window.
 */

import { PipSubtitleManager, SubtitleParams } from '../services/PipSubtitleManager';
import { PiPWindow } from '@kit.ArkUI';

@Component
export struct PipSubtitleContainer {
  @Prop subtitleText: string = '字幕已就绪';
  @Prop fontSize: number = 24;
  @Prop fontColor: string = '#FFFFFF';
  @Prop subtitleBgColor: string = '#3c1464';
  @Prop backgroundOpacity: number = 0.6;
  @Prop containerHeight: number = 120;
  @State isPipMode: boolean = false;

  private pipManager: PipSubtitleManager = PipSubtitleManager.getInstance();
  private xComponentController: XComponentController = new XComponentController();

  aboutToAppear(): void {
    // Register PiP state change callback
    this.pipManager.registerLifecycleCallback((state: PiPWindow.PiPState) => {
      if (state === PiPWindow.PiPState.STARTED) {
        this.isPipMode = true;
      } else if (state === PiPWindow.PiPState.STOPPED || state === PiPWindow.PiPState.ERROR) {
        this.isPipMode = false;
      }
    });
  }

  aboutToDisappear(): void {
    // No special handling needed on destroy, PipSubtitleManager is singleton
  }

  build() {
    Column() {
      if (!this.isPipMode) {
        // When not in PiP mode, show subtitle preview in place
        Stack() {
          // Background layer
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.subtitleBgColor)
            .opacity(this.backgroundOpacity)
            .borderRadius(12)

          // Content layer
          Column() {
            Text(this.subtitleText)
              .fontSize(this.fontSize)
              .fontColor(this.fontColor)
              .fontWeight(FontWeight.Bold)
              .textAlign(TextAlign.Center)
              .textShadow({ radius: 4, color: '#000000', offsetX: 1, offsetY: 1 })
              .width('100%')
              .maxLines(4)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .height('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height(this.containerHeight)
      } else {
        // In PiP mode, show placeholder
        Column() {
          Text('Subtitle is displayed in PiP window')
            .fontSize(14)
            .fontColor('#666666')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .height(this.containerHeight)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#1A000000')
        .borderRadius(12)
      }

      // Hidden XComponent for PiP
      XComponent({ id: 'pip_video_surface', type: 'surface', controller: this.xComponentController })
        .onLoad(() => {
          this.pipManager.setXComponentController(this.xComponentController);
          // Try to make surface transparent (though PiP might still enforce black)
          this.xComponentController.setXComponentSurfaceSize({ surfaceWidth: 1, surfaceHeight: 1 });
        })
        .width(1)
        .height(1)
        .opacity(0.01) // Keep slightly visible to ensure it's rendered
        .backgroundColor(Color.Transparent)
    }
    .width('100%')
  }
}
