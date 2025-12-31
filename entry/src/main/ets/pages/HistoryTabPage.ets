import router from '@ohos.router';
import { Session } from '../model/Session';
import { HistoryStorage } from '../storage/HistoryStorage';
import { HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode, hdsEffect } from '@kit.UIDesignKit';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { THEMES } from '../model/Theme';

const TITLE_BAR_HEIGHT_MINI: number = 100;

@Component
struct SwipeActionButton {
  @Prop icon: Resource;
  @Prop bgColor: ResourceColor;
  @Prop iconColor: ResourceColor = Color.White;
  @Prop btnId: number = 0;
  @Prop isLightEffectBright: boolean = true;
  @Prop isDarkMode: boolean = true;
  @Link activeBtnId: number;
  action: () => void = () => {};
  
  @State scaleValue: number = 1.0;

  build() {
    Column() {
      SymbolGlyph(this.icon)
        .fontSize(22)
        .fontColor([this.iconColor])
    }
    .width(48)
    .height(48)
    .borderRadius(24)
    .backgroundColor(this.bgColor)
    .justifyContent(FlexAlign.Center)
    .scale({ x: this.scaleValue, y: this.scaleValue })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.isDarkMode ? hdsEffect.PointLightSourceType.NONE :
          (this.activeBtnId === this.btnId ? (this.isLightEffectBright ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.SOFT) : hdsEffect.PointLightSourceType.NONE),
        illuminatedType: this.isDarkMode ? hdsEffect.PointLightIlluminatedType.NONE :
          (this.activeBtnId !== 0 ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT : hdsEffect.PointLightIlluminatedType.NONE)
      })
      .buildEffect())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
          this.activeBtnId = this.btnId;
          this.scaleValue = 0.9;
        });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
          this.activeBtnId = 0;
          this.scaleValue = 1.0;
        });
      }
    })
    .onClick(() => {
      this.action();
    })
  }
}

@Component
export struct HistoryTabPage {
  @Prop @Watch('onVisibleChange') isVisible: boolean = false;
  @Prop isLightEffectBright: boolean = true;
  @Prop isDarkMode: boolean = true;
  @Prop type: 'translation' | 'scan' = 'translation';
  @StorageLink('themeColorIndex') themeColorIndex: number = 0;
  @State sessions: Session[] = [];
  @State pendingDeleteId: number = -1;
  @State deleteMessage: string = '确定要删除这条历史记录吗？';
  @State isDeleteAll: boolean = false;
  @State showFavorites: boolean = false;
  @State activeSwipeBtnId: number = 0;

  // Animation states
  @State cardOffsets: number[] = [];
  @State cardOpacities: number[] = [];
  private animationTimeouts: number[] = [];

