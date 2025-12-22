@Entry
@Component
struct TokenCard {
  @LocalStorageProp('totalTokens') totalTokens: string = '...';
  @LocalStorageProp('chartPoints') chartPoints: number[][] = [[0, 100], [100, 100]];

  build() {
    Stack() {
      // Background
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.RightBottom,
          colors: [['#FF2A1740', 0.0], ['#FF1A0F26', 1.0]]
        })
        .borderRadius(16)
      
      Column() {
        // Header
        Row() {
          Text('Token 统计')
            .fontSize(12)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
            .opacity(0.8)
          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12 })

        // Main Content
        Column() {
          Text(this.totalTokens)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text('近7天总消耗')
            .fontSize(12)
            .fontColor(Color.White)
            .opacity(0.6)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 16, top: 8 })

        Blank()

        // Chart
        Shape() {
          Polyline()
            .points(this.chartPoints)
            .fill('none')
            .stroke(Color.White)
            .strokeWidth(3)
            .strokeLineCap(LineCapStyle.Round)
            .strokeLineJoin(LineJoinStyle.Round)
        }
        .viewPort({ x: 0, y: 0, width: 100, height: 100 })
        .width('100%')
        .height('45%')
        .margin({ bottom: 12, left: 12, right: 12 })
        .opacity(0.8)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      postCardAction(this, {
        "action": "router",
        "abilityName": "EntryAbility",
        "params": {
          "targetPage": "pages/Index"
        }
      });
    })
  }
}
