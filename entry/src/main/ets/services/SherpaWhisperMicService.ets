/**
 * @fileoverview This file contains code related to AI content generation.
 * @compliance EU AI Act, US EO 14110, China Interim Measures for Generative AI Services
 * @metadata {
 *   "Label": "AI_Generated_Content",
 *   "ContentProducer": "Voot_App",
 *   "ProduceID": "VOOT_GEN_001",
 *   "ReservedCode1": "RESERVED",
 *   "ContentPropagator": "Voot_App",
 *   "PropagateID": "VOOT_PROP_001",
 *   "ReservedCode2": "RESERVED"
 * }
 */
import audio from '@ohos.multimedia.audio';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';

import {
  OfflineRecognizer,
  OfflineRecognizerConfig,
  OfflineRecognizerResult,
  OfflineStream,
  Samples
} from '../sherpa/NonStreamingAsr';
import { AsrModelType, ASR_MODELS, AsrModelStorage } from '../storage/AsrModelStorage';

// ====== Result types for UI ======

export class AsrResult {
  text: string;
  isFinal: boolean;

  constructor(text: string, isFinal: boolean) {
    this.text = text;
    this.isFinal = isFinal;
  }
}

export type AsrResultCallback = (res: AsrResult) => void;
export type AsrErrorCallback = (msg: string) => void;

interface DecodePlan {
  clearBuffer: boolean;
  isFinal: boolean;
  label: string;
  enforceMinSamples: boolean;
  failureMessage?: string;
  maxSamples?: number;
}

// ====== Main service: mic + ASR (NO worker) ======

export class SherpaWhisperMicService {
  private ctx?: common.UIAbilityContext;
  private recognizer?: OfflineRecognizer;

  private capturer: audio.AudioCapturer | null = null;
  private capturing: boolean = false;

  private onResult?: AsrResultCallback;
  private onError?: AsrErrorCallback;

  // buffer mic PCM until stop()
  private pcmChunks: Int16Array[] = [];

  private readonly sampleRate: number = 16000;
  private readonly enableDebugLogs: boolean = true;
  private chunkCounter: number = 0;

  // for partial (real-time-ish) decoding
  private lastPartialDecodeTime: number = 0;
  private partialIntervalMs: number = 800; // default ~0.8s for faster responsiveness
  private partialWindowSeconds: number = 4; // default ~4s window
  private isDecodingPartial: boolean = false;

  // SenseVoice 模型的默认参数（需要更长的音频段才能获得好的识别效果）
  private static readonly SENSE_VOICE_INTERVAL_MS = 2000; // 2秒解码一次，给模型更多上下文
  private static readonly SENSE_VOICE_WINDOW_SECONDS = 8; // 8秒窗口，提高准确率
  private static readonly MOONSHINE_INTERVAL_MS = 800; // 0.8秒
  private static readonly MOONSHINE_WINDOW_SECONDS = 4; // 4秒

  // 当前加载的模型类型
  private currentModelType: AsrModelType = AsrModelType.MOONSHINE_EN;
  // SenseVoice 语言配置
  private senseVoiceLanguage: string = 'auto';

  /**
   * 获取当前加载的模型类型
   */
  getCurrentModelType(): AsrModelType {
    return this.currentModelType;
  }

  /**
   * Configure ASR decode timing for real-time performance.
   * @param intervalMs partial decode interval in ms (lower = faster updates, higher CPU)
   * @param windowSeconds max audio window for partial decode in seconds
   */
  setDecodeParams(intervalMs: number, windowSeconds: number): void {
    this.partialIntervalMs = Math.max(300, intervalMs); // min 300ms for fast updates
    this.partialWindowSeconds = Math.max(2, Math.min(windowSeconds, 6)); // 2-6s range for quick response
  }

  /**
   * Set VAD sensitivity.
   * Currently a placeholder for future implementation or simple energy threshold adjustment.
   * @param sensitivity 0=Low, 1=Medium, 2=High
   */
  setVadSensitivity(sensitivity: number): void {
    // TODO: Implement actual VAD sensitivity adjustment
    // For now, we can just log it or adjust internal thresholds if available
    if (this.enableDebugLogs) {
      console.info(`[SherpaMic] VAD sensitivity set to ${sensitivity}`);
    }
  }

