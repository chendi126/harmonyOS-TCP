# 🔌 HarmonyOS TCP 通信应用

<div align="center">

![HarmonyOS](https://img.shields.io/badge/HarmonyOS-4.0+-blue.svg)
![ArkTS](https://img.shields.io/badge/ArkTS-TypeScript-green.svg)
![Version](https://img.shields.io/badge/version-1.0.0-brightgreen.svg)
![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)

一款基于HarmonyOS开发的TCP网络通信应用，支持多种协议和设备控制功能

[功能特性](#-功能特性) • [快速开始](#-快速开始) • [使用说明](#-使用说明) • [技术架构](#-技术架构) • [贡献指南](#-贡献指南)

</div>

## 📱 项目简介

HarmonyOS TCP 通信应用是一款专业的网络通信和设备控制应用，支持TCP、UDP、HTTP等多种网络协议，可与各种硬件设备进行通信。应用具备实时数据监控、设备控制、定时提醒等功能，采用现代化的液态玻璃UI设计，为用户提供优雅的交互体验。

## ✨ 功能特性

### 🔗 网络通信
- **多协议支持**: TCP、UDP、HTTP、HTTPS、WebSocket、MQTT、Serial、Modbus
- **实时连接**: 支持实时连接状态监控和自动重连
- **数据传输**: 支持JSON、HEX、ASCII等多种数据格式
- **连接测试**: 内置连接测试工具，支持ping和端口扫描

### ⏰ 智能提醒
- **双闹钟系统**: 支持两个独立的用药提醒闹钟
- **系统通知**: 基于HarmonyOS原生通知系统
- **定时同步**: 闹钟设置自动同步到硬件设备
- **灵活配置**: 24小时制时间选择，支持开关控制

### 📊 环境监测
- **实时数据**: 温度、湿度等环境参数实时显示
- **数据可视化**: 直观的数据展示界面
- **历史记录**: 环境数据变化趋势记录
- **异常告警**: 环境参数异常自动提醒

### 🔧 设备管理
- **设备查找**: 支持硬件设备LED闪烁定位
- **状态监控**: 实时设备运行状态监控
- **参数配置**: 设备参数远程配置和管理
- **固件升级**: 支持OTA固件升级功能

### 🎨 用户界面
- **液态玻璃设计**: 现代化的毛玻璃视觉效果
- **响应式布局**: 适配不同屏幕尺寸
- **暗色主题**: 护眼的深色界面设计
- **流畅动画**: 丰富的交互动画效果

## 🚀 快速开始

### 环境要求

- **开发环境**: DevEco Studio 4.0+
- **操作系统**: HarmonyOS 4.0+
- **API版本**: API 10+
- **编程语言**: ArkTS (TypeScript)

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/chendi126/harmonyOS-TCP.git
   cd harmonyOS-TCP
   ```

2. **导入项目**
   - 打开DevEco Studio
   - 选择"Open"导入项目
   - 等待依赖下载完成

3. **配置签名**
   - 在DevEco Studio中配置应用签名
   - 确保设备已开启开发者模式

4. **运行应用**
   - 连接HarmonyOS设备或启动模拟器
   - 点击"Run"按钮编译并安装应用

## 📖 使用说明

### 设备连接

1. **配置网络参数**
   - 打开应用，点击设置按钮
   - 输入设备IP地址和端口号
   - 选择通信协议（默认TCP）

2. **建立连接**
   - 点击"连接"按钮
   - 等待连接状态变为"已连接"
   - 连接成功后可进行设备操作

### 闹钟设置

1. **设置提醒时间**
   - 在主界面点击闹钟设置区域
   - 选择小时和分钟
   - 开启闹钟开关

2. **同步到设备**
   - 闹钟设置会自动同步到硬件设备
   - 设备将在指定时间发出提醒

### 数据监测

1. **查看环境数据**
   - 主界面实时显示温湿度数据
   - 数据每秒自动更新

2. **设备监控**
   - 切换到"设备监控"页面
   - 查看设备运行状态和日志信息

## 🏗️ 技术架构

### 核心技术栈

- **前端框架**: ArkTS + ArkUI
- **网络通信**: HarmonyOS Socket API
- **数据存储**: HarmonyOS Preferences API
- **通知系统**: HarmonyOS NotificationManager
- **UI设计**: 液态玻璃设计系统

### 项目结构

```
harmonyOS-TCP/
├── entry/src/main/ets/
│   ├── pages/                 # 页面组件
│   │   ├── Index.ets         # 主页面
│   │   ├── ProtocolConfig.ets # 协议配置
│   │   ├── DataTest.ets      # 数据测试
│   │   ├── DeviceMonitor.ets # 设备监控
│   │   ├── onhalf.ets        # 半屏显示
│   │   └── time.ets          # 时间设置
│   ├── common/               # 公共组件
│   │   ├── GlassStyles.ets   # 液态玻璃样式
│   │   └── SafeAreaUtils.ets # 安全区域工具
│   └── entryability/         # 应用入口
├── AppScope/                 # 应用配置
└── resources/               # 资源文件
```

### 核心模块

- **网络通信模块**: 基于HarmonyOS Socket API的多协议通信
- **数据管理模块**: 本地数据持久化和状态管理
- **UI组件库**: 可复用的液态玻璃风格组件
- **通知服务**: 系统级通知和提醒服务

## 🔧 故障排除

### 常见问题

**Q: 无法连接到设备**
- 检查设备IP地址和端口是否正确
- 确认设备和手机在同一网络
- 检查防火墙设置

**Q: 闹钟不响**
- 确认系统通知权限已开启
- 检查设备勿扰模式设置
- 验证闹钟时间设置是否正确

**Q: 环境数据不更新**
- 检查设备连接状态
- 确认设备传感器工作正常
- 重启应用重新连接

### 调试模式

启用调试模式查看详细日志：
```typescript
// 在DeviceMonitor页面查看实时日志
// 支持INFO、WARN、ERROR级别过滤
```

## 🤝 贡献指南

我们欢迎所有形式的贡献！请遵循以下步骤：

1. **Fork项目** 到您的GitHub账户
2. **创建特性分支** (`git checkout -b feature/AmazingFeature`)
3. **提交更改** (`git commit -m 'Add some AmazingFeature'`)
4. **推送分支** (`git push origin feature/AmazingFeature`)
5. **创建Pull Request**

### 开发规范

- 遵循ArkTS编码规范
- 添加适当的注释和文档
- 确保代码通过所有测试
- 保持UI设计一致性

### 代码提交规范

```
feat: 新功能
fix: 修复bug
docs: 文档更新
style: 代码格式调整
refactor: 代码重构
test: 测试相关
chore: 构建过程或辅助工具的变动
```

## 📄 许可证

本项目采用Apache License 2.0许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 📞 联系我们

- **项目维护者**: chendi126
- **项目主页**: https://github.com/chendi126/harmonyOS-TCP

## 🙏 致谢

感谢所有为这个项目做出贡献的开发者和用户！

---

<div align="center">

**如果这个项目对您有帮助，请给我们一个⭐️**

Made with ❤️ for HarmonyOS Community

</div>