  dialogController: CustomDialogController = new CustomDialogController({
    builder: DeleteConfirmTabDialog({
      confirm: () => {
        this.confirmDelete();
      },
      message: $deleteMessage
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  })

  helpDialogController: CustomDialogController = new CustomDialogController({
    builder: HelpTabDialog(),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  })

  async confirmDelete() {
    if (this.isDeleteAll) {
      if (this.showFavorites) {
        await HistoryStorage.getInstance().deleteAllStarredSessions(this.type);
      } else {
        await HistoryStorage.getInstance().deleteAllNonStarredSessions(this.type);
      }
      this.sessions = [];
      this.isDeleteAll = false;
    } else if (this.pendingDeleteId !== -1) {
      await HistoryStorage.getInstance().deleteSession(this.pendingDeleteId);
      await this.refreshSessions();
      this.pendingDeleteId = -1;
    }
  }

  async refreshSessions() {
    if (this.showFavorites) {
      this.sessions = await HistoryStorage.getInstance().getStarredSessions(this.type);
    } else {
      this.sessions = await HistoryStorage.getInstance().getSessions(this.type);
    }
    
    // Initialize animation arrays if needed
    if (this.sessions.length > this.cardOffsets.length) {
      const newLength = this.sessions.length;
      const currentLength = this.cardOffsets.length;
      for (let i = currentLength; i < newLength; i++) {
        this.cardOffsets.push(-50); // Start from left
        this.cardOpacities.push(0);
      }
    }

    if (this.isVisible) {
      this.playAnimations();
    }
  }

  async aboutToAppear() {
    await this.refreshSessions();
  }

  aboutToDisappear() {
    this.clearAnimationTimeouts();
  }

  onVisibleChange() {
    if (this.isVisible) {
      this.resetAnimations();
      this.playAnimations();
    } else {
      this.clearAnimationTimeouts();
    }
  }

  resetAnimations() {
    this.clearAnimationTimeouts();
    for (let i = 0; i < this.cardOffsets.length; i++) {
      this.cardOffsets[i] = -50;
      this.cardOpacities[i] = 0;
    }
  }

  playAnimations() {
    // Only animate visible items or a reasonable batch
    const count = Math.min(this.sessions.length, 20); 
    for (let i = 0; i < count; i++) {
      let id = setTimeout(() => {
        animateTo({
          duration: 300,
          curve: Curve.FastOutSlowIn
        }, () => {
          this.cardOffsets[i] = 0;
          this.cardOpacities[i] = 1.0;
        })
      }, i * 50);
      this.animationTimeouts.push(id);
    }
    // Immediately show remaining items to avoid them being hidden forever if list is long
    for (let i = count; i < this.sessions.length; i++) {
       this.cardOffsets[i] = 0;
       this.cardOpacities[i] = 1.0;
    }
  }

  clearAnimationTimeouts() {
    this.animationTimeouts.forEach(id => clearTimeout(id));
    this.animationTimeouts = [];
  }

  async toggleStar(session: Session) {
    const newStarred = !session.isStarred;
    await HistoryStorage.getInstance().updateStarred(session.id, newStarred);
    const newSessions = this.showFavorites 
      ? await HistoryStorage.getInstance().getStarredSessions(this.type)
      : await HistoryStorage.getInstance().getSessions(this.type);
    animateTo({
      duration: 300,
      curve: Curve.EaseInOut
    }, () => {
      this.sessions = newSessions;
    });
    promptAction.showToast({
      message: newStarred ? '已添加到收藏' : '已取消收藏'
    });
  }

  shareSession(session: Session) {
    let shareContent = `${session.title}\n`;
    shareContent += `时间: ${new Date(session.startTime).toLocaleString()}\n\n`;

    if (session.summary) {
      shareContent += `【AI总结】\n${session.summary}\n\n`;
    }

    shareContent += `【原文】\n${session.originalText}\n\n`;

    if (session.translatedText) {
      shareContent += `【译文】\n${session.translatedText}`;
    }

    try {
      const sharedData: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.PLAIN_TEXT,
        title: session.title,
        content: shareContent
      });

      const controller: systemShare.ShareController = new systemShare.ShareController(sharedData);

      const context = getContext(this) as common.UIAbilityContext;

      controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      });
    } catch (error) {
      promptAction.showToast({ message: '分享失败' });
    }
  }

  @Builder
  SessionItemBuilder(session: Session, index: number) {
    Row() {
      if (session.type === 'scan' && session.imageUri) {
        Image(session.imageUri)
          .width(60)
          .height(80)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .margin({ right: 12 })
      }

      Column() {
        Text(session.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(new Date(session.startTime).toLocaleString())
          .fontSize(14)
          .fontColor($r('sys.color.font_on_secondary'))
          .margin({ top: 4, bottom: 4 })
        if (session.summary) {
          Text(session.summary)
            .fontSize(14)
            .fontColor($r('sys.color.font_on_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 8 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('calc(100% - 48vp)')
    .padding(16)
    .margin({ left: 24, right: 24 })
    .backgroundColor(THEMES[this.themeColorIndex].secondaryColor)
    .borderRadius(24)
    .opacity(this.cardOpacities[index] ?? 1)
    .translate({ x: this.cardOffsets[index] ?? 0 })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
      })
      .buildEffect())
    .onClick(() => {
      if (session.type === 'scan') {
        // TODO: 跳转到扫描详情页，或者复用 ScanPage？
        // 暂时复用 SessionDetailPage，但需要 SessionDetailPage 支持显示图片
        router.pushUrl({
          url: 'pages/SessionDetailPage',
          params: {
            sessionId: session.id
          }
        });
      } else {
        router.pushUrl({
          url: 'pages/SessionDetailPage',
          params: {
            sessionId: session.id
          }
        });
      }
    })
  }

  @Builder
  DeleteButton(id: number, session: Session) {
    Row({ space: 8 }) {
      // 删除按钮
      SwipeActionButton({
        icon: $r('sys.symbol.trash'),
        bgColor: Color.Red,
        btnId: 1,
        isLightEffectBright: this.isLightEffectBright,
        isDarkMode: this.isDarkMode,
        activeBtnId: $activeSwipeBtnId,
        action: () => {
          this.pendingDeleteId = id;
          this.deleteMessage = '确定要删除这条历史记录吗？';
          this.isDeleteAll = false;
          this.dialogController.open();
        }
      })

      // 收藏按钮
      SwipeActionButton({
        icon: session.isStarred ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'),
        bgColor: '#FFB800',
        btnId: 2,
        isLightEffectBright: this.isLightEffectBright,
        isDarkMode: this.isDarkMode,
        activeBtnId: $activeSwipeBtnId,
        action: () => {
          this.toggleStar(session);
        }
      })

      // 分享按钮
      SwipeActionButton({
        icon: $r('sys.symbol.share'),
        bgColor: '#4CAF50',
        btnId: 3,
        isLightEffectBright: this.isLightEffectBright,
        isDarkMode: this.isDarkMode,
        activeBtnId: $activeSwipeBtnId,
        action: () => {
          this.shareSession(session);
        }
      })
    }
    .height('100%')
    .padding({ left: 8, right: 8 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Stack() {
      // 主题背景图片
      if (THEMES[this.themeColorIndex].backgroundImage) {
        Image(THEMES[this.themeColorIndex].backgroundImage)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      }

      HdsNavigation() {
      List({ space: 8 }) {
        ListItem() {
          Column().height(TITLE_BAR_HEIGHT_MINI)
        }

        ForEach(this.sessions, (session: Session, index: number) => {
          ListItem() {
            this.SessionItemBuilder(session, index)
          }
          .swipeAction({
            end: {
              builder: () => {
                this.DeleteButton(session.id, session)
              }
            }
          })
        }, (session: Session) => `${session.id}_${session.isStarred}_${session.summary?.length || 0}`)
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: 36 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, currentRatio: number) => {
        if (isVisible && currentRatio > 0) {
          this.refreshSessions();
        }
      })
    }
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(false)
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
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: Color.White
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: Color.White
            }
          }
        }
      },
      content: {
        title: {
          mainTitle: this.showFavorites 
            ? (this.type === 'scan' ? '扫描收藏' : '翻译收藏')
            : (this.type === 'scan' ? '扫描历史' : '翻译历史'),
        },
        menu: {
          value: [
            {
              content: {
                label: '解释',
                icon: $r('sys.symbol.questionmark_circle'),
                isEnabled: true,
                action: () => {
                  animateTo({
                    duration: 300,
                    curve: Curve.Smooth
                  }, () => {
                    this.helpDialogController.open();
                  });
                }
              }
            },
            {
              content: {
                label: this.showFavorites ? '全部历史' : '收藏夹',
                icon: this.showFavorites ? $r('sys.symbol.clock') : $r('sys.symbol.star_fill'),
                isEnabled: true,
                action: () => {
                  animateTo({
                    duration: 300,
                    curve: Curve.Smooth
                  }, () => {
                    this.showFavorites = !this.showFavorites;
                    this.refreshSessions();
                  });
                }
              }
            },
            {
              content: {
                label: '一键删除',
                icon: $r('sys.symbol.trash_fill'),
                isEnabled: true,
                action: () => {
                  animateTo({
                    duration: 300,
                    curve: Curve.Smooth
                  }, () => {
                    if (this.sessions.length > 0) {
                      this.deleteMessage = this.showFavorites ? '确定要删除所有收藏记录吗？' : '确定要删除所有历史记录吗？';
                      this.isDeleteAll = true;
                      this.dialogController.open();
                    }
                  });
                }
              }
            }
          ]
        },
      },
      avoidLayoutSafeArea: true
    })
    }
    .width('100%')
    .height('100%')
  }
}

