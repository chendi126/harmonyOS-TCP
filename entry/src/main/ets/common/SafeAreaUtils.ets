/**
 * 安全区域工具类
 * 用于处理全屏显示时的安全区域适配
 */
import { window } from '@kit.ArkUI';

// 全局变量存储安全区域信息
let statusBarHeight: number = 44; // 默认状态栏高度
let navigationBarHeight: number = 0; // 默认导航栏高度
let isInitialized: boolean = false;

export class SafeAreaUtils {
  /**
   * 初始化安全区域信息
   */
  public static async initialize(): Promise<void> {
    if (isInitialized) {
      return;
    }

    try {
      const windowClass = await window.getLastWindow(getContext());
      const avoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);

      // 获取状态栏高度
      statusBarHeight = avoidArea.topRect.height || 44;

      // 获取导航栏高度
      navigationBarHeight = avoidArea.bottomRect.height || 0;

      isInitialized = true;
      console.info('SafeAreaUtils initialized:', {
        statusBarHeight: statusBarHeight,
        navigationBarHeight: navigationBarHeight
      });
    } catch (error) {
      console.error('Failed to initialize SafeAreaUtils:', error);
      // 使用默认值
      statusBarHeight = 44;
      navigationBarHeight = 0;
      isInitialized = true;
    }
  }

  /**
   * 获取状态栏高度
   */
  public static getStatusBarHeight(): number {
    return statusBarHeight;
  }

  /**
   * 获取导航栏高度
   */
  public static getNavigationBarHeight(): number {
    return navigationBarHeight;
  }

  /**
   * 获取安全区域顶部内边距
   */
  public static getTopSafeAreaInset(): number {
    return statusBarHeight;
  }

  /**
   * 获取安全区域底部内边距
   */
  public static getBottomSafeAreaInset(): number {
    return navigationBarHeight;
  }

  /**
   * 检查是否已初始化
   */
  public static isReady(): boolean {
    return isInitialized;
  }
}
