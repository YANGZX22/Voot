let storageTall = new LocalStorage();

@Entry(storageTall)
@Component
struct TokenCardTall {
  @LocalStorageProp('formId') formId: string = '';
  @LocalStorageProp('dailyTotals') dailyTotals: number[] = [0, 0, 0, 0, 0, 0, 0];
  @LocalStorageProp('dateLabels') dateLabels: string[] = ['', '', '', '', '', '', ''];

  build() {
    Stack() {
      // Background
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [['#FF2A1740', 0.0], ['#FF1A0F26', 1.0]]
        })
        .borderRadius(16)

      // Content
      Column() {
        // Header
        Row() {
          Text('Token 趋势')
            .fontSize(12)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
            .opacity(0.8)
          Blank()
          Text('近7天')
            .fontSize(10)
            .fontColor(Color.White)
            .opacity(0.5)
        }
        .width('100%')
        .padding({ left: 12, right: 12 })

        Blank()

        // Chart area
        Row() {
          ForEach([0, 1, 2, 3, 4, 5, 6], (index: number) => {
            Column() {
              // Usage number - right above bar
              Text(this.formatNumber(this.dailyTotals[index] || 0))
                .fontSize(8)
                .fontColor(Color.White)
                .opacity(0.7)
                .margin({ bottom: 2 })
              
              // Bar
              Column()
                .width(10)
                .height(this.getBarHeight(index))
                .backgroundColor(Color.White)
                .opacity(0.85)
                .borderRadius(5)
              
              // Date label at bottom
              Text(this.getDayLabel(index))
                .fontSize(8)
                .fontColor(Color.White)
                .opacity(0.5)
                .margin({ top: 4 })
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.End)
          })
        }
        .width('100%')
        .padding({ left: 8, right: 8, bottom: 10 })
        .alignItems(VerticalAlign.Bottom)
      }
      .width('100%')
      .height('100%')
      .padding({ top: 10 })
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: {
          targetPage: 'pages/Index',
          formId: this.formId,
          widgetAction: 'refreshTokenCard'
        }
      });
    })
  }

  getBarHeight(index: number): number {
    const maxVal = Math.max(...this.dailyTotals, 1);
    const val = this.dailyTotals[index] || 0;
    const height = Math.max((val / maxVal) * 45, 4);
    return height;
  }

  formatNumber(num: number): string {
    if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'k';
    }
    return num.toString();
  }

  getDayLabel(index: number): string {
    if (this.dateLabels[index]) {
      return this.dateLabels[index];
    }
    // Fallback if dateLabels not available
    const today = new Date();
    const d = new Date(today);
    d.setDate(today.getDate() - (6 - index));
    const month = d.getMonth() + 1;
    const day = d.getDate();
    return `${month}/${day}`;
  }
}
