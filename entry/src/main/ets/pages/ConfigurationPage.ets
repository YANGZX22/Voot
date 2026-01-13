import { hdsEffect, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { AuthUtil, LogUtil, ToastUtil } from '@pura/harmony-utils';
import { userAuth } from '@kit.UserAuthenticationKit';
import userIAM_userAuth from '@ohos.userIAM.userAuth';
import { TokenUsageChart } from '../components/TokenUsageChart';
import { THEMES } from '../model/Theme';
import { ColorMetrics, curves, promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

const TITLE_BAR_HEIGHT_MINI: number = 110;
const AUTH_SUCCESS_CODE: number = userAuth.UserAuthResultCode.SUCCESS

// 已验证的 API 槽位信息
export interface ValidatedApiSlot {
  apiIndex: number;      // 供应商索引 (0-3)
  slotIndex: number;     // 槽位索引 (0-2)
  providerName: string;  // 供应商名称
  alias: string;         // 用户自定义别名
  model: string;         // 模型名称
  displayName: string;   // 显示名称（别名或"供应商 N"）
}

// API 选择器组件（水平滚动 Picker）
@Component
struct ApiSelectorSheet {
  @Prop validatedSlots: ValidatedApiSlot[] = [];
  @Prop selectedApiIndex: number = 0;
  @Prop selectedSlotIndex: number = 0;
  @Prop isDarkMode: boolean = true;
  @Prop isLightEffectBright: boolean = true;
  onSelect: (apiIndex: number, slotIndex: number) => void = () => {};
  onClose: () => void = () => {};
  @StorageLink('themeColorIndex') themeColorIndex: number = 0;

  @State currentSelectedIndex: number = 0; // 在 validatedSlots 数组中的索引
  @State pressedIndex: number = -1; // 按下的卡片索引
  @State activeCardIndex: number = -1; // 用于追踪当前点光源激活的卡片
  @State headerOpacity: number = 0;
  @State headerOffsetY: number = -20;
  @State pickerOpacity: number = 0;
  @State pickerScale: number = 0.9;
  private scroller: Scroller = new Scroller();

  aboutToAppear() {
    // 找到当前选中项在列表中的索引
    for (let i = 0; i < this.validatedSlots.length; i++) {
      if (this.validatedSlots[i].apiIndex === this.selectedApiIndex &&
          this.validatedSlots[i].slotIndex === this.selectedSlotIndex) {
        this.currentSelectedIndex = i;
        break;
      }
    }
    
    // 入场动画
    setTimeout(() => {
      animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
        this.headerOpacity = 1;
        this.headerOffsetY = 0;
      });
    }, 50);
    
    setTimeout(() => {
      animateTo({ duration: 400, curve: Curve.FastOutSlowIn }, () => {
        this.pickerOpacity = 1;
        this.pickerScale = 1.0;
      });
      // 滚动到当前选中项
      setTimeout(() => {
        this.scroller.scrollToIndex(this.currentSelectedIndex, true, ScrollAlign.CENTER);
      }, 100);
    }, 150);
  }

  build() {
    Column() {
      // 顶部拖动指示条
      Row()
        .width(40)
        .height(4)
        .borderRadius(2)
        .backgroundColor('#50FFFFFF')
        .margin({ top: 12, bottom: 24 })

      // 标题区域
      Column() {
        Text('选择 API')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ bottom: 8 })

        Text('左右滑动选择已配置的翻译 / LLM 服务')
          .fontSize(14)
          .fontColor('#AAFFFFFF')
      }
      .opacity(this.headerOpacity)
      .offset({ y: this.headerOffsetY })
      .margin({ bottom: 32 })

      // 水平滚动 Picker
      if (this.validatedSlots.length === 0) {
        Column() {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
            .fontSize(40)
            .fontColor(['#80FFFFFF'])
            .margin({ bottom: 16 })
          Text('暂无已配置的 API')
            .fontSize(16)
            .fontColor('#80FFFFFF')
          Text('请先在"配置 API"中添加密钥')
            .fontSize(14)
            .fontColor('#60FFFFFF')
            .margin({ top: 8 })
        }
        .height(180)
        .justifyContent(FlexAlign.Center)
        .opacity(this.pickerOpacity)
        .scale({ x: this.pickerScale, y: this.pickerScale })
      } else {
        List({ scroller: this.scroller }) {
          ForEach(this.validatedSlots, (slot: ValidatedApiSlot, index: number) => {
            ListItem() {
              this.SlotCard(slot, index)
            }
          })
        }
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(200)
        .padding({ top: 10, bottom: 10 })
        .clip(false)
        .contentStartOffset(60)
        .contentEndOffset(60)
        .opacity(this.pickerOpacity)
        .scale({ x: this.pickerScale, y: this.pickerScale })
      }

      // 确认按钮
      Button('确定')
        .width('90%')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(THEMES[this.themeColorIndex].primaryColor)
        .backgroundColor('#F5FFFFFF')
        .borderRadius(25)
        .margin({ top: 32, bottom: 28 })
        .onClick(() => {
          if (this.validatedSlots.length > 0 && this.currentSelectedIndex < this.validatedSlots.length) {
            const selected = this.validatedSlots[this.currentSelectedIndex];
            this.onSelect(selected.apiIndex, selected.slotIndex);
          }
          this.onClose();
        })
    }
    .width('100%')
    .padding({ bottom: 16 })
    .backgroundColor(Color.Transparent)
    .backgroundBlurStyle(BlurStyle.BACKGROUND_ULTRA_THICK)
    .borderRadius({ topLeft: 28, topRight: 28 })
    .linearGradient({
      angle: 180,
      colors: this.isDarkMode
        ? [['#FF000000', 0.0], ['#FF000000', 1.0]]
        : [[THEMES[this.themeColorIndex].primaryColor.replace('#', '#E0'), 0.0], [THEMES[this.themeColorIndex].primaryColor.replace('#', '#F0'), 1.0]]
    })
  }

  @Builder
  SlotCard(slot: ValidatedApiSlot, index: number) {
    Column() {
      // 供应商图标
      Image(this.getProviderIcon(slot.providerName))
        .width(48)
        .height(48)
        .fillColor(this.currentSelectedIndex === index ? THEMES[this.themeColorIndex].primaryColor : Color.White)
        .margin({ bottom: 12 })

      // 显示名称
      Text(slot.displayName)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.currentSelectedIndex === index ? THEMES[this.themeColorIndex].primaryColor : Color.White)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 100 })

      // 模型名称
      if (slot.model) {
        Text(slot.model)
          .fontSize(11)
          .fontColor(this.currentSelectedIndex === index ? THEMES[this.themeColorIndex].secondaryColor : '#99FFFFFF')
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .constraintSize({ maxWidth: 100 })
          .margin({ top: 4 })
      }

      // 供应商名称（如果有别名）
      if (slot.alias && slot.alias.length > 0) {
        Text(slot.providerName)
          .fontSize(11)
          .fontColor(this.currentSelectedIndex === index ? THEMES[this.themeColorIndex].primaryColor : '#60FFFFFF')
          .margin({ top: 4 })
      }
    }
    .width(130)
    .height(160)
    .padding(16)
    .borderRadius(24)
    .backgroundColor(this.currentSelectedIndex === index 
      ? Color.White 
      : (this.pressedIndex === index ? '#33FFFFFF' : '#20FFFFFF'))
    .border({
      width: 2,
      color: this.currentSelectedIndex === index ? THEMES[this.themeColorIndex].primaryColor : Color.Transparent
    })
    .shadow({
      radius: 0,
      color: Color.Transparent,
      offsetX: 0,
      offsetY: 0
    })
    .scale({
      x: this.pressedIndex === index ? 0.95 : (this.currentSelectedIndex === index ? 1.02 : 0.95),
      y: this.pressedIndex === index ? 0.95 : (this.currentSelectedIndex === index ? 1.02 : 0.95)
    })
    .margin({ left: 8, right: 8 })
    .animation({ duration: 300, curve: Curve.FastOutSlowIn })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
          (this.activeCardIndex === index
            ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
            : hdsEffect.PointLightSourceType.NONE),
        illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE :
          (this.activeCardIndex !== -1
            ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            : hdsEffect.PointLightIlluminatedType.NONE)
      })
      .buildEffect())
    .onClick(() => {
      animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
        this.currentSelectedIndex = index;
      });
      // 滚动到选中项并居中
      this.scroller.scrollToIndex(index, true, ScrollAlign.CENTER);
    })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        animateTo({
          duration: 150,
          curve: Curve.EaseOut
        }, () => {
          this.pressedIndex = index;
          this.activeCardIndex = index;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        animateTo({
          duration: 200,
          curve: Curve.EaseOut
        }, () => {
          this.pressedIndex = -1;
          this.activeCardIndex = -1;
        });
      }
    })
  }

  private getProviderIcon(providerName: string): Resource {
    switch (providerName) {
      case 'OpenAI': return $r('app.media.OpenAI');
      case 'DeepL': return $r('app.media.DeepL');
      case 'Ollama': return $r('app.media.Ollama');
      case 'Doubao': return $r('app.media.Doubao');
      default: return $r('sys.symbol.gearshape');
    }
  }
}

