/**
 * FloatingTabBar - 悬浮导航栏组件
 */
import { curves } from '@kit.ArkUI';
import { hdsEffect, hdsMaterial } from '@kit.UIDesignKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { THEMES } from '../model/Theme';

@Component
export struct FloatingTabBar {
  @Watch('onIndexChange')
  @Prop currentIndex: number = 0;
  @Prop isDarkMode: boolean = false;
  @Prop themeColorIndex: number = 0;
  @Prop @Watch('onConfigChange') autoCollapseTabBar: boolean = true;
  @Prop collapseDirection: number = 0; // 0: Left, 1: Right

  onTabChange: (index: number) => void = () => {};

  @State sliderOffsetX: number = 0;
  @State barWidth: number = 0;
  @State sliderScaleX: number = 1.0;
  @State sliderScaleY: number = 1.0;

  @State isDragging: boolean = false;
  private dragStartX: number = 0;
  private forceSmoothDrop: boolean = false;
  private dragDeformTimer: number = -1;

  @State isCollapsed: boolean = false;
  private collapseTimer: number = -1;
  @State customMaterialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;

  private readonly TAB_COUNT: number = 5;
  private readonly BAR_HEIGHT: number = 58;
  private readonly SLIDER_V_PAD: number = 5;
  private readonly SLIDER_H_PAD: number = 5;
  private readonly COLLAPSED_WIDTH: number = 95;