  /**
   * 设置 SenseVoice 模型的语言
   * @param language 语言代码: 'zh', 'en', 'ja', 'ko', 'yue', 或 'auto'
   */
  setSenseVoiceLanguage(language: string): void {
    this.senseVoiceLanguage = language;
    if (this.enableDebugLogs) {
      console.info(`[SherpaMic] SenseVoice language set to ${language}`);
    }
  }

  /**
   * Initialize ASR model from rawfile using the app's resourceManager.
   * Must be called once before start().
   * @param modelType 模型类型，默认为 Moonshine EN
   */
  async init(ctx: common.UIAbilityContext, modelType: AsrModelType = AsrModelType.MOONSHINE_EN): Promise<void> {
    this.ctx = ctx;
    this.currentModelType = modelType;

    const cfg = new OfflineRecognizerConfig();

    // Feature config
    cfg.featConfig.sampleRate = this.sampleRate;
    cfg.featConfig.featureDim = 80;

    // 是否使用下载的模型（需要绝对路径，不传 resourceManager）
    let useDownloadedModel = false;

    if (modelType === AsrModelType.SENSE_VOICE_MULTI) {
      // SenseVoice 多语言模型配置
      const modelInfo = ASR_MODELS[AsrModelType.SENSE_VOICE_MULTI];
      
      // 优先检查下载目录
      const downloadedPath = AsrModelStorage.getDownloadedModelPath(ctx);
      let base: string;
      
      if (downloadedPath && downloadedPath.length > 0) {
        // 使用下载的模型（绝对路径，不传递 resourceManager）
        base = downloadedPath;
        useDownloadedModel = true;
        console.info(`[SherpaMic] Using downloaded SenseVoice model from: ${base}`);
      } else {
        // 回退到 rawfile（开发时内置的模型）
        base = `rawfile/${modelInfo.folderName}`;
        console.info(`[SherpaMic] Using rawfile SenseVoice model`);
      }

      cfg.modelConfig.senseVoice.model = `${base}/model.int8.onnx`;
      cfg.modelConfig.senseVoice.language = this.senseVoiceLanguage;
      cfg.modelConfig.senseVoice.useItn = true;
      cfg.modelConfig.tokens = `${base}/tokens.txt`;

      // SenseVoice 模型类型
      cfg.modelConfig.modelType = 'sense_voice';
      cfg.modelConfig.modelingUnit = 'cjkchar';
      cfg.modelConfig.numThreads = 4; // SenseVoice 使用更多线程提高性能
      cfg.modelConfig.debug = false; // 关闭调试减少开销

      console.info(`[SherpaMic] Initializing SenseVoice model with language: ${this.senseVoiceLanguage}`);
    } else {
      // Moonshine 英语模型配置（默认）
      const modelInfo = ASR_MODELS[AsrModelType.MOONSHINE_EN];
      const base: string = `rawfile/${modelInfo.folderName}`;

      cfg.modelConfig.moonshine.preprocessor = `${base}/preprocess.onnx`;
      cfg.modelConfig.moonshine.encoder = `${base}/encode.int8.onnx`;
      cfg.modelConfig.moonshine.uncachedDecoder = `${base}/uncached_decode.int8.onnx`;
      cfg.modelConfig.moonshine.cachedDecoder = `${base}/cached_decode.int8.onnx`;
      cfg.modelConfig.tokens = `${base}/tokens.txt`;

      // Moonshine 模型类型
      cfg.modelConfig.modelType = 'moonshine';
      cfg.modelConfig.modelingUnit = 'bpe';
      cfg.modelConfig.numThreads = 2; // Moonshine 使用 2 线程足够
      cfg.modelConfig.debug = false;

      console.info('[SherpaMic] Initializing Moonshine EN model');
    }

    // 通用配置
    cfg.modelConfig.provider = 'cpu';
    cfg.decodingMethod = 'greedy_search';

    if (!this.ctx) {
      throw new Error('SherpaWhisperMicService.init: ctx is undefined');
    }

    // 根据模型来源选择是否传递 resourceManager
    // - 下载的模型使用绝对路径，不传递 resourceManager
    // - rawfile 中的模型需要传递 resourceManager
    if (useDownloadedModel) {
      // 使用绝对路径，不传递 resourceManager
      this.recognizer = new OfflineRecognizer(cfg, undefined);
      console.info(`[SherpaMic] Model initialized with absolute path (no resourceManager)`);
    } else {
      // 使用 rawfile 路径，传递 resourceManager
      this.recognizer = new OfflineRecognizer(cfg, this.ctx.resourceManager);
      console.info(`[SherpaMic] Model initialized with resourceManager`);
    }

    // 根据模型类型自动调整解码参数
    // SenseVoice 多语言模型需要更长的音频段才能获得好的识别效果
    if (modelType === AsrModelType.SENSE_VOICE_MULTI) {
      this.partialIntervalMs = SherpaWhisperMicService.SENSE_VOICE_INTERVAL_MS;
      this.partialWindowSeconds = SherpaWhisperMicService.SENSE_VOICE_WINDOW_SECONDS;
      console.info(`[SherpaMic] Using SenseVoice decode params: interval=${this.partialIntervalMs}ms, window=${this.partialWindowSeconds}s`);
    } else {
      this.partialIntervalMs = SherpaWhisperMicService.MOONSHINE_INTERVAL_MS;
      this.partialWindowSeconds = SherpaWhisperMicService.MOONSHINE_WINDOW_SECONDS;
      console.info(`[SherpaMic] Using Moonshine decode params: interval=${this.partialIntervalMs}ms, window=${this.partialWindowSeconds}s`);
    }

    console.info(`[SherpaMic] Model initialized: ${modelType}`);
  }

