import request from '@ohos.request';
import fs from '@ohos.file.fs';
import zlib from '@ohos.zlib';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';
import { ASR_MODELS, AsrModelType } from '../storage/AsrModelStorage';

/**
 * 下载状态枚举
 */
export enum DownloadState {
  IDLE = 'idle',
  DOWNLOADING = 'downloading',
  EXTRACTING = 'extracting',
  COMPLETED = 'completed',
  FAILED = 'failed',
  PAUSED = 'paused'
}

/**
 * 下载进度信息
 */
export interface DownloadProgress {
  state: DownloadState;
  progress: number;        // 0-100
  downloadedMB: number;    // 已下载大小 MB
  totalMB: number;         // 总大小 MB
  speed: string;           // 下载速度
  errorMessage: string;    // 错误信息
}

/**
 * 下载进度回调
 */
export type DownloadProgressCallback = (progress: DownloadProgress) => void;

/**
 * 模型文件信息
 */
interface ModelFileInfo {
  name: string;
  sizeMB: number;
}

/**
 * 模型下载服务
 * 支持断点续传、进度回调、自动解压
 */
export class ModelDownloadService {
  private static instance: ModelDownloadService | null = null;
  private downloadTask: request.DownloadTask | null = null;
  private progressCallback: DownloadProgressCallback | null = null;
  private currentState: DownloadState = DownloadState.IDLE;
  private lastDownloadedBytes: number = 0;
  private lastTimestamp: number = 0;

  // 使用 Gitee 镜像或其他国内可访问的 CDN（用户可配置）
  // GitHub 原始链接经常无法访问，提供备用下载源
  private static readonly DOWNLOAD_SOURCES: string[] = [
    // 主下载源 - HuggingFace 镜像（国内可访问）
    'https://hf-mirror.com/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx',
    // 备用源 - GitHub Releases
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17.tar.bz2'
  ];

  // SenseVoice 模型需要的文件列表
  private static readonly MODEL_FILES: string[] = [
    'model.int8.onnx',
    'tokens.txt'
  ];

  private constructor() {}

  public static getInstance(): ModelDownloadService {
    if (!ModelDownloadService.instance) {
      ModelDownloadService.instance = new ModelDownloadService();
    }
    return ModelDownloadService.instance;
  }

  /**
   * 获取当前下载状态
   */
  public getState(): DownloadState {
    return this.currentState;
  }

  /**
   * 设置进度回调
   */
  public setProgressCallback(callback: DownloadProgressCallback | null): void {
    this.progressCallback = callback;
  }

  /**
   * 获取模型目录路径
   */
  private getModelDir(context: common.UIAbilityContext): string {
    const modelInfo = ASR_MODELS[AsrModelType.SENSE_VOICE_MULTI];
    return `${context.filesDir}/${modelInfo.folderName}`;
  }