// 选项选择器底部弹出组件
@Component
struct OptionSelectorSheet {
  title: string = '';
  description: string = '';
  options: string[] = [];
  @Prop selectedIndex: number = 0;
  @Prop isDarkMode: boolean = true;
  @Prop isLightEffectBright: boolean = true;
  onSelect: (index: number) => void = () => {};
  onClose: () => void = () => {};
  @StorageLink('themeColorIndex') themeColorIndex: number = 0;

  @State itemScales: number[] = [];
  @State itemOpacities: number[] = [];
  @State pressedIndex: number = -1;
  @State headerOpacity: number = 0;
  @State headerOffsetY: number = -20;
  @State activeChipIndex: number = -1; // 用于追踪当前激活的选项

  aboutToAppear() {
    this.itemScales = this.options.map(() => 0.85);
    this.itemOpacities = this.options.map(() => 0);
    
    // 标题动画
    setTimeout(() => {
      animateTo({
        duration: 300,
        curve: Curve.FastOutSlowIn
      }, () => {
        this.headerOpacity = 1;
        this.headerOffsetY = 0;
      });
    }, 50);
    
    // 逐个动画显示选项
    this.options.forEach((_, i) => {
      setTimeout(() => {
        animateTo({
          duration: 280,
          curve: Curve.FastOutSlowIn
        }, () => {
          this.itemScales[i] = 1.0;
          this.itemOpacities[i] = 1.0;
        });
      }, 120 + i * 35);
    });
  }

  build() {
    Column() {
      // 顶部拖动指示条
      Row()
        .width(40)
        .height(4)
        .borderRadius(2)
        .backgroundColor('#50FFFFFF')
        .margin({ top: 12, bottom: 20 })

      // 标题区域
      Column() {
        Text(this.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ bottom: 6 })

        // 描述
        if (this.description) {
          Text(this.description)
            .fontSize(13)
            .fontColor('#BBFFFFFF')
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .opacity(this.headerOpacity)
      .offset({ y: this.headerOffsetY })
      .margin({ bottom: 20, left: 24, right: 24 })

      // 选项网格
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(this.options, (option: string, index: number) => {
          this.OptionChip(option, index)
        })
      }
      .width('100%')
      .padding({ left: 12, right: 12 })

      // 完成按钮
      Button('完成')
        .width('90%')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(THEMES[this.themeColorIndex].primaryColor)
        .backgroundColor('#F5FFFFFF')
        .borderRadius(25)
        .margin({ top: 28, bottom: 28 })
        .onClick(() => this.onClose())
    }
    .width('100%')
    .padding({ bottom: 16 })
    .backgroundColor(Color.Transparent)
    .backgroundBlurStyle(BlurStyle.BACKGROUND_ULTRA_THICK)
    .borderRadius({ topLeft: 28, topRight: 28 })
    .linearGradient({
      angle: 180,
      colors: this.isDarkMode
        ? [['#FF000000', 0.0], ['#FF000000', 1.0]]
        : [[THEMES[this.themeColorIndex].primaryColor.replace('#', '#E0'), 0.0], [THEMES[this.themeColorIndex].primaryColor.replace('#', '#F0'), 1.0]]
    })
  }

  @Builder
  OptionChip(option: string, index: number) {
    // 使用 Column 作为固定尺寸容器，防止内部变化影响布局
    Column() {
      Text(option)
        .fontSize(15)
        .fontWeight(FontWeight.Medium) // 固定字重，避免宽度变化
        .fontColor(this.selectedIndex === index ? THEMES[this.themeColorIndex].primaryColor : Color.White)
        .textAlign(TextAlign.Center)
        .transition(TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.EaseOut }))
    }
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .backgroundColor(this.selectedIndex === index
      ? Color.White
      : (this.pressedIndex === index ? '#33FFFFFF' : '#14FFFFFF'))
    .borderRadius(20)
    .margin(5)
    .opacity(this.itemOpacities[index] ?? 1)
    // 仅在选中时加柔和主题描边
    .border({
      width: 1.5,
      color: this.selectedIndex === index
        ? THEMES[this.themeColorIndex].primaryColor
        : Color.Transparent,
      style: BorderStyle.Solid
    })
    // 选中态不再增加额外阴影，保持干净
    .shadow({
      radius: 0,
      color: Color.Transparent,
      offsetX: 0,
      offsetY: 0
    })
    // 使用 renderFit 配合 scale，让缩放不影响布局
    .renderFit(RenderFit.CENTER)
    .scale({
      x: this.pressedIndex === index ? 0.95 : (this.selectedIndex === index ? 1.02 : 1.0),
      y: this.pressedIndex === index ? 0.95 : (this.selectedIndex === index ? 1.02 : 1.0)
    })
    .animation({
      duration: 180,
      curve: Curve.FastOutSlowIn
    })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
          (this.activeChipIndex === index
            ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
            : hdsEffect.PointLightSourceType.NONE),
        illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE :
          (this.activeChipIndex !== -1
            ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            : hdsEffect.PointLightIlluminatedType.NONE)
      })
      .buildEffect())
    .onClick(() => {
      this.onSelect(index);
    })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        animateTo({
          duration: 150,
          curve: Curve.EaseOut
        }, () => {
          this.pressedIndex = index;
          this.activeChipIndex = index;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        animateTo({
          duration: 200,
          curve: Curve.EaseIn
        }, () => {
          this.pressedIndex = -1;
          this.activeChipIndex = -1;
        });
      }
    })
  }
}

