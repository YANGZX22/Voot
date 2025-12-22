/**
 * PiP (Picture-in-Picture) Subtitle Manager
 *
 * Implements floating subtitle window using PiP, no SYSTEM_FLOAT_WINDOW permission required.
 * Based on HarmonyOS PiPWindow API.
 */

import { PiPWindow } from '@kit.ArkUI';
import { BusinessError } from '@ohos.base';
import { NodeController, FrameNode, BuilderNode, UIContext } from '@kit.ArkUI';
import { typeNode } from '@ohos.arkui.node';
import common from '@ohos.app.ability.common';

const TAG = '[PipSubtitle]';

/**
 * Subtitle parameters interface
 */
export interface SubtitleParams {
  text: string;
  fontSize: number;
  fontColor: string;
  backgroundColor: string;
}

/**
 * Subtitle builder - used for PiP customUIController
 */
@Builder
function subtitleBuilder(params: SubtitleParams) {
  Column() {
    Text(params.text)
      .fontSize(params.fontSize)
      .fontColor(params.fontColor)
      .textAlign(TextAlign.Center)
      .maxLines(4)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
  }
  .width('100%')
  .height('100%')
  .backgroundColor(params.backgroundColor)
  .justifyContent(FlexAlign.Center)
}

/**
 * Subtitle node controller - for PiP custom UI
 */
class SubtitleNodeController extends NodeController {
  private subtitleNode: BuilderNode<[SubtitleParams]> | null = null;
  private uiContext: UIContext | null = null;
  private params: SubtitleParams;

  constructor() {
    super();
    this.params = {
      text: '字幕已就绪',
      fontSize: 20,
      fontColor: '#FFFFFF',
      backgroundColor: '#3c1464'
    };
  }

  setUIContext(context: UIContext): void {
    this.uiContext = context;
  }

  makeNode(uiContext: UIContext): FrameNode | null {
    if (!this.uiContext) {
      this.uiContext = uiContext;
    }

    this.subtitleNode = new BuilderNode<[SubtitleParams]>(uiContext);
    this.subtitleNode.build(wrapBuilder<[SubtitleParams]>(subtitleBuilder), this.params);
    return this.subtitleNode.getFrameNode();
  }

  updateText(text: string): void {
    if (this.params.text === text) {
      return;
    }
    this.params.text = text;
    if (this.subtitleNode && this.uiContext) {
      this.subtitleNode.update(this.params);
    }
  }

  updateStyle(style: Partial<SubtitleParams>): void {
    if (style.fontSize !== undefined) {
      this.params.fontSize = style.fontSize;
    }
    if (style.fontColor !== undefined) {
      this.params.fontColor = style.fontColor;
    }
    if (style.backgroundColor !== undefined) {
      this.params.backgroundColor = style.backgroundColor;
    }
    if (this.subtitleNode && this.uiContext) {
      this.subtitleNode.update(this.params);
    }
  }

  getParams(): SubtitleParams {
    return this.params;
  }
}

/**
 * PiP Subtitle Manager - Singleton pattern
 */
export class PipSubtitleManager {
  private static instance: PipSubtitleManager | null = null;

  private pipController: PiPWindow.PiPController | null = null;
  private xComponentController: XComponentController | null = null;
  private nodeController: SubtitleNodeController;
  private isInitialized: boolean = false;
  private isPipRunning: boolean = false;
  private lifecycleCallback: ((state: PiPWindow.PiPState) => void) | null = null;
  private context: common.UIAbilityContext | null = null;
  private uiContext: UIContext | null = null;

  private constructor() {
    this.nodeController = new SubtitleNodeController();
  }

  /**
   * Get singleton instance
   */
  static getInstance(): PipSubtitleManager {
    if (!PipSubtitleManager.instance) {
      PipSubtitleManager.instance = new PipSubtitleManager();
    }
    return PipSubtitleManager.instance;
  }

  /**
   * Set XComponent controller
   */
  setXComponentController(controller: XComponentController): void {
    this.xComponentController = controller;
  }

  /**
   * Check if PiP is available
   */
  isPipEnabled(): boolean {
    try {
      return PiPWindow.isPiPEnabled();
    } catch (e) {
      console.error(`${TAG} isPipEnabled check failed: ${JSON.stringify(e)}`);
      return false;
    }
  }

