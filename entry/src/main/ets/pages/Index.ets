import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import socket from '@ohos.net.socket';
import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SafeAreaUtils } from '../common/SafeAreaUtils';
import { GlassStyles, GlassColors, GlassAnimations, GlassTextStyles } from '../common/GlassStyles';

const TAG: string = '[PublishOperation]';
const DOMAIN_NUMBER: number = 0xFF00;

// 在文件顶部添加类型定义
interface AlarmTimeCommand {
  alarm_id: number;
  hour: number;
  min: number;
  enable: number;
}

interface AlarmSetting {
  hour: number;
  min: number;
  enabled: boolean;
}

interface EnvironmentData {
  temperature: number;
  humidity: number;
}

// 添加日期时间命令接口
interface DateTimeCommand {
  year: number;
  month: number;
  day: number;
  hour: number;
  min: number;
  sec: number;
}

// 添加查找设备命令接口
interface FindDeviceCommand {
  type: string;
  speed?: number;
}

@Entry
@Component
struct Index {
  @State ipAddress: string = '';
  @State port: number = 8888;
  @State message: string = '';
  @State receivedData: string = '';
  @State isConnected: boolean = false;
  @State temperature: number = 0;
  @State humidity: number = 0;
  @State showSettings: boolean = false;
  @State isShowFindDevice: boolean = false; // 添加查找设备模态框状态
  @State isFindingDevice: boolean = false; // 添加是否正在查找设备的状态

  @State currentAlarm: number = 0;
  @State statusBarHeight: number = 44; // 状态栏高度

  @State alarmSettings: AlarmSetting[] = [
    {hour: 7, min: 0, enabled: false}, // 闹钟1
    {hour: 8, min: 0, enabled: false}  // 闹钟2
  ];

  @State isShowSheet: boolean = false;
  @State isShowSidebar: boolean = false; // 侧边栏显示状态
  private items: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  private context = getContext(this) as common.UIAbilityContext;
  private preferencesInstance: preferences.Preferences | null = null;
  private readonly PREFERENCES_NAME: string = 'alarm_settings';
  private readonly ALARM_KEY_PREFIX: string = 'alarm_';
  private readonly IP_ADDRESS_KEY: string = 'ip_address';
  private readonly PORT_KEY: string = 'port';

  private tcpSocket: socket.TCPSocket | null = null;

