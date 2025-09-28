import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import socket from '@ohos.net.socket';
import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { GlassStyles, GlassColors, GlassAnimations, GlassTextStyles } from '../common/GlassStyles';

// 设备状态接口
interface DeviceStatus {
  online: boolean;
  lastSeen: string;
  uptime: number;
  cpuUsage: number;
  memoryUsage: number;
  temperature: number;
  voltage: number;
  signalStrength: number;
}

// 日志条目接口
interface LogEntry {
  timestamp: string;
  level: 'INFO' | 'WARN' | 'ERROR' | 'DEBUG';
  message: string;
}

// 状态查询命令接口
interface StatusCommand {
  type: string;
  timestamp: number;
}

@Entry
@Component
struct DeviceMonitor {
  @State deviceStatus: DeviceStatus = {
    online: false,
    lastSeen: '--',
    uptime: 0,
    cpuUsage: 0,
    memoryUsage: 0,
    temperature: 0,
    voltage: 0,
    signalStrength: 0
  };

  @State logs: LogEntry[] = [];
  @State isMonitoring: boolean = false;
  @State refreshInterval: number = 1000; // 刷新间隔(ms)
  @State selectedLogLevel: string = 'ALL';
  @State showRealTimeChart: boolean = false;

  // 真实设备连接
  @State useRealDevice: boolean = false;
  @State ipAddress: string = '';
  @State port: number = 8888;
  private tcpSocket: socket.TCPSocket | null = null;

  // 实时数据图表数据
  @State cpuHistory: number[] = [];
  @State memoryHistory: number[] = [];
  @State temperatureHistory: number[] = [];

  private monitorTimer: number | undefined = undefined;
  private maxHistoryPoints: number = 50;

  aboutToAppear() {
    this.loadConnectionSettings();
    this.startMonitoring();
  }

  aboutToDisappear() {
    this.stopMonitoring();
    this.disconnectDevice();
  }

  // 开始监控
  startMonitoring() {
    if (this.isMonitoring) return;

    this.isMonitoring = true;
    this.monitorTimer = setInterval(() => {
      this.updateDeviceStatus();
    }, this.refreshInterval);

    promptAction.showToast({ message: '开始监控设备状态' });
  }

  // 停止监控
  stopMonitoring() {
    if (!this.isMonitoring) return;

    this.isMonitoring = false;
    if (this.monitorTimer !== undefined) {
      clearInterval(this.monitorTimer);
      this.monitorTimer = undefined;
    }

    promptAction.showToast({ message: '停止监控设备状态' });
  }

  // 更新设备状态
  updateDeviceStatus() {
    if (this.useRealDevice && this.tcpSocket && this.deviceStatus.online) {
      // 请求真实设备状态
      this.requestDeviceStatus();
    } else {
      // 使用模拟数据
      this.updateSimulatedStatus();
    }
  }

  // 请求真实设备状态
  private requestDeviceStatus() {
    if (!this.tcpSocket) return;

    // 发送状态查询命令
    const statusCmd: StatusCommand = {
      type: "GET_STATUS",
      timestamp: new Date().getTime()
    };

    this.tcpSocket.send({
      data: JSON.stringify(statusCmd),
      encoding: 'utf-8'
    }, (err) => {
      if (err) {
        console.error('发送状态查询失败:', err);
        this.addLog('ERROR', '状态查询失败: ' + (err.message || '网络错误'));
        // 如果发送失败，回退到模拟数据
        this.updateSimulatedStatus();
      }
    });
  }

  // 更新模拟状态数据
  private updateSimulatedStatus() {
    this.deviceStatus = {
      online: Math.random() > 0.1, // 90%在线率
      lastSeen: new Date().toLocaleTimeString(),
      uptime: this.deviceStatus.uptime + 1,
      cpuUsage: Math.random() * 100,
      memoryUsage: 30 + Math.random() * 40,
      temperature: 25 + Math.random() * 15,
      voltage: 3.2 + Math.random() * 0.6,
      signalStrength: 60 + Math.random() * 40
    };

    this.updateHistoryData();

    // 模拟日志生成
    if (Math.random() > 0.7) {
      this.addRandomLog();
    }
  }