// 语言选择器底部弹出组件（垂直列表样式）
@Component
struct LanguageSelectorSheet {
  title: string = '';
  description: string = '';
  options: string[] = [];
  @Prop selectedIndex: number = 0;
  @Prop isDarkMode: boolean = true;
  @Prop isLightEffectBright: boolean = true;
  onSelect: (index: number) => void = () => {};
  onClose: () => void = () => {};
  @StorageLink('themeColorIndex') themeColorIndex: number = 0;

  @State itemScales: number[] = [];
  @State itemOpacities: number[] = [];
  @State pressedIndex: number = -1;
  @State headerOpacity: number = 0;
  @State headerOffsetY: number = -20;
  @State activeItemIndex: number = -1;

  aboutToAppear() {
    this.itemScales = this.options.map(() => 0.85);
    this.itemOpacities = this.options.map(() => 0);
    
    // 标题动画
    setTimeout(() => {
      animateTo({
        duration: 300,
        curve: Curve.FastOutSlowIn
      }, () => {
        this.headerOpacity = 1;
        this.headerOffsetY = 0;
      });
    }, 50);
    
    // 逐个动画显示选项
    this.options.forEach((_, i) => {
      setTimeout(() => {
        animateTo({
          duration: 280,
          curve: Curve.FastOutSlowIn
        }, () => {
          this.itemScales[i] = 1.0;
          this.itemOpacities[i] = 1.0;
        });
      }, 120 + i * 50);
    });
  }

  build() {
    Column() {
      // 顶部拖动指示条
      Row()
        .width(40)
        .height(4)
        .borderRadius(2)
        .backgroundColor('#50FFFFFF')
        .margin({ top: 12, bottom: 20 })

      // 标题区域
      Column() {
        Text(this.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ bottom: 6 })

        // 描述
        if (this.description) {
          Text(this.description)
            .fontSize(13)
            .fontColor('#BBFFFFFF')
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .opacity(this.headerOpacity)
      .offset({ y: this.headerOffsetY })
      .margin({ bottom: 20, left: 24, right: 24 })

      // 语言列表（垂直排列，每个语言单独一行）
      Column({ space: 8 }) {
        ForEach(this.options, (option: string, index: number) => {
          this.LanguageItem(option, index)
        })
      }
      .alignItems(HorizontalAlign.Center)

      // 完成按钮
      Button('完成')
        .width('90%')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(THEMES[this.themeColorIndex].primaryColor)
        .backgroundColor('#F5FFFFFF')
        .borderRadius(25)
        .margin({ top: 28, bottom: 28 })
        .onClick(() => this.onClose())
    }
    .width('100%')
    .padding({ bottom: 16 })
    .backgroundColor(Color.Transparent)
    .backgroundBlurStyle(BlurStyle.BACKGROUND_ULTRA_THICK)
    .borderRadius({ topLeft: 28, topRight: 28 })
    .linearGradient({
      angle: 180,
      colors: this.isDarkMode
        ? [['#FF000000', 0.0], ['#FF000000', 1.0]]
        : [[THEMES[this.themeColorIndex].primaryColor.replace('#', '#E0'), 0.0], [THEMES[this.themeColorIndex].primaryColor.replace('#', '#F0'), 1.0]]
    })
  }

  @Builder
  LanguageItem(option: string, index: number) {
    Row() {
      Text(option)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.selectedIndex === index ? THEMES[this.themeColorIndex].primaryColor : Color.White)
        .transition(TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.EaseOut }))
    }
    .align(Alignment.Center)
    .width(200)
    .height(48)
    .padding({ left: 20, right: 20 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.selectedIndex === index
      ? Color.White
      : (this.pressedIndex === index ? '#33FFFFFF' : '#14FFFFFF'))
    .borderRadius(20)
    .opacity(this.itemOpacities[index] ?? 1)
    .border({
      width: 1.5,
      color: this.selectedIndex === index
        ? THEMES[this.themeColorIndex].primaryColor
        : Color.Transparent,
      style: BorderStyle.Solid
    })
    .renderFit(RenderFit.CENTER)
    .scale({
      x: this.pressedIndex === index ? 0.97 : (this.selectedIndex === index ? 1.01 : 1.0),
      y: this.pressedIndex === index ? 0.97 : (this.selectedIndex === index ? 1.01 : 1.0)
    })
    .animation({
      duration: 180,
      curve: Curve.FastOutSlowIn
    })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
          (this.activeItemIndex === index
            ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
            : hdsEffect.PointLightSourceType.NONE),
        illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE :
          (this.activeItemIndex !== -1
            ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            : hdsEffect.PointLightIlluminatedType.NONE)
      })
      .buildEffect())
    .onClick(() => {
      this.onSelect(index);
    })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        animateTo({
          duration: 150,
          curve: Curve.EaseOut
        }, () => {
          this.pressedIndex = index;
          this.activeItemIndex = index;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        animateTo({
          duration: 200,
          curve: Curve.EaseIn
        }, () => {
          this.pressedIndex = -1;
          this.activeItemIndex = -1;
        });
      }
    })
  }
}

@Component
struct ConfigCard {
  title: string = '';
  @Prop content: string = '';
  btnId: number = 0;
  isSymbol: boolean = false;
  @Prop showLockIcon: boolean = true;
  icon?: Resource;
  @Prop isLightEffectBright: boolean = true;
  @Prop isDarkMode: boolean = true;
  callback: () => void = () => {};
  onInfoClick?: () => void = undefined;
  
  @Link activeBtn: number;
  @State scaleValue: number = 1.0;
  @State bgColor: ResourceColor = '#803c1464';
  @State textColor: ResourceColor = $r('sys.color.font_on_primary');
  @StorageLink('themeColorIndex') @Watch('onThemeColorChange') themeColorIndex: number = 0;

  aboutToAppear() {
    // 初始化背景色为当前主题色
    this.bgColor = THEMES[this.themeColorIndex].secondaryColor;
  }

  onThemeColorChange() {
    if (this.activeBtn === this.btnId) {
      this.bgColor = Color.White;
      this.textColor = THEMES[this.themeColorIndex].primaryColor;
    } else {
      this.bgColor = THEMES[this.themeColorIndex].secondaryColor;
      this.textColor = Color.White;
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.icon) {
        SymbolGlyph(this.icon)
          .fontSize(80)
          .fontColor([this.textColor])
          .opacity(0.1)
          .position({ bottom: -10, left: -10 })
      }

      Column() {
        Text(this.title)
          .fontSize(14)
          .fontColor(this.textColor)
          .opacity(0.7)
          .fontWeight(FontWeight.Medium)
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 4 })
        
        Blank()

