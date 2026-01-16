import { TokenUsageStorage, ModelTokenUsage } from '../storage/TokenUsageStorage';
import { hdsEffect } from '@kit.UIDesignKit';
import { THEMES } from '../model/Theme';

class ChartPoint {
  x: number = 0;
  y: number = 0;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}

@Component
export struct TokenUsageChart {
  @Watch('onModelChange') @Prop modelName: string;
  @StorageProp('TokenUsage_LastUpdate') @Watch('onDataUpdate') lastUpdate: number = 0;
  @StorageProp('TokenUsage_Ready') @Watch('onStorageReady') isStorageReady: boolean = false;
  
  @State usageData: ModelTokenUsage = {};
  @State points: number[] = []; // [x1, y1, x2, y2, ...] normalized
  @State dates: string[] = [];
  @State maxTokens: number = 100;

  // Visual effects state
  @Link activeBtn: number;
  @Prop isLightEffectBright: boolean = true;
  @State scaleValue: number = 1.0;
  @State bgColor: ResourceColor = '#803c1464';
  @State textColor: ResourceColor = Color.White;
  @State subTextColor: ResourceColor = '#CCFFFFFF';
  @State isPressed: boolean = false;
  @StorageLink('themeColorIndex') @Watch('onThemeColorChange') themeColorIndex: number = 0;
  
  private readonly btnId: number = 98;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  aboutToAppear() {
    // 初始化背景色为当前主题色
    this.applyTheme(false);
    this.loadData();
  }

  onModelChange() {
    this.loadData();
  }

  onDataUpdate() {
    this.loadData();
  }

  onStorageReady() {
    if (this.isStorageReady) {
      this.loadData();
    }
  }

  onThemeColorChange() {
    // 当主题切换时，按当前按压状态更新颜色
    this.applyTheme(this.isPressed);
    this.drawChart();
  }

  private applyTheme(isPressed: boolean) {
    if (isPressed) {
      this.bgColor = Color.White;
      this.textColor = THEMES[this.themeColorIndex].primaryColor;
      this.subTextColor = THEMES[this.themeColorIndex].primaryColor;
    } else {
      this.bgColor = THEMES[this.themeColorIndex].secondaryColor;
      this.textColor = Color.White;
      this.subTextColor = '#CCFFFFFF';
    }
  }

  // 将主题主色转换成 rgba 字符串，避免不同颜色格式解析差异
  private primaryRgba(alpha: number): string {
    const base = THEMES[this.themeColorIndex].primaryColor.replace('#', '');
    const hex = base.length === 8 ? base.substring(2) : base; // 兼容可能的 AARRGGBB
    const r = parseInt(hex.substring(0, 2), 16);
    const g = parseInt(hex.substring(2, 4), 16);
    const b = parseInt(hex.substring(4, 6), 16);
    const a = Math.max(0, Math.min(1, alpha));
    return `rgba(${r}, ${g}, ${b}, ${a})`;
  }

  press(): void {
    animateTo({ duration: 100, curve: Curve.EaseIn }, () => {
      this.isPressed = true;
      this.scaleValue = 0.95;
      this.applyTheme(true);
      this.drawChart(); // Redraw canvas with new colors
    });
  }