  /**
   * 重新初始化为不同的模型
   * @param modelType 新的模型类型
   */
  async switchModel(modelType: AsrModelType): Promise<void> {
    if (!this.ctx) {
      throw new Error('SherpaWhisperMicService.switchModel: ctx is undefined, call init first');
    }

    // 如果正在录音，先停止
    if (this.capturing) {
      this.stop();
      // 等待停止完成
      await new Promise<void>(resolve => setTimeout(resolve, 200));
    }

    // 释放当前识别器
    this.recognizer = undefined;

    // 重新初始化
    await this.init(this.ctx, modelType);
  }

  private async ensureCapturer(): Promise<void> {
    if (this.capturer !== null) {
      return;
    }

    const streamInfo: audio.AudioStreamInfo = {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    };

    const info: audio.AudioCapturerInfo = {
      source: audio.SourceType.SOURCE_TYPE_MIC,
      capturerFlags: 0
    };

    const options: audio.AudioCapturerOptions = {
      streamInfo,
      capturerInfo: info
    };

    try {
      this.capturer = await audio.createAudioCapturer(options);
    } catch (e) {
      if (this.onError) {
        this.onError('无法创建音频捕捉，检查您的麦克风权限');
      }
      console.error('AudioCapturer create failed: ' + JSON.stringify(e));
    }
  }

  /**
   * Start mic capture and buffer PCM. Decodes:
   *   - partial results every ~1.2s (isFinal=false)
   *   - one final result when stop() is called (isFinal=true)
   */
  start(onResult: AsrResultCallback, onError: AsrErrorCallback): void {
    this.onResult = onResult;
    this.onError = onError;

    if (!this.recognizer) {
      const msg = 'start: recognizer not initialized. Call init() first.';
      console.error(msg);
      if (this.onError) {
        this.onError(msg);
      }
      return;
    }

    this.pcmChunks = [];
    this.capturing = true;
    this.lastPartialDecodeTime = 0;
    this.isDecodingPartial = false;

    void this.captureLoop();
  }

