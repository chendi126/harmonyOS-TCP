/**
 * 液态玻璃样式工具类
 * 提供全局统一的液态玻璃视觉效果
 */

// 液态玻璃颜色配置
export class GlassColors {
  // 主背景渐变色
  static readonly PRIMARY_GRADIENT_START = '#E8F4FD'; // 浅蓝色
  static readonly PRIMARY_GRADIENT_END = '#F0F8FF';   // 极浅蓝色

  // 次要背景渐变色
  static readonly SECONDARY_GRADIENT_START = '#F8FBFF'; // 极浅蓝白色
  static readonly SECONDARY_GRADIENT_END = '#FFFFFF';   // 纯白色

  // 玻璃卡片背景
  static readonly GLASS_CARD = 'rgba(255, 255, 255, 0.25)';

  // 玻璃卡片边框
  static readonly GLASS_BORDER = 'rgba(255, 255, 255, 0.3)';

  // 模糊背景
  static readonly BLUR_BACKGROUND = 'rgba(255, 255, 255, 0.1)';

  // 高光效果
  static readonly HIGHLIGHT = 'rgba(255, 255, 255, 0.6)';

  // 阴影颜色
  static readonly SHADOW = 'rgba(0, 0, 0, 0.08)';

  // 深度阴影
  static readonly DEEP_SHADOW = 'rgba(0, 0, 0, 0.12)';

  // 按钮渐变色 - Primary
  static readonly BUTTON_PRIMARY_START = '#4A90E2';
  static readonly BUTTON_PRIMARY_END = '#357ABD';

  // 按钮渐变色 - Secondary
  static readonly BUTTON_SECONDARY_START = '#FF6B6B';
  static readonly BUTTON_SECONDARY_END = '#E55353';

  // 按钮渐变色 - Success
  static readonly BUTTON_SUCCESS_START = '#4ECDC4';
  static readonly BUTTON_SUCCESS_END = '#44A08D';

  // 按钮渐变色 - Warning
  static readonly BUTTON_WARNING_START = '#FFD93D';
  static readonly BUTTON_WARNING_END = '#F39C12';
}

// 液态玻璃样式配置
export class GlassStyles {
  // 获取主背景色
  static getMainBackgroundColor(): string {
    return GlassColors.PRIMARY_GRADIENT_START;
  }

  // 获取玻璃卡片背景色
  static getGlassCardBackgroundColor(): string {
    return GlassColors.GLASS_CARD;
  }

  // 获取玻璃边框色
  static getGlassBorderColor(): string {
    return GlassColors.GLASS_BORDER;
  }

  // 获取阴影色
  static getShadowColor(): string {
    return GlassColors.SHADOW;
  }

  // 获取深度阴影色
  static getDeepShadowColor(): string {
    return GlassColors.DEEP_SHADOW;
  }

  // 获取标题栏背景色
  static getTitleBarBackgroundColor(): string {
    return 'rgba(255, 255, 255, 0.8)';
  }

  // 获取按钮渐变起始色
  static getButtonGradientStart(type: 'primary' | 'secondary' | 'success' | 'warning' = 'primary'): string {
    switch (type) {
      case 'primary':
        return GlassColors.BUTTON_PRIMARY_START;
      case 'secondary':
        return GlassColors.BUTTON_SECONDARY_START;
      case 'success':
        return GlassColors.BUTTON_SUCCESS_START;
      case 'warning':
        return GlassColors.BUTTON_WARNING_START;
      default:
        return GlassColors.BUTTON_PRIMARY_START;
    }
  }

  // 获取按钮渐变结束色
  static getButtonGradientEnd(type: 'primary' | 'secondary' | 'success' | 'warning' = 'primary'): string {
    switch (type) {
      case 'primary':
        return GlassColors.BUTTON_PRIMARY_END;
      case 'secondary':
        return GlassColors.BUTTON_SECONDARY_END;
      case 'success':
        return GlassColors.BUTTON_SUCCESS_END;
      case 'warning':
        return GlassColors.BUTTON_WARNING_END;
      default:
        return GlassColors.BUTTON_PRIMARY_END;
    }
  }

  // 获取输入框背景色
  static getInputBackgroundColor(): string {
    return 'rgba(255, 255, 255, 0.4)';
  }

  // 获取浮动面板背景色
  static getFloatingPanelBackgroundColor(): string {
    return 'rgba(255, 255, 255, 0.9)';
  }

  // 获取状态指示器背景色
  static getStatusIndicatorBackgroundColor(isActive: boolean = false): string {
    return isActive ? 'rgba(76, 175, 80, 0.2)' : 'rgba(158, 158, 158, 0.2)';
  }

  // 获取状态指示器边框色
  static getStatusIndicatorBorderColor(isActive: boolean = false): string {
    return isActive ? 'rgba(76, 175, 80, 0.3)' : 'rgba(158, 158, 158, 0.3)';
  }

  // 获取数据卡片背景色
  static getDataCardBackgroundColor(): string {
    return 'rgba(255, 255, 255, 0.3)';
  }

  // 获取导航按钮背景色
  static getNavButtonBackgroundColor(): string {
    return 'rgba(255, 255, 255, 0.6)';
  }

  // 获取模态框背景色
  static getModalBackgroundColor(): string {
    return 'rgba(255, 255, 255, 0.95)';
  }
}

// 液态玻璃动画效果
export class GlassAnimations {
  // 获取悬停缩放比例
  static getHoverScale(): number {
    return 1.02;
  }

  // 获取按下缩放比例
  static getPressScale(): number {
    return 0.98;
  }

  // 获取悬停阴影色
  static getHoverShadowColor(): string {
    return 'rgba(0, 0, 0, 0.15)';
  }

  // 获取按下阴影色
  static getPressShadowColor(): string {
    return 'rgba(0, 0, 0, 0.1)';
  }

  // 获取动画持续时间
  static getAnimationDuration(): number {
    return 300;
  }

  // 获取滑入动画持续时间
  static getSlideAnimationDuration(): number {
    return 400;
  }
}

// 液态玻璃文字样式
export class GlassTextStyles {
  // 获取主标题字体大小
  static getPrimaryTitleFontSize(): number {
    return 28;
  }

  // 获取次标题字体大小
  static getSecondaryTitleFontSize(): number {
    return 20;
  }

  // 获取正文字体大小
  static getBodyTextFontSize(): number {
    return 16;
  }

  // 获取标签字体大小
  static getLabelTextFontSize(): number {
    return 14;
  }

  // 获取主标题颜色
  static getPrimaryTitleColor(): string {
    return '#2C3E50';
  }

  // 获取次标题颜色
  static getSecondaryTitleColor(): string {
    return '#34495E';
  }

  // 获取正文颜色
  static getBodyTextColor(): string {
    return '#5D6D7E';
  }

  // 获取标签颜色
  static getLabelTextColor(): string {
    return '#7F8C8D';
  }

  // 获取文字阴影颜色
  static getTextShadowColor(): string {
    return 'rgba(255, 255, 255, 0.8)';
  }
}
