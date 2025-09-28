import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import socket from '@ohos.net.socket';
import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { GlassStyles, GlassColors, GlassAnimations, GlassTextStyles } from '../common/GlassStyles';

// 数据格式枚举
enum DataFormat {
  TEXT = 'TEXT',
  JSON = 'JSON',
  HEX = 'HEX',
  BINARY = 'BINARY'
}

// 测试命令预设
interface TestCommand {
  name: string;
  description: string;
  data: string;
  format: DataFormat;
}

@Entry
@Component
struct DataTest {
  @State sendData: string = '';
  @State receivedData: string = '';
  @State selectedFormat: DataFormat = DataFormat.TEXT;
  @State isConnected: boolean = false;
  @State connectionInfo: string = '';
  @State sendHistory: string[] = [];
  @State showHistory: boolean = false;

  // TCP连接相关
  @State ipAddress: string = '';
  @State port: number = 8888;
  private tcpSocket: socket.TCPSocket | null = null;

  // 预设测试命令
  @State testCommands: TestCommand[] = [
    {
      name: 'LED控制',
      description: '控制LED开关',
      data: '{"cmd":"LED","state":1}',
      format: DataFormat.JSON
    },
    {
      name: '获取状态',
      description: '查询设备状态',
      data: '{"cmd":"STATUS"}',
      format: DataFormat.JSON
    },
    {
      name: '重启设备',
      description: '重启嵌入式设备',
      data: 'RESET',
      format: DataFormat.TEXT
    },
    {
      name: '读取寄存器',
      description: 'Modbus读取寄存器',
      data: '01 03 00 00 00 01 84 0A',
      format: DataFormat.HEX
    },
    {
      name: '心跳包',
      description: '发送心跳保持连接',
      data: 'PING',
      format: DataFormat.TEXT
    }
  ];

  private context = getContext(this) as common.UIAbilityContext;
  private preferencesInstance: preferences.Preferences | null = null;
  private socket: socket.TCPSocket | null = null;

  async aboutToAppear() {
    await this.initPreferences();
    await this.loadConnectionInfo();
  }

  // 初始化Preferences
  async initPreferences() {
    try {
      this.preferencesInstance = await preferences.getPreferences(this.context, 'data_test');
    } catch {
      console.error('Preferences初始化失败');
    }
  }

  // 加载连接信息
  async loadConnectionInfo() {
    if (!this.preferencesInstance) return;
    
    try {
      const savedInfo = await this.preferencesInstance.get('connection_info', '');
      if (typeof savedInfo === 'string' && savedInfo) {
        this.connectionInfo = savedInfo;
      }
      
      const history = await this.preferencesInstance.get('send_history', '');
      if (typeof history === 'string' && history) {
        // 简单的字符串数组解析，避免JSON.parse的any类型
        if (history.startsWith('[') && history.endsWith(']')) {
          const items = history.slice(1, -1).split('","');
          this.sendHistory = items.map(item => item.replace(/^"|"$/g, ''));
        }
      }
    } catch {
      console.error('加载连接信息失败');
    }
  }

  // 保存发送历史
  async saveSendHistory() {
    if (!this.preferencesInstance) return;
    
    try {
      await this.preferencesInstance.put('send_history', JSON.stringify(this.sendHistory));
      await this.preferencesInstance.flush();
    } catch (err) {
      console.error('保存发送历史失败:', err);
    }
  }

  // 格式化数据
  formatData(data: string, format: DataFormat): string {
    switch (format) {
      case DataFormat.JSON:
        // 简单的JSON格式化，避免JSON.parse的any类型
        try {
          // 基本的JSON格式化，添加缩进
          let formatted = data.trim();
          if (formatted.startsWith('{') && formatted.endsWith('}')) {
            formatted = formatted.replace(/,/g, ',\n  ').replace(/{/g, '{\n  ').replace(/}/g, '\n}');
          }
          return formatted;
        } catch {
          return data;
        }
      case DataFormat.HEX:
        return data.replace(/\s+/g, ' ').toUpperCase();
      case DataFormat.BINARY:
        return data.replace(/[^01]/g, '');
      default:
        return data;
    }
  }