  /**
   * 检查模型是否已下载
   */
  public async checkModelExists(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const modelDir = this.getModelDir(context);
      
      // 检查目录是否存在 - 使用异步方法返回布尔值
      const dirExists = await fs.access(modelDir);
      if (!dirExists) {
        return false;
      }

      // 检查所有必需文件
      for (const fileName of ModelDownloadService.MODEL_FILES) {
        const filePath = `${modelDir}/${fileName}`;
        try {
          const fileExists = await fs.access(filePath);
          if (!fileExists) {
            console.info(`[ModelDownloadService] Missing file: ${fileName}`);
            return false;
          }
        } catch (e) {
          console.info(`[ModelDownloadService] Missing file: ${fileName}`);
          return false;
        }
      }

      // 检查模型文件大小（至少 100MB）
      const modelPath = `${modelDir}/model.int8.onnx`;
      const stat = fs.statSync(modelPath);
      if (stat.size < 100 * 1024 * 1024) {
        console.info(`[ModelDownloadService] Model file too small: ${stat.size}`);
        return false;
      }

      return true;
    } catch (e) {
      console.info(`[ModelDownloadService] Check model error: ${JSON.stringify(e)}`);
      return false;
    }
  }

  /**
   * 开始下载模型
   */
  public async startDownload(context: common.UIAbilityContext): Promise<void> {
    if (this.currentState === DownloadState.DOWNLOADING) {
      console.warn('[ModelDownloadService] Download already in progress');
      return;
    }

    this.currentState = DownloadState.DOWNLOADING;
    this.notifyProgress({
      state: DownloadState.DOWNLOADING,
      progress: 0,
      downloadedMB: 0,
      totalMB: ASR_MODELS[AsrModelType.SENSE_VOICE_MULTI].fileSizeMB,
      speed: '准备中...',
      errorMessage: ''
    });

    try {
      // 创建模型目录
      const modelDir = this.getModelDir(context);
      try {
        fs.mkdirSync(modelDir);
      } catch (e) {
        // 目录可能已存在
      }

      // 下载所有必需的文件
      await this.downloadModelFiles(context, modelDir);

      this.currentState = DownloadState.COMPLETED;
      this.notifyProgress({
        state: DownloadState.COMPLETED,
        progress: 100,
        downloadedMB: ASR_MODELS[AsrModelType.SENSE_VOICE_MULTI].fileSizeMB,
        totalMB: ASR_MODELS[AsrModelType.SENSE_VOICE_MULTI].fileSizeMB,
        speed: '',
        errorMessage: ''
      });

    } catch (error) {
      const err = error as BusinessError;
      console.error(`[ModelDownloadService] Download failed: ${JSON.stringify(err)}`);
      this.currentState = DownloadState.FAILED;
      this.notifyProgress({
        state: DownloadState.FAILED,
        progress: 0,
        downloadedMB: 0,
        totalMB: ASR_MODELS[AsrModelType.SENSE_VOICE_MULTI].fileSizeMB,
        speed: '',
        errorMessage: err.message ?? '下载失败'
      });
    }
  }

  /**
   * 下载模型文件
   */
  private async downloadModelFiles(context: common.UIAbilityContext, modelDir: string): Promise<void> {
    const baseUrl = 'https://hf-mirror.com/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main';
    
    // 文件列表和大小（用于进度计算）
    const modelFile: ModelFileInfo = { name: 'model.int8.onnx', sizeMB: 218 };
    const tokensFile: ModelFileInfo = { name: 'tokens.txt', sizeMB: 0.1 };
    const files: ModelFileInfo[] = [modelFile, tokensFile];

    let totalDownloaded = 0;
    const totalSize = files.reduce((sum, f) => sum + f.sizeMB, 0);

    for (const file of files) {
      const fileUrl = `${baseUrl}/${file.name}`;
      const filePath = `${modelDir}/${file.name}`;

      console.info(`[ModelDownloadService] Downloading ${file.name} from ${fileUrl}`);

      await this.downloadSingleFile(context, fileUrl, filePath, (downloaded, total) => {
        const fileProgress = total > 0 ? (downloaded / total) : 0;
        const currentFileMB = file.sizeMB * fileProgress;
        const overallMB = totalDownloaded + currentFileMB;
        const overallProgress = (overallMB / totalSize) * 100;

        this.notifyProgress({
          state: DownloadState.DOWNLOADING,
          progress: Math.min(99, Math.round(overallProgress)),
          downloadedMB: Math.round(overallMB * 10) / 10,
          totalMB: Math.round(totalSize),
          speed: this.calculateSpeed(downloaded),
          errorMessage: ''
        });
      });

      totalDownloaded += file.sizeMB;
    }
  }

  /**
   * 下载单个文件
   */
  private async downloadSingleFile(
    context: common.UIAbilityContext,
    url: string,
    filePath: string,
    onProgress: (downloaded: number, total: number) => void
  ): Promise<void> {
    return new Promise((resolve, reject) => {
      const config: request.DownloadConfig = {
        url: url,
        filePath: filePath,
        enableMetered: true,
        enableRoaming: true,
        title: 'SenseVoice 模型下载',
        description: '正在下载 SenseVoice 语音识别模型'
      };

      request.downloadFile(context, config).then((task) => {
        this.downloadTask = task;

        task.on('progress', (receivedSize: number, totalSize: number) => {
          onProgress(receivedSize, totalSize);
        });

        task.on('complete', () => {
          console.info(`[ModelDownloadService] File download complete: ${filePath}`);
          this.downloadTask = null;
          resolve();
        });

        task.on('fail', (err: number) => {
          console.error(`[ModelDownloadService] File download failed: ${err}`);
          this.downloadTask = null;
          reject(new Error(`下载失败，错误码: ${err}`));
        });

      }).catch((err: BusinessError) => {
        reject(err);
      });
    });
  }

  /**
   * 计算下载速度
   */
  private calculateSpeed(currentBytes: number): string {
    const now = Date.now();
    const timeDiff = (now - this.lastTimestamp) / 1000; // 秒
    
    if (timeDiff < 0.5) {
      return this.lastTimestamp > 0 ? '计算中...' : '';
    }

    const bytesDiff = currentBytes - this.lastDownloadedBytes;
    const bytesPerSecond = bytesDiff / timeDiff;

    this.lastDownloadedBytes = currentBytes;
    this.lastTimestamp = now;

    if (bytesPerSecond < 1024) {
      return `${Math.round(bytesPerSecond)} B/s`;
    } else if (bytesPerSecond < 1024 * 1024) {
      return `${(bytesPerSecond / 1024).toFixed(1)} KB/s`;
    } else {
      return `${(bytesPerSecond / (1024 * 1024)).toFixed(1)} MB/s`;
    }
  }

  /**
   * 暂停下载
   */
  public async pauseDownload(): Promise<void> {
    if (this.downloadTask) {
      await this.downloadTask.pause();
      this.currentState = DownloadState.PAUSED;
      this.notifyProgress({
        state: DownloadState.PAUSED,
        progress: 0,
        downloadedMB: 0,
        totalMB: ASR_MODELS[AsrModelType.SENSE_VOICE_MULTI].fileSizeMB,
        speed: '',
        errorMessage: ''
      });
    }
  }

  /**
   * 恢复下载
   */
  public async resumeDownload(): Promise<void> {
    if (this.downloadTask) {
      await this.downloadTask.resume();
      this.currentState = DownloadState.DOWNLOADING;
    }
  }

  /**
   * 取消下载
   */
  public async cancelDownload(context: common.UIAbilityContext): Promise<void> {
    if (this.downloadTask) {
      await this.downloadTask.delete();
      this.downloadTask = null;
    }

    // 清理已下载的文件
    try {
      const modelDir = this.getModelDir(context);
      fs.rmdirSync(modelDir);
    } catch (e) {
      // 忽略删除错误
    }

    this.currentState = DownloadState.IDLE;
    this.notifyProgress({
      state: DownloadState.IDLE,
      progress: 0,
      downloadedMB: 0,
      totalMB: 0,
      speed: '',
      errorMessage: ''
    });
  }

  /**
   * 删除已下载的模型
   */
  public async deleteModel(context: common.UIAbilityContext): Promise<void> {
    try {
      const modelDir = this.getModelDir(context);
      fs.rmdirSync(modelDir);
      console.info('[ModelDownloadService] Model deleted successfully');
    } catch (e) {
      console.error(`[ModelDownloadService] Delete model error: ${JSON.stringify(e)}`);
    }
    this.currentState = DownloadState.IDLE;
  }

  /**
   * 获取模型文件路径（用于加载模型）
   */
  public getModelPath(context: common.UIAbilityContext): string {
    return this.getModelDir(context);
  }

  /**
   * 通知进度更新
   */
  private notifyProgress(progress: DownloadProgress): void {
    if (this.progressCallback) {
      this.progressCallback(progress);
    }
  }
}
