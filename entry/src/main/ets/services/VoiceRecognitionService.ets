import audio from '@ohos.multimedia.audio';

export interface RecognitionResult {
  text: string;
  confidence: number;
  isFinal: boolean;
}

export class VoiceRecognitionService {
  private audioCapturer: audio.AudioCapturer | undefined;
  private isRecognizing: boolean = false;

  private onResultCb?: (result: RecognitionResult) => void;
  private onErrorCb?: (message: string) => void;
  private onCompleteCb?: () => void;

  private readonly config: audio.AudioCapturerOptions = {
    streamInfo: {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    },
    capturerInfo: {
      source: audio.SourceType.SOURCE_TYPE_MIC,
      capturerFlags: 0
    }
  };

  async initialize(): Promise<void> {
    this.audioCapturer = await audio.createAudioCapturer(this.config);
  }

  /**
   * NEW: takes 3 callbacks here
   */
  async startRecognition(
    onResult: (r: RecognitionResult) => void,
    onError: (msg: string) => void,
    onComplete: () => void
  ): Promise<void> {
    if (!this.audioCapturer) {
      throw new Error('VoiceRecognitionService not initialized');
    }

    this.onResultCb = onResult;
    this.onErrorCb = onError;
    this.onCompleteCb = onComplete;
    this.isRecognizing = true;

    await this.audioCapturer.start();
    this.loop();
  }

  private async loop(): Promise<void> {
    if (!this.audioCapturer) return;

    const bufSize = await this.audioCapturer.getBufferSize();

    while (this.isRecognizing) {
      try {
        const data = await this.audioCapturer.read(bufSize, true);

        if (data.byteLength > 0) {
          const mock: RecognitionResult = {
            text: 'Mock ASR result',
            confidence: 0.9,
            isFinal: true
          };
          if (this.onResultCb) this.onResultCb(mock);
        }
      } catch (err) {
        if (this.onErrorCb) this.onErrorCb(JSON.stringify(err));
        break;
      }
    }

    if (this.onCompleteCb) this.onCompleteCb();
  }

  async stopRecognition(): Promise<void> {
    if (!this.audioCapturer || !this.isRecognizing) return;
    this.isRecognizing = false;
    await this.audioCapturer.stop();
  }

  async release(): Promise<void> {
    await this.stopRecognition();
    if (this.audioCapturer) {
      await this.audioCapturer.release();
      this.audioCapturer = undefined;
    }
  }
}
