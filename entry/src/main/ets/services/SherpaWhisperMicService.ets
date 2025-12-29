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

import {
  OfflineRecognizer,
  OfflineRecognizerConfig,
  OfflineRecognizerResult,
  OfflineStream,
  Samples
} from '../sherpa/NonStreamingAsr';

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

// ====== Main service: mic + Moonshine ASR (NO worker) ======

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
   * Initialize Moonshine tiny EN model from rawfile using the app's resourceManager.
   * Must be called once before start().
   */
  async init(ctx: common.UIAbilityContext): Promise<void> {
    this.ctx = ctx;

    const cfg = new OfflineRecognizerConfig();

    // Feature config
    cfg.featConfig.sampleRate = this.sampleRate;
    cfg.featConfig.featureDim = 80;

    // Model files in rawfile, as in the docs:
    // entry/src/main/resources/rawfile/sherpa-onnx-moonshine-tiny-en-int8/
    const base: string = 'rawfile/sherpa-onnx-moonshine-tiny-en-int8';

    cfg.modelConfig.moonshine.preprocessor = `${base}/preprocess.onnx`;
    cfg.modelConfig.moonshine.encoder = `${base}/encode.int8.onnx`;
    cfg.modelConfig.moonshine.uncachedDecoder = `${base}/uncached_decode.int8.onnx`;
    cfg.modelConfig.moonshine.cachedDecoder = `${base}/cached_decode.int8.onnx`;
    cfg.modelConfig.tokens = `${base}/tokens.txt`;

    // Important: tell sherpa-onnx what model family we use
    cfg.modelConfig.modelType = 'moonshine';
    cfg.modelConfig.modelingUnit = 'bpe';
    cfg.modelConfig.debug = true;

    // Threads / provider / decoding
    cfg.modelConfig.numThreads = 2;
    cfg.modelConfig.provider = 'cpu';
    cfg.decodingMethod = 'greedy_search';

    if (!this.ctx) {
      throw new Error('SherpaWhisperMicService.init: ctx is undefined');
    }

    // Pass resourceManager so rawfile paths work
    this.recognizer = new OfflineRecognizer(cfg, this.ctx.resourceManager);
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
      if (bufferedSamples < this.sampleRate / 2) {
        if (this.enableDebugLogs) {
          console.info(`[SherpaMic] skip ${plan.label} decode, samples=${bufferedSamples}`);
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
