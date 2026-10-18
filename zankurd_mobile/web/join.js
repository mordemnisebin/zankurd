// ZanKurd davet bağlantısı: zankurd.com/join/<KOD> → uygulamada aç.
(function () {
  'use strict';

  var APP_ID = 'com.zankurd.app';
  var PLAY_URL = 'https://play.google.com/store/apps/details?id=com.zankurd.app';
  var APPSTORE_URL = 'https://apps.apple.com/app/id6797175984';

  var STRINGS = {
    ku: {
      heading: 'Te vedixwînin pêşbirkekê',
      headingGeneric: 'Bi ZanKurd re bilîze',
      codeLabel: 'Koda vexwendinê',
      copy: 'Kodê kopî bike',
      copied: 'Hate kopîkirin',
      openApp: 'Di sepanê de veke',
      noApp: 'Sepan tune?',
      playWeb: 'Di gerokê de bilîze',
      desktopNote: 'Vê girêdanê li ser têlefonê veke an sepanê dakêşe.'
    },
    tr: {
      heading: 'Seni bir yarışmaya çağırıyorlar',
      headingGeneric: 'ZanKurd ile oyna',
      codeLabel: 'Davet kodu',
      copy: 'Kodu kopyala',
      copied: 'Kopyalandı',
      openApp: 'Uygulamada aç',
      noApp: 'Uygulama yok mu?',
      playWeb: 'Tarayıcıda oyna',
      desktopNote: 'Bu bağlantıyı telefonda aç ya da uygulamayı indir.'
    }
  };

  function $(id) { return document.getElementById(id); }

  function parseCode() {
    var m = /^\/join\/([A-Za-z0-9-]{1,16})\/?$/.exec(location.pathname);
    var raw = m ? m[1] : '';
    if (!raw) {
      // Yedek: yol yeniden yazılmadan (ör. statik sunucu) ?code= ile de çalışır.
      try {
        raw = new URLSearchParams(location.search).get('code') || '';
      } catch (e) { raw = ''; }
    }
    if (!/^[A-Za-z0-9-]{1,16}$/.test(raw)) return '';
    return raw.toUpperCase();
  }

  function formatCode(code) {
    return /^\d{6}$/.test(code) ? code.slice(0, 3) + ' ' + code.slice(3) : code;
  }

  function platform() {
    var ua = navigator.userAgent || '';
    if (/Android/i.test(ua)) return 'android';
    if (/iPhone|iPad|iPod/i.test(ua) ||
        (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)) return 'ios';
    return 'desktop';
  }

  var code = parseCode();
  var os = platform();
  var lang = (navigator.language || '').toLowerCase().indexOf('tr') === 0 ? 'tr' : 'ku';
  var copiedTimer = null;

  function applyLang() {
    var s = STRINGS[lang];
    document.documentElement.lang = lang;
    $('heading').textContent = code ? s.heading : s.headingGeneric;
    $('code-label').textContent = s.codeLabel;
    $('copy').textContent = s.copy;
    $('open-app').textContent = s.openApp;
    $('desktop-note').textContent = s.desktopNote;
    $('no-app').textContent = s.noApp;
    $('web-link').textContent = s.playWeb;
    $('lang-toggle').textContent = lang === 'tr' ? 'KU' : 'TR';
  }

  function openApp() {
    if (os === 'android') {
      location.href = 'intent://zankurd.com/join/' + code + '#Intent;scheme=' + APP_ID +
        ';package=' + APP_ID + ';S.browser_fallback_url=' +
        encodeURIComponent(PLAY_URL) + ';end';
    } else if (os === 'ios') {
      var left = false;
      function mark() { left = true; }
      document.addEventListener('visibilitychange', function () {
        if (document.hidden) mark();
      });
      window.addEventListener('pagehide', mark);
      setTimeout(function () {
        if (!left && !document.hidden) location.href = APPSTORE_URL;
      }, 1500);
      location.href = 'com.zankurd.app://zankurd.com/join/' + code;
    }
  }

  function init() {
    if (code) {
      $('code').textContent = formatCode(code);
      $('code-box').hidden = false;
      $('web-link').href = '/join/' + code + '?web=1';
      $('web-link').hidden = false;
    }
    if (os === 'desktop') {
      if (code) $('desktop-note').hidden = false;
    } else if (code) {
      $('open-app').hidden = false;
    }
    applyLang();

    $('lang-toggle').addEventListener('click', function () {
      lang = lang === 'tr' ? 'ku' : 'tr';
      applyLang();
    });
    $('open-app').addEventListener('click', openApp);
    $('copy').addEventListener('click', function () {
      var done = function () {
        $('copy').textContent = STRINGS[lang].copied;
        clearTimeout(copiedTimer);
        copiedTimer = setTimeout(applyLang, 1800);
      };
      try {
        navigator.clipboard.writeText(code).then(done, function () {});
      } catch (e) { /* pano yok: sessiz geç */ }
    });

    if (code && os !== 'desktop') {
      try {
        if (!sessionStorage.getItem('zk_join_auto')) {
          sessionStorage.setItem('zk_join_auto', '1');
          openApp();
        }
      } catch (e) { /* depolama kapalı: otomatik deneme yok */ }
    }
  }

  init();
})();
