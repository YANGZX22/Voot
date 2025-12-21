import window from '@ohos.window';

@Entry
@Component
struct SubtitlePage {
  @StorageProp('voot_translated_text') message: string = '等待翻译...';
  @StorageProp('subtitleFontSize') fontSize: number = 30;
  @StorageProp('subtitleFontColor') fontColor: string = '#FFFFFF';
  @StorageProp('subtitleBackgroundColor') bgColor: string = '#3c1464';
  @StorageProp('subtitleBackgroundOpacity') bgOpacity: number = 0.4;

  private currentWindow: window.Window | undefined;
  private startLocationY: number = 0;

  async aboutToAppear() {
    try {
      this.currentWindow = await window.findWindow('voot_subtitle');
    } catch (e) {
      console.error('SubtitlePage: failed to find window ' + JSON.stringify(e));
    }
  }

  build() {
    Stack() {
      // Background layer
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.bgColor)
        .opacity(this.bgOpacity)

      // Content layer
      Column() {
        Text(this.message)
          .fontSize(this.fontSize)
          .fontColor(this.fontColor)
          .fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center)
          .textShadow({ radius: 5, color: Color.Black, offsetX: 2, offsetY: 2 })
          .width('100%')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .gesture(
      PanGesture({ direction: PanDirection.Vertical })
        .onActionStart(() => {
          if (this.currentWindow) {
            this.startLocationY = this.currentWindow.getWindowProperties().windowRect.top;
          }
        })
        .onActionUpdate((event: GestureEvent) => {
          if (this.currentWindow) {
            // Direct calculation: start position + total offset
            // No conversion needed, both in same coordinate system
            const targetY = this.startLocationY + event.offsetY;
            this.currentWindow.moveWindowTo(0, targetY);
          }
        })
    )
  }
}