  async aboutToAppear() {
    // 初始化安全区域工具
    await SafeAreaUtils.initialize();
    this.statusBarHeight = SafeAreaUtils.getStatusBarHeight();

    // 初始化Preferences
    await this.initPreferences();
    // 加载保存的设置
    await this.loadSettings();

    // 获取当前时间
    const now = new Date();
    const currentHour = now.getHours();
    const currentMinute = now.getMinutes();

    // 检查是否有闹钟时间与当前时间匹配
    let matchedAlarm = this.alarmSettings.find(alarm =>
    alarm.enabled && alarm.hour === currentHour && Math.abs(alarm.min - currentMinute) <= 0
    );

    // 如果没有匹配的闹钟时间，则不发送通知
    if (!matchedAlarm) {
      console.info('当前没有匹配的闹钟时间，不发送通知');
      return;
    }

    // 找到了匹配的闹钟，发送通知
    let title = '智慧药盒';
    let content = `现在是 ${currentHour}:${currentMinute.toString().padStart(2, '0')}，该吃药了！`;

    // 闹钟索引作为通知ID
    let id = this.alarmSettings.indexOf(matchedAlarm) + 1;

    // 构建通知请求
    let notificationRequest: notificationManager.NotificationRequest = {
      id: id,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title,
          text: content,
          additionalText: '智能闹钟提醒'
        }
      }
    };

    // 检查通知权限并发送通知
    let context = getContext(this) as common.UIAbilityContext;

    notificationManager.isNotificationEnabled()
      .then((enabled) => {
        if (!enabled) {
          promptAction.showToast({ message: '请先开启通知权限' });
          // 尝试请求权限
          return notificationManager.requestEnableNotification();
        } else {
          return Promise.resolve();
        }
      })
      .then(() => {
        return notificationManager.publish(notificationRequest);
      })
      .catch(() => {
        console.error('发送通知失败');
        promptAction.showToast({ message: '发送通知失败' });
      });
  }

  // 初始化Preferences
  async initPreferences() {
    try {
      this.preferencesInstance = await preferences.getPreferences(this.context, this.PREFERENCES_NAME);
      console.info('Preferences初始化成功');
    } catch (err) {
      console.error('Preferences初始化失败:', err);
    }
  }

  // 加载保存的设置
  async loadSettings() {
    if (!this.preferencesInstance) {
      console.error('Preferences实例未初始化');
      return;
    }

    try {
      // 加载IP地址和端口
      const savedIp = await this.preferencesInstance.get(this.IP_ADDRESS_KEY, '');
      const savedPort = await this.preferencesInstance.get(this.PORT_KEY, 8888);
      
      if (typeof savedIp === 'string' && savedIp) {
        this.ipAddress = savedIp;
      }
      
      if (typeof savedPort === 'number') {
        this.port = savedPort;
      }

      // 加载闹钟设置
      for (let i = 0; i < this.alarmSettings.length; i++) {
        const alarmKey = `${this.ALARM_KEY_PREFIX}${i}`;
        const savedAlarm = await this.preferencesInstance.get(alarmKey, '');
        
        if (typeof savedAlarm === 'string' && savedAlarm) {
          try {
            // 使用正则表达式解析JSON字符串，避免any类型
            const hourMatch = savedAlarm.match(/"hour"\s*:\s*(\d+)/);
            const minMatch = savedAlarm.match(/"min"\s*:\s*(\d+)/);
            const enabledMatch = savedAlarm.match(/"enabled"\s*:\s*(true|false)/);

            if (hourMatch && minMatch) {
              this.alarmSettings[i] = {
                hour: parseInt(hourMatch[1]),
                min: parseInt(minMatch[1]),
                enabled: enabledMatch ? enabledMatch[1] === 'true' : false
              };
            }
          } catch {
            console.error(`解析闹钟${i}设置失败`);
          }
        }
      }
      
      console.info('设置加载成功');
    } catch (err) {
      console.error('加载设置失败:', err);
    }
  }

  // 保存闹钟设置
  async saveAlarmSetting(index: number) {
    if (!this.preferencesInstance) {
      console.error('Preferences实例未初始化');
      return;
    }

    try {
      const alarmKey = `${this.ALARM_KEY_PREFIX}${index}`;
      const alarmData = JSON.stringify(this.alarmSettings[index]);
      
      // 保存闹钟设置
      await this.preferencesInstance.put(alarmKey, alarmData);
      await this.preferencesInstance.flush();
      
      console.info(`闹钟${index + 1}设置已保存`);
    } catch (err) {
      console.error(`保存闹钟${index + 1}设置失败:`, err);
    }
  }

  // 保存连接设置
  async saveConnectionSettings() {
    if (!this.preferencesInstance) {
      console.error('Preferences实例未初始化');
      return;
    }

    try {
      // 保存IP地址和端口
      await this.preferencesInstance.put(this.IP_ADDRESS_KEY, this.ipAddress);
      await this.preferencesInstance.put(this.PORT_KEY, this.port);
      await this.preferencesInstance.flush();
      
      console.info('连接设置已保存');
    } catch (err) {
      console.error('保存连接设置失败:', err);
    }
  }

  // 连接设备
  connectDevice() {
    if (this.isConnected) {
      promptAction.showToast({ message: '已连接设备，无需重复连接' });
      return;
    }

    try {
      this.tcpSocket = socket.constructTCPSocketInstance();

      this.tcpSocket.on('connect', () => {
        this.isConnected = true;
        promptAction.showToast({ message: '连接成功', duration: 2000 });
        
        // 连接成功后自动发送当前时间
        this.sendCurrentDateTime();
        // 保存连接设置
        this.saveConnectionSettings();
      });

      this.tcpSocket.on('message', (data: socket.SocketMessageInfo) => {
        try {
          // 安全处理接收到的数据
          if (data.message instanceof ArrayBuffer) {
            const arr = new Uint8Array(data.message);
            let str = '';
            for (let i = 0; i < arr.length; i++) {
              str += String.fromCharCode(arr[i]);
            }
            this.receivedData = str;
            this.parseEnvironmentData(str);
          } else {
            this.receivedData = String(data.message);
            this.parseEnvironmentData(this.receivedData);
          }
        } catch (err) {
          console.error('数据处理错误:', err);
          this.receivedData = '数据解析错误';
        }
      });

      this.tcpSocket.on('close', () => {
        this.isConnected = false;
        promptAction.showToast({ message: '连接已关闭', duration: 2000 });
      });

      this.tcpSocket.on('error', (err) => {
        this.isConnected = false;
        console.error('连接错误详情:', JSON.stringify(err));
        promptAction.showToast({
          message: `连接失败: ${err.message || '请检查IP/端口或网络'}`,
          duration: 3000
        });
      });

      const options: socket.TCPConnectOptions = {
        address: {
          address: this.ipAddress,
          port: this.port,
          family: 1
        },
        timeout: 5000
      };
      console.log('正在尝试连接到:', this.ipAddress, this.port);
      this.tcpSocket.connect(options);

    } catch (err) {
      this.isConnected = false;
      console.error('连接异常详情:', JSON.stringify(err));
      promptAction.showToast({
        message: `连接异常: ${err.message || '未知错误'}`,
        duration: 3000
      });
    }
  }

  // 发送当前日期时间到单片机
  sendCurrentDateTime() {
    if (!this.tcpSocket || !this.isConnected) {
      return;
    }

    // 获取当前日期时间
    const now = new Date();
    const dateTimeCmd: DateTimeCommand = {
      year: now.getFullYear(),
      month: now.getMonth() + 1, // getMonth() 返回 0-11
      day: now.getDate(),
      hour: now.getHours(),
      min: now.getMinutes(),
      sec: now.getSeconds()
    };

    // 发送JSON格式的日期时间
    this.tcpSocket.send({
      data: JSON.stringify(dateTimeCmd),
      encoding: 'utf-8'
    }, (err) => {
      if (err) {
        console.error('发送日期时间失败:', err);
      } else {
        console.info('已发送当前日期时间到设备');
      }
    });
  }

  // 解析温湿度数据
  parseEnvironmentData(dataStr: string) {
    try {
      // 使用正则表达式解析JSON字符串，避免any类型
      const tempMatch = dataStr.match(/"temperature"\s*:\s*([\d.]+)/);
      const humidityMatch = dataStr.match(/"humidity"\s*:\s*([\d.]+)/);

      if (tempMatch && humidityMatch) {
        const temperature = parseFloat(tempMatch[1]);
        const humidity = parseFloat(humidityMatch[1]);

        if (!isNaN(temperature) && !isNaN(humidity)) {
          this.temperature = temperature;
          this.humidity = humidity;
        }
      }
    } catch {
      console.error('温湿度数据解析错误');
    }
  }

  // 发送消息
  sendMessage() {
    if (!this.tcpSocket || !this.isConnected) {
      promptAction.showToast({ message: '请先连接设备' });
      return;
    }

    this.tcpSocket.send({
      data: this.message,
      encoding: 'utf-8'
    }, (err) => {
      if (err) {
        promptAction.showToast({ message: '发送失败' });
      } else {
        this.message = '';
        promptAction.showToast({ message: '发送成功' });
      }
    });
  }

  // 断开连接
  disconnectDevice() {
    if (this.tcpSocket) {
      this.tcpSocket.close();
      this.tcpSocket = null;
    }
    this.isConnected = false;
  }

  // 发送闹钟时间命令方法
  private sendAlarmTimeCommand(index: number) {
    if (!this.tcpSocket || !this.isConnected) {
      promptAction.showToast({ message: '请先连接设备' });
      return;
    }

    const cmd: AlarmTimeCommand = {
      alarm_id: index + 1, // 闹钟ID从1开始
      hour: this.alarmSettings[index].hour,
      min: this.alarmSettings[index].min,
      enable: this.alarmSettings[index].enabled ? 1 : 0
    };

    this.tcpSocket.send({
      data: JSON.stringify(cmd),
      encoding: 'utf-8'
    }, (err) => {
      if (err) {
        promptAction.showToast({ message: '发送失败' });
      } else {
        promptAction.showToast({ message: `闹钟${index + 1}设置已${this.alarmSettings[index].enabled ? '启用' : '禁用'}` });
        // 保存闹钟设置到本地
        this.saveAlarmSetting(index);
      }
    });
  }

  // 发送查找设备命令
  private sendFindDeviceCommand(speed: number) {
    if (!this.tcpSocket || !this.isConnected) {
      promptAction.showToast({ message: '请先连接设备' });
      return;
    }

    const cmd: FindDeviceCommand = {
      type: "FIND_DEVICE",
      speed: speed
    };

    this.tcpSocket.send({
      data: JSON.stringify(cmd),
      encoding: 'utf-8'
    }, (err) => {
      if (err) {
        promptAction.showToast({ message: '发送查找命令失败' });
      } else {
        promptAction.showToast({ message: '已发送查找命令' });
        this.isFindingDevice = true; // 设置为正在查找状态
      }
    });
  }

  // 发送停止查找命令
  private sendStopFindCommand() {
    if (!this.tcpSocket || !this.isConnected) {
      promptAction.showToast({ message: '请先连接设备' });
      return;
    }

    const cmd: FindDeviceCommand = {
      type: "STOP_FIND"
    };

    this.tcpSocket.send({
      data: JSON.stringify(cmd),
      encoding: 'utf-8'
    }, (err) => {
      if (err) {
        promptAction.showToast({ message: '发送停止命令失败' });
      } else {
        promptAction.showToast({ message: '已停止查找' });
        this.isFindingDevice = false; // 重置查找状态
        this.isShowFindDevice = false;
      }
    });
  }

  // 显示时间选择器
  showTimePickerDialog(index: number) {
    // 设置当前闹钟索引
    this.currentAlarm = index;
    
    // 获取当前闹钟的时间
    let selectedHour = this.alarmSettings[index].hour;
    let selectedMinute = this.alarmSettings[index].min;
    
    // 创建Date对象用于时间选择器
    let selectedDate = new Date();
    selectedDate.setHours(selectedHour);
    selectedDate.setMinutes(selectedMinute);
    
    // 创建时间选择器对话框
    TimePickerDialog.show({
      selected: selectedDate,
      useMilitaryTime: true, // 使用24小时制
      onAccept: (value: TimePickerResult) => {
        // 更新闹钟设置
        this.alarmSettings[this.currentAlarm] = {
          hour: value.hour,
          min: value.minute,
          enabled: this.alarmSettings[this.currentAlarm].enabled
        };
        
        // 发送闹钟时间命令
        this.sendAlarmTimeCommand(this.currentAlarm);
      },
      onCancel: () => {
        console.info('取消设置时间');
      }
    })
  }

  @Builder
  SheetBuilder() {
    Column() {
      Column() {
        Text('连接设置')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 24 })

        TextInput({ placeholder: '设备IP地址', text: this.ipAddress })
          .width('90%')
          .height(48)
          .borderRadius(24)
          .backgroundColor('#F5F5F5')
          .placeholderColor('#999999')
          .padding({ left: 16, right: 16 })
          .margin({ bottom: 16 })
          .onChange((value: string) => {
            this.ipAddress = value;
          })

        TextInput({ placeholder: '端口号', text: this.port.toString() })
          .width('90%')
          .height(48)
          .borderRadius(24)
          .backgroundColor('#F5F5F5')
          .placeholderColor('#999999')
          .padding({ left: 16, right: 16 })
          .margin({ bottom: 24 })
          .onChange((value: string) => {
            this.port = parseInt(value) || 8888;
          })

        Row() {
          Button(this.isConnected ? '断开连接' : '连接设备')
            .width('45%')
            .height(48)
            .borderRadius(24)
            .backgroundColor(this.isConnected ? '#ffff2929' : '#ff0b8fff')
            .onClick(() => {
              if (this.isConnected) {
                this.disconnectDevice();
              } else {
                this.connectDevice();
                this.showSettings = false;
              }
            })
        }
        .width('90%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .padding({ top: 16, bottom: 24 })
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  FindDeviceSheetBuilder() {
    Column() {
      Column() {
        Text('查找设备')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 24 })

        Text('选择闪烁速度:')
          .fontSize(16)
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 16, left: '5%' })

        Row() {
          Button('慢速')
            .width('28%')
            .height(48)
            .borderRadius(24)
            .onClick(() => {
              this.sendFindDeviceCommand(1);
            })

          Blank()
            .width('20%') // 添加空白区域作为间隔

          Button('快速')
            .width('28%')
            .height(48)
            .borderRadius(24)
            .onClick(() => {
              this.sendFindDeviceCommand(2);
            })
        }
        .width('90%')
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 24 })

        Button('停止查找')
          .width('90%')
          .height(48)
          .borderRadius(24)
          .backgroundColor(this.isFindingDevice ? '#ffff2929' : '#cccccc')
          .enabled(this.isFindingDevice)
          .onClick(() => {
            this.sendStopFindCommand();
          })
      }
      .width('100%')
      .height('100%')
      .padding({ top: 16, bottom: 24 })
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  AlarmCardBuilder(index: number) {
    Column() {
      Row() {
        Text(`闹钟${index + 1}`)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2C3E50')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 12 })

      Text(`${this.alarmSettings[index].hour.toString().padStart(2, '0')}:${this.alarmSettings[index].min.toString().padStart(2, '0')}`)
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor('#34495E')
        .margin({ bottom: 12 })

      Toggle({ type: ToggleType.Switch, isOn: this.alarmSettings[index].enabled })
        .switchPointColor('#FFFFFF')
        .selectedColor('#4ECDC4')
        .margin({ bottom: 12 })
        .onChange((isOn: boolean) => {
          this.alarmSettings[index].enabled = isOn;
          this.sendAlarmTimeCommand(index);
        })

      Button('设置时间')
        .width(120)
        .height(40)
        .fontSize(16)
        .borderRadius(20)
        .backgroundColor('#4A90E2')
        .fontColor('#FFFFFF')
        .shadow({ radius: 8, color: 'rgba(74, 144, 226, 0.3)', offsetX: 0, offsetY: 4 })
        .onClick(() => {
          this.showTimePickerDialog(index);
        })
    }
    .width('48%')
    .padding(20)
    .backgroundColor(GlassStyles.getGlassCardBackgroundColor())
    .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
    .borderRadius(16)
    .backdropBlur(15)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .shadow({ radius: 15, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 6 })
  }

  build() {
    Column() {
        // 状态栏占位区域
        Row()
          .width('100%')
          .height(30) // 动态状态栏高度
          .backgroundColor('transparent')

        // 标题栏
        Row() {
          // 设置按钮
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.ic_public_settings'))
              .width(24)
              .height(24)
              .fillColor('#2C3E50')
          }
          .width(40)
          .height(40)
          .backgroundColor(GlassStyles.getGlassCardBackgroundColor())
          .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
          .shadow({ radius: 8, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 2 })
          .margin({ right: 12 })
          .onClick(() => {
            this.isShowSheet = !this.isShowSheet;
          })
          .bindSheet($$this.isShowSheet, this.SheetBuilder(), {
            detents: [SheetSize.MEDIUM],
            preferType: SheetType.BOTTOM,
            title: { title: '设备连接'},
          })

          Text('智慧药盒')
            .fontSize(GlassTextStyles.getPrimaryTitleFontSize())
            .fontWeight(FontWeight.Bold)
            .fontColor(GlassTextStyles.getPrimaryTitleColor())

          Blank()

          if (this.isConnected) {
            Row() {
              Circle({ width: 10, height: 10 })
                .fill('#4ECDC4')
                .margin({ right: 8 })

              Text('已连接')
                .fontSize(14)
                .fontColor('#4ECDC4')
                .fontWeight(FontWeight.Medium)
            }
            .backgroundColor('rgba(78, 205, 196, 0.1)')
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(16)
            .border({ width: 1, color: 'rgba(78, 205, 196, 0.3)' })
          }

          // 侧边栏按钮
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.ic_contacts_rcs_list'))
              .width(24)
              .height(24)
              .fillColor('#2C3E50')
          }
          .width(40)
          .height(40)
          .backgroundColor(GlassStyles.getGlassCardBackgroundColor())
          .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
          .shadow({ radius: 8, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 2 })
          .margin({ left: 12 })
          .onClick(() => {
            this.isShowSidebar = true;
          })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .backgroundColor('rgba(255, 255, 255, 0.00)')
        .backdropBlur(20)
        .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
        .shadow({ radius: 8, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 2 })

        Scroll() {
          Column() {
            // 温湿度显示区域
            Column() {
              Text('环境数据')
                .fontSize(GlassTextStyles.getSecondaryTitleFontSize())
                .fontWeight(FontWeight.Bold)
                .fontColor(GlassTextStyles.getPrimaryTitleColor())
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 16 })

              Row() {
                Column() {
                  Row() {
                    Image($r('app.media.ic_contacts_blood_type')) // 替换为温度图标
                      .width(24)
                      .height(24)
                      .margin({ right: 8 })
                      .fillColor('#FF6B6B')

                    Text('温度')
                      .fontSize(16)
                      .fontColor('#5D6D7E')
                      .fontWeight(FontWeight.Medium)
                  }
                  .margin({ bottom: 8 })

                  Text(`${this.temperature.toFixed(1)}°C`)
                    .fontSize(28)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FF6B6B')
                }
                .width('50%')
                .alignItems(HorizontalAlign.Center)

                Column() {
                  Row() {
                    Image($r('app.media.ic_gallery_blur')) // 替换为湿度图标
                      .width(24)
                      .height(24)
                      .margin({ right: 8 })
                      .fillColor('#4A90E2')

                    Text('湿度')
                      .fontSize(16)
                      .fontColor('#5D6D7E')
                      .fontWeight(FontWeight.Medium)
                  }
                  .margin({ bottom: 8 })

                  Text(`${this.humidity.toFixed(1)}%`)
                    .fontSize(28)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#4A90E2')
                }
                .width('50%')
                .alignItems(HorizontalAlign.Center)
              }
              .width('100%')
              .padding(20)
              .borderRadius(20)
              .backgroundColor(GlassStyles.getGlassCardBackgroundColor())
              .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
              .backdropBlur(20)
              .shadow({ radius: 20, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 8 })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 8 })

            // 闹钟设置区域
            Column() {
              Text('闹钟设置')
                .fontSize(GlassTextStyles.getSecondaryTitleFontSize())
                .fontWeight(FontWeight.Bold)
                .fontColor(GlassTextStyles.getPrimaryTitleColor())
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 16 })

              Row() {
                this.AlarmCardBuilder(0)
                
                Blank()
                
                this.AlarmCardBuilder(1)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 16 })

            // 原始数据显示区域（可折叠）
            Column() {
              Text('调试信息')
                .fontSize(GlassTextStyles.getBodyTextFontSize())
                .fontWeight(FontWeight.Medium)
                .fontColor(GlassTextStyles.getBodyTextColor())
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })

              Text(this.receivedData || '暂无数据')
                .width('100%')
                .fontSize(14)
                .fontColor('#666666')
                .backgroundColor('#F5F5F5')
                .padding(12)
                .borderRadius(8)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 16 })

            // 连接状态显示
            if (this.isConnected) {
              Text(`已连接到: ${this.ipAddress}:${this.port}`)
                .width('100%')
                .textAlign(TextAlign.Center)
                .fontSize(14)
                .fontColor('#4CAF50')
                .margin({ top: 8, bottom: 16 })
            }
            
            // 药丸图标
            Row() {
              Blank()
              
              Image($r('app.media.ic_contacts_emergency_information_drug'))
                .width(64)
                .height(64)
                .fillColor('#FF4081')
                .margin({ top: 16, bottom: 24 })
                .onClick(() => {
                  if (!this.isConnected) {
                    promptAction.showToast({ message: '请先连接设备' });
                    return;
                  }
                  this.isShowFindDevice = true;
                  this.isFindingDevice = false; // 重置查找状态
                })
                .bindSheet($$this.isShowFindDevice, this.FindDeviceSheetBuilder(), {
                  detents: [SheetSize.MEDIUM],
                  preferType: SheetType.BOTTOM,
                  title: { title: '查找设备'},
                })
              
              Blank()
            }
            .width('100%')

            Text('查找设备')
              .fontColor(Color.Gray)
              .fontSize(15)

            // 功能按钮区域
            Row() {
              Button('协议配置')
                .width('45%')
                .height(48)
                .backgroundColor(GlassStyles.getButtonGradientStart('warning'))
                .fontColor(Color.White)
                .fontSize(GlassTextStyles.getBodyTextFontSize())
                .fontWeight(FontWeight.Medium)
                .borderRadius(24)
                .shadow({
                  radius: 12,
                  color: 'rgba(255, 217, 61, 0.3)',
                  offsetX: 0,
                  offsetY: 6
                })
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/ProtocolConfig'
                  }).catch(() => {
                    console.error('跳转失败');
                    promptAction.showToast({ message: '页面跳转失败' });
                  });
                })

              Button('设备监控')
                .width('45%')
                .height(48)
                .backgroundColor(GlassStyles.getButtonGradientStart('secondary'))
                .fontColor(Color.White)
                .fontSize(GlassTextStyles.getBodyTextFontSize())
                .fontWeight(FontWeight.Medium)
                .borderRadius(24)
                .shadow({
                  radius: 12,
                  color: 'rgba(255, 107, 107, 0.3)',
                  offsetX: 0,
                  offsetY: 6
                })
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/DeviceMonitor'
                  }).catch(() => {
                    console.error('跳转失败');
                    promptAction.showToast({ message: '页面跳转失败' });
                  });
                })
            }
            .width('90%')
            .justifyContent(FlexAlign.SpaceBetween)
            .margin({ top: 32, bottom: 16 })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [[GlassColors.PRIMARY_GRADIENT_START, 0.0], [GlassColors.PRIMARY_GRADIENT_END, 1.0]]
        })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [[GlassColors.PRIMARY_GRADIENT_START, 0.0], [GlassColors.PRIMARY_GRADIENT_END, 1.0]]
    })
    .bindContentCover($$this.isShowSidebar, this.SidebarBuilder(), {
      modalTransition: ModalTransition.NONE,
      backgroundColor: 'rgba(0, 0, 0, 0.5)'
    })
  }

  // 侧边栏构建器
  @Builder
  SidebarBuilder() {
    Row() {
      Blank()

      // 侧边栏内容
      Column() {
        // 顶部间距
        Blank()
          .height(60)

        // 标题栏
        Row() {
          Text('关于应用')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2C3E50')
            .layoutWeight(1)

          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.ic_public_cancel_filled'))
              .width(24)
              .height(24)
              .fillColor('#666666')
          }
          .width(36)
          .height(36)
          .backgroundColor('rgba(255, 255, 255, 0.6)')
          .border({ width: 1, color: 'rgba(255, 255, 255, 0.4)' })
          .shadow({ radius: 6, color: 'rgba(0, 0, 0, 0.08)', offsetX: 0, offsetY: 2 })
          .onClick(() => {
            this.isShowSidebar = false;
          })
        }
        .width('100%')
        .height(56)
        .padding({ left: 20, right: 20 })

        Divider()
          .color('rgba(0, 0, 0, 0.1)')
          .strokeWidth(1)

        // 侧边栏内容
        Column() {
          // 开发者信息
          this.SidebarItem('开发者', 'Augment Code Team', () => {
            promptAction.showToast({ message: '感谢使用智慧药盒应用！' });
          })

          Divider().color('rgba(0, 0, 0, 0.08)').strokeWidth(0.5)

          // 开源网址
          this.SidebarItem('开源网址', 'github.com/augment-code/smart-pillbox', () => {
            promptAction.showToast({ message: '开源地址已复制到剪贴板' });
          })

          Divider().color('rgba(0, 0, 0, 0.08)').strokeWidth(0.5)

          // 隐私政策
          this.SidebarItem('隐私政策', '查看隐私保护政策', () => {
            promptAction.showToast({ message: '隐私政策：我们严格保护您的个人信息' });
          })

          Divider().color('rgba(0, 0, 0, 0.08)').strokeWidth(0.5)

          // 备案号
          this.SidebarItem('备案号', '京ICP备2024000001号', () => {
            promptAction.showToast({ message: '备案信息已显示' });
          })

          Divider().color('rgba(0, 0, 0, 0.08)').strokeWidth(0.5)

          // 版本信息
          this.SidebarItem('版本信息', 'v1.0.0 (Build 2024.01)', () => {
            promptAction.showToast({ message: '当前版本：v1.0.0' });
          })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 16 })

        Blank()

        // 底部版权信息
        Text('© 2024 Augment Code. All rights reserved.')
          .fontSize(12)
          .fontColor('#999999')
          .textAlign(TextAlign.Center)
          .padding({ bottom: 20 })
      }
      .width(320)
      .height('100%')
      .backgroundColor('rgba(255, 255, 255, 0.85)')
      .backdropBlur(25)
      .borderRadius({ topLeft: 16, bottomLeft: 16 })
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.3)' })
      .shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.1)', offsetX: -5, offsetY: 0 })
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      this.isShowSidebar = false;
    })
  }

  // 侧边栏项目构建器
  @Builder
  SidebarItem(title: string, subtitle: string, onClick: () => void) {
    Column() {
      Row() {
        Column() {
          Text(title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#2C3E50')
            .textAlign(TextAlign.Start)

          Text(subtitle)
            .fontSize(14)
            .fontColor('#666666')
            .textAlign(TextAlign.Start)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Image($r('app.media.ic_public_arrow_right_filled'))
          .width(16)
          .height(16)
          .fillColor('#CCCCCC')
      }
      .width('100%')
      .padding({ top: 16, bottom: 16 })
      .onClick(onClick)
    }
    .width('100%')
  }
}