  release(): void {
    animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
      this.isPressed = false;
      this.scaleValue = 1.0;
      this.applyTheme(false);
      this.drawChart(); // Redraw canvas with new colors
    });
  }

  async loadData() {
    // Try to get from AppStorage first for immediate update if available
    const storageData = AppStorage.get<ModelTokenUsage>(`TokenUsage_${this.modelName}`);
    if (storageData) {
      this.usageData = storageData;
    } else {
      // Fallback to loading from disk
      const storage = TokenUsageStorage.getInstance();
      this.usageData = await storage.getModelUsage(this.modelName);
    }
    this.processData();
  }

  processData() {
    const entries = Object.entries(this.usageData).sort((a, b) => a[0].localeCompare(b[0]));
    // Take last 7 days for better visualization
    const recentEntries = entries.slice(-7);
    
    if (recentEntries.length === 0) {
      this.points = [];
      this.dates = [];
      this.maxTokens = 100;
      this.drawChart();
      return;
    }

    this.dates = recentEntries.map(e => e[0].slice(5)); // MM-DD
    const values = recentEntries.map(e => e[1]);
    this.maxTokens = Math.max(...values, 100); // Minimum scale 100

    // We will calculate drawing points in drawChart because we need canvas size
    this.drawChart();
  }

  drawChart() {
    if (!this.context) return;
    
    const isPressed = this.isPressed;
    const width = this.context.width;
    const height = this.context.height;
    const padding = 20;
    const topPadding = 35; // Extra space for top label
    const graphWidth = width - padding * 2;
    const graphHeight = height - padding - topPadding;

    this.context.clearRect(0, 0, width, height);

    // Draw background
    // this.context.fillStyle = '#803c1464';
    // this.context.fillRect(0, 0, width, height);

    if (this.dates.length === 0) {
      this.context.fillStyle = this.subTextColor as string;
      this.context.font = '14vp sans-serif';
      this.context.textAlign = 'center';
      this.context.fillText('暂无数据', width / 2, height / 2);
      return;
    }

    const entries = Object.entries(this.usageData).sort((a, b) => a[0].localeCompare(b[0])).slice(-7);
    const values = entries.map(e => e[1]);
    
    // Calculate points
    const points: ChartPoint[] = [];
    const stepX = graphWidth / (Math.max(values.length - 1, 1));
    
    values.forEach((val, index) => {
      const x = padding + index * stepX;
      const y = height - padding - (val / this.maxTokens) * graphHeight;
      points.push(new ChartPoint(x, y));
    });

    // Build curve path helper
    const buildCurvePath = () => {
      this.context.beginPath();
      if (points.length === 1) {
        this.context.moveTo(padding, height - padding);
        this.context.lineTo(points[0].x, points[0].y);
      } else {
        this.context.moveTo(points[0].x, points[0].y);
        for (let i = 0; i < points.length - 1; i++) {
          const p0 = points[i];
          const p1 = points[i + 1];
          // Simple bezier control points for smoothing
          const cp1x = p0.x + (p1.x - p0.x) / 2;
          const cp1y = p0.y;
          const cp2x = p0.x + (p1.x - p0.x) / 2;
          const cp2y = p1.y;
          this.context.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p1.x, p1.y);
        }
      }
    };

    // Draw fill first to避免在曲线位置叠出第二条线
    buildCurvePath();
    this.context.lineTo(points[points.length - 1].x, height - padding);
    this.context.lineTo(points[0].x, height - padding);
    this.context.closePath();
    const gradient = this.context.createLinearGradient(0, 0, 0, height);
    if (isPressed) {
      gradient.addColorStop(0, this.primaryRgba(0.55));
      gradient.addColorStop(1, this.primaryRgba(0.15));
    } else {
      gradient.addColorStop(0, '#59FFFFFF'); // 0x59 = ~35%
      gradient.addColorStop(1, '#00FFFFFF');
    }
    this.context.fillStyle = gradient;
    this.context.fill();

    // Then stroke the curve once
    buildCurvePath();
    this.context.lineWidth = 3;
    this.context.strokeStyle = this.textColor as string;
    this.context.lineCap = 'round';
    this.context.lineJoin = 'round';
    this.context.stroke();

    // Draw dots and labels
    this.context.fillStyle = this.textColor as string;
    this.context.textAlign = 'center';
    this.context.font = '10vp sans-serif';
    
    points.forEach((p, i) => {
      // Dot
      this.context.beginPath();
      this.context.arc(p.x, p.y, 4, 0, Math.PI * 2);
      this.context.fillStyle = this.textColor as string;
      this.context.fill();

      // Date label
      this.context.fillStyle = this.subTextColor as string;
      this.context.fillText(this.dates[i], p.x, height - 5);
      
      // Value label
      this.context.fillStyle = this.textColor as string;
      this.context.fillText(values[i].toString(), p.x, p.y - 12);
    });
    
    // Draw max value on Y axis - Removed to avoid overlap
    // this.context.textAlign = 'left';
    // this.context.fillStyle = this.textColor as string;
    // this.context.fillText(this.maxTokens.toString(), 5, padding);
  }

  build() {
    Column() {
      Row() {
        Text('Token 统计')
          .fontSize(16)
          .fontColor(this.textColor)
          .fontWeight(FontWeight.Medium)

        SymbolGlyph($r('sys.symbol.info_circle'))
          .fontSize(16)
          .fontColor([this.subTextColor])
          .margin({ left: 6 })
          .onClick(() => {
            AlertDialog.show({
              title: 'Token 统计说明',
              message: '此数据仅在本地统计，用于估算您的使用量。\n不同模型对 Token 的计算方式可能略有差异，具体计费请以 API 提供商为准。',
              confirm: {
                value: '我知道了',
                fontColor: THEMES[this.themeColorIndex].primaryColor,
                action: () => {}
              }
            })
          })

        Blank()
        Text(this.modelName)
          .fontSize(12)
          .fontColor(this.subTextColor)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16 })

      Canvas(this.context)
        .width('100%')
        .height(120)
        .onReady(() => {
          this.drawChart();
        })
    }
    .width('calc(100% - 32vp)')
    .shadow({ radius: 10, color: $r('sys.color.comp_background_tertiary')})
    .height(160)
    .backgroundColor(this.bgColor)
    .borderRadius(26)
    .margin({ bottom: 10 })
    .alignItems(HorizontalAlign.Center)
    .scale({ x: this.scaleValue, y: this.scaleValue })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.activeBtn === this.btnId ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT) : hdsEffect.PointLightSourceType.NONE,
        illuminatedType: this.activeBtn !== 0 ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT : hdsEffect.PointLightIlluminatedType.NONE
      })
      .buildEffect())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.press();
        this.activeBtn = this.btnId;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.release();
        this.activeBtn = 0;
      }
    })
  }
}
