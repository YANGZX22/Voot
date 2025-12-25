/**
 * ContinuityService - 跨端流转服务
 * 管理设备发现、连接和数据迁移
 */
import { distributedDeviceManager } from '@kit.DistributedServiceKit';
import { BusinessError } from '@ohos.base';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import abilityAccessCtrl, { Permissions, PermissionRequestResult } from '@ohos.abilityAccessCtrl';

// 回调数据接口 - 避免使用 inline object literal types
interface DiscoverSuccessData {
  device: distributedDeviceManager.DeviceBasicInfo;
}

interface DiscoverFailureData {
  reason: number;
}

interface DeviceStateChangeData {
  action: number;
  device: distributedDeviceManager.DeviceBasicInfo;
}

interface BindResultData {
  deviceId: string;
}

// 设备基本信息
export interface DeviceInfo {
  deviceId: string;
  deviceName: string;
  deviceType: number | string;
  networkId: string;
}

// 字幕样式配置接口
export interface SubtitleStyleConfig {
  fontSize: number;
  fontColor: string;
  backgroundColor: string;
  height: number;
}

// 流转状态数据（保存到目标设备的数据）
export interface ContinuityState {
  // 录音状态
  isListening: boolean;
  // 翻译进行中状态
  isTranslating?: boolean;
  // 当前原文
  originalText: string;
  // 当前译文
  translatedText: string;
  // 当前会话ID
  sessionId: number;
  // 完整原文
  fullOriginalText: string;
  // 完整译文
  fullTranslatedText: string;
  // API配置快照
  apiConfig: string; // JSON string
  // 时间戳
  timestamp: number;
}// 流转数据键名
export const CONTINUITY_KEY = 'voot_continuity_data';

// 回调类型
export type OnDeviceFoundCallback = (device: DeviceInfo) => void;
export type OnDeviceLostCallback = (deviceId: string) => void;
export type OnContinueSuccessCallback = () => void;
export type OnContinueFailureCallback = (error: string) => void;

export class ContinuityService {
  private static instance: ContinuityService | null = null;
  private dmInstance: distributedDeviceManager.DeviceManager | null = null;
  private isInitialized: boolean = false;
  private isDiscovering: boolean = false;
  private availableDevices: DeviceInfo[] = [];

  // 回调
  private onDeviceFoundCallback: OnDeviceFoundCallback | null = null;
  private onDeviceLostCallback: OnDeviceLostCallback | null = null;

  private constructor() {}

  static getInstance(): ContinuityService {
    if (ContinuityService.instance === null) {
      ContinuityService.instance = new ContinuityService();
    }
    return ContinuityService.instance;
  }

  setOnDeviceFoundCallback(callback: OnDeviceFoundCallback) {
    this.onDeviceFoundCallback = callback;
  }

  setOnDeviceLostCallback(callback: OnDeviceLostCallback) {
    this.onDeviceLostCallback = callback;
  }

  /**
   * 请求分布式数据同步权限
   */
  async requestDistributedPermission(context: common.UIAbilityContext): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const permissions: Array<Permissions> = ['ohos.permission.DISTRIBUTED_DATASYNC'];
    