  aboutToAppear() {
    this.resetTimer();
    // 检测设备材质能力，不支持 IMMERSIVE 时降级为 SMOOTH
    try {
      let materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
      if (materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) < 0) {
        this.customMaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;
      }
    } catch (err) {
      let message = (err as BusinessError).message;
      let code = (err as BusinessError).code;
      console.error(`getSystemMaterialTypes failed, code: ${code}, message: ${message}`);
      // 出错时保守降级为流畅
      this.customMaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;
    }
  }

  aboutToDisappear() {
    clearTimeout(this.collapseTimer);
  }

  onConfigChange() {
    if (!this.autoCollapseTabBar) {
      clearTimeout(this.collapseTimer);
      if (this.isCollapsed) {
        animateTo({ duration: 500, curve: curves.springMotion(0.68, 0.88) }, () => {
          this.isCollapsed = false;
        });
      }
    } else {
      this.resetTimer();
    }
  }

  resetTimer() {
    clearTimeout(this.collapseTimer);
    if (this.autoCollapseTabBar && !this.isCollapsed) {
      this.collapseTimer = setTimeout(() => {
        animateTo({ duration: 500, curve: curves.springMotion(0.68, 0.88) }, () => {
          this.isCollapsed = true;
        });
      }, 5000); // 5 seconds
    }
  }

  private getItemWidth(): number {
    return this.barWidth / this.TAB_COUNT;
  }

  private getSliderTargetX(): number {
    return this.currentIndex * this.getItemWidth() + this.SLIDER_H_PAD;
  }

  private getSliderWidth(): number {
    return this.getItemWidth() - this.SLIDER_H_PAD * 2;
  }

  private getSliderHeight(): number {
    return this.BAR_HEIGHT - this.SLIDER_V_PAD * 2;
  }

  private getThemeColor(alpha: string): string {
    const color = THEMES[this.themeColorIndex].primaryColor;
    if (color.startsWith('#')) {
      const hex = color.length === 9 ? color.substring(3) : color.substring(1);
      return '#' + alpha + hex;
    }
    return color;
  }

  private getIcon(index: number): Resource {
    switch (index) {
      case 0: return $r('app.media.configuration');
      case 1: return $r('app.media.translation');
      case 2: return $r('app.media.wand');
      case 3: return $r('app.media.scan');
      case 4: return $r('app.media.settings');
      default: return $r('app.media.configuration');
    }
  }

  private getLabel(index: number): string {
    switch (index) {
      case 0: return '配置';
      case 1: return '翻译';
      case 2: return '润色';
      case 3: return '扫描';
      case 4: return '设置';
      default: return '配置';
    }
  }

  onIndexChange(): void {
    if (!this.isCollapsed) {
      this.resetTimer();
      if (this.forceSmoothDrop) {
        this.forceSmoothDrop = false;
        animateTo({ duration: 300, curve: curves.springMotion(0.68, 0.88) }, () => {
          this.sliderOffsetX = this.getSliderTargetX();
          this.sliderScaleX = 1.0;
          this.sliderScaleY = 1.0;
        });
      } else {
        animateTo({ duration: 150, curve: Curve.EaseIn }, () => {
          this.sliderScaleX = 0.82;
          this.sliderScaleY = 1.08;
        });
        animateTo({
          duration: 500,
          curve: curves.springMotion(0.68, 0.88),
          delay: 80
        }, () => {
          this.sliderOffsetX = this.getSliderTargetX();
          this.sliderScaleX = 1.0;
          this.sliderScaleY = 1.0;
        });
      }
    }
  }

  build() {
    Row() {
      Stack({ alignContent: Alignment.Start }) {
        // 液态玻璃滑块 (展开状态下显示)
        if (this.barWidth > 0) {
          Row()
            .width(this.getSliderWidth())
            .height(this.getSliderHeight())
            .borderRadius(this.getSliderHeight() / 2)
            .backgroundBlurStyle(BlurStyle.Thin)
            .backgroundColor(this.isDarkMode
              ? this.getThemeColor('CC')
              : this.getThemeColor('AA'))
            .border({ width: 0.5, color: this.isDarkMode ? '#40FFFFFF' : '#35FFFFFF' })
            .shadow({ radius: 20, color: this.getThemeColor('35'), offsetY: 4 })
            .scale({ x: this.sliderScaleX, y: this.sliderScaleY })
            .position({ x: this.sliderOffsetX, y: this.SLIDER_V_PAD })
            .opacity(this.isCollapsed ? 0 : 1)
            .hitTestBehavior(HitTestMode.None)
            .visualEffect(new hdsEffect.HdsEffectBuilder()
              .pointLight({
                sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE : hdsEffect.PointLightSourceType.SOFT,
                illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE :
                  hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
              })
              .buildEffect())
        }

      // 折叠后的小球内容 (显示当前Tab icon和名称) 置于此处使其在底部，避免展开时阻挡第一项的点击事件
      Row() {
        Image(this.getIcon(this.currentIndex))
          .width(22)
          .height(22)
          .fillColor(Color.White)
        Text(this.getLabel(this.currentIndex))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .margin({ left: 6 })
      }
      .width(this.COLLAPSED_WIDTH)
      .height(this.BAR_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .opacity(this.isCollapsed ? 1 : 0)
      .hitTestBehavior(this.isCollapsed ? HitTestMode.Default : HitTestMode.Transparent)
      .zIndex(this.isCollapsed ? 2 : 0)
      .onClick(() => {
        if (this.isCollapsed) {
          animateTo({ duration: 500, curve: curves.springMotion(0.68, 0.88) }, () => {
            this.isCollapsed = false;
          });
          this.resetTimer();
        }
      })

      // 5 个 Tab — 纯内联，不用 @Builder / ForEach
      Row() {
        Column() {
          Image($r('app.media.configuration')).width(22).height(22)
            .fillColor(this.currentIndex === 0 ? Color.White : (this.isDarkMode ? '#55FFFFFF' : '#40FFFFFF'))
          Text('配置').fontSize(10).margin({ top: 2 })
            .fontWeight(this.currentIndex === 0 ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.currentIndex === 0 ? Color.White : (this.isDarkMode ? '#55FFFFFF' : '#40FFFFFF'))
        }.justifyContent(FlexAlign.Center).layoutWeight(1).height('100%')
        .onClick(() => { this.onTabChange(0); this.resetTimer(); })

        Column() {
          Image($r('app.media.translation')).width(22).height(22)
            .fillColor(this.currentIndex === 1 ? Color.White : (this.isDarkMode ? '#55FFFFFF' : '#40FFFFFF'))
          Text('翻译').fontSize(10).margin({ top: 2 })
            .fontWeight(this.currentIndex === 1 ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.currentIndex === 1 ? Color.White : (this.isDarkMode ? '#55FFFFFF' : '#40FFFFFF'))
        }.justifyContent(FlexAlign.Center).layoutWeight(1).height('100%')
        .onClick(() => { this.onTabChange(1); this.resetTimer(); })

        Column() {
          Image($r('app.media.wand')).width(22).height(22)
            .fillColor(this.currentIndex === 2 ? Color.White : (this.isDarkMode ? '#55FFFFFF' : '#40FFFFFF'))
          Text('润色').fontSize(10).margin({ top: 2 })
            .fontWeight(this.currentIndex === 2 ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.currentIndex === 2 ? Color.White : (this.isDarkMode ? '#55FFFFFF' : '#40FFFFFF'))
        }.justifyContent(FlexAlign.Center).layoutWeight(1).height('100%')
        .onClick(() => { this.onTabChange(2); this.resetTimer(); })

        Column() {
          Image($r('app.media.scan')).width(22).height(22)
            .fillColor(this.currentIndex === 3 ? Color.White : (this.isDarkMode ? '#55FFFFFF' : '#40FFFFFF'))
          Text('扫描').fontSize(10).margin({ top: 2 })
            .fontWeight(this.currentIndex === 3 ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.currentIndex === 3 ? Color.White : (this.isDarkMode ? '#55FFFFFF' : '#40FFFFFF'))
        }.justifyContent(FlexAlign.Center).layoutWeight(1).height('100%')
        .onClick(() => { this.onTabChange(3); this.resetTimer(); })

        Column() {
          Image($r('app.media.settings')).width(22).height(22)
            .fillColor(this.currentIndex === 4 ? Color.White : (this.isDarkMode ? '#55FFFFFF' : '#40FFFFFF'))
          Text('设置').fontSize(10).margin({ top: 2 })
            .fontWeight(this.currentIndex === 4 ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.currentIndex === 4 ? Color.White : (this.isDarkMode ? '#55FFFFFF' : '#40FFFFFF'))
        }.justifyContent(FlexAlign.Center).layoutWeight(1).height('100%')
        .onClick(() => { this.onTabChange(4); this.resetTimer(); })
      }
      .width(this.barWidth > 0 ? this.barWidth : '100%') // 保持内部尺寸不变避免收缩时挤压
      .height('100%')
      .opacity(this.isCollapsed ? 0 : 1)
      .hitTestBehavior(this.isCollapsed ? HitTestMode.Transparent : HitTestMode.Default)
      .zIndex(this.isCollapsed ? 0 : 2)
      .gesture(
        GestureGroup(GestureMode.Sequence,
          LongPressGesture({ repeat: false, duration: 250 })
            .onAction(() => {
              if (this.isCollapsed) return;
              this.isDragging = true;
              clearTimeout(this.collapseTimer);
              animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
                this.sliderScaleX = 1.1; // 放大
                this.sliderScaleY = 1.1;
              });
            }),
          PanGesture(new PanGestureOptions({ direction: PanDirection.Horizontal }))
            .onActionStart((event: GestureEvent) => {
              if (!this.isDragging) return;
              this.dragStartX = this.sliderOffsetX;
            })
            .onActionUpdate((event: GestureEvent) => {
              if (!this.isDragging) return;
              const newX = this.dragStartX + event.offsetX;
              const minX = this.SLIDER_H_PAD;
              const maxX = this.barWidth - this.getSliderWidth() - this.SLIDER_H_PAD;
              this.sliderOffsetX = Math.max(minX, Math.min(newX, maxX));

              // 增加流体液态效果：根据拖拽速度发生拉伸与挤压形变
              const velocity = Math.abs(event.velocityX || 0);
              const stretch = Math.min(0.35, velocity / 3000); 

              animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
                 this.sliderScaleX = 1.1 + stretch;
                 this.sliderScaleY = 1.1 - stretch * 0.5; // X拉伸时Y成比例缩短
              });

              clearTimeout(this.dragDeformTimer);
              this.dragDeformTimer = setTimeout(() => {
                if (this.isDragging) {
                  animateTo({ duration: 300, curve: curves.springMotion(0.6, 0.8) }, () => {
                    this.sliderScaleX = 1.1;
                    this.sliderScaleY = 1.1;
                  });
                }
              }, 100);
            })
            .onActionEnd((event: GestureEvent) => {
              if (!this.isDragging) return;
              this.isDragging = false;
              clearTimeout(this.dragDeformTimer);
              
              const sliderCenterX = this.sliderOffsetX + this.getSliderWidth() / 2;
              const itemWidth = this.getItemWidth();
              const targetIndex = Math.max(0, Math.min(this.TAB_COUNT - 1, Math.floor(sliderCenterX / itemWidth)));
              
              if (targetIndex !== this.currentIndex) {
                this.forceSmoothDrop = true;
                this.onTabChange(targetIndex);
              } else {
                animateTo({ duration: 300, curve: curves.springMotion(0.68, 0.88) }, () => {
                  this.sliderOffsetX = this.getSliderTargetX();
                  this.sliderScaleX = 1.0;
                  this.sliderScaleY = 1.0;
                });
              }
              this.resetTimer();
            })
            .onActionCancel(() => {
              if (!this.isDragging) return;
              this.isDragging = false;
              clearTimeout(this.dragDeformTimer);
              animateTo({ duration: 300, curve: curves.springMotion(0.68, 0.88) }, () => {
                this.sliderOffsetX = this.getSliderTargetX();
                this.sliderScaleX = 1.0;
                this.sliderScaleY = 1.0;
              });
              this.resetTimer();
            })
        )
      )
    }
    .width(this.isCollapsed ? this.COLLAPSED_WIDTH : '100%')
    .height(this.BAR_HEIGHT)
    .borderRadius(this.BAR_HEIGHT / 2)
    .clip(true)
    .backdropBlur(20)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .border({ width: 1.5, color: THEMES[this.themeColorIndex].tertiaryColor })
    .shadow({ 
      radius: this.isCollapsed ? 20 : 28, 
      color: this.isCollapsed ? this.getThemeColor('35') : '#22000000', 
      offsetY: 8 
    })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE : hdsEffect.PointLightSourceType.SOFT,
        illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE :
          hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
      })
      .buildEffect())
    .gesture(
      PanGesture(new PanGestureOptions({ direction: this.collapseDirection === 0 ? PanDirection.Left : PanDirection.Right }))
        .onActionEnd(() => {
          if (this.autoCollapseTabBar && !this.isCollapsed) {
            clearTimeout(this.collapseTimer);
            animateTo({ duration: 500, curve: curves.springMotion(0.68, 0.88) }, () => {
              this.isCollapsed = true;
            });
          }
        })
    )
      .onAreaChange((_old: Area, newArea: Area) => {
        const w = Number(newArea.width);
        if (!this.isCollapsed && w > this.COLLAPSED_WIDTH + 10) {
          this.barWidth = w;
          this.sliderOffsetX = this.getSliderTargetX();
        }
      })
      
    }
    .width('100%')
    .height(this.BAR_HEIGHT)
    .justifyContent(this.collapseDirection === 0 ? FlexAlign.Start : FlexAlign.End) // 左贴靠或右贴靠
  }
}