  /**
   * Initialize PiP controller
   * @param ctx - UIAbilityContext
   * @param uiContext - UIContext
   * @param contentHeight - Initial content height for PiP window in pixels (default: 200)
   */
  async init(ctx: common.UIAbilityContext, uiContext: UIContext, contentHeight: number = 200): Promise<boolean> {
    if (this.isInitialized) {
      console.info(`${TAG} Already initialized`);
      return true;
    }

    if (!this.isPipEnabled()) {
      console.error(`${TAG} PiP is disabled on this device`);
      return false;
    }

    this.context = ctx;
    this.uiContext = uiContext;
    this.nodeController.setUIContext(uiContext);

    // Ensure XComponentController is available
    if (!this.xComponentController) {
      this.xComponentController = new XComponentController();
    }

    try {
      // Create PiP configuration
      // Use VIDEO_LIVE template, suitable for real-time content
      // Width is fixed at 400, height is configurable for subtitle display
      const config: PiPWindow.PiPConfiguration = {
        context: ctx,
        componentController: this.xComponentController,
        templateType: PiPWindow.PiPTemplateType.VIDEO_LIVE,
        contentWidth: 400,
        contentHeight: contentHeight,
        // Use customUIController to display subtitles
        customUIController: this.nodeController
      };

      // Create PiP controller
      this.pipController = await PiPWindow.create(config);

      // Disable auto start
      this.pipController.setAutoStartEnabled(false);

      // Register state change callback
      this.pipController.on('stateChange', (state: PiPWindow.PiPState, reason: string) => {
        this.handleStateChange(state, reason);
      });

      this.isInitialized = true;
      console.info(`${TAG} PiP controller initialized successfully`);
      return true;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`${TAG} Failed to create PiP controller: ${error.code}, ${error.message}`);
      return false;
    }
  }

  /**
   * Handle PiP state change
   */
  private handleStateChange(state: PiPWindow.PiPState, reason: string): void {
    let stateStr = '';
    switch (state) {
      case PiPWindow.PiPState.ABOUT_TO_START:
        stateStr = 'ABOUT_TO_START';
        break;
      case PiPWindow.PiPState.STARTED:
        stateStr = 'STARTED';
        this.isPipRunning = true;
        break;
      case PiPWindow.PiPState.ABOUT_TO_STOP:
        stateStr = 'ABOUT_TO_STOP';
        break;
      case PiPWindow.PiPState.STOPPED:
        stateStr = 'STOPPED';
        this.isPipRunning = false;
        break;
      case PiPWindow.PiPState.ABOUT_TO_RESTORE:
        stateStr = 'ABOUT_TO_RESTORE';
        break;
      case PiPWindow.PiPState.ERROR:
        stateStr = 'ERROR';
        this.isPipRunning = false;
        break;
    }

    console.info(`${TAG} stateChange: ${stateStr}, reason: ${reason}`);

    if (this.lifecycleCallback) {
      this.lifecycleCallback(state);
    }
  }

  /**
   * Register lifecycle callback
   */
  registerLifecycleCallback(callback: (state: PiPWindow.PiPState) => void): void {
    this.lifecycleCallback = callback;
  }

  /**
   * Start PiP subtitle
   */
  async startPip(): Promise<boolean> {
    if (!this.isInitialized || !this.pipController) {
      console.error(`${TAG} PiP not initialized`);
      return false;
    }

    if (this.isPipRunning) {
      console.info(`${TAG} PiP already running`);
      return true;
    }

    try {
      await this.pipController.startPiP();
      console.info(`${TAG} PiP started successfully`);
      return true;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`${TAG} Failed to start PiP: ${error.code}, ${error.message}`);
      return false;
    }
  }

  /**
   * Stop PiP subtitle
   */
  async stopPip(): Promise<void> {
    if (!this.pipController) {
      console.info(`${TAG} PiP controller not available`);
      return;
    }

    // Always try to stop PiP, even if isPipRunning is false
    // This handles edge cases where state might be out of sync
    try {
      await this.pipController.stopPiP();
      this.isPipRunning = false;
      console.info(`${TAG} PiP stopped successfully`);
    } catch (err) {
      const error = err as BusinessError;
      // Error code 1300012 means PiP window state is abnormal (already stopped)
      // Error code 1300015 means repeated PiP operation
      if (error.code === 1300012 || error.code === 1300015) {
        console.info(`${TAG} PiP already stopped or state abnormal: ${error.code}`);
        this.isPipRunning = false;
      } else {
        console.error(`${TAG} Failed to stop PiP: ${error.code}, ${error.message}`);
      }
    }
  }

  /**
   * Update subtitle text
   */
  updateSubtitle(text: string): void {
    this.nodeController.updateText(text);
  }

  /**
   * Update subtitle style
   */
  updateStyle(style: Partial<SubtitleParams>): void {
    this.nodeController.updateStyle(style);
  }

  /**
   * Update PiP window content size (width and height ratio)
   * @param width - Content width in px
   * @param height - Content height in px
   */
  updateContentSize(width: number, height: number): void {
    if (!this.pipController) {
      console.warn(`${TAG} Cannot update content size: PiP controller not initialized`);
      return;
    }
    try {
      this.pipController.updateContentSize(width, height);
      console.info(`${TAG} Content size updated to ${width}x${height}`);
    } catch (err) {
      console.error(`${TAG} Failed to update content size: ${JSON.stringify(err)}`);
    }
  }

  /**
   * Check if PiP is running
   */
  isRunning(): boolean {
    return this.isPipRunning;
  }

  /**
   * Destroy PiP controller
   */
  async destroy(): Promise<void> {
    if (this.pipController) {
      try {
        if (this.isPipRunning) {
          await this.pipController.stopPiP();
        }
        this.pipController.off('stateChange');
        this.pipController = null;
      } catch (err) {
        console.error(`${TAG} destroy error: ${JSON.stringify(err)}`);
      }
    }
    this.isInitialized = false;
    this.isPipRunning = false;
  }
}