        if (this.isSymbol) {
          if (this.showLockIcon) {
            SymbolGlyph($r('sys.symbol.face'))
              .fontSize(28)
              .fontColor([this.textColor])
              .fontWeight(FontWeight.Bold)
              .alignSelf(ItemAlign.Start)
          } else {
            SymbolGlyph($r('sys.symbol.arrow_right'))
              .fontSize(28)
              .fontColor([this.textColor])
              .fontWeight(FontWeight.Bold)
              .alignSelf(ItemAlign.Start)
          }
        } else {
          Text(this.content)
            .fontSize(20)
            .fontColor(this.textColor)
            .fontWeight(FontWeight.Bold)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .alignSelf(ItemAlign.Start)
        }
      }
      .width('100%')
      .height('100%')
      .padding(16)
      .alignItems(HorizontalAlign.Start)

      if (this.onInfoClick) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.info_circle'))
            .fontSize(20)
            .fontColor([this.textColor])
            .opacity(0.5)
        }
        .backgroundColor(Color.Transparent)
        .width(40)
        .height(40)
        .margin({ top: 4, right: 4 })
        .onClick((event) => {
          if (this.onInfoClick) {
            this.onInfoClick();
          }
        })
      }
    }
    .backgroundColor(this.bgColor)
    .width('100%')
    .height('100%')
    .borderRadius(24)
    .clip(true)
    .scale({ x: this.scaleValue, y: this.scaleValue })
    .onTouch((event: TouchEvent) => {
      this.handleTouch(event);
    })
    .onClick(() => {
      if (this.callback) this.callback();
    })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
          (this.activeBtn === this.btnId
          ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT)
          : hdsEffect.PointLightSourceType.NONE),
        illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE :
          (this.activeBtn !== 0
          ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
          : hdsEffect.PointLightIlluminatedType.NONE)
      })
      .buildEffect())
    .shadow({ radius: 20, color: '#1A000000'})
  }

  handleTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.pressButton();
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.leaveButton();
    }
  }

  pressButton(): void {
    animateTo({
      duration: 200,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.activeBtn = this.btnId;
      this.scaleValue = 0.95;
      this.bgColor = Color.White;
      this.textColor = THEMES[this.themeColorIndex].primaryColor;
    })
  }

  leaveButton(): void {
    animateTo({
      duration: 200,
      curve: Curve.EaseOut
    }, () => {
      this.activeBtn = 0;
      this.scaleValue = 1.0;
      this.bgColor = THEMES[this.themeColorIndex].secondaryColor;
      this.textColor = Color.White;
    })
  }
}

@Component
export struct ConfigurationPage {
  // Props
  apiOptions: string[] = [];
  @Prop selectedApiIndex: number = 0;
  @Prop selectedSlotIndex: number = 0; // 当前槽位索引
  @Prop currentModelName: string = '';
  @Prop currentApiAlias: string = ''; // 当前选中 API 的别名（用于显示）
  @Prop validatedApiSlots: ValidatedApiSlot[] = []; // 已验证的 API 槽位列表
  languageOptions: string[] = [];
  languageDisplayOptions: string[] = [];
  @Prop selectedLanguageIndex: number = 0;
  intervalOptions: string[] = [];
  @Prop selectedIntervalIndex: number = 0;
  contextsOptions: string[] = [];
  @Prop selectedContextsIndex: number = 0;
  temperatureOptions: string[] = [];
  @Prop selectedTemperatureIndex: number = 0;
  maxTokensOptions: string[] = [];
  @Prop selectedMaxTokensIndex: number = 0;
  vadSensitivityOptions: string[] = [];
  @Prop selectedVadSensitivityIndex: number = 0;
  minMatchLenOptions: string[] = [];
  @Prop selectedMinMatchLenIndex: number = 0;
  @Prop @Watch('onVisibleChange') isVisible: boolean = false;
  @Prop isLightEffectBright: boolean = true;
  @Prop isDarkMode: boolean = true;
  @Prop isLeftHand: boolean = false;
  @Prop isRightHand: boolean = false;
  @StorageLink('themeColorIndex') @Watch('onThemeColorChange') themeColorIndex: number = 0;

  // API Config Page Settings
  @StorageLink('apiConfigRequireScreenLock') apiConfigRequireScreenLock: boolean = true;

  // Callbacks
  onCycleApi: () => void = () => {};
  onSelectApi: (apiIndex: number, slotIndex: number) => void = () => {}; // 新的 API 选择回调
  onCycleLanguage: () => void = () => {};
  onSelectLanguage: (index: number) => void = () => {};
  onOpenApiSettings: () => void = () => {};
  onSelectInterval: (index: number) => void = () => {};
  onSelectContexts: (index: number) => void = () => {};
  onSelectTemperature: (index: number) => void = () => {};
  onSelectMaxTokens: (index: number) => void = () => {};
  onSelectVadSensitivity: (index: number) => void = () => {};
  onSelectMinMatchLen: (index: number) => void = () => {};

  @State activeBtn: number = 0;

  // 握持弹窗临时关闭状态
  @State isHandPopupDismissed: boolean = false;

  // 底部选择器状态
  // 统一的 Sheet 状态
  @State isSheetVisible: boolean = false;
  @State sheetTitle: string = '';
  @State sheetDescription: string = '';
  @State sheetOptions: string[] = [];
  @State sheetSelectedIndex: number = 0;
  // 使用枚举类型代替函数引用，避免 @State 不支持函数的问题
  @State sheetType: string = ''; // 'interval' | 'contexts' | 'temperature' | 'maxTokens' | 'vad' | 'minMatch' | 'api'

  // Animation states
  @State cardScales: number[] = [0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9];
  @State cardOpacities: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

  // New states for disclaimer card
  @State disclaimerScale: number = 1.0;
  @State disclaimerBgColor: ResourceColor = '#803c1464';
  @State disclaimerTextColor: ResourceColor = Color.White;
  @State disclaimerSubTextColor: ResourceColor = $r('sys.color.font_tertiary');
  
  // API 介绍展开状态
  @State isApiIntroExpanded: boolean = false;
  @State disclaimerWidth: string = 'calc(100% - 48vp)';
  @State disclaimerHeight: number = 120;
  @State disclaimerBorderRadius: number = 30;
  @State expandedContentOpacity: number = 0;
  @State collapsedContentOpacity: number = 1;
  private longPressTimer: number | undefined = undefined;

  private animationTimeouts: number[] = [];

  aboutToAppear() {
    // 初始化disclaimer背景色为当前主题色
    this.disclaimerBgColor = THEMES[this.themeColorIndex].secondaryColor;
    this.disclaimerSubTextColor = THEMES[this.themeColorIndex].primaryColor.replace('#', '#CC');
    if (this.isVisible) {
      this.playAnimations();
    }
  }

  aboutToDisappear() {
    this.clearAnimationTimeouts();
  }

  onVisibleChange() {
    if (this.isVisible) {
      this.isHandPopupDismissed = false;
      this.resetAnimations();
      this.playAnimations();
    } else {
      this.clearAnimationTimeouts();
    }
  }

  resetAnimations() {
    this.clearAnimationTimeouts();
    for (let i = 0; i < 12; i++) {
      this.cardScales[i] = 0.8;
      this.cardOpacities[i] = 0;
    }
  }

  playAnimations() {
    for (let i = 0; i < 12; i++) {
      let id = setTimeout(() => {
        animateTo({
          duration: 300,
          curve: Curve.FastOutSlowIn
        }, () => {
          this.cardScales[i] = 1.0;
          this.cardOpacities[i] = 1.0;
        })
      }, i * 50);
      this.animationTimeouts.push(id);
    }
  }

  clearAnimationTimeouts() {
    this.animationTimeouts.forEach(id => clearTimeout(id));
    this.animationTimeouts = [];
  }

  onThemeColorChange() {
    if (this.activeBtn === 99) {
      this.disclaimerBgColor = Color.White;
      this.disclaimerTextColor = THEMES[this.themeColorIndex].primaryColor;
      this.disclaimerSubTextColor = THEMES[this.themeColorIndex].primaryColor;
    } else {
      this.disclaimerBgColor = THEMES[this.themeColorIndex].secondaryColor;
      this.disclaimerTextColor = Color.White;
      this.disclaimerSubTextColor = THEMES[this.themeColorIndex].primaryColor.replace('#', '#CC');
    }
  }

