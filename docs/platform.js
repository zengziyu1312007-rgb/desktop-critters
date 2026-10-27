(function (root) {
  'use strict';
  function detectDevice(info) {
    const ua = String(info.userAgent || '').toLowerCase();
    const platform = String(info.platform || '').toLowerCase();
    const hints = info.hints || {};
    if (/android|iphone|ipad|ipod|windows phone/.test(ua) || (platform.includes('mac') && (info.maxTouchPoints || 0) > 1)) return 'mobile';
    if (/win/.test(String(hints.platform || platform).toLowerCase()) || /windows nt/.test(ua)) return /arm/.test(String(hints.architecture || '').toLowerCase()) ? 'windows-arm' : 'windows';
    if (/mac/.test(String(hints.platform || platform).toLowerCase()) || /macintosh/.test(ua)) return 'mac';
    return 'unknown';
  }
  if (typeof module !== 'undefined' && module.exports) module.exports = { detectDevice };
  root.DesktopCrittersPlatform = { detectDevice };
})(typeof globalThis !== 'undefined' ? globalThis : this);
