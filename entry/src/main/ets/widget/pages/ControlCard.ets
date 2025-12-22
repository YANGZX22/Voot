@Entry
@Component
struct ControlCard {
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

      // Content
      Column() {
        // Header
        Text('Voot 快捷控制')
          .fontSize(12)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .opacity(0.8)
          .width('100%')
          .textAlign(TextAlign.Start)
          .padding({ left: 12, top: 10 })

        Blank()

        // Buttons
        Row() {
          // PiP Subtitle Button
          Column() {
            Column() {
              Image($r('app.media.pip'))
                .width(24)
                .height(24)
            }
            .width(44)
            .height(44)
            .borderRadius(22)
            .backgroundColor('#40FFFFFF')
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              postCardAction(this, {
                'action': 'router',
                'abilityName': 'EntryAbility',
                'params': {
                  'widgetAction': 'togglePip'
                }
              });
            })

            Text('字幕')
              .fontSize(10)
              .fontColor(Color.White)
              .opacity(0.8)
              .margin({ top: 6 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)

          // Read Aloud Button
          Column() {
            Column() {
              Image($r('app.media.sound'))
                .width(24)
                .height(24)
            }
            .width(44)
            .height(44)
            .borderRadius(22)
            .backgroundColor('#40FFFFFF')
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              postCardAction(this, {
                'action': 'router',
                'abilityName': 'EntryAbility',
                'params': {
                  'widgetAction': 'toggleReadAloud'
                }
              });
            })

            Text('朗读')
              .fontSize(10)
              .fontColor(Color.White)
              .opacity(0.8)
              .margin({ top: 6 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: 14 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      postCardAction(this, {
        'action': 'router',
        'abilityName': 'EntryAbility',
        'params': {
          'targetPage': 'pages/Index'
        }
      });
    })
  }
}