  private getLanguageLabels(): string[] {
    if (this.languageDisplayOptions.length > 0) {
      return this.languageDisplayOptions;
    }
    return this.languageOptions;
  }

  private openOptionSheet(title: string, description: string, options: string[], selected: number, type: string): void {
    this.sheetTitle = title;
    this.sheetDescription = description;
    this.sheetOptions = options;
    this.sheetSelectedIndex = selected;
    this.sheetType = type;
    this.isSheetVisible = true;
  }

  private handleSheetSelect(index: number): void {
    switch (this.sheetType) {
      case 'interval':
        this.onSelectInterval(index);
        break;
      case 'contexts':
        this.onSelectContexts(index);
        break;
      case 'temperature':
        this.onSelectTemperature(index);
        break;
      case 'maxTokens':
        this.onSelectMaxTokens(index);
        break;
      case 'vad':
        this.onSelectVadSensitivity(index);
        break;
      case 'minMatch':
        this.onSelectMinMatchLen(index);
        break;
      case 'language':
        this.onSelectLanguage(index);
        break;
    }
  }

  pressDisclaimer(): void {
    animateTo({ duration: 100, curve: Curve.EaseIn }, () => {
      this.disclaimerScale = 0.95;
      this.disclaimerBgColor = Color.White;
      this.disclaimerTextColor = THEMES[this.themeColorIndex].primaryColor;
      this.disclaimerSubTextColor = THEMES[this.themeColorIndex].primaryColor;
    });
    
    // 开始长按计时器
    this.longPressTimer = setTimeout(() => {
      this.showApiIntro();
    }, 600); // 600ms 触发长按
  }

  releaseDisclaimer(): void {
    // 清除长按计时器
    if (this.longPressTimer !== undefined) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = undefined;
    }
    
    animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
      this.disclaimerScale = 1.0;
      this.disclaimerBgColor = THEMES[this.themeColorIndex].secondaryColor;
      this.disclaimerTextColor = Color.White;
      this.disclaimerSubTextColor = THEMES[this.themeColorIndex].primaryColor.replace('#', '#CC');
    });
  }
  
  showApiIntro(): void {
    // 标记展开状态
    this.isApiIntroExpanded = true;
    this.activeBtn = 0; // 关闭光效
    
    // 淡出简短内容
    animateTo({
      duration: 150,
      curve: Curve.EaseOut
    }, () => {
      this.collapsedContentOpacity = 0;
      this.disclaimerScale = 1.0;
      this.disclaimerBgColor = THEMES[this.themeColorIndex].secondaryColor;
      this.disclaimerTextColor = Color.White;
      this.disclaimerSubTextColor = THEMES[this.themeColorIndex].primaryColor.replace('#', '#CC');
    });
    
    // 展开卡片
    setTimeout(() => {
      animateTo({
        duration: 400,
        curve: Curve.FastOutSlowIn
      }, () => {
        this.disclaimerWidth = 'calc(100% - 48vp)';
        this.disclaimerHeight = 400; // 调整高度以减少留白
        this.disclaimerBorderRadius = 32;
      });
    }, 100);
    
    // 淡入详细内容
    setTimeout(() => {
      animateTo({
        duration: 300,
        curve: Curve.EaseOut
      }, () => {
        this.expandedContentOpacity = 1;
      });
    }, 350);
  }
  
  hideApiIntro(): void {
    // 淡出详细内容
    animateTo({
      duration: 200,
      curve: Curve.EaseIn
    }, () => {
      this.expandedContentOpacity = 0;
    });
    
    // 收缩卡片
    setTimeout(() => {
      animateTo({
        duration: 350,
        curve: Curve.FastOutSlowIn
      }, () => {
        this.disclaimerWidth = 'calc(100% - 48vp)';
        this.disclaimerHeight = 120;
        this.disclaimerBorderRadius = 30;
        this.disclaimerBgColor = THEMES[this.themeColorIndex].secondaryColor;
        this.disclaimerTextColor = Color.White;
        this.disclaimerSubTextColor = THEMES[this.themeColorIndex].primaryColor.replace('#', '#CC');
      });
    }, 150);
    
    // 淡入简短内容
    setTimeout(() => {
      animateTo({
        duration: 250,
        curve: Curve.EaseOut
      }, () => {
        this.collapsedContentOpacity = 1;
      });
      this.isApiIntroExpanded = false;
    }, 400);
  }

  handleConfigApi(): void {
    // 如果不需要屏幕锁定验证，直接打开API配置页面
    if (!this.apiConfigRequireScreenLock) {
      this.onOpenApiSettings();
      return;
    }

    let facestatus = AuthUtil.getAvailableStatus(userIAM_userAuth.UserAuthType.FACE, userIAM_userAuth.AuthTrustLevel.ATL1)
    let fingerstatus = AuthUtil.getAvailableStatus(userIAM_userAuth.UserAuthType.FINGERPRINT, userIAM_userAuth.AuthTrustLevel.ATL2)
    let pinstatus = AuthUtil.getAvailableStatus(userIAM_userAuth.UserAuthType.PIN, userIAM_userAuth.AuthTrustLevel.ATL2)
    if (facestatus.status) {
      AuthUtil.onStart({
        authType: [userAuth.UserAuthType.FACE],
        authTrustLevel: userAuth.AuthTrustLevel.ATL3,
        title: '请验证人脸',
        showTip: true
      }, (result: userAuth.UserAuthResult) => {
        const authPassed: boolean = !!result && result.result === AUTH_SUCCESS_CODE;
        if (authPassed) {
          this.onOpenApiSettings();
          return;
        }
        promptAction.showToast({ message: 'Voot 无法验证您的人脸识别确认信息，请重试'})})
    } else if (!facestatus.status && fingerstatus.status) {
      AuthUtil.onStartEasy(true, (result: userAuth.UserAuthResult) => {
        const authPassed: boolean = !!result && result.result === AUTH_SUCCESS_CODE;
        if (authPassed) {
          this.onOpenApiSettings();
          return;
        }
        promptAction.showToast({ message: 'Voot 无法验证您的指纹识别确认信息，请重试'})})
    } else if (!facestatus.status && !fingerstatus.status && pinstatus.status) {
      AuthUtil.onStartEasy(true, (result: userAuth.UserAuthResult) => {
        const authPassed: boolean = !!result && result.result === AUTH_SUCCESS_CODE;
        if (authPassed) {
          this.onOpenApiSettings();
          return;
        }
        promptAction.showToast({ message: 'Voot 无法验证您的锁屏密码确认信息，请重试'})})
    } else {
      this.onOpenApiSettings()
      promptAction.showToast({ message: '您似乎没有屏幕锁定选项'})}
  }

  build() {
    Stack() {
      HdsNavigation() {
        Scroll() {
          Column() {
            Blank().height(TITLE_BAR_HEIGHT_MINI);

            Column() {
              // 收起状态的内容
              if (!this.isApiIntroExpanded) {
                Column() {
                  SymbolGlyph($r('sys.symbol.exclamationmark_shield_fill'))
                    .fontSize(24)
                    .fontColor([this.disclaimerTextColor])
                    .margin({ bottom: 8 })
                  Text('Voot 不提供或转售任何 API 密钥')
                    .fontSize(16)
                    .fontColor(this.disclaimerTextColor)
                    .fontWeight(FontWeight.Medium)
                    .margin({ bottom: 4 })
                    .textAlign(TextAlign.Center)
                  Text('长按了解')
                    .fontSize(12)
                    .fontColor(this.disclaimerTextColor)
                    .margin({ top: 4 })
                }
                .opacity(this.collapsedContentOpacity)
              }
              
              // 展开状态的内容
              if (this.isApiIntroExpanded) {
                Scroll() {
                  Column() {
                    // 顶部关闭按钮
                    Row() {
                      SymbolGlyph($r('sys.symbol.exclamationmark_shield_fill'))
                        .fontSize(24)
                        .fontColor([Color.White])
                      Text('关于 API 密钥')
                        .fontSize(20)
                        .fontColor(Color.White)
                        .fontWeight(FontWeight.Bold)
                        .margin({ left: 12 })
                      Blank()
                      Button({ type: ButtonType.Circle }) {
                        SymbolGlyph($r('sys.symbol.arrow_up'))
                          .fontSize(16)
                          .fontColor([Color.White])
                          .fontWeight(FontWeight.Bold)
                      }
                      .width(32)
                      .height(32)
                      .backgroundColor($r('sys.color.comp_background_secondary'))
                      .onClick(() => {
                        this.hideApiIntro();
                      })
                    }
                    .width('100%')
                    .padding({ left: 4, right: 4, bottom: 24 })
                    
                    // API 介绍内容
                    Column({ space: 24 }) {
                      // 什么是 API 密钥
                      Row({ space: 16 }) {
                        SymbolGlyph($r('sys.symbol.key'))
                          .fontSize(24)
                          .fontColor(['#EEFFFFFF'])
                          .margin({ top: 2 })
                        Column({ space: 4 }) {
                          Text('什么是 API 密钥？')
                            .fontSize(16)
                            .fontColor(Color.White)
                            .fontWeight(FontWeight.Medium)
                          Text('API 密钥是您访问大模型服务的凭证。Voot 使用此密钥直接与服务商（如 OpenAI、豆包）通信。')
                            .fontSize(14)
                            .fontColor('#CCFFFFFF')
                            .lineHeight(20)
                        }
                        .layoutWeight(1)
                        .alignItems(HorizontalAlign.Start)
                      }
                      .width('100%')
                      .alignItems(VerticalAlign.Top)

                      // 安全承诺
                      Row({ space: 16 }) {
                        SymbolGlyph($r('sys.symbol.lock_shield'))
                          .fontSize(24)
                          .fontColor(['#EEFFFFFF'])
                          .margin({ top: 2 })
                        Column({ space: 4 }) {
                          Text('安全承诺')
                            .fontSize(16)
                            .fontColor(Color.White)
                            .fontWeight(FontWeight.Medium)
                          Text('您的密钥仅加密存储在本地设备上，受系统安全芯片保护。Voot 不会上传、收集或与第三方共享您的密钥。')
                            .fontSize(14)
                            .fontColor('#CCFFFFFF')
                            .lineHeight(20)
                        }
                        .layoutWeight(1)
                        .alignItems(HorizontalAlign.Start)
                      }
                      .width('100%')
                      .alignItems(VerticalAlign.Top)

                      // 直连服务
                      Row({ space: 16 }) {
                        SymbolGlyph($r('sys.symbol.link'))
                          .fontSize(24)
                          .fontColor(['#EEFFFFFF'])
                          .margin({ top: 2 })
                        Column({ space: 4 }) {
                          Text('直连服务')
                            .fontSize(16)
                            .fontColor(Color.White)
                            .fontWeight(FontWeight.Medium)
                          Text('所有请求均由您的设备直接发送至服务商，不经过任何中间服务器，确保隐私安全。')
                            .fontSize(14)
                            .fontColor('#CCFFFFFF')
                            .lineHeight(20)
                        }
                        .layoutWeight(1)
                        .alignItems(HorizontalAlign.Start)
                      }
                      .width('100%')
                      .alignItems(VerticalAlign.Top)
                    }
                    .width('100%')
                    .padding({ left: 4, right: 4 })
                  }
                  .width('100%')
                }
                .scrollBar(BarState.Off)
                .width('100%')
                .layoutWeight(1)
                .opacity(this.expandedContentOpacity)
                .nestedScroll({
                  scrollForward: NestedScrollMode.SELF_FIRST,
                  scrollBackward: NestedScrollMode.SELF_FIRST
                })
              }
            }
            .width(this.disclaimerWidth)
            .height(this.disclaimerHeight)
            .padding(20)
          .margin({ bottom: 10 })
          .backgroundColor(this.disclaimerBgColor)
          .borderRadius(this.disclaimerBorderRadius)
          .alignItems(HorizontalAlign.Center)
          .justifyContent(this.isApiIntroExpanded ? FlexAlign.Start : FlexAlign.Center)
          .opacity(this.cardOpacities[0])
          .scale({ x: this.disclaimerScale * this.cardScales[0], y: this.disclaimerScale * this.cardScales[0] })
          .zIndex(this.isApiIntroExpanded ? 100 : 0)
          .shadow(this.isApiIntroExpanded ? {
            radius: 32,
            color: '#40000000',
            offsetX: 0,
            offsetY: 8
          } : {
            radius: 0,
            color: 'transparent',
            offsetX: 0,
            offsetY: 0
          })
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              sourceType: this.activeBtn === 99 ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT) : hdsEffect.PointLightSourceType.NONE,
              illuminatedType: this.activeBtn !== 0 ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT : hdsEffect.PointLightIlluminatedType.NONE
            })
            .buildEffect())
          .onTouch((event: TouchEvent) => {
            if (this.isApiIntroExpanded) {
              return; // 展开状态下不响应触摸
            }
            if (event.type === TouchType.Down) {
              this.pressDisclaimer();
              this.activeBtn = 99;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.releaseDisclaimer();
              this.activeBtn = 0;
            }
          })

          TokenUsageChart({
            modelName: this.currentApiAlias || this.apiOptions[this.selectedApiIndex],
            activeBtn: $activeBtn,
            isLightEffectBright: this.isLightEffectBright
          })
          .opacity(this.cardOpacities[1])
          .scale({ x: this.cardScales[1], y: this.cardScales[1] })

          Grid() {
            GridItem() {
              ConfigCard({
                title: '选择 API',
                content: this.currentApiAlias || this.apiOptions[this.selectedApiIndex],
                btnId: 1,
                icon: $r('sys.symbol.more'),
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => { this.sheetType = 'api'; this.isSheetVisible = true; },
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '选择 API 说明',
                    message: '点击选择已验证的翻译 / LLM 服务。',
                    confirm: {
                      value: '我知道了',
                      fontColor: THEMES[this.themeColorIndex].primaryColor,
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[2])
            .scale({ x: this.cardScales[2], y: this.cardScales[2] })

            GridItem() {
              ConfigCard({
                title: '配置 API',
                content: '',
                btnId: 2,
                icon: $r('sys.symbol.gearshape'),
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => {
                  animateTo({ duration: 400, curve: Curve.FastOutSlowIn }, () => {
                    this.handleConfigApi()
                  })
                },
                isSymbol: true,
                showLockIcon: this.apiConfigRequireScreenLock,
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '配置 API 说明',
                    message: '编辑、添加 API 和提示词。',
                    confirm: {
                      value: '我知道了',
                      fontColor: THEMES[this.themeColorIndex].primaryColor,
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[3])
            .scale({ x: this.cardScales[3], y: this.cardScales[3] })

            GridItem() {
              ConfigCard({
                title: '原始语言',
                content: '英语',
                btnId: 3,
                icon: $r('sys.symbol.mic_arrow_2_circlepath'),
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => {
                  // ToastUtil.showToast('当前仅支持英语作为原始语言');
                },
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '原始语言说明',
                    message: '翻译功能的原始语言，暂时仅支持英语。',
                    confirm: {
                      value: '我知道了',
                      fontColor: THEMES[this.themeColorIndex].primaryColor,
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[4])
            .scale({ x: this.cardScales[4], y: this.cardScales[4] })

            GridItem() {
              ConfigCard({
                title: '目标语言',
                content: this.getLanguageLabels()[this.selectedLanguageIndex],
                btnId: 4,
                icon: $r('sys.symbol.translate_e2c'),
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => this.openOptionSheet(
                  '目标语言',
                  '翻译、扫描结果将输出为所选语言',
                  this.getLanguageLabels(),
                  this.selectedLanguageIndex,
                  'language'
                ),
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '目标语言说明',
                    message: '翻译、扫描结果将输出为目标语言，点击选择语言。',
                    confirm: {
                      value: '我知道了',
                      fontColor: THEMES[this.themeColorIndex].primaryColor,
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[5])
            .scale({ x: this.cardScales[5], y: this.cardScales[5] })

            GridItem() {
              ConfigCard({
                title: '间隔',
                content: this.intervalOptions[this.selectedIntervalIndex] + ' 秒',
                btnId: 5,
                icon: $r('sys.symbol.clock'),
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => this.openOptionSheet(
                  '翻译间隔',
                  '设置两次翻译请求之间的最小时间间隔',
                  this.intervalOptions.map(v => v + ' 秒'),
                  this.selectedIntervalIndex,
                  'interval'
                ),
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '间隔说明',
                    message: '设置两次翻译请求之间的最小时间间隔（秒），同时也作为传译的时间间隔。\n较短的间隔能提供更实时的反馈，但会消耗更多 Token。\n默认间隔推荐为5。',
                    confirm: {
                      value: '我知道了',
                      fontColor: THEMES[this.themeColorIndex].primaryColor,
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[6])
            .scale({ x: this.cardScales[6], y: this.cardScales[6] })

            GridItem() {
              ConfigCard({
                title: '上下文',
                content: this.contextsOptions[this.selectedContextsIndex] + ' 轮',
                btnId: 6,
                icon: $r('sys.symbol.book_pages'),
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => this.openOptionSheet(
                  '历史上下文',
                  '更多上下文有助于模型理解语境，但会消耗更多 Token',
                  this.contextsOptions.map(v => v + ' 轮'),
                  this.selectedContextsIndex,
                  'contexts'
                ),
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '上下文说明',
                    message: '适用于翻译功能。设置发送给翻译模型的历史对话轮数。\n更多的上下文有助于模型理解语境，提高翻译准确度，但会消耗更多 Token。\n默认上下文推荐为3。',
                    confirm: {
                      value: '我知道了',
                      fontColor: THEMES[this.themeColorIndex].primaryColor,
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[7])
            .scale({ x: this.cardScales[7], y: this.cardScales[7] })

            GridItem() {
              ConfigCard({
                title: '温度',
                content: this.temperatureOptions[this.selectedTemperatureIndex],
                btnId: 7,
                icon: $r('sys.symbol.color_temperature_1'),
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => this.openOptionSheet(
                  '模型温度',
                  '较低更确定，较高更随机',
                  this.temperatureOptions,
                  this.selectedTemperatureIndex,
                  'temperature'
                ),
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '温度说明',
                    message: '适用于翻译、润色和扫描。控制模型输出的随机性。\n较低的值使输出更集中和确定。较高的值使输出更随机和多样。\n默认温度推荐为0.3，且不建议过大。',
                    confirm: {
                      value: '我知道了',
                      fontColor: THEMES[this.themeColorIndex].primaryColor,
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[8])
            .scale({ x: this.cardScales[8], y: this.cardScales[8] })

            GridItem() {
              ConfigCard({
                title: '最大 Token',
                content: this.maxTokensOptions[this.selectedMaxTokensIndex],
                btnId: 8,
                icon: $r('sys.symbol.doc_text_badge_arrow_right'),
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => this.openOptionSheet(
                  '最大 Token',
                  '单次回复的最大长度',
                  this.maxTokensOptions.map(v => v),
                  this.selectedMaxTokensIndex,
                  'maxTokens'
                ),
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '最大 Token 说明',
                    message: '适用于翻译、润色和扫描。设置模型单次回复生成的最大 Token 数量。\n较小的值适合简短回复，响应更快。较大的值允许更长的回复，但可能增加延迟。\n默认最大 Token 推荐为256。',
                    confirm: {
                      value: '我知道了',
                      fontColor: THEMES[this.themeColorIndex].primaryColor,
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[9])
            .scale({ x: this.cardScales[9], y: this.cardScales[9] })

            GridItem() {
              ConfigCard({
                title: 'VAD 灵敏度',
                content: this.vadSensitivityOptions[this.selectedVadSensitivityIndex],
                btnId: 9,
                icon: $r('sys.symbol.magnetic_sensor'),
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => this.openOptionSheet(
                  'VAD 灵敏度',
                  '较高更敏感但可能误报噪音',
                  this.vadSensitivityOptions,
                  this.selectedVadSensitivityIndex,
                  'vad'
                ),
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: 'VAD 灵敏度说明',
                    message: '适用于翻译功能。设置语音活动检测的灵敏度。\n较高的灵敏度更容易检测到语音，但也可能误报噪音。\n默认 VAD 灵敏度推荐为中。',
                    confirm: {
                      value: '我知道了',
                      fontColor: THEMES[this.themeColorIndex].primaryColor,
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[10])
            .scale({ x: this.cardScales[10], y: this.cardScales[10] })

            GridItem() {
              ConfigCard({
                title: '最小匹配长度',
                content: this.minMatchLenOptions[this.selectedMinMatchLenIndex] + ' 字符',
                btnId: 10,
                icon: $r('sys.symbol.root'),
                isLightEffectBright: this.isLightEffectBright,
                isDarkMode: this.isDarkMode,
                callback: () => this.openOptionSheet(
                  '最小匹配长度',
                  '智能拼接文本时的最小重叠字符数',
                  this.minMatchLenOptions.map(v => v + ' 字符'),
                  this.selectedMinMatchLenIndex,
                  'minMatch'
                ),
                activeBtn: $activeBtn,
                onInfoClick: () => {
                  AlertDialog.show({
                    title: '最小匹配长度说明',
                    message: '适用于翻译功能。设置智能拼接文本时的最小重叠字符数。\n较大的值能减少误拼接，但可能导致重复。\n默认最小匹配长度推荐为5。',
                    confirm: {
                      value: '我知道了',
                      fontColor: THEMES[this.themeColorIndex].primaryColor,
                      action: () => {}
                    }
                  })
                }
              })
            }
            .opacity(this.cardOpacities[11])
            .scale({ x: this.cardScales[11], y: this.cardScales[11] })
          }
          .columnsTemplate('1fr 1fr')
          .rowsTemplate('1fr 1fr 1fr 1fr 1fr')
          .columnsGap(10)
          .rowsGap(10)
          .padding({ left: 24, right: 24 })
          .height(560)
        }
        .width('100%')
        .padding({ bottom: 100 })
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .bindSheet($$this.isSheetVisible, this.UnifiedSheetBuilder(), {
      height: SheetSize.FIT_CONTENT,
      backgroundColor: Color.Transparent,
      blurStyle: BlurStyle.NONE,
      showClose: false,
      dragBar: false,
      onDisappear: () => {
        this.isSheetVisible = false;
      }
    })
    .titleBar({
      style: {
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_on_tertiary'),
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_on_tertiary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_on_tertiary')
            }
          }
        },
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: Color.White,
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        }
      },
      content: {
        title: { mainTitle: '配置' },
      },
      avoidLayoutSafeArea: true
    })

      // 握持快捷按钮
      if ((this.isLeftHand || this.isRightHand) && !this.isHandPopupDismissed) {
        Column() {
          List({ space: 16 }) {
            // 1. Select API
            ListItem() {
              Column() {
                this.QuickActionButton($r('sys.symbol.more'), 1, () => { this.sheetType = 'api'; this.isSheetVisible = true; })
              }
              .margin({ top: 16 })
            }
            // 2. Config API
            ListItem() {
              this.QuickActionButton($r('sys.symbol.gearshape'), 2, () => this.handleConfigApi())
            }
            // 3. Original Language
            ListItem() {
              this.QuickActionButton($r('sys.symbol.mic_arrow_2_circlepath'), 3, () => {
                // ToastUtil.showToast('当前仅支持英语作为原始语言');
              })
            }
            // 4. Target Language
            ListItem() {
              this.QuickActionButton($r('sys.symbol.translate_e2c'), 4, () => this.onCycleLanguage())
            }
            // 5. Interval
            ListItem() {
              this.QuickActionButton($r('sys.symbol.clock'), 5, () => this.openOptionSheet(
                  '翻译间隔',
                  '设置两次翻译请求之间的最小时间间隔',
                  this.intervalOptions.map(v => v + ' 秒'),
                  this.selectedIntervalIndex,
                  'interval'
                ))
            }
            // 6. Contexts
            ListItem() {
              this.QuickActionButton($r('sys.symbol.book_pages'), 6, () => this.openOptionSheet(
                  '历史上下文',
                  '更多上下文有助于模型理解语境，但会消耗更多 Token',
                  this.contextsOptions.map(v => v + ' 轮'),
                  this.selectedContextsIndex,
                  'contexts'
                ))
            }
            // 7. Temperature
            ListItem() {
              this.QuickActionButton($r('sys.symbol.color_temperature_1'), 7, () => this.openOptionSheet(
                  '模型温度',
                  '较低更确定，较高更随机',
                  this.temperatureOptions,
                  this.selectedTemperatureIndex,
                  'temperature'
                ))
            }
            // 8. Max Tokens
            ListItem() {
              this.QuickActionButton($r('sys.symbol.doc_text_badge_arrow_right'), 8, () => this.openOptionSheet(
                  '最大 Token',
                  '单次回复的最大长度',
                  this.maxTokensOptions.map(v => v),
                  this.selectedMaxTokensIndex,
                  'maxTokens'
                ))
            }
            // 9. VAD Sensitivity
            ListItem() {
              this.QuickActionButton($r('sys.symbol.magnetic_sensor'), 9, () => this.openOptionSheet(
                  'VAD 灵敏度',
                  '较高更敏感但可能误报噪音',
                  this.vadSensitivityOptions,
                  this.selectedVadSensitivityIndex,
                  'vad'
                ))
            }
            // 10. Min Match Length
            ListItem() {
              Column() {
                this.QuickActionButton($r('sys.symbol.root'), 10, () => this.openOptionSheet(
                  '最小匹配长度',
                  '智能拼接文本时的最小重叠字符数',
                  this.minMatchLenOptions.map(v => v + ' 字符'),
                  this.selectedMinMatchLenIndex,
                  'minMatch'
                ))
              }
              .margin({ bottom: 16 })
            }
          }
          .width('100%')
          .scrollBar(BarState.Off)
          .alignListItem(ListItemAlign.Center)
          .borderRadius(32)
          .clip(true)
        }
        .width(64)
        .constraintSize({ maxHeight: '50%' })
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .border({ width: 1.5, color: THEMES[this.themeColorIndex].tertiaryColor })
        .backdropBlur(20)
        .borderRadius(32)
        .position({ x: this.isLeftHand ? 0 : '100%', y: '30%' })
        .markAnchor({ x: this.isLeftHand ? 0 : '100%', y: 0 })
        .translate({ x: this.isLeftHand ? 16 : -16 })
        .alignItems(HorizontalAlign.Center)
        .clip(true)
        .transition(
          TransitionEffect.move(this.isLeftHand ? TransitionEdge.START : TransitionEdge.END)
            .animation({ duration: 300, curve: Curve.EaseOut })
        )
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal, distance: 5 })
            .onActionEnd((event: GestureEvent) => {
              // 左手时左滑关闭，右手时右滑关闭
              if ((this.isLeftHand && event.offsetX < -20) ||
                  (this.isRightHand && event.offsetX > 20)) {
                animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
                  this.isHandPopupDismissed = true;
                });
              }
            })
        )
      }
    }
    .width('100%')
    .height('100%')
  }
  
  @Builder
  QuickActionButton(icon: Resource, btnId: number, callback: () => void) {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor(this.activeBtn === btnId ? [THEMES[this.themeColorIndex].primaryColor] : [Color.White])
    }
    .width(48)
    .height(48)
    .backgroundColor(this.activeBtn === btnId ? Color.White : THEMES[this.themeColorIndex].secondaryColor)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.2)', offsetY: 4 })
    .stateStyles({
      pressed: {
        .scale({ x: 0.95, y: 0.95 })
      },
      normal: {
        .scale({ x: 1.0, y: 1.0 })
      }
    })
    .onClick(() => {
      callback();
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.activeBtn = btnId; });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.activeBtn = 0; });
      }
    })
  }

  @Builder
  UnifiedSheetBuilder() {
    if (this.sheetType === 'api') {
      ApiSelectorSheet({
        validatedSlots: this.validatedApiSlots,
        selectedApiIndex: this.selectedApiIndex,
        selectedSlotIndex: this.selectedSlotIndex,
        isDarkMode: this.isDarkMode,
        isLightEffectBright: this.isLightEffectBright,
        onSelect: (apiIndex: number, slotIndex: number) => {
          this.onSelectApi(apiIndex, slotIndex);
        },
        onClose: () => {
          this.isSheetVisible = false;
        }
      })
    } else if (this.sheetType === 'language') {
      LanguageSelectorSheet({
        title: this.sheetTitle,
        description: this.sheetDescription,
        options: this.sheetOptions,
        selectedIndex: this.sheetSelectedIndex,
        isDarkMode: this.isDarkMode,
        isLightEffectBright: this.isLightEffectBright,
        onSelect: (index: number) => {
          this.sheetSelectedIndex = index;
          this.handleSheetSelect(index);
        },
        onClose: () => {
          this.isSheetVisible = false;
        }
      })
    } else {
      OptionSelectorSheet({
        title: this.sheetTitle,
        description: this.sheetDescription,
        options: this.sheetOptions,
        selectedIndex: this.sheetSelectedIndex,
        isDarkMode: this.isDarkMode,
        isLightEffectBright: this.isLightEffectBright,
        onSelect: (index: number) => {
          this.sheetSelectedIndex = index;
          this.handleSheetSelect(index);
        },
        onClose: () => {
          this.isSheetVisible = false;
        }
      })
    }
  }
}
