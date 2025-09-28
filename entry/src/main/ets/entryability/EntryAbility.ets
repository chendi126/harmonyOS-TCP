import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { UIContext } from '@kit.ArkUI';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import workScheduler from '@ohos.resourceschedule.workScheduler';


const TAG: string = '[EatNotification]';
const DOMAIN_NUMBER: number = 0xFF00;

// 定义工作ID常量
const MORNING_NOTIFICATION_WORK_ID = 1001;
const NOON_NOTIFICATION_WORK_ID = 1002;
const EVENING_NOTIFICATION_WORK_ID = 1003;


export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    this.setupMorningNotification();
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {

    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 设置窗口全屏和延伸到安全区
    this.setFullScreen(windowStage);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
    });
  }

  // 设置全屏显示
  private setFullScreen(windowStage: window.WindowStage): void {
    try {
      const mainWindow = windowStage.getMainWindowSync();

      // 设置窗口全屏
      mainWindow.setWindowSystemBarEnable(['status', 'navigation']);

      // 设置状态栏和导航栏样式
      const systemBarProperties: window.SystemBarProperties = {
        statusBarColor: '#00ffffff', // 透明状态栏
        navigationBarColor: '#00ffffff', // 透明导航栏
        statusBarContentColor: '#FF000000', // 状态栏内容为黑色
        navigationBarContentColor: '#FF000000', // 导航栏内容为黑色
        isStatusBarLightIcon: false, // 状态栏图标为深色
        isNavigationBarLightIcon: false // 导航栏图标为深色
      };

      mainWindow.setWindowSystemBarProperties(systemBarProperties);

      // 设置窗口布局延伸到安全区域
      mainWindow.setWindowLayoutFullScreen(true);

      hilog.info(0x0000, 'testTag', 'Full screen mode enabled successfully');
    } catch (err) {
      hilog.error(0x0000, 'testTag', 'Failed to set full screen mode: %{public}s', JSON.stringify(err) ?? '');
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }


  // 设置早餐通知（8:00）
  private setupMorningNotification(): void {
    // 获取当前时间
    const now = new Date();
    const currentHour = now.getHours();
    const currentMinute = now.getMinutes();
    this.setupMealNotification(
      MORNING_NOTIFICATION_WORK_ID,
      'morning',
      '饮食提醒',
      '别忘记吃饭哦~',
      currentHour,
      currentMinute
    );
  }

  // 统一设置餐饮通知方法
  private setupMealNotification(
    workId: number,
    notificationType: string,
    title: string,
    content: string,
    hour: number,
    minute: number
  ): void {
    try {
      // 计算下一个触发时间
      const now = new Date();
      const triggerTime = new Date();
      triggerTime.setHours(hour, minute, 0, 0);

      // 如果今天的触发时间已过，则设置为明天
      if (now > triggerTime) {
        triggerTime.setDate(triggerTime.getDate() + 1);
      }

      hilog.info(DOMAIN_NUMBER, TAG, `设置通知触发时间: ${triggerTime.toLocaleString()}`);

      // 创建工作信息
      const workInfo: workScheduler.WorkInfo = {
        workId: workId,
        networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
        bundleName: this.context.abilityInfo.bundleName,
        abilityName: this.context.abilityInfo.name,
        parameters: {
          notificationType: notificationType,
          title: title,
          content: content,
          triggerTimeStr: triggerTime.toLocaleString()
        }
      };

      // 使用仅有一个参数的startWork方法
      try {
        // 开始工作调度
        workScheduler.startWork(workInfo);
        hilog.info(DOMAIN_NUMBER, TAG, `工作已调度，ID: ${workId}, 类型: ${notificationType}, 触发时间: ${triggerTime.toLocaleString()}`);
      } catch (err) {
        hilog.error(DOMAIN_NUMBER, TAG, `调度工作失败: ${JSON.stringify(err)}`);
      }
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `设置餐饮通知失败: ${JSON.stringify(error)}`);
    }
  }

  // 当workScheduler触发时处理工作的方法
  public onWorkStart(workInfo: workScheduler.WorkInfo): void {
    hilog.info(DOMAIN_NUMBER, TAG, `工作开始，ID: ${workInfo.workId}`);

    try {
      if (workInfo.parameters) {
        // 使用Record<string, string>代替any类型
        const params = workInfo.parameters as Record<string, string>;
        const notificationType = params.notificationType || '';
        const title = params.title || '饮食提醒';
        const content = params.content || '记得吃饭';

        // 发送通知
        this.sendNotification(workInfo.workId, title, content);
        hilog.info(DOMAIN_NUMBER, TAG, `已发送${notificationType}通知`);
      }
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `处理工作失败: ${JSON.stringify(error)}`);
    }
  }

  // 发送通知
  private sendNotification(id: number, title: string, content: string): void {
    // 构建通知请求
    const notificationRequest: notificationManager.NotificationRequest = {
      id: id,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title,
          text: content,
          additionalText: '食物记录应用提醒'
        }
      }
    };

    try {
      // 发送通知
      notificationManager.publish(notificationRequest);
      hilog.info(DOMAIN_NUMBER, TAG, `通知发送成功，ID: ${id}`);
    } catch (err) {
      hilog.error(DOMAIN_NUMBER, TAG, `发送通知失败: ${JSON.stringify(err)}`);
    }
  }

}
