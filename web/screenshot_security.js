// Screenshot Security JavaScript Module
// This file handles screenshot blocking for web browsers including mobile Chrome

class ScreenshotSecurity {
  constructor() {
    this.securityEnabled = false;
    this.securityScriptId = 'flutter-security-script';
    this.indicatorId = 'security-indicator';
    
    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.initialize());
    } else {
      this.initialize();
    }
  }

  initialize() {
    // Enable security by default for student areas
    if (window.location.pathname.includes('/dashboard') || 
        window.location.pathname.includes('/student') ||
        window.location.pathname.includes('/course')) {
      this.enable();
    }
    
    // Also enable if we're in a Flutter web app
    if (window.flutterConfiguration || window._flutter) {
      this.enable();
    }
    
    console.log('Screenshot security initialized');
  }

  enable() {
    if (this.securityEnabled) return;
    
    this.securityEnabled = true;
    
    // Prevent context menu (right-click)
    document.addEventListener('contextmenu', this.preventDefault.bind(this), true);
    
    // Prevent keyboard shortcuts for screenshots
    document.addEventListener('keydown', this.preventScreenshotKeys.bind(this), true);
    
    // Prevent drag and drop
    document.addEventListener('dragstart', this.preventDefault.bind(this), true);
    document.addEventListener('drop', this.preventDefault.bind(this), true);
    
    // Prevent text selection
    document.addEventListener('selectstart', this.preventDefault.bind(this), true);
    
    // Prevent copy/paste
    document.addEventListener('copy', this.preventDefault.bind(this), true);
    document.addEventListener('paste', this.preventDefault.bind(this), true);
    document.addEventListener('cut', this.preventDefault.bind(this), true);
    
    // Prevent print screen
    document.addEventListener('keyup', this.preventPrintScreen.bind(this), true);
    
    // Mobile-specific security measures
    this.addMobileSecurity();
    
    // Add CSS to prevent user selection
    this.addSecurityStyles();
    
    // Show security indicator
    this.showSecurityIndicator();
    
    console.log('Screenshot blocking enabled');
  }

  disable() {
    if (!this.securityEnabled) return;
    
    this.securityEnabled = false;
    
    // Remove event listeners
    document.removeEventListener('contextmenu', this.preventDefault.bind(this), true);
    document.removeEventListener('keydown', this.preventScreenshotKeys.bind(this), true);
    document.removeEventListener('dragstart', this.preventDefault.bind(this), true);
    document.removeEventListener('drop', this.preventDefault.bind(this), true);
    document.removeEventListener('selectstart', this.preventDefault.bind(this), true);
    document.removeEventListener('copy', this.preventDefault.bind(this), true);
    document.removeEventListener('paste', this.preventDefault.bind(this), true);
    document.removeEventListener('cut', this.preventDefault.bind(this), true);
    document.removeEventListener('keyup', this.preventPrintScreen.bind(this), true);
    
    // Remove mobile security
    this.removeMobileSecurity();
    
    // Remove security styles
    this.removeSecurityStyles();
    
    // Hide security indicator
    this.hideSecurityIndicator();
    
    console.log('Screenshot blocking disabled');
  }

  preventDefault(e) {
    e.preventDefault();
    e.stopPropagation();
    return false;
  }

  preventScreenshotKeys(e) {
    // Prevent Ctrl+S, Ctrl+C, Ctrl+V, Ctrl+X, Ctrl+A, Ctrl+P
    if (e.ctrlKey || e.metaKey) {
      const key = e.key.toLowerCase();
      if (['s', 'c', 'v', 'x', 'a', 'p'].includes(key)) {
        this.preventDefault(e);
      }
    }
    
    // Prevent Print Screen key
    if (e.key === 'PrintScreen' || e.keyCode === 44) {
      this.preventDefault(e);
    }
    
    // Prevent F12 (Developer Tools)
    if (e.key === 'F12' || e.keyCode === 123) {
      this.preventDefault(e);
    }
  }

  preventPrintScreen(e) {
    if (e.key === 'PrintScreen' || e.keyCode === 44) {
      this.preventDefault(e);
    }
  }

  addMobileSecurity() {
    // Prevent mobile screenshot gestures
    document.addEventListener('touchstart', this.preventDefault.bind(this), true);
    document.addEventListener('touchmove', this.preventDefault.bind(this), true);
    document.addEventListener('touchend', this.preventDefault.bind(this), true);
    
    // Prevent mobile context menu
    document.addEventListener('touchhold', this.preventDefault.bind(this), true);
    
    // Prevent mobile zoom
    document.addEventListener('gesturestart', this.preventDefault.bind(this), true);
    document.addEventListener('gesturechange', this.preventDefault.bind(this), true);
    document.addEventListener('gestureend', this.preventDefault.bind(this), true);
    
    // Add viewport meta tag to prevent zoom
    this.addViewportMeta();
  }

  removeMobileSecurity() {
    document.removeEventListener('touchstart', this.preventDefault.bind(this), true);
    document.removeEventListener('touchmove', this.preventDefault.bind(this), true);
    document.removeEventListener('touchend', this.preventDefault.bind(this), true);
    document.removeEventListener('touchhold', this.preventDefault.bind(this), true);
    document.removeEventListener('gesturestart', this.preventDefault.bind(this), true);
    document.removeEventListener('gesturechange', this.preventDefault.bind(this), true);
    document.removeEventListener('gestureend', this.preventDefault.bind(this), true);
  }

  addViewportMeta() {
    // Add or update viewport meta tag to prevent zoom
    let viewport = document.querySelector('meta[name="viewport"]');
    if (!viewport) {
      viewport = document.createElement('meta');
      viewport.name = 'viewport';
      document.head.appendChild(viewport);
    }
    viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
  }

  addSecurityStyles() {
    const style = document.createElement('style');
    style.id = this.securityScriptId;
    style.textContent = `
      * {
        -webkit-user-select: none !important;
        -moz-user-select: none !important;
        -ms-user-select: none !important;
        user-select: none !important;
        -webkit-touch-callout: none !important;
        -webkit-tap-highlight-color: transparent !important;
        -webkit-touch-callout: none !important;
        -webkit-user-select: none !important;
        -khtml-user-select: none !important;
        -moz-user-select: none !important;
        -ms-user-select: none !important;
        user-select: none !important;
      }
      
      body {
        -webkit-touch-callout: none !important;
        -webkit-user-select: none !important;
        -khtml-user-select: none !important;
        -moz-user-select: none !important;
        -ms-user-select: none !important;
        user-select: none !important;
        -webkit-touch-callout: none !important;
        -webkit-user-select: none !important;
        -khtml-user-select: none !important;
        -moz-user-select: none !important;
        -ms-user-select: none !important;
        user-select: none !important;
      }
      
      img {
        -webkit-user-drag: none !important;
        -khtml-user-drag: none !important;
        -moz-user-drag: none !important;
        -o-user-drag: none !important;
        user-drag: none !important;
        pointer-events: none !important;
        -webkit-user-select: none !important;
        -moz-user-select: none !important;
        -ms-user-select: none !important;
        user-select: none !important;
      }
      
      /* Prevent mobile screenshot gestures */
      @media (max-width: 768px) {
        * {
          -webkit-touch-callout: none !important;
          -webkit-user-select: none !important;
          user-select: none !important;
          -webkit-touch-callout: none !important;
          -webkit-user-select: none !important;
          -khtml-user-select: none !important;
          -moz-user-select: none !important;
          -ms-user-select: none !important;
          user-select: none !important;
        }
        
        body {
          -webkit-touch-callout: none !important;
          -webkit-user-select: none !important;
          user-select: none !important;
          -webkit-touch-callout: none !important;
          -webkit-user-select: none !important;
          -khtml-user-select: none !important;
          -moz-user-select: none !important;
          -ms-user-select: none !important;
          user-select: none !important;
        }
        
        /* Prevent mobile gestures */
        html, body {
          touch-action: none !important;
          -webkit-touch-callout: none !important;
          -webkit-user-select: none !important;
          -khtml-user-select: none !important;
          -moz-user-select: none !important;
          -ms-user-select: none !important;
          user-select: none !important;
        }
      }
      
      /* Additional security for all screen sizes */
      html {
        -webkit-touch-callout: none !important;
        -webkit-user-select: none !important;
        -khtml-user-select: none !important;
        -moz-user-select: none !important;
        -ms-user-select: none !important;
        user-select: none !important;
      }
    `;
    document.head.appendChild(style);
  }

  removeSecurityStyles() {
    const style = document.getElementById(this.securityScriptId);
    if (style) {
      style.remove();
    }
  }

  showSecurityIndicator() {
    let indicator = document.getElementById(this.indicatorId);
    if (!indicator) {
      indicator = document.createElement('div');
      indicator.id = this.indicatorId;
      indicator.style.cssText = `
        position: fixed;
        top: 10px;
        right: 10px;
        background: rgba(0, 0, 0, 0.8);
        color: red;
        padding: 8px 12px;
        border-radius: 12px;
        border: 1px solid red;
        font-size: 10px;
        font-weight: bold;
        z-index: 9999;
        display: flex;
        align-items: center;
        gap: 4px;
        font-family: Arial, sans-serif;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
        -webkit-user-select: none;
        -moz-user-select: none;
        -ms-user-select: none;
        user-select: none;
      `;
      indicator.innerHTML = `
        <span style="color: red;">🔒</span>
        <span style="color: red;">WEB SECURE</span>
      `;
      document.body.appendChild(indicator);
    }
    indicator.style.display = 'flex';
  }

  hideSecurityIndicator() {
    const indicator = document.getElementById(this.indicatorId);
    if (indicator) {
      indicator.style.display = 'none';
    }
  }
}

// Initialize screenshot security
const screenshotSecurity = new ScreenshotSecurity();

// Export for global access
window.screenshotSecurity = screenshotSecurity; 