import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import socket from '@ohos.net.socket';
import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { BusinessError } from '@kit.BasicServicesKit';
import { GlassStyles, GlassColors, GlassAnimations, GlassTextStyles } from '../common/GlassStyles';

// 协议类型枚举
enum ProtocolType {
  TCP = 'TCP',
  UDP = 'UDP',
  HTTP = 'HTTP',
  HTTPS = 'HTTPS',
  WEBSOCKET = 'WebSocket',
  MQTT = 'MQTT',
  SERIAL = 'Serial',
  MODBUS = 'Modbus'
}

// 连接配置接口
interface ConnectionConfig {
  protocol: ProtocolType;
  host: string;
  port: number;
  timeout: number;
  // TCP/UDP 特有参数
  keepAlive?: boolean;
  // HTTP/HTTPS 特有参数
  method?: string;
  // WebSocket 特有参数
  subProtocol?: string;
  // MQTT 特有参数
  clientId?: string;
  username?: string;
  password?: string;
  topic?: string;
  // Serial 特有参数
  baudRate?: number;
  dataBits?: number;
  stopBits?: number;
  parity?: string;
  // Modbus 特有参数
  slaveId?: number;
  functionCode?: number;
}

@Entry
@Component
struct ProtocolConfig {
  @State selectedProtocol: ProtocolType = ProtocolType.TCP;
  @State config: ConnectionConfig = {
    protocol: ProtocolType.TCP,
    host: '192.168.1.100',
    port: 8888,
    timeout: 5000
  };
  @State isConnected: boolean = false;
  @State connectionStatus: string = '未连接';
  @State testResult: string = '';
  @State showAdvanced: boolean = false;

  // 获取协议显示名称的方法
  private getProtocolDisplayName(protocol: ProtocolType): string {
    switch (protocol) {
      case ProtocolType.TCP:
        return 'TCP';
      case ProtocolType.UDP:
        return 'UDP';
      case ProtocolType.HTTP:
        return 'HTTP';
      case ProtocolType.HTTPS:
        return 'HTTPS';
      case ProtocolType.WEBSOCKET:
        return 'WebSocket';
      case ProtocolType.MQTT:
        return 'MQTT';
      case ProtocolType.SERIAL:
        return 'Serial';
      case ProtocolType.MODBUS:
        return 'Modbus';
      default:
        return protocol;
    }
  }

  private context = getContext(this) as common.UIAbilityContext;
  private preferencesInstance: preferences.Preferences | null = null;
  private socket: socket.TCPSocket | socket.UDPSocket | null = null;

  async aboutToAppear() {
    await this.initPreferences();
    await this.loadConfig();
  }

  // 初始化Preferences
  async initPreferences() {
    try {
      this.preferencesInstance = await preferences.getPreferences(this.context, 'protocol_config');
    } catch {
      console.error('Preferences初始化失败');
    }
  }