    try {
      const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(context, permissions);
      if (result.authResults[0] === 0) {
        console.info('[ContinuityService] DISTRIBUTED_DATASYNC permission granted');
        return true;
      } else {
        console.warn('[ContinuityService] DISTRIBUTED_DATASYNC permission denied');
        promptAction.showToast({ message: '需要分布式同步权限才能进行跨端流转' });
        return false;
      }
    } catch (err) {
      const e = err as BusinessError;
      console.error('[ContinuityService] requestDistributedPermission failed: ' + e.message);
      return false;
    }
  }

  /**
   * 初始化设备管理器
   */
  async init(context: common.UIAbilityContext): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }

    // 先请求权限
    const hasPermission = await this.requestDistributedPermission(context);
    if (!hasPermission) {
      return false;
    }

    try {
      const bundleName = context.abilityInfo.bundleName;
      this.dmInstance = distributedDeviceManager.createDeviceManager(bundleName);

      // 注册设备发现成功回调
      this.dmInstance.on('discoverSuccess', (data: DiscoverSuccessData) => {
        console.info('[ContinuityService] discoverSuccess: ' + JSON.stringify(data));
        const device: DeviceInfo = {
          deviceId: data.device.deviceId,
          deviceName: data.device.deviceName,
          deviceType: data.device.deviceType,
          networkId: String(data.device.networkId || '')
        };
        
        // 避免重复添加
        const exists = this.availableDevices.some(d => d.deviceId === device.deviceId);
        if (!exists) {
          this.availableDevices.push(device);
          if (this.onDeviceFoundCallback) {
            this.onDeviceFoundCallback(device);
          }
        }
      });

      // 注册设备发现失败回调
      this.dmInstance.on('discoverFailure', (data: DiscoverFailureData) => {
        console.warn('[ContinuityService] discoverFailure: ' + JSON.stringify(data));
      });

      // 注册设备状态变化回调
      this.dmInstance.on('deviceStateChange', (data: DeviceStateChangeData) => {
        console.info('[ContinuityService] deviceStateChange: ' + JSON.stringify(data));
        // action: 0-OFFLINE, 1-ONLINE, 2-READY, 3-CHANGE
        if (data.action === 0) {
          // 设备离线
          const index = this.availableDevices.findIndex(d => d.deviceId === data.device.deviceId);
          if (index !== -1) {
            this.availableDevices.splice(index, 1);
            if (this.onDeviceLostCallback) {
              this.onDeviceLostCallback(data.device.deviceId);
            }
          }
        }
      });

      this.isInitialized = true;
      console.info('[ContinuityService] DeviceManager initialized successfully');
      return true;
    } catch (err) {
      const e = err as BusinessError;
      console.error('[ContinuityService] init failed: ' + e.code + ', ' + e.message);
      return false;
    }
  }

  /**
   * 开始发现设备
   */
  startDiscovering(): boolean {
    if (!this.isInitialized || !this.dmInstance) {
      console.error('[ContinuityService] Not initialized');
      return false;
    }

    if (this.isDiscovering) {
      console.info('[ContinuityService] Already discovering');
      return true;
    }

    try {
      const discoverParam: Record<string, number> = {
        'discoverTargetType': 1 // 1表示设备
      };
      const filterOptions: Record<string, number> = {
        'availableStatus': 0 // 0表示可信设备
      };

      this.dmInstance.startDiscovering(discoverParam, filterOptions);
      this.isDiscovering = true;
      console.info('[ContinuityService] Started discovering devices');
      return true;
    } catch (err) {
      const e = err as BusinessError;
      console.error('[ContinuityService] startDiscovering failed: ' + e.code + ', ' + e.message);
      return false;
    }
  }

  /**
   * 停止发现设备
   */
  stopDiscovering(): void {
    if (!this.dmInstance || !this.isDiscovering) {
      return;
    }

    try {
      this.dmInstance.stopDiscovering();
      this.isDiscovering = false;
      console.info('[ContinuityService] Stopped discovering devices');
    } catch (err) {
      const e = err as BusinessError;
      console.error('[ContinuityService] stopDiscovering failed: ' + e.code + ', ' + e.message);
    }
  }

  /**
   * 获取已发现的可用设备列表
   */
  getAvailableDevices(): DeviceInfo[] {
    return [...this.availableDevices];
  }

  /**
   * 获取已连接（可信任）的设备列表
   */
  getTrustedDevices(): DeviceInfo[] {
    if (!this.dmInstance) {
      return [];
    }

    try {
      const deviceList = this.dmInstance.getAvailableDeviceListSync();
      const result: DeviceInfo[] = [];
      for (const device of deviceList) {
        const info: DeviceInfo = {
          deviceId: device.deviceId,
          deviceName: device.deviceName,
          deviceType: device.deviceType,
          networkId: String(device.networkId || '')
        };
        result.push(info);
      }
      return result;
    } catch (err) {
      const e = err as BusinessError;
      console.error('[ContinuityService] getTrustedDevices failed: ' + e.code + ', ' + e.message);
      return [];
    }
  }

  /**
   * 绑定设备（建立信任关系）
   */
  async bindDevice(deviceId: string): Promise<boolean> {
    if (!this.dmInstance) {
      return false;
    }

    return new Promise((resolve) => {
      try {
        const bindParam: Record<string, Object> = {
          'bindType': 1,
          'targetPkgName': 'com.zixiao.voot',
          'appName': 'Voot',
          'appOperation': '请求连接以进行跨端字幕流转',
          'customDescription': 'Voot 需要与此设备建立连接，以便在大屏设备上继续查看字幕'
        };

        this.dmInstance!.bindTarget(deviceId, bindParam, (err: BusinessError, data: BindResultData) => {
          if (err) {
            console.error('[ContinuityService] bindDevice failed: ' + err.code + ', ' + err.message);
            resolve(false);
            return;
          }
          console.info('[ContinuityService] bindDevice success: ' + data.deviceId);
          resolve(true);
        });
      } catch (err) {
        const e = err as BusinessError;
        console.error('[ContinuityService] bindDevice error: ' + e.code + ', ' + e.message);
        resolve(false);
      }
    });
  }



  /**
   * 构建流转状态数据
   */
  static buildContinuityState(
    isListening: boolean,
    isTranslating: boolean,
    originalText: string,
    translatedText: string,
    sessionId: number,
    fullOriginalText: string,
    fullTranslatedText: string,
    apiConfigJson: string
  ): ContinuityState {
    return {
      isListening,
      isTranslating,
      originalText,
      translatedText,
      sessionId,
      fullOriginalText,
      fullTranslatedText,
      apiConfig: apiConfigJson,
      timestamp: Date.now()
    };
  }

  /**
   * 序列化流转状态
   */
  static serializeState(state: ContinuityState): string {
    return JSON.stringify(state);
  }

  /**
   * 反序列化流转状态
   */
  static deserializeState(json: string): ContinuityState | null {
    try {
      return JSON.parse(json) as ContinuityState;
    } catch (e) {
      console.error('[ContinuityService] deserializeState failed: ' + JSON.stringify(e));
      return null;
    }
  }

  /**
   * 获取设备类型名称
   */
  static getDeviceTypeName(deviceType: number): string {
    // DeviceType枚举: 0-UNKNOWN, 0x0E-PHONE, 0x11-TABLET, 0x6D-2in1, 0x0A-PC
    switch (deviceType) {
      case 0x0E:
        return '手机';
      case 0x11:
        return '平板';
      case 0x6D:
        return '折叠屏';
      case 0x0A:
        return '电脑';
      default:
        return '设备';
    }
  }

  /**
   * 获取设备类型图标名称（返回字符串，UI 层处理显示）
   */
  static getDeviceTypeIconName(deviceType: number): string {
    switch (deviceType) {
      case 0x0E:
        return 'phone';
      case 0x11:
        return 'tablet';
      case 0x6D:
        return 'phone_flip';
      case 0x0A:
        return 'laptop';
      default:
        return 'device';
    }
  }

  /**
   * 销毁服务
   */
  destroy(): void {
    this.stopDiscovering();
    if (this.dmInstance) {
      try {
        this.dmInstance.off('discoverSuccess');
        this.dmInstance.off('discoverFailure');
        this.dmInstance.off('deviceStateChange');
      } catch (e) {
        // ignore
      }
      this.dmInstance = null;
    }
    this.isInitialized = false;
    this.availableDevices = [];
    this.onDeviceFoundCallback = null;
    this.onDeviceLostCallback = null;
  }
}