  // 更新历史数据
  private updateHistoryData() {
    this.cpuHistory.push(this.deviceStatus.cpuUsage);
    this.memoryHistory.push(this.deviceStatus.memoryUsage);
    this.temperatureHistory.push(this.deviceStatus.temperature);

    // 限制历史数据长度
    if (this.cpuHistory.length > this.maxHistoryPoints) {
      this.cpuHistory.shift();
      this.memoryHistory.shift();
      this.temperatureHistory.shift();
    }
  }

  // 加载连接设置
  private async loadConnectionSettings() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const prefs = await preferences.getPreferences(context, 'main_settings');

      const savedIp = await prefs.get('ip_address', '');
      const savedPort = await prefs.get('port', 8888);

      if (typeof savedIp === 'string' && savedIp) {
        this.ipAddress = savedIp;
        this.useRealDevice = true;
        this.connectToDevice();
      }

      if (typeof savedPort === 'number') {
        this.port = savedPort;
      }
    } catch (err) {
      console.error('加载连接设置失败:', err);
    }
  }

  // 连接到设备
  private connectToDevice() {
    if (!this.ipAddress || !this.port) return;

    try {
      this.tcpSocket = socket.constructTCPSocketInstance();

      this.tcpSocket.on('connect', () => {
        this.deviceStatus.online = true;
        this.addLog('INFO', `已连接到设备: ${this.ipAddress}:${this.port}`);
      });

      this.tcpSocket.on('message', (data: socket.SocketMessageInfo) => {
        this.handleDeviceMessage(data);
      });

      this.tcpSocket.on('close', () => {
        this.deviceStatus.online = false;
        this.addLog('WARN', '设备连接已断开');
      });

      this.tcpSocket.on('error', (err) => {
        this.deviceStatus.online = false;
        this.addLog('ERROR', `连接错误: ${err.message || '网络不可达'}`);
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
      this.addLog('ERROR', `连接异常: ${err.message || '未知错误'}`);
    }
  }

  // 处理设备消息
  private handleDeviceMessage(data: socket.SocketMessageInfo) {
    try {
      let messageStr = '';
      if (data.message instanceof ArrayBuffer) {
        const arr = new Uint8Array(data.message);
        for (let i = 0; i < arr.length; i++) {
          messageStr += String.fromCharCode(arr[i]);
        }
      } else {
        messageStr = String(data.message);
      }

      // 解析设备状态数据
      this.parseDeviceStatus(messageStr);

    } catch (err) {
      this.addLog('ERROR', '数据解析错误: ' + (err.message || '格式错误'));
    }
  }

  // 解析设备状态
  private parseDeviceStatus(dataStr: string) {
    try {
      // 使用正则表达式解析JSON数据，避免any类型
      const cpuMatch = dataStr.match(/"cpu_usage"\s*:\s*([\d.]+)/);
      const memoryMatch = dataStr.match(/"memory_usage"\s*:\s*([\d.]+)/);
      const tempMatch = dataStr.match(/"temperature"\s*:\s*([\d.]+)/);
      const voltageMatch = dataStr.match(/"voltage"\s*:\s*([\d.]+)/);
      const signalMatch = dataStr.match(/"signal_strength"\s*:\s*([\d.]+)/);
      const uptimeMatch = dataStr.match(/"uptime"\s*:\s*(\d+)/);

      if (cpuMatch) this.deviceStatus.cpuUsage = parseFloat(cpuMatch[1]);
      if (memoryMatch) this.deviceStatus.memoryUsage = parseFloat(memoryMatch[1]);
      if (tempMatch) this.deviceStatus.temperature = parseFloat(tempMatch[1]);
      if (voltageMatch) this.deviceStatus.voltage = parseFloat(voltageMatch[1]);
      if (signalMatch) this.deviceStatus.signalStrength = parseFloat(signalMatch[1]);
      if (uptimeMatch) this.deviceStatus.uptime = parseInt(uptimeMatch[1]);

      this.deviceStatus.lastSeen = new Date().toLocaleTimeString();
      this.updateHistoryData();

      // 检查是否有日志信息
      const logMatch = dataStr.match(/"log"\s*:\s*"([^"]+)"/);
      const levelMatch = dataStr.match(/"log_level"\s*:\s*"([^"]+)"/);

      if (logMatch && levelMatch) {
        const level = levelMatch[1] as 'INFO' | 'WARN' | 'ERROR' | 'DEBUG';
        this.addLog(level, logMatch[1]);
      }

    } catch (err) {
      this.addLog('ERROR', '状态解析失败: ' + (err.message || '数据格式错误'));
    }
  }

  // 断开设备连接
  private disconnectDevice() {
    if (this.tcpSocket) {
      this.tcpSocket.close();
      this.tcpSocket = null;
    }
  }

  // 添加日志
  private addLog(level: 'INFO' | 'WARN' | 'ERROR' | 'DEBUG', message: string) {
    const newLog: LogEntry = {
      timestamp: new Date().toLocaleTimeString(),
      level: level,
      message: message
    };

    this.logs.unshift(newLog);
    if (this.logs.length > 100) {
      this.logs = this.logs.slice(0, 100);
    }
  }

  // 添加随机日志（仅用于模拟模式）
  addRandomLog() {
    const levels: ('INFO' | 'WARN' | 'ERROR' | 'DEBUG')[] = ['INFO', 'WARN', 'ERROR', 'DEBUG'];
    const messages = [
      '设备启动完成',
      '传感器数据更新',
      '网络连接正常',
      '内存使用率较高',
      '温度传感器异常',
      '电压波动检测',
      '接收到控制命令',
      '数据发送成功'
    ];

    const newLog: LogEntry = {
      timestamp: new Date().toLocaleTimeString(),
      level: levels[Math.floor(Math.random() * levels.length)],
      message: messages[Math.floor(Math.random() * messages.length)]
    };

    this.logs.unshift(newLog);
    if (this.logs.length > 100) {
      this.logs = this.logs.slice(0, 100);
    }
  }

  // 获取过滤后的日志
  getFilteredLogs(): LogEntry[] {
    if (this.selectedLogLevel === 'ALL') {
      return this.logs;
    }
    return this.logs.filter(log => log.level === this.selectedLogLevel);
  }

  // 格式化运行时间
  formatUptime(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  @Builder
  StatusCardBuilder(title: string, value: string, unit: string, color: string, icon?: Resource) {
    Column() {
      if (icon) {
        Image(icon)
          .width(24)
          .height(24)
          .fillColor(color)
          .margin({ bottom: 8 })
      }
      
      Text(title)
        .fontSize(14)
        .fontColor('#666666')
        .margin({ bottom: 4 })
      
      Row() {
        Text(value)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
        
        Text(unit)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ left: 4 })
      }
    }
    .width('48%')
    .height(80)
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .shadow({ radius: 4, color: 'rgba(0, 0, 0, 0.1)', offsetX: 0, offsetY: 2 })
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

        Text('设备监控')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 数据源切换按钮
        Button(this.useRealDevice ? '真实' : '模拟')
          .fontSize(12)
          .height(32)
          .backgroundColor(this.useRealDevice ? '#2196F3' : '#9E9E9E')
          .margin({ right: 8 })
          .onClick(() => {
            this.useRealDevice = !this.useRealDevice;
            if (this.useRealDevice && this.ipAddress) {
              this.connectToDevice();
            } else {
              this.disconnectDevice();
            }
            promptAction.showToast({
              message: this.useRealDevice ? '切换到真实设备数据' : '切换到模拟数据'
            });
          })

        Button(this.isMonitoring ? '停止' : '开始')
          .fontSize(16)
          .backgroundColor(this.isMonitoring ? '#FF5722' : '#4CAF50')
          .onClick(() => {
            if (this.isMonitoring) {
              this.stopMonitoring();
            } else {
              this.startMonitoring();
            }
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF')

      Scroll() {
        Column() {
          // 设备状态概览
          Column() {
            Row() {
              Text('设备状态')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .layoutWeight(1)

              Row() {
                Circle({ width: 12, height: 12 })
                  .fill(this.deviceStatus.online ? '#4CAF50' : '#FF5722')
                  .margin({ right: 8 })
                
                Text(this.deviceStatus.online ? '在线' : '离线')
                  .fontSize(14)
                  .fontColor(this.deviceStatus.online ? '#4CAF50' : '#FF5722')
              }
            }
            .width('100%')
            .margin({ bottom: 16 })

            // 基础信息
            Column() {
              Row() {
                Text(`最后通信: ${this.deviceStatus.lastSeen}`)
                  .fontSize(14)
                  .fontColor('#666666')
                  .layoutWeight(1)
                
                Text(`运行时间: ${this.formatUptime(this.deviceStatus.uptime)}`)
                  .fontSize(14)
                  .fontColor('#666666')
              }
              .width('100%')
              .margin({ bottom: 12 })

              // 状态卡片
              Row() {
                this.StatusCardBuilder('CPU使用率', this.deviceStatus.cpuUsage.toFixed(1), '%', '#FF9800')
                
                Blank()
                
                this.StatusCardBuilder('内存使用', this.deviceStatus.memoryUsage.toFixed(1), '%', '#2196F3')
              }
              .width('100%')
              .margin({ bottom: 12 })

              Row() {
                this.StatusCardBuilder('温度', this.deviceStatus.temperature.toFixed(1), '°C', '#FF5722')
                
                Blank()
                
                this.StatusCardBuilder('电压', this.deviceStatus.voltage.toFixed(2), 'V', '#4CAF50')
              }
              .width('100%')
              .margin({ bottom: 12 })

              this.StatusCardBuilder('信号强度', this.deviceStatus.signalStrength.toFixed(0), 'dBm', '#9C27B0')
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)

          // 实时日志
          Column() {
            Text('实时日志')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 16 })

            // 日志列表
            if (this.getFilteredLogs().length === 0) {
              Text('暂无日志记录')
                .fontSize(14)
                .fontColor('#999999')
                .textAlign(TextAlign.Center)
                .width('100%')
                .height(100)
            } else {
              List() {
                ForEach(this.getFilteredLogs().slice(0, 20), (log: LogEntry, index: number) => {
                  ListItem() {
                    Row() {
                      Text(log.timestamp)
                        .fontSize(12)
                        .fontColor('#999999')
                        .width(80)
                      
                      Text(log.level)
                        .fontSize(12)
                        .fontColor(this.getLogLevelColor(log.level))
                        .width(50)
                        .textAlign(TextAlign.Center)
                        .backgroundColor(this.getLogLevelBgColor(log.level))
                        .borderRadius(4)
                        .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                      
                      Text(log.message)
                        .fontSize(12)
                        .fontColor('#333333')
                        .layoutWeight(1)
                        .margin({ left: 8 })
                    }
                    .width('100%')
                    .padding(8)
                    .backgroundColor(index % 2 === 0 ? '#FAFAFA' : '#FFFFFF')
                  }
                })
              }
              .width('100%')
              .height(240)
              .borderRadius(8)
              .backgroundColor('#F8F8F8')
            }

            // 日志级别过滤器 - 移到下方
            Column() {
              Text('日志级别:')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#333333')
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 12, top: 20 })

              Row() {
                ForEach(['ALL', 'INFO', 'WARN', 'ERROR'], (level: string) => {
                  Button(level)
                    .fontSize(13)
                    .height(36)
                    .layoutWeight(1)
                    .backgroundColor(this.selectedLogLevel === level ? '#007AFF' : '#F8F8F8')
                    .fontColor(this.selectedLogLevel === level ? Color.White : '#666666')
                    .borderRadius(18)
                    .border({
                      width: this.selectedLogLevel === level ? 0 : 1,
                      color: '#E0E0E0'
                    })
                    .shadow({
                      radius: this.selectedLogLevel === level ? 4 : 0,
                      color: 'rgba(0, 122, 255, 0.3)',
                      offsetX: 0,
                      offsetY: 2
                    })
                    .margin({ right: level === 'ERROR' ? 0 : 8 })
                    .onClick(() => {
                      this.selectedLogLevel = level;
                    })
                })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ top: 16 })
        }
        .padding(16)
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
  }

  // 获取日志级别颜色
  private getLogLevelColor(level: string): string {
    switch (level) {
      case 'ERROR': return '#FFFFFF';
      case 'WARN': return '#FFFFFF';
      case 'INFO': return '#FFFFFF';
      case 'DEBUG': return '#FFFFFF';
      default: return '#333333';
    }
  }

  // 获取日志级别背景色
  private getLogLevelBgColor(level: string): string {
    switch (level) {
      case 'ERROR': return '#FF5722';
      case 'WARN': return '#FF9800';
      case 'INFO': return '#4CAF50';
      case 'DEBUG': return '#9E9E9E';
      default: return '#E0E0E0';
    }
  }
}
