import { webview } from '@kit.ArkWeb';
import { url } from '@kit.ArkTS';
import common from '@ohos.app.ability.common';

export interface PolicyHighlight {
  title: string;
  description: string | url.URL;
}

export interface PolicySheetConfig {
  title: string;
  intro: string;
  action: string;
  asset?: Resource;
  useWeb: boolean;
  highlights?: Array<PolicyHighlight>;
}

export enum PolicySheetType {
  Privacy = 0,
  Terms,
  About
}

function resolveHighlightText(desc: string | url.URL): string {
  if (typeof desc === 'string') {
    return desc;
  }
  return desc.toString();
}

export function getPolicySheetConfig(type: PolicySheetType, versionName: string = ''): PolicySheetConfig {
  switch (type) {
    case PolicySheetType.Terms:
      return {
        title: '用户协议',
        intro: '阅读并同意最新的《用户协议》，了解使用条款、账号安全与服务边界。',
        action: '我已知晓',
        asset: $rawfile('html/agreement.html'),
        useWeb: true
      };
    case PolicySheetType.About:
      return {
        title: '关于 Voot',
        intro: 'Voot 致力于安全、隐私与易用。',
        action: '继续体验',
        useWeb: false,
        highlights: [
          {
            title: '版本信息',
            description: versionName || 'Unknown'
          },
          {
            title: '项目仓库',
            description: 'https://github.com/YANGZX22/Voot'
          },
          {
            title: '联系我们',
            description: 'mailto:voot@mail.yangzixiao.com'
          }
        ]
      };
    case PolicySheetType.Privacy:
    default:
      return {
        title: '隐私政策',
        intro: '我们严格遵循最小化采集原则，不会上传语音与密钥，请在使用前阅读《关于 Voot 与隐私的声明》。',
        action: '我已知晓',
        asset: $rawfile('html/privacy.html'),
        useWeb: true
      };
  }
}

@Builder
export function PolicySheetContent(
  config: PolicySheetConfig,
  controller: webview.WebviewController,
  actionHandler: () => void,
  context?: common.UIAbilityContext
) {
  Column() {
    Blank().height(8);
    Text(config.title)
      .fontSize(20)
      .fontWeight(FontWeight.Medium)
      .margin({ bottom: 12 })
      .fontColor(Color.White)
    Text(config.intro)
      .fontSize(14)
      .fontColor(Color.Grey)
      .textAlign(TextAlign.Start)
      .margin({ bottom: 16 })
    if (config.useWeb && config.asset) {
      Web({
        src: config.asset,
        controller
      })
        .width('100%')
        .height(260)
        .margin({ bottom: 24 })
    } else if (config.highlights && config.highlights.length > 0) {
      Column() {
        List() {
          ForEach(config.highlights, (item: PolicyHighlight, index?: number) => {
            ListItem() {
              Column() {
                Text(item.title)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Color.White)
                  .margin({ bottom: 4 })
                Text(resolveHighlightText(item.description).replace('mailto:', ''))
                  .fontSize(14)
                  .fontColor((resolveHighlightText(item.description).startsWith('http') || resolveHighlightText(item.description).startsWith('mailto')) ? '#80D1A8FF' : Color.Grey)
                  .lineHeight(20)
                  .onClick(() => {
                    const desc = resolveHighlightText(item.description);
                    if (context && (desc.startsWith('http') || desc.startsWith('mailto'))) {
                      context.startAbility({
                        action: 'ohos.want.action.viewData',
                        entities: ['entity.system.browsable'],
                        uri: desc
                      });
                    }
                  })
              }
              .width('100%')
            }
            .padding({ top: 12, bottom: 12 })
          }, (_item: PolicyHighlight, index?: number) => (index ?? 0).toString())
        }
        .divider({ strokeWidth: 0.5, color: '#22ffffff' })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .margin({ bottom: 24 })
      .backgroundColor('#331b1b1b')
      .borderRadius(18)
    } else {
      Text('VOOT 聚焦实时翻译与字幕体验，更多信息敬请期待。')
        .fontSize(14)
        .fontColor(Color.Grey)
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding({ left: 16, right: 16, top: 12, bottom: 24 })
        .backgroundColor('#331b1b1b')
        .borderRadius(18)
        .margin({ bottom: 24 })
    }
    Button(config.action)
      .type(ButtonType.Capsule)
      .backgroundColor('#e63c1464')
      .width('100%')
      .height(44)
      .onClick(() => {
        actionHandler();
      })
  }
  .padding({ left: 24, right: 24, top: 16, bottom: 24 })
  .backgroundColor(Color.Transparent)
  .borderRadius({ topLeft: 24, topRight: 24 })
}
