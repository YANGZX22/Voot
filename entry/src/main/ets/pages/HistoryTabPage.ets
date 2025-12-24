import router from '@ohos.router';
import { Session } from '../model/Session';
import { HistoryStorage } from '../storage/HistoryStorage';
import { HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';

const TITLE_BAR_HEIGHT_MINI: number = 94;

@Component
export struct HistoryTabPage {
  @State sessions: Session[] = [];
  @State pendingDeleteId: number = -1;
  @State deleteMessage: string = '确定要删除这条历史记录吗？';
  @State isDeleteAll: boolean = false;
  @State showFavorites: boolean = false;

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
        await HistoryStorage.getInstance().deleteAllStarredSessions();
      } else {
        await HistoryStorage.getInstance().deleteAllNonStarredSessions();
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
      this.sessions = await HistoryStorage.getInstance().getStarredSessions();
    } else {
      this.sessions = await HistoryStorage.getInstance().getSessions();
    }
  }

  async aboutToAppear() {
    await this.refreshSessions();
  }

  async toggleStar(session: Session) {
    const newStarred = !session.isStarred;
    await HistoryStorage.getInstance().updateStarred(session.id, newStarred);
    const newSessions = this.showFavorites 
      ? await HistoryStorage.getInstance().getStarredSessions()
      : await HistoryStorage.getInstance().getSessions();
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
  SessionItemBuilder(session: Session) {
    Column() {
      Text(session.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
      Text(new Date(session.startTime).toLocaleString())
        .fontSize(14)
        .fontColor('#AAAAAA')
        .margin({ top: 4, bottom: 4 })
      if (session.summary) {
        Text(session.summary)
          .fontSize(14)
          .fontColor('#888888')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor('#803c1464')
    .borderRadius(24)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/SessionDetailPage',
        params: {
          sessionId: session.id
        }
      });
    })
  }

  @Builder
  DeleteButton(id: number, session: Session) {
    Row({ space: 8 }) {
      // 删除按钮 - 红色
      Column() {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(22)
          .fontColor([Color.White])
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .backgroundColor(Color.Red)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.pendingDeleteId = id;
        this.deleteMessage = '确定要删除这条历史记录吗？';
        this.isDeleteAll = false;
        this.dialogController.open();
      })

      // 收藏按钮 - 黄色
      Column() {
        SymbolGlyph(session.isStarred ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
          .fontSize(22)
          .fontColor([Color.White])
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .backgroundColor('#FFB800')
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.toggleStar(session);
      })

      // 分享按钮 - 绿色
      Column() {
        SymbolGlyph($r('sys.symbol.share'))
          .fontSize(22)
          .fontColor([Color.White])
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .backgroundColor('#4CAF50')
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.shareSession(session);
      })
    }
    .height('100%')
    .padding({ left: 8, right: 8 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    HdsNavigation() {
      List({ space: 8 }) {
        ListItem() {
          Column().height(TITLE_BAR_HEIGHT_MINI)
        }

        ForEach(this.sessions, (session: Session) => {
          ListItem() {
            this.SessionItemBuilder(session)
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
      .padding({ left: 16, right: 16, bottom: 36 })
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
    .hideBackButton(true)
    .titleBar({
      style: {
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
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
            }
          }
        }
      },
      content: {
        title: {
          mainTitle: this.showFavorites ? '收藏' : '历史',
        },
        menu: {
          value: [
            {
              content: {
                label: '解释',
                icon: $r('sys.symbol.info_circle'),
                isEnabled: true,
                action: () => {
                  this.helpDialogController.open();
                }
              }
            },
            {
              content: {
                label: this.showFavorites ? '全部历史' : '收藏夹',
                icon: this.showFavorites ? $r('sys.symbol.clock') : $r('sys.symbol.star_fill'),
                isEnabled: true,
                action: () => {
                  this.showFavorites = !this.showFavorites;
                  this.refreshSessions();
                }
              }
            },
            {
              content: {
                label: '一键删除',
                icon: $r('sys.symbol.trash_fill'),
                isEnabled: true,
                action: () => {
                  if (this.sessions.length > 0) {
                    this.deleteMessage = this.showFavorites ? '确定要删除所有收藏记录吗？' : '确定要删除所有历史记录吗？';
                    this.isDeleteAll = true;
                    this.dialogController.open();
                  }
                }
              }
            }
          ]
        },
      },
      avoidLayoutSafeArea: true
    })
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

      Button('知道了')
        .width('80%')
        .borderRadius(30)
        .margin({ top: 20, bottom: 16 })
        .backgroundColor('#3c1464')
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