  // 发送数据
  sendTestData() {
    if (!this.sendData.trim()) {
      promptAction.showToast({ message: '请输入要发送的数据' });
      return;
    }

    // 格式化数据
    const formattedData = this.formatData(this.sendData, this.selectedFormat);

    // 添加到历史记录
    const historyItem = `[${new Date().toLocaleTimeString()}] ${this.selectedFormat}: ${formattedData}`;
    this.sendHistory.unshift(historyItem);
    if (this.sendHistory.length > 50) {
      this.sendHistory = this.sendHistory.slice(0, 50);
    }
    this.saveSendHistory();

    // 真实发送数据
    this.sendRealData(formattedData);
  }

  // 真实数据发送方法
  private sendRealData(data: string) {
    // 检查是否有连接
    if (!this.tcpSocket || !this.isConnected) {
      // 尝试从主页面获取连接信息
      this.loadConnectionFromMainPage();

      if (!this.ipAddress || !this.port) {
        promptAction.showToast({ message: '请先在主页面连接设备，或手动配置连接信息' });
        this.receivedData = '错误: 未连接设备';
        return;
      }

      // 尝试建立连接
      this.connectToDevice(data);
      return;
    }

    // 发送数据
    this.tcpSocket.send({
      data: data,
      encoding: 'utf-8'
    }, (err) => {
      if (err) {
        promptAction.showToast({ message: '发送失败: ' + (err.message || '网络错误') });
        this.receivedData = `发送失败: ${err.message || '网络错误'}`;
      } else {
        promptAction.showToast({ message: '数据已发送' });
        this.receivedData = '数据已发送，等待响应...';
      }
    });
  }

  // 从主页面加载连接信息
  private async loadConnectionFromMainPage() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const mainPrefs = await preferences.getPreferences(context, 'main_settings');

      const savedIp = await mainPrefs.get('ip_address', '');
      const savedPort = await mainPrefs.get('port', 8888);

      if (typeof savedIp === 'string' && savedIp) {
        this.ipAddress = savedIp;
      }