@CustomDialog
struct DeleteConfirmTabDialog {
  controller: CustomDialogController
  confirm: () => void = () => {}
  @Link message: string

  build() {
    Column() {
      Text('删除确认')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.Black)
        .margin({ top: 24, bottom: 12 })
        .textAlign(TextAlign.Center)
      
      Text(this.message)
        .fontSize(16)
        .fontColor('#666666')
        .margin({ bottom: 24 })
        .textAlign(TextAlign.Center)

      Row() {
        Button('取消')
          .borderRadius(30)
          .onClick(() => {
            this.controller.close()
          })
          .backgroundColor('#F5F5F5')
          .fontColor('#666666')
          .layoutWeight(1)
          .margin({ right: 12 })
        
        Button('删除')
          .borderRadius(30)
          .onClick(() => {
            this.confirm()
            this.controller.close()
          })
          .backgroundColor('#FF0000')
          .fontColor(Color.White)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .width(300)
    .backgroundColor(Color.White)
    .borderRadius(30)
    .alignItems(HorizontalAlign.Center)
  }
}

@CustomDialog
struct HelpTabDialog {
  controller: CustomDialogController
  @StorageLink('themeColorIndex') themeColorIndex: number = 0;

  build() {
    Column() {
      Text('历史记录使用说明')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.Black)
        .margin({ top: 24, bottom: 16 })
        .textAlign(TextAlign.Center)

      Column({ space: 12 }) {
        Row({ space: 8 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(18)
              .fontColor([Color.White])
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor(Color.Red)
          .justifyContent(FlexAlign.Center)

          Text('左滑卡片点击红色按钮删除单条记录')
            .fontSize(14)
            .fontColor('#333333')
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 8 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.star'))
              .fontSize(18)
              .fontColor([Color.White])
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor('#FFB800')
          .justifyContent(FlexAlign.Center)

          Text('左滑卡片点击黄色按钮收藏（移入收藏夹）')
            .fontSize(14)
            .fontColor('#333333')
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 8 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.share'))
              .fontSize(18)
              .fontColor([Color.White])
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor('#4CAF50')
          .justifyContent(FlexAlign.Center)

          Text('左滑卡片点击绿色按钮分享记录')
            .fontSize(14)
            .fontColor('#333333')
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 8 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.star_fill'))
              .fontSize(18)
              .fontColor([Color.White])
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor('#666666')
          .justifyContent(FlexAlign.Center)

          Text('点击右上角菜单切换收藏夹/全部历史')
            .fontSize(14)
            .fontColor('#333333')
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 8 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.trash_fill'))
              .fontSize(18)
              .fontColor([Color.White])
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor('#666666')
          .justifyContent(FlexAlign.Center)

          Text('历史/收藏分别删除，互不影响')
            .fontSize(14)
            .fontColor('#333333')
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Divider()
          .margin({ top: 8, bottom: 8 })

        Text('点击卡片可查看详情并生成 AI 总结')
          .fontSize(14)
          .fontColor('#666666')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Button('我知道了')
        .width('80%')
        .borderRadius(30)
        .margin({ top: 20, bottom: 16 })
        .backgroundColor(THEMES[this.themeColorIndex].primaryColor)
        .fontColor(Color.White)
        .onClick(() => {
          this.controller.close();
        })
    }
    .width(320)
    .backgroundColor(Color.White)
    .borderRadius(30)
    .alignItems(HorizontalAlign.Center)
  }
}

// Entry wrapper for router navigation
@Entry
@Component
struct HistoryPage {
  @StorageLink('isLightEffectBright') isLightEffectBright: boolean = true;
  @StorageLink('themeMode') themeMode: number = 1;
  @State type: 'translation' | 'scan' = 'translation';
  
  get isDarkMode(): boolean {
    return this.themeMode === 1;
  }

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['type']) {
      this.type = params['type'] as 'translation' | 'scan';
    }
  }

  build() {
    Column() {
      HistoryTabPage({
        isVisible: true,
        isLightEffectBright: this.isLightEffectBright,
        isDarkMode: this.isDarkMode,
        type: this.type
      })
    }
    .width('100%')
    .height('100%')
  }
}