  private async captureLoop(): Promise<void> {
    await this.ensureCapturer();
    if (!this.capturer) {
      return;
    }

    try {
      await this.capturer.start();
    } catch (e) {
      if (this.onError) {
        this.onError('Failed to start AudioCapturer');
      }
      console.error('AudioCapturer start failed: ' + JSON.stringify(e));
      return;
    }

    while (this.capturing) {
      try {
        const bufferSize: number = await this.capturer.getBufferSize();
        const buf: ArrayBuffer = await this.capturer.read(bufferSize, true);
        const view = new Int16Array(buf);
        if (view.length > 0) {
          const copy = new Int16Array(view.length);
          copy.set(view);
          this.pcmChunks.push(copy);
          this.chunkCounter++;
          if (this.enableDebugLogs && (this.chunkCounter <= 3 || this.chunkCounter % 50 === 0)) {
            this.logInt16Stats(`chunk#${this.chunkCounter}`, copy);
          }
        }

        // --- partial decode every ~1.2s ---
        const now = Date.now();
        if (!this.isDecodingPartial &&
          now - this.lastPartialDecodeTime >= this.partialIntervalMs) {
          this.lastPartialDecodeTime = now;
          this.isDecodingPartial = true;
          void this.decodePartial(false).finally(() => {
            this.isDecodingPartial = false;
          });
        }
      } catch (e) {
        console.error('Error reading from mic: ' + JSON.stringify(e));
        if (this.onError) {
          this.onError('Error reading from mic');
        }
        break;
      }
    }

    try {
      await this.capturer.stop();
    } catch (e) {
      console.warn('Error stopping capturer: ' + JSON.stringify(e));
    }

    // final decode once for the buffered audio
    this.decodeFinal();
  }

  /**
   * Shared logic to merge current PCM chunks into a Float32Array.
   */
  private buildWaveform(clearBuffer: boolean, maxSamples?: number): Float32Array | null {
    if (this.pcmChunks.length === 0) {
      return null;
    }

    let totalLen = 0;
    for (const c of this.pcmChunks) {
      totalLen += c.length;
    }

    let sliceStart: number = 0;
    if (maxSamples !== undefined && totalLen > maxSamples) {
      sliceStart = totalLen - maxSamples;
    }

    // Optimization: Prune old chunks if we have a window limit and aren't clearing everything
    if (!clearBuffer && maxSamples !== undefined && sliceStart > 0) {
      let removedSamples = 0;
      while (this.pcmChunks.length > 0) {
        const firstChunk = this.pcmChunks[0];
        // Keep the chunk if it contains the start of our slice
        if (removedSamples + firstChunk.length <= sliceStart) {
          removedSamples += firstChunk.length;
          this.pcmChunks.shift();
        } else {
          break;
        }
      }
      // Adjust calculations based on removed chunks
      sliceStart -= removedSamples;
      totalLen -= removedSamples;
    }

    const copyLen: number = totalLen - sliceStart;
    if (copyLen <= 0) {
      return null;
    }
    const merged = new Int16Array(copyLen);
    let copied = 0;
    let skipped = sliceStart;
    for (const c of this.pcmChunks) {
      if (skipped >= c.length) {
        skipped -= c.length;
        continue;
      }

      const chunkStart = skipped > 0 ? skipped : 0;
      const available = c.length - chunkStart;
      const needed = copyLen - copied;
      const take = Math.min(available, needed);
      const slice = c.subarray(chunkStart, chunkStart + take);
      merged.set(slice, copied);
      copied += take;
      skipped = 0;

      if (copied >= copyLen) {
        break;
      }
    }

    if (clearBuffer) {
      this.pcmChunks = [];
    }

    const f32 = new Float32Array(merged.length);
    for (let i = 0; i < merged.length; i++) {
      f32[i] = merged[i] / 32768.0;
    }

    return f32;
  }

  private async decodePartial(isFinal: boolean): Promise<void> {
    await this.decodeFromBuffer({
      clearBuffer: false,
      isFinal,
      label: 'partial',
      enforceMinSamples: true,
      maxSamples: this.sampleRate * this.partialWindowSeconds // configurable window
    });
  }

  private decodeFinal(): void {
    void this.decodeFromBuffer({
      clearBuffer: true,
      isFinal: true,
      label: 'final',
      enforceMinSamples: false,
      failureMessage: 'Offline decode failed'
    });
  }