      if (typeof savedPort === 'number') {
        this.port = savedPort;
      }
    } catch (err) {
      console.error('加载主页面连接信息失败:', err);
    }
  }

  // 连接到设备
  private connectToDevice(pendingData?: string) {
    if (this.tcpSocket) {
      this.tcpSocket.close();
    }

    try {
      this.tcpSocket = socket.constructTCPSocketInstance();

      this.tcpSocket.on('connect', () => {
        this.isConnected = true;
        this.connectionInfo = `已连接: ${this.ipAddress}:${this.port}`;
        promptAction.showToast({ message: '连接成功' });

        // 如果有待发送的数据，立即发送
        if (pendingData) {
          this.sendRealData(pendingData);
        }
      });

      this.tcpSocket.on('message', (data: socket.SocketMessageInfo) => {
        try {
          let responseStr = '';
          if (data.message instanceof ArrayBuffer) {
            const arr = new Uint8Array(data.message);
            for (let i = 0; i < arr.length; i++) {
              responseStr += String.fromCharCode(arr[i]);
            }
          } else {
            responseStr = String(data.message);
          }

          this.receivedData = `[${new Date().toLocaleTimeString()}] 收到: ${responseStr}`;
        } catch (err) {
          console.error('数据处理错误:', err);
          this.receivedData = '数据解析错误';
        }
      });

      this.tcpSocket.on('close', () => {
        this.isConnected = false;
        this.connectionInfo = '连接已断开';
      });

      this.tcpSocket.on('error', (err) => {
        this.isConnected = false;
        this.connectionInfo = '连接失败';
        promptAction.showToast({
          message: `连接失败: ${err.message || '请检查IP/端口'}`
        });
        this.receivedData = `连接错误: ${err.message || '网络不可达'}`;
      });

      const options: socket.TCPConnectOptions = {
        address: {
          address: this.ipAddress,
          port: this.port,
          family: 1
        },
        timeout: 5000
      };

      this.tcpSocket.connect(options);

    } catch (err) {
      this.isConnected = false;
      promptAction.showToast({ message: '连接异常' });
      this.receivedData = `连接异常: ${err.message || '未知错误'}`;
    }
  }

  // 断开设备连接
  private disconnectDevice() {
    if (this.tcpSocket) {
      this.tcpSocket.close();
      this.tcpSocket = null;
    }
    this.isConnected = false;
    this.connectionInfo = '';
  }

  // 清空数据
  clearData() {
    this.sendData = '';
    this.receivedData = '';
  }

  // 清空历史
  clearHistory() {
    this.sendHistory = [];
    this.saveSendHistory();
  }

  @Builder
  FormatSelectorBuilder() {
    Column() {
      Text('数据格式:')
        .fontSize(GlassTextStyles.getBodyTextFontSize())
        .fontColor(GlassTextStyles.getBodyTextColor())
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 8 })

      Row() {
        ForEach(Object.values(DataFormat), (format: DataFormat) => {
          Button(format)
            .fontSize(12)
            .height(36)
            .layoutWeight(1)
            .backgroundColor(this.selectedFormat === format ?
              GlassStyles.getButtonGradientStart('primary') :
              GlassStyles.getGlassCardBackgroundColor())
            .fontColor(this.selectedFormat === format ? Color.White :
              GlassTextStyles.getBodyTextColor())
            .borderRadius(18)
            .border({
              width: 1,
              color: this.selectedFormat === format ?
                GlassStyles.getButtonGradientStart('primary') :
                GlassStyles.getGlassBorderColor()
            })
            .shadow({
              radius: this.selectedFormat === format ? 6 : 3,
              color: this.selectedFormat === format ?
                'rgba(74, 144, 226, 0.3)' :
                GlassStyles.getShadowColor(),
              offsetX: 0,
              offsetY: 2
            })
            .margin({ right: format === DataFormat.BINARY ? 0 : 8 })
            .onClick(() => {
              this.selectedFormat = format;
            })
        })
      }
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: 16 })
  }

  @Builder
  QuickCommandsBuilder() {
    Column() {
      Row() {
        Text('快速命令')
          .fontSize(GlassTextStyles.getSecondaryTitleFontSize())
          .fontWeight(FontWeight.Bold)
          .fontColor(GlassTextStyles.getPrimaryTitleColor())
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ bottom: 16 })

      Grid() {
        ForEach(this.testCommands, (command: TestCommand, index: number) => {
          GridItem() {
            Column() {
              Text(command.name)
                .fontSize(GlassTextStyles.getLabelTextFontSize())
                .fontWeight(FontWeight.Bold)
                .fontColor(GlassTextStyles.getPrimaryTitleColor())
                .margin({ bottom: 4 })

              Text(command.description)
                .fontSize(12)
                .fontColor(GlassTextStyles.getLabelTextColor())
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .height(60)
            .padding(8)
            .backgroundColor(GlassStyles.getGlassCardBackgroundColor())
            .borderRadius(12)
            .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
            .backdropBlur(10)
            .shadow({ radius: 6, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 3 })
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.sendData = command.data;
              this.selectedFormat = command.format;
            })
          }
        })
      }
      .columnsTemplate('1fr 1fr')
      .rowsGap(8)
      .columnsGap(8)
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(GlassStyles.getGlassCardBackgroundColor())
    .borderRadius(16)
    .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
    .backdropBlur(15)
    .shadow({ radius: 15, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 6 })
    .margin({ bottom: 16 })
  }

  @Builder
  HistoryBuilder() {
    Column() {
      Row() {
        Text('发送历史')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)

        Button('清空')
          .fontSize(14)
          .backgroundColor('transparent')
          .fontColor('#FF5722')
          .onClick(() => {
            this.clearHistory();
          })
      }
      .width('100%')
      .margin({ bottom: 16 })

      if (this.sendHistory.length === 0) {
        Text('暂无发送记录')
          .fontSize(14)
          .fontColor('#999999')
          .textAlign(TextAlign.Center)
          .width('100%')
          .height(60)
      } else {
        List() {
          ForEach(this.sendHistory.slice(0, 10), (item: string, index: number) => {
            ListItem() {
              Text(item)
                .fontSize(12)
                .fontColor('#666666')
                .width('100%')
                .padding(8)
                .backgroundColor('#F8F8F8')
                .borderRadius(4)
                .onClick(() => {
                  // 从历史记录中提取数据
                  const parts = item.split(': ');
                  if (parts.length >= 2) {
                    this.sendData = parts.slice(1).join(': ');
                  }
                })
            }
            .margin({ bottom: 4 })
          })
        }
        .width('100%')
        .height(200)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  build() {
    Column() {
      // 状态栏占位区域
      Row()
        .width('100%')
        .height(44) // 状态栏高度
        .backgroundColor('#FFFFFF')

      // 标题栏
      Row() {
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_public_back'))
            .width(24)
            .height(24)
            .fillColor('#333333')
        }
        .width(40)
        .height(40)
        .backgroundColor('transparent')
        .onClick(() => {
          router.back();
        })

        Text('数据测试')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button('清空')
          .fontSize(14)
          .width(60)
          .height(36)
          .backgroundColor('#FF5722')
          .borderRadius(18)
          .onClick(() => {
            this.clearData();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF')

      Scroll() {
        Column() {
          // 快速命令
          this.QuickCommandsBuilder()

          // 数据输入区域
          Column() {
            Text('数据发送')
              .fontSize(GlassTextStyles.getSecondaryTitleFontSize())
              .fontWeight(FontWeight.Bold)
              .fontColor(GlassTextStyles.getPrimaryTitleColor())
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 16 })

            // 格式选择器
            this.FormatSelectorBuilder()

            // 数据输入框
            TextArea({ text: this.sendData, placeholder: '请输入要发送的数据...' })
              .width('100%')
              .height(120)
              .borderRadius(12)
              .backgroundColor(GlassStyles.getInputBackgroundColor())
              .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
              .backdropBlur(10)
              .shadow({ radius: 4, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 2 })
              .onChange((value: string) => {
                this.sendData = value;
              })
              .margin({ bottom: 16 })

            // 发送按钮
            Button('发送数据')
              .width('100%')
              .height(48)
              .backgroundColor(GlassStyles.getButtonGradientStart('primary'))
              .fontColor(Color.White)
              .borderRadius(24)
              .shadow({
                radius: 12,
                color: 'rgba(74, 144, 226, 0.3)',
                offsetX: 0,
                offsetY: 4
              })
              .onClick(() => {
                this.sendTestData();
              })
          }
          .width('100%')
          .padding(20)
          .backgroundColor(GlassStyles.getGlassCardBackgroundColor())
          .borderRadius(16)
          .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
          .backdropBlur(15)
          .shadow({ radius: 15, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 6 })
          .margin({ top: 16 })

          // 接收数据区域
          Column() {
            Text('接收数据')
              .fontSize(GlassTextStyles.getSecondaryTitleFontSize())
              .fontWeight(FontWeight.Bold)
              .fontColor(GlassTextStyles.getPrimaryTitleColor())
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 16 })

            TextArea({ text: this.receivedData, placeholder: '接收到的数据将显示在这里...' })
              .width('100%')
              .height(120)
              .borderRadius(12)
              .backgroundColor(GlassStyles.getDataCardBackgroundColor())
              .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
              .backdropBlur(10)
              .shadow({ radius: 4, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 2 })
              .enabled(false)
          }
          .width('100%')
          .padding(20)
          .backgroundColor(GlassStyles.getGlassCardBackgroundColor())
          .borderRadius(16)
          .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
          .backdropBlur(15)
          .shadow({ radius: 15, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 6 })
          .margin({ top: 16 })

          // 发送历史
          this.HistoryBuilder()
        }
        .padding(16)
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
  }
}