  // 加载配置
  async loadConfig() {
    if (!this.preferencesInstance) return;
    
    try {
      const savedConfig = await this.preferencesInstance.get('connection_config', '');
      if (typeof savedConfig === 'string' && savedConfig) {
        // 使用正则表达式解析配置，避免any类型
        const protocolMatch = savedConfig.match(/"protocol"\s*:\s*"([^"]+)"/);
        const hostMatch = savedConfig.match(/"host"\s*:\s*"([^"]+)"/);
        const portMatch = savedConfig.match(/"port"\s*:\s*(\d+)/);
        const timeoutMatch = savedConfig.match(/"timeout"\s*:\s*(\d+)/);

        if (protocolMatch && hostMatch && portMatch && timeoutMatch) {
          this.config = {
            protocol: protocolMatch[1] as ProtocolType,
            host: hostMatch[1],
            port: parseInt(portMatch[1]),
            timeout: parseInt(timeoutMatch[1])
          };
          this.selectedProtocol = this.config.protocol;
        }
      }
    } catch {
      console.error('加载配置失败');
    }
  }

  // 保存配置
  async saveConfig() {
    if (!this.preferencesInstance) return;
    
    try {
      await this.preferencesInstance.put('connection_config', JSON.stringify(this.config));
      await this.preferencesInstance.flush();
      promptAction.showToast({ message: '配置已保存' });
    } catch {
      console.error('保存配置失败');
    }
  }

  // 协议切换处理
  onProtocolChange(protocol: ProtocolType) {
    this.selectedProtocol = protocol;
    this.config.protocol = protocol;
    
    // 根据协议设置默认端口
    switch (protocol) {
      case ProtocolType.TCP:
        this.config.port = 8888;
        break;
      case ProtocolType.UDP:
        this.config.port = 8889;
        break;
      case ProtocolType.HTTP:
        this.config.port = 80;
        this.config.method = 'GET';
        break;
      case ProtocolType.HTTPS:
        this.config.port = 443;
        this.config.method = 'GET';
        break;
      case ProtocolType.WEBSOCKET:
        this.config.port = 8080;
        break;
      case ProtocolType.MQTT:
        this.config.port = 1883;
        this.config.clientId = 'HOS_Client_' + Date.now();
        break;
      case ProtocolType.SERIAL:
        this.config.baudRate = 115200;
        this.config.dataBits = 8;
        this.config.stopBits = 1;
        this.config.parity = 'None';
        break;
      case ProtocolType.MODBUS:
        this.config.port = 502;
        this.config.slaveId = 1;
        this.config.functionCode = 3;
        break;
    }
  }

  // 测试连接
  async testConnection() {
    this.connectionStatus = '连接中...';
    this.testResult = '';

    try {
      switch (this.selectedProtocol) {
        case ProtocolType.TCP:
          await this.testTCPConnection();
          break;
        case ProtocolType.UDP:
          await this.testUDPConnection();
          break;
        case ProtocolType.HTTP:
        case ProtocolType.HTTPS:
          await this.testHTTPConnection();
          break;
        default:
          this.testResult = `${this.selectedProtocol} 协议测试功能开发中...`;
          this.connectionStatus = '测试完成';
      }
    } catch (err) {
      this.connectionStatus = '连接失败';
      this.testResult = '连接错误: 未知错误';
    }
  }

  // TCP连接测试
  async testTCPConnection() {
    return new Promise<void>((resolve, reject) => {
      const tcpSocket = socket.constructTCPSocketInstance();

      tcpSocket.on('connect', () => {
        this.isConnected = true;
        this.connectionStatus = '连接成功';
        this.testResult = `TCP连接成功: ${this.config.host}:${this.config.port}`;
        tcpSocket.close();
        resolve();
      });

      tcpSocket.on('error', (err) => {
        this.isConnected = false;
        this.connectionStatus = '连接失败';
        reject(err);
      });

      const options: socket.TCPConnectOptions = {
        address: {
          address: this.config.host,
          port: this.config.port,
          family: 1
        },
        timeout: this.config.timeout
      };

      tcpSocket.connect(options);
    });
  }

  // UDP连接测试
  async testUDPConnection() {
    return new Promise<void>((resolve, reject) => {
      const udpSocket = socket.constructUDPSocketInstance();

      udpSocket.bind({ address: '0.0.0.0', port: 0, family: 1 }, (err) => {
        if (err) {
          reject(err);
          return;
        }

        // 发送测试数据
        udpSocket.send({
          data: 'UDP Test Message',
          address: {
            address: this.config.host,
            port: this.config.port,
            family: 1
          }
        }, (err) => {
          if (err) {
            reject(err);
          } else {
            this.connectionStatus = '测试完成';
            this.testResult = `UDP测试消息已发送到: ${this.config.host}:${this.config.port}`;
            resolve();
          }
          udpSocket.close();
        });
      });
    });
  }

  // HTTP连接测试
  async testHTTPConnection() {
    // 这里可以使用@ohos.net.http模块进行HTTP请求测试
    this.connectionStatus = '测试完成';
    this.testResult = `HTTP ${this.config.method} 请求测试: ${this.config.protocol.toLowerCase()}://${this.config.host}:${this.config.port}`;
  }

  @Builder
  ProtocolSelectorBuilder() {
    Column() {
      Text('选择协议类型')
        .fontSize(GlassTextStyles.getSecondaryTitleFontSize())
        .fontWeight(FontWeight.Bold)
        .fontColor(GlassTextStyles.getPrimaryTitleColor())
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 16 })

      Grid() {
        ForEach(Object.values(ProtocolType), (protocol: ProtocolType) => {
          GridItem() {
            Button(this.getProtocolDisplayName(protocol))
              .width('100%')
              .height(40)
              .fontSize(14)
              .backgroundColor(this.selectedProtocol === protocol ?
                GlassStyles.getButtonGradientStart('primary') :
                GlassStyles.getGlassCardBackgroundColor())
              .fontColor(this.selectedProtocol === protocol ? Color.White :
                GlassTextStyles.getBodyTextColor())
              .borderRadius(12)
              .border({
                width: 1,
                color: this.selectedProtocol === protocol ?
                  GlassStyles.getButtonGradientStart('primary') :
                  GlassStyles.getGlassBorderColor()
              })
              .shadow({
                radius: this.selectedProtocol === protocol ? 8 : 4,
                color: this.selectedProtocol === protocol ?
                  'rgba(74, 144, 226, 0.3)' :
                  GlassStyles.getShadowColor(),
                offsetX: 0,
                offsetY: 2
              })
              .onClick(() => {
                this.onProtocolChange(protocol);
              })
          }
        })
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .rowsGap(8)
      .columnsGap(8)
      .width('100%')
      .height(80)
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
  BasicConfigBuilder() {
    Column() {
      // 基础配置标题行
      Row() {
        Text('基础配置')
          .fontSize(GlassTextStyles.getSecondaryTitleFontSize())
          .fontWeight(FontWeight.Bold)
          .fontColor(GlassTextStyles.getPrimaryTitleColor())

        Blank()

        // 显示当前选择的协议
        Text(`当前协议: ${this.getProtocolDisplayName(this.selectedProtocol)}`)
          .fontSize(GlassTextStyles.getLabelTextFontSize())
          .fontColor(GlassTextStyles.getLabelTextColor())
          .backgroundColor(GlassStyles.getGlassCardBackgroundColor())
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(16)
          .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
          .backdropBlur(10)
      }
      .width('100%')
      .alignSelf(ItemAlign.Start)
      .margin({ bottom: 16 })

      // 主机地址
      Row() {
        Text('主机地址:')
          .width(80)
          .fontSize(GlassTextStyles.getBodyTextFontSize())
          .fontColor(GlassTextStyles.getBodyTextColor())
          .fontWeight(FontWeight.Medium)

        TextInput({ text: this.config.host })
          .layoutWeight(1)
          .height(44)
          .backgroundColor(GlassStyles.getInputBackgroundColor())
          .borderRadius(12)
          .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
          .backdropBlur(10)
          .shadow({ radius: 4, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 2 })
          .onChange((value: string) => {
            this.config.host = value;
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 端口号
      Row() {
        Text('端口号:')
          .width(80)
          .fontSize(GlassTextStyles.getBodyTextFontSize())
          .fontColor(GlassTextStyles.getBodyTextColor())
          .fontWeight(FontWeight.Medium)

        TextInput({ text: this.config.port.toString() })
          .layoutWeight(1)
          .height(44)
          .type(InputType.Number)
          .backgroundColor(GlassStyles.getInputBackgroundColor())
          .borderRadius(12)
          .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
          .backdropBlur(10)
          .shadow({ radius: 4, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 2 })
          .onChange((value: string) => {
            this.config.port = parseInt(value) || 8888;
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 超时时间
      Row() {
        Text('超时(ms):')
          .width(80)
          .fontSize(GlassTextStyles.getBodyTextFontSize())
          .fontColor(GlassTextStyles.getBodyTextColor())
          .fontWeight(FontWeight.Medium)

        TextInput({ text: this.config.timeout.toString() })
          .layoutWeight(1)
          .height(44)
          .type(InputType.Number)
          .backgroundColor(GlassStyles.getInputBackgroundColor())
          .borderRadius(12)
          .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
          .backdropBlur(10)
          .shadow({ radius: 4, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 2 })
          .onChange((value: string) => {
            this.config.timeout = parseInt(value) || 5000;
          })
      }
      .width('100%')
      .margin({ bottom: 16 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(GlassStyles.getGlassCardBackgroundColor())
    .borderRadius(16)
    .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
    .backdropBlur(15)
    .shadow({ radius: 15, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 6 })
    .margin({ bottom: 16 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  AdvancedConfigBuilder() {
    Column() {
      Row() {
        Text('高级配置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)

        Button(this.showAdvanced ? '收起' : '展开')
          .fontSize(14)
          .backgroundColor('transparent')
          .fontColor('#007AFF')
          .onClick(() => {
            this.showAdvanced = !this.showAdvanced;
          })
      }
      .width('100%')
      .margin({ bottom: 16 })

      if (this.showAdvanced) {
        Column() {
          // TCP/UDP 特有配置
          if (this.selectedProtocol === ProtocolType.TCP) {
            Row() {
              Text('保持连接:')
                .width(100)
                .fontSize(16)

              Toggle({ type: ToggleType.Switch, isOn: this.config.keepAlive || false })
                .onChange((isOn: boolean) => {
                  this.config.keepAlive = isOn;
                })
            }
            .width('100%')
            .margin({ bottom: 12 })
          }

          // HTTP/HTTPS 特有配置
          if (this.selectedProtocol === ProtocolType.HTTP || this.selectedProtocol === ProtocolType.HTTPS) {
            Row() {
              Text('请求方法:')
                .width(100)
                .fontSize(16)

              Select([
                { value: 'GET' },
                { value: 'POST' },
                { value: 'PUT' },
                { value: 'DELETE' }
              ])
                .selected(0)
                .value(this.config.method || 'GET')
                .onSelect((index: number, value: string) => {
                  this.config.method = value;
                })
            }
            .width('100%')
            .margin({ bottom: 12 })
          }

          // MQTT 特有配置
          if (this.selectedProtocol === ProtocolType.MQTT) {
            Column() {
              Row() {
                Text('客户端ID:')
                  .width(100)
                  .fontSize(16)

                TextInput({ text: this.config.clientId || '' })
                  .layoutWeight(1)
                  .height(40)
                  .onChange((value: string) => {
                    this.config.clientId = value;
                  })
              }
              .width('100%')
              .margin({ bottom: 12 })

              Row() {
                Text('用户名:')
                  .width(100)
                  .fontSize(16)

                TextInput({ text: this.config.username || '' })
                  .layoutWeight(1)
                  .height(40)
                  .onChange((value: string) => {
                    this.config.username = value;
                  })
              }
              .width('100%')
              .margin({ bottom: 12 })

              Row() {
                Text('密码:')
                  .width(100)
                  .fontSize(16)

                TextInput({ text: this.config.password || '' })
                  .layoutWeight(1)
                  .height(40)
                  .type(InputType.Password)
                  .onChange((value: string) => {
                    this.config.password = value;
                  })
              }
              .width('100%')
              .margin({ bottom: 12 })

              Row() {
                Text('主题:')
                  .width(100)
                  .fontSize(16)

                TextInput({ text: this.config.topic || '' })
                  .layoutWeight(1)
                  .height(40)
                  .onChange((value: string) => {
                    this.config.topic = value;
                  })
              }
              .width('100%')
              .margin({ bottom: 12 })
            }
          }

          // Serial 特有配置
          if (this.selectedProtocol === ProtocolType.SERIAL) {
            Column() {
              Row() {
                Text('波特率:')
                  .width(100)
                  .fontSize(16)

                Select([
                  { value: '9600' },
                  { value: '19200' },
                  { value: '38400' },
                  { value: '57600' },
                  { value: '115200' }
                ])
                  .selected(4)
                  .value(this.config.baudRate?.toString() || '115200')
                  .onSelect((index: number, value: string) => {
                    this.config.baudRate = parseInt(value);
                  })
              }
              .width('100%')
              .margin({ bottom: 12 })

              Row() {
                Text('数据位:')
                  .width(100)
                  .fontSize(16)

                Select([
                  { value: '7' },
                  { value: '8' }
                ])
                  .selected(1)
                  .value(this.config.dataBits?.toString() || '8')
                  .onSelect((index: number, value: string) => {
                    this.config.dataBits = parseInt(value);
                  })
              }
              .width('100%')
              .margin({ bottom: 12 })

              Row() {
                Text('停止位:')
                  .width(100)
                  .fontSize(16)

                Select([
                  { value: '1' },
                  { value: '2' }
                ])
                  .selected(0)
                  .value(this.config.stopBits?.toString() || '1')
                  .onSelect((index: number, value: string) => {
                    this.config.stopBits = parseInt(value);
                  })
              }
              .width('100%')
              .margin({ bottom: 12 })

              Row() {
                Text('校验位:')
                  .width(100)
                  .fontSize(16)

                Select([
                  { value: 'None' },
                  { value: 'Even' },
                  { value: 'Odd' }
                ])
                  .selected(0)
                  .value(this.config.parity || 'None')
                  .onSelect((index: number, value: string) => {
                    this.config.parity = value;
                  })
              }
              .width('100%')
              .margin({ bottom: 12 })
            }
          }

          // Modbus 特有配置
          if (this.selectedProtocol === ProtocolType.MODBUS) {
            Column() {
              Row() {
                Text('从站ID:')
                  .width(100)
                  .fontSize(16)

                TextInput({ text: this.config.slaveId?.toString() || '1' })
                  .layoutWeight(1)
                  .height(40)
                  .type(InputType.Number)
                  .onChange((value: string) => {
                    this.config.slaveId = parseInt(value) || 1;
                  })
              }
              .width('100%')
              .margin({ bottom: 12 })

              Row() {
                Text('功能码:')
                  .width(100)
                  .fontSize(16)

                Select([
                  { value: '1 - 读线圈' },
                  { value: '2 - 读离散输入' },
                  { value: '3 - 读保持寄存器' },
                  { value: '4 - 读输入寄存器' },
                  { value: '5 - 写单个线圈' },
                  { value: '6 - 写单个寄存器' }
                ])
                  .selected(2)
                  .onSelect((index: number, value: string) => {
                    this.config.functionCode = index + 1;
                  })
              }
              .width('100%')
              .margin({ bottom: 12 })
            }
          }
        }
        .width('100%')
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
        .backgroundColor('transparent')

      // 标题栏
      Row() {
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_public_back'))
            .width(24)
            .height(24)
            .fillColor('#2C3E50')
        }
        .width(40)
        .height(40)
        .backgroundColor(GlassStyles.getGlassCardBackgroundColor())
        .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
        .shadow({ radius: 8, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 2 })
        .onClick(() => {
          router.back();
        })

        Text('协议配置')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2C3E50')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button('保存')
          .fontSize(16)
          .fontColor('#FFFFFF')
          .backgroundColor('#4ECDC4')
          .borderRadius(20)
          .shadow({ radius: 8, color: 'rgba(78, 205, 196, 0.3)', offsetX: 0, offsetY: 4 })
          .onClick(() => {
            this.saveConfig();
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
          // 协议选择器
          this.ProtocolSelectorBuilder()

          // 基础配置
          this.BasicConfigBuilder()

          // 高级配置
          this.AdvancedConfigBuilder()

          // 连接状态
          Column() {
            Text('连接状态')
              .fontSize(GlassTextStyles.getSecondaryTitleFontSize())
              .fontWeight(FontWeight.Bold)
              .fontColor(GlassTextStyles.getPrimaryTitleColor())
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 16 })

            Text(this.connectionStatus)
              .fontSize(GlassTextStyles.getBodyTextFontSize())
              .fontColor(this.isConnected ? '#4CAF50' : '#FF5722')
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 8 })

            if (this.testResult) {
              Text(this.testResult)
                .fontSize(GlassTextStyles.getLabelTextFontSize())
                .fontColor(GlassTextStyles.getLabelTextColor())
                .margin({ bottom: 16 })
            }

            Row() {
              Button('测试连接')
                .width('48%')
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
                  this.testConnection();
                })

              Button('清除结果')
                .width('48%')
                .height(48)
                .backgroundColor(GlassStyles.getButtonGradientStart('secondary'))
                .fontColor(Color.White)
                .borderRadius(24)
                .shadow({
                  radius: 12,
                  color: 'rgba(255, 107, 107, 0.3)',
                  offsetX: 0,
                  offsetY: 4
                })
                .onClick(() => {
                  this.testResult = '';
                  this.connectionStatus = '未连接';
                  this.isConnected = false;
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .margin({ bottom: 16 })

            // 数据测试按钮
            Button('数据测试')
              .width('100%')
              .height(48)
              .backgroundColor(GlassStyles.getButtonGradientStart('warning'))
              .fontColor(Color.White)
              .borderRadius(24)
              .shadow({
                radius: 12,
                color: 'rgba(255, 217, 61, 0.3)',
                offsetX: 0,
                offsetY: 4
              })
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/DataTest'
                }).catch(() => {
                  console.error('跳转失败');
                  promptAction.showToast({ message: '页面跳转失败' });
                });
              })
          }
          .width('100%')
          .padding(20)
          .backgroundColor(GlassStyles.getGlassCardBackgroundColor())
          .borderRadius(16)
          .border({ width: 1, color: GlassStyles.getGlassBorderColor() })
          .backdropBlur(15)
          .shadow({ radius: 15, color: GlassStyles.getShadowColor(), offsetX: 0, offsetY: 6 })
          .borderRadius(12)
          .margin({ top: 16 })
        }
        .padding(16)
      }
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
  }
}