  /**
   * Stop mic capture; triggers decodeFinal().
   */
  stop(): void {
    this.capturing = false;
  }

  private async decodeFromBuffer(plan: DecodePlan): Promise<void> {
    if (!this.recognizer) {
      if (plan.failureMessage && this.onError) {
        this.onError(plan.failureMessage);
      }
      return;
    }

    if (plan.enforceMinSamples) {
      const bufferedSamples: number = this.getBufferedSampleCount();
      // SenseVoice 需要更长的音频（至少1.5秒）才能获得准确识别
      const minSamples = this.currentModelType === AsrModelType.SENSE_VOICE_MULTI 
        ? this.sampleRate * 1.5  // 1.5秒
        : this.sampleRate / 2;   // 0.5秒
      if (bufferedSamples < minSamples) {
        if (this.enableDebugLogs) {
          console.info(`[SherpaMic] skip ${plan.label} decode, samples=${bufferedSamples}, need=${minSamples}`);
        }
        return;
      }
    }

    const waveform: Float32Array | null = this.buildWaveform(plan.clearBuffer, plan.maxSamples);
    if (!waveform) {
      if (plan.label === 'final') {
        console.info('decodeFinal: no audio captured');
      }
      return;
    }

    const samples: Samples = {
      samples: waveform,
      sampleRate: this.sampleRate
    };

    try {
      const stream: OfflineStream = this.recognizer.createStream();
      stream.acceptWaveform(samples);
      if (this.enableDebugLogs) {
        this.logFloatStats(`${plan.label}-buffer`, waveform);
      }
      this.recognizer.decode(stream);
      const result: OfflineRecognizerResult = this.recognizer.getResult(stream);
      this.emitAsrResult(result, plan);
    } catch (e) {
      console.error(`[SherpaMic] ${plan.label} decode failed: ` + JSON.stringify(e));
      if (plan.failureMessage && this.onError) {
        this.onError(plan.failureMessage);
      }
    }
  }

  private getBufferedSampleCount(): number {
    let totalLen = 0;
    for (const chunk of this.pcmChunks) {
      totalLen += chunk.length;
    }
    return totalLen;
  }

  private emitAsrResult(result: OfflineRecognizerResult, plan: DecodePlan): void {
    const text: string = (result.text ?? '').trim();
    const label: string = plan.label === 'final' ? 'final' : 'partial';
    console.info(`ASR ${label} decode result="${text}"`);

    if (text.length === 0) {
      if (this.enableDebugLogs) {
        console.warn(`[SherpaMic] ${plan.label} decode returned empty text, json=${result.json}`);
      }
      return;
    }

    if (this.onResult) {
      const payload = new AsrResult(text, plan.isFinal);
      this.onResult(payload);
    }
  }

  private logInt16Stats(label: string, data: Int16Array): void {
    if (!this.enableDebugLogs || data.length === 0) {
      return;
    }
    let peak: number = 0;
    let sumSq: number = 0;
    for (let i = 0; i < data.length; i++) {
      const sample = data[i];
      const absVal = Math.abs(sample);
      if (absVal > peak) {
        peak = absVal;
      }
      sumSq += sample * sample;
    }
    const rms = Math.sqrt(sumSq / data.length);
    console.info(`[SherpaMic] ${label}: len=${data.length} peak=${peak} rms=${rms.toFixed(1)}`);
  }

  private logFloatStats(label: string, data: Float32Array): void {
    if (!this.enableDebugLogs || data.length === 0) {
      return;
    }
    let peak: number = 0;
    let sumSq: number = 0;
    const step = Math.max(1, Math.floor(data.length / 4000));
    let counted: number = 0;
    for (let i = 0; i < data.length; i += step) {
      const val = data[i];
      const absVal = Math.abs(val);
      if (absVal > peak) {
        peak = absVal;
      }
      sumSq += val * val;
      counted++;
    }
    const rms = Math.sqrt(sumSq / counted);
    console.info(`[SherpaMic] ${label}: len=${data.length} step=${step} peak=${peak.toFixed(4)} rms=${rms.toFixed(4)}`);
  }
}
