/**
 * @fileoverview This file contains code related to AI content generation.
 * @compliance EU AI Act, US EO 14110, China Interim Measures for Generative AI Services
 * @metadata {"ai_generated_content": true, "sensitive_logic": true}
 */
import worker, {
  ThreadWorkerGlobalScope,
  MessageEvents,
  ErrorEvent
} from '@ohos.worker';

import {
  OfflineRecognizer,
  OfflineRecognizerConfig,
  OfflineStream,
  Samples
} from '../sherpa/NonStreamingAsr';

// -------- message types --------

class InitMessage {
  readonly type: 'init' = 'init';
  readonly modelDir?: string; // ignored (we always use rawfile)

  constructor(modelDir?: string) {
    this.modelDir = modelDir;
  }
}

class PcmMessage {
  readonly type: 'pcm' = 'pcm';
  readonly pcm: ArrayBuffer;

  constructor(pcm: ArrayBuffer) {
    this.pcm = pcm;
  }
}

class FlushMessage {
  readonly type: 'flush' = 'flush';
}

type MessageFromMain = InitMessage | PcmMessage | FlushMessage;

class ReadyMessage {
  readonly type: 'ready' = 'ready';
}

class FinalMessage {
  readonly type: 'final' = 'final';
  readonly text: string;

  constructor(text: string) {
    this.text = text;
  }
}

class ErrorMessage {
  readonly type: 'error' = 'error';
  readonly message: string;

  constructor(message: string) {
    this.message = message;
  }
}

type MessageToMain = ReadyMessage | FinalMessage | ErrorMessage;

// -------- worker state --------

const workerPort: ThreadWorkerGlobalScope = worker.workerPort;

let recognizer: OfflineRecognizer | undefined;
let pcmChunks: Int16Array[] = [];

// -------- utils --------

function post(msg: MessageToMain): void {
  workerPort.postMessage(msg);
}

function postError(message: string): void {
  const e = new ErrorMessage(message);
  post(e);
  console.error('ASR worker error:', message);
}

// -------- recognizer init from rawfile --------

function createOfflineRecognizerFromRawfile(): OfflineRecognizer {
  const cfg = new OfflineRecognizerConfig();

  // Feature config
  cfg.featConfig.sampleRate = 16000;
  cfg.featConfig.featureDim = 80;

  // Base path inside rawfile/
  // Make sure this folder name matches exactly your folder under rawfile/
  const base: string = 'rawfile/sherpa-onnx-moonshine-tiny-en-int8';

  // Moonshine model files (adjust names if yours differ slightly)
  cfg.modelConfig.moonshine.preprocessor = `${base}/preprocess.onnx`;
  cfg.modelConfig.moonshine.encoder      = `${base}/encode.int8.onnx`;          // or encoder.int8.onnx
  cfg.modelConfig.moonshine.uncachedDecoder = `${base}/uncached_decode.int8.onnx`;
  cfg.modelConfig.moonshine.cachedDecoder   = `${base}/cached_decode.int8.onnx`;

  // Token file
  cfg.modelConfig.tokens = `${base}/tokens.txt`;

  // IMPORTANT: tell sherpa-onnx which model family we use
  cfg.modelConfig.modelType = 'moonshine';

  // Moonshine is English BPE
  cfg.modelConfig.modelingUnit = 'bpe';

  // No extra language selection for Moonshine tiny-en, it’s just English
  // (Optional) cfg.modelConfig.moonshine.<other fields> if they exist in your NonStreamingAsr.ets

  // Threads / provider / decoding
  cfg.modelConfig.numThreads = 2;
  cfg.modelConfig.provider = 'cpu';
  cfg.decodingMethod = 'greedy_search';

  return new OfflineRecognizer(cfg);
}

function handleInit(_msg: InitMessage): void {
  try {
    recognizer = createOfflineRecognizerFromRawfile();
    const ready = new ReadyMessage();
    post(ready);
    console.info('ASR worker: OfflineRecognizer initialized (moonshine tiny)');
  } catch (e) {
    const reason = String(e);
    postError('Failed to init OfflineRecognizer: ' + reason);
  }
}

// -------- PCM handling --------

function handlePcm(msg: PcmMessage): void {
  if (!msg.pcm) {
    return;
  }
  const chunk = new Int16Array(msg.pcm);
  if (chunk.length > 0) {
    pcmChunks.push(chunk);
  }
}

function mergePcm(): Int16Array | null {
  if (pcmChunks.length === 0) {
    return null;
  }
  let totalLen = 0;
  for (const c of pcmChunks) {
    totalLen += c.length;
  }
  const merged = new Int16Array(totalLen);
  let offset = 0;
  for (const c of pcmChunks) {
    merged.set(c, offset);
    offset += c.length;
  }
  pcmChunks = [];
  return merged;
}

// -------- flush -> decode --------

function handleFlush(): void {
  if (!recognizer) {
    postError('flush: recognizer not initialized (ASR init failed)');
    return;
  }

  const merged = mergePcm();
  if (!merged || merged.length === 0) {
    console.info('ASR worker: flush with empty PCM; nothing to decode');
    return;
  }

  const f32 = new Float32Array(merged.length);
  for (let i = 0; i < merged.length; i++) {
    f32[i] = merged[i] / 32768.0;
  }

  const s: Samples = {
    samples: f32,
    sampleRate: 16000
  };

  try {
    const stream: OfflineStream = recognizer.createStream();
    stream.acceptWaveform(s);
    recognizer.decode(stream);
    const result = recognizer.getResult(stream);
    const text = result.text.trim();
    console.info(`ASR worker: decode result="${text}"`);
    if (text.length > 0) {
      const msg = new FinalMessage(text);
      post(msg);
    }
  } catch (_e) {
    postError('Offline decode failed');
  }
}

// -------- message handling --------

function onMessage(event: MessageEvents): void {
  const data = event.data as MessageFromMain;
  switch (data.type) {
    case 'init':
      handleInit(data);
      break;
    case 'pcm':
      handlePcm(data);
      break;
    case 'flush':
      handleFlush();
      break;
    default:
      console.warn('ASR worker: unknown message');
      break;
  }
}

workerPort.onmessage = (e: MessageEvents): void => {
  onMessage(e);
};

workerPort.onmessageerror = (_e: MessageEvents): void => {
  postError('Worker message error');
};

workerPort.onerror = (e: ErrorEvent): void => {
  postError('Worker runtime error: ' + e.message);
};
