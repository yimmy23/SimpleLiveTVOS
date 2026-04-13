/**
 * mnsv2 签名模块 - 纯 JS，无 Node 依赖
 * 用法:
 *   // 浏览器:
 *   <script src="mnsv2_bundle.js"></script>
 *   <script>
 *     var result = XhsMnsV2.sign('/api/path?query=1', null); // GET
 *     var result = XhsMnsV2.sign('/api/path', '{"key":"val"}'); // POST
 *     // result = { "x-s": "XYS_...", "x-t": "...", "x-s-common": "..." }
 *   </script>
 *
 *   // Node.js:
 *   const { XhsMnsV2 } = require('./mnsv2_bundle.js');
 *   var result = XhsMnsV2.sign('/api/path', null);
 */
(function(root) {
  "use strict";

  // ============================================================
  // 1. 环境 shim（仅在非浏览器环境需要）
  // ============================================================
  var g = typeof window !== 'undefined' ? window : (typeof global !== 'undefined' ? global : {});

  if (typeof g.location === 'undefined') {
    g.location = {
      href: 'https://www.xiaohongshu.com/explore',
      host: 'www.xiaohongshu.com', hostname: 'www.xiaohongshu.com',
      origin: 'https://www.xiaohongshu.com', protocol: 'https:',
      pathname: '/explore', search: '', hash: '', port: '',
      reload: function(){}, assign: function(){}, replace: function(){}
    };
  }
  if (typeof g.document === 'undefined') {
    g.document = {
      createElement: function(tag) {
        var el = { style: {}, tagName: tag, setAttribute: function(){}, getAttribute: function(){ return null; },
          appendChild: function(){}, removeChild: function(){}, addEventListener: function(){}, innerHTML: '', textContent: '' };
        if (tag === 'canvas') {
          el.getContext = function() { return { fillRect:function(){}, fillText:function(){}, measureText:function(){return{width:10}},
            getImageData:function(){return{data:new Uint8Array(100)}}, canvas:{toDataURL:function(){return 'data:,'}} }; };
          el.toDataURL = function(){ return 'data:,'; };
        }
        return el;
      },
      body: { appendChild:function(){}, removeChild:function(){}, style:{} },
      head: { appendChild:function(){} },
      querySelectorAll: function(){ return []; }, querySelector: function(){ return null; },
      getElementById: function(){ return null; }, getElementsByTagName: function(){ return []; },
      addEventListener: function(){}, removeEventListener: function(){},
      createEvent: function(){ return { initEvent:function(){} }; },
      cookie: '', documentElement: { style:{}, getAttribute:function(){return null}, clientWidth:1920, clientHeight:1080 },
      createTextNode: function(){ return {}; }, readyState: 'complete', hidden: false, visibilityState: 'visible', title: ''
    };
    g.document.location = g.location;
  }
  if (typeof g.navigator === 'undefined') {
    g.navigator = {
      userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
      platform: 'MacIntel', language: 'zh-CN', languages: ['zh-CN','zh'],
      hardwareConcurrency: 8, deviceMemory: 8, maxTouchPoints: 0, vendor: 'Google Inc.',
      appVersion: '5.0', cookieEnabled: true,
      plugins: { length:5, item:function(){return null}, namedItem:function(){return null}, refresh:function(){} },
      mimeTypes: { length:2, item:function(){return null}, namedItem:function(){return null} },
      connection: { effectiveType:'4g', downlink:10, rtt:50 }, webdriver: false
    };
  }
  if (typeof g.screen === 'undefined') g.screen = { width:1920, height:1080, availWidth:1920, availHeight:1050, colorDepth:24, pixelDepth:24 };
  if (typeof g.localStorage === 'undefined') {
    var _ls = {};
    g.localStorage = { getItem:function(k){return _ls[k]||null}, setItem:function(k,v){_ls[k]=String(v)}, removeItem:function(k){delete _ls[k]}, length:0, key:function(){return null}, clear:function(){_ls={}} };
  }
  if (typeof g.sessionStorage === 'undefined') {
    var _ss = {};
    g.sessionStorage = { getItem:function(k){return _ss[k]||null}, setItem:function(k,v){_ss[k]=String(v)}, removeItem:function(k){delete _ss[k]}, length:0, key:function(){return null}, clear:function(){_ss={}} };
  }
  if (typeof g.performance === 'undefined') g.performance = { now:function(){return Date.now()}, timing:{navigationStart:Date.now()}, getEntriesByType:function(){return[]}, mark:function(){}, measure:function(){} };
  if (typeof g.MutationObserver === 'undefined') g.MutationObserver = function(){ this.observe=function(){}; this.disconnect=function(){}; this.takeRecords=function(){return[]}; };
  if (typeof g.crypto === 'undefined') g.crypto = { getRandomValues: function(arr) { for(var i=0;i<arr.length;i++) arr[i]=Math.floor(Math.random()*256); return arr; }, subtle:{} };
  if (typeof g.Image === 'undefined') g.Image = function(){};
  if (typeof g.HTMLElement === 'undefined') g.HTMLElement = function(){};
  if (typeof g.HTMLCanvasElement === 'undefined') g.HTMLCanvasElement = function(){};
  if (typeof g.Event === 'undefined') g.Event = function(t){ this.type=t; };
  if (typeof g.CustomEvent === 'undefined') g.CustomEvent = g.Event;
  if (typeof g.XMLHttpRequest === 'undefined') g.XMLHttpRequest = function(){ this.open=function(){}; this.send=function(){}; this.setRequestHeader=function(){}; this.addEventListener=function(){}; };
  if (typeof g.fetch === 'undefined') g.fetch = function(){ return Promise.resolve({json:function(){return{}},text:function(){return''}}); };
  if (typeof g.history === 'undefined') g.history = { length:2, pushState:function(){}, replaceState:function(){} };
  if (typeof g.requestAnimationFrame === 'undefined') g.requestAnimationFrame = function(cb){ return setTimeout(cb,16); };
  if (typeof g.cancelAnimationFrame === 'undefined') g.cancelAnimationFrame = function(id){ clearTimeout(id); };
  if (typeof g.chrome === 'undefined') g.chrome = {};
  if (typeof g.top === 'undefined') g.top = g;
  if (typeof g.parent === 'undefined') g.parent = g;
  if (typeof g.self === 'undefined') g.self = g;
  if (typeof g.btoa === 'undefined') g.btoa = function(s) { return (typeof Buffer !== 'undefined') ? Buffer.from(s,'binary').toString('base64') : ''; };
  if (typeof g.atob === 'undefined') g.atob = function(s) { return (typeof Buffer !== 'undefined') ? Buffer.from(s,'base64').toString('binary') : ''; };

  // ============================================================
  // 2. MD5 实现
  // ============================================================
  var md5hex = (function() {
    function safeAdd(x,y){var l=(x&0xffff)+(y&0xffff),m=(x>>16)+(y>>16)+(l>>16);return(m<<16)|(l&0xffff)}
    function bitRotateLeft(n,c){return(n<<c)|(n>>>(32-c))}
    function md5cmn(q,a,b,x,s,t){return safeAdd(bitRotateLeft(safeAdd(safeAdd(a,q),safeAdd(x,t)),s),b)}
    function ff(a,b,c,d,x,s,t){return md5cmn((b&c)|((~b)&d),a,b,x,s,t)}
    function gg(a,b,c,d,x,s,t){return md5cmn((b&d)|(c&(~d)),a,b,x,s,t)}
    function hh(a,b,c,d,x,s,t){return md5cmn(b^c^d,a,b,x,s,t)}
    function ii(a,b,c,d,x,s,t){return md5cmn(c^(b|(~d)),a,b,x,s,t)}
    function binlMD5(x,len){x[len>>5]|=0x80<<(len%32);x[((len+64>>>9)<<4)+14]=len;var a=1732584193,b=-271733879,c=-1732584194,d=271733878;for(var i=0;i<x.length;i+=16){var oa=a,ob=b,oc=c,od=d;a=ff(a,b,c,d,x[i],7,-680876936);d=ff(d,a,b,c,x[i+1],12,-389564586);c=ff(c,d,a,b,x[i+2],17,606105819);b=ff(b,c,d,a,x[i+3],22,-1044525330);a=ff(a,b,c,d,x[i+4],7,-176418897);d=ff(d,a,b,c,x[i+5],12,1200080426);c=ff(c,d,a,b,x[i+6],17,-1473231341);b=ff(b,c,d,a,x[i+7],22,-45705983);a=ff(a,b,c,d,x[i+8],7,1770035416);d=ff(d,a,b,c,x[i+9],12,-1958414417);c=ff(c,d,a,b,x[i+10],17,-42063);b=ff(b,c,d,a,x[i+11],22,-1990404162);a=ff(a,b,c,d,x[i+12],7,1804603682);d=ff(d,a,b,c,x[i+13],12,-40341101);c=ff(c,d,a,b,x[i+14],17,-1502002290);b=ff(b,c,d,a,x[i+15],22,1236535329);a=gg(a,b,c,d,x[i+1],5,-165796510);d=gg(d,a,b,c,x[i+6],9,-1069501632);c=gg(c,d,a,b,x[i+11],14,643717713);b=gg(b,c,d,a,x[i],20,-373897302);a=gg(a,b,c,d,x[i+5],5,-701558691);d=gg(d,a,b,c,x[i+10],9,38016083);c=gg(c,d,a,b,x[i+15],14,-660478335);b=gg(b,c,d,a,x[i+4],20,-405537848);a=gg(a,b,c,d,x[i+9],5,568446438);d=gg(d,a,b,c,x[i+14],9,-1019803690);c=gg(c,d,a,b,x[i+3],14,-187363961);b=gg(b,c,d,a,x[i+8],20,1163531501);a=gg(a,b,c,d,x[i+13],5,-1444681467);d=gg(d,a,b,c,x[i+2],9,-51403784);c=gg(c,d,a,b,x[i+7],14,1735328473);b=gg(b,c,d,a,x[i+12],20,-1926607734);a=hh(a,b,c,d,x[i+5],4,-378558);d=hh(d,a,b,c,x[i+8],11,-2022574463);c=hh(c,d,a,b,x[i+11],16,1839030562);b=hh(b,c,d,a,x[i+14],23,-35309556);a=hh(a,b,c,d,x[i+1],4,-1530992060);d=hh(d,a,b,c,x[i+4],11,1272893353);c=hh(c,d,a,b,x[i+7],16,-155497632);b=hh(b,c,d,a,x[i+10],23,-1094730640);a=hh(a,b,c,d,x[i+13],4,681279174);d=hh(d,a,b,c,x[i],11,-358537222);c=hh(c,d,a,b,x[i+3],16,-722521979);b=hh(b,c,d,a,x[i+6],23,76029189);a=hh(a,b,c,d,x[i+9],4,-640364487);d=hh(d,a,b,c,x[i+12],11,-421815835);c=hh(c,d,a,b,x[i+15],16,530742520);b=hh(b,c,d,a,x[i+2],23,-995338651);a=ii(a,b,c,d,x[i],6,-198630844);d=ii(d,a,b,c,x[i+7],10,1126891415);c=ii(c,d,a,b,x[i+14],15,-1416354905);b=ii(b,c,d,a,x[i+5],21,-57434055);a=ii(a,b,c,d,x[i+12],6,1700485571);d=ii(d,a,b,c,x[i+3],10,-1894986606);c=ii(c,d,a,b,x[i+10],15,-1051523);b=ii(b,c,d,a,x[i+1],21,-2054922799);a=ii(a,b,c,d,x[i+8],6,1873313359);d=ii(d,a,b,c,x[i+15],10,-30611744);c=ii(c,d,a,b,x[i+6],15,-1560198380);b=ii(b,c,d,a,x[i+13],21,1309151649);a=ii(a,b,c,d,x[i+4],6,-145523070);d=ii(d,a,b,c,x[i+11],10,-1120210379);c=ii(c,d,a,b,x[i+2],15,718787259);b=ii(b,c,d,a,x[i+9],21,-343485551);a=safeAdd(a,oa);b=safeAdd(b,ob);c=safeAdd(c,oc);d=safeAdd(d,od)}return[a,b,c,d]}
    function rstr2binl(s){var o=[];o[(s.length>>2)-1]=void 0;for(var i=0;i<o.length;i++)o[i]=0;for(var i=0;i<s.length*8;i+=8)o[i>>5]|=(s.charCodeAt(i/8)&0xff)<<(i%32);return o}
    function rstr2hex(s){var h='0123456789abcdef',o='';for(var i=0;i<s.length;i++){var x=s.charCodeAt(i);o+=h.charAt((x>>>4)&0xf)+h.charAt(x&0xf)}return o}
    function str2rstrUTF8(s){return unescape(encodeURIComponent(s))}
    function rstrMD5(s){return binl2rstr(binlMD5(rstr2binl(s),s.length*8))}
    function binl2rstr(i){var o='';for(var p=0;p<i.length*32;p+=8)o+=String.fromCharCode((i[p>>5]>>>(p%32))&0xff);return o}
    return function(s){ return rstr2hex(rstrMD5(str2rstrUTF8(s))); };
  })();

  // ============================================================
  // 3. 自定义 Base64 编码 (G.xE / G.lz)
  // ============================================================
  var CUSTOM_B64 = "ZmserbBoHQtNP+wOcza/LpngG8yJq42KWYj0DSfdikx3VT16IlUAFM97hECvuRX5";
  var STD_B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

  function encodeUtf8ToBytes(str) {
    var encoded = encodeURIComponent(str), bytes = [];
    for (var i = 0; i < encoded.length; i++) {
      if (encoded[i] === '%') { bytes.push(parseInt(encoded[i+1] + encoded[i+2], 16)); i += 2; }
      else bytes.push(encoded.charCodeAt(i));
    }
    return bytes;
  }

  function customBase64Encode(bytes) {
    // Standard base64 encode
    var chars = STD_B64, r = '', i;
    for (i = 0; i < bytes.length - 2; i += 3) {
      var n = (bytes[i] << 16) | (bytes[i+1] << 8) | bytes[i+2];
      r += chars[(n>>18)&63] + chars[(n>>12)&63] + chars[(n>>6)&63] + chars[n&63];
    }
    if (i === bytes.length - 1) {
      var n = bytes[i] << 16;
      r += chars[(n>>18)&63] + chars[(n>>12)&63] + '==';
    } else if (i === bytes.length - 2) {
      var n = (bytes[i] << 16) | (bytes[i+1] << 8);
      r += chars[(n>>18)&63] + chars[(n>>12)&63] + chars[(n>>6)&63] + '=';
    }
    // Translate to custom alphabet
    var out = '';
    for (var j = 0; j < r.length; j++) {
      var idx = STD_B64.indexOf(r[j]);
      out += idx >= 0 ? CUSTOM_B64[idx] : r[j];
    }
    return out;
  }

  // ============================================================
  // 4. CRC32 (G.tb — 带 EDB88320 异或)
  // ============================================================
  function crc32xor(str) {
    var table = [], i, j, c;
    for (i = 0; i < 256; i++) { c = i; for (j = 0; j < 8; j++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; table[i] = c; }
    var crc = -1;
    for (i = 0; i < str.length; i++) crc = table[(crc ^ str.charCodeAt(i)) & 0xff] ^ (crc >>> 8);
    return ((-1 ^ crc) ^ 0xedb88320) >>> 0;
  }

  // ============================================================
  // 5. 在非浏览器环境，提前设置关键全局（必须在 IIFE 外也能生效）
  // ============================================================
  if (typeof module !== 'undefined' && module.exports && typeof window === 'undefined') {
    // Node 环境：确保 eval 在全局作用域
    // 这个赋值必须在所有 require 之前
    var _g = typeof globalThis !== 'undefined' ? globalThis : global;
    if (!_g._mnsv2_env_ready) {
      _g._mnsv2_env_ready = true;
    }
  }

  // ============================================================
  // 5b. mnsv2 初始化状态
  // ============================================================
  var _mnsv2Ready = false;
  var _initError = null;

  function _ensureMnsv2() {
    if (_mnsv2Ready) return;
    if (_initError) throw new Error('mnsv2 init failed: ' + _initError);
    throw new Error('mnsv2 not initialized. Call XhsMnsV2.init() first or use initFromFiles()');
  }

  // ============================================================
  // 6. 对外 API
  // ============================================================
  var XhsMnsV2 = {
    /**
     * 从已下载的文件初始化 mnsv2（Node.js 环境）
     * @param {string} dir - js 文件目录路径
     */
    initFromFiles: function(dir) {
      if (_mnsv2Ready) return true;
      if (typeof g.mnsv2 === 'function') { _mnsv2Ready = true; return true; }

      var fs = require('fs'), path = require('path'), cryptoMod = require('crypto');
      // 确保绝对路径
      var join = function(f) { return path.resolve(dir, f); };

      // 设置 Node 环境 shim（和 run_mnsv2.js 一致）
      // 安全设置全局属性（Node v24+ 某些属性只读）
      function safeSet(obj, key, val) {
        try { obj[key] = val; } catch(e) {
          try { Object.defineProperty(obj, key, { value: val, writable: true, configurable: true }); } catch(e2) {}
        }
      }
      safeSet(g, 'window', g); safeSet(g, 'self', g); safeSet(g, 'top', g); safeSet(g, 'parent', g);
      safeSet(g, 'location', { href:'https://www.xiaohongshu.com/explore', host:'www.xiaohongshu.com', hostname:'www.xiaohongshu.com', origin:'https://www.xiaohongshu.com', protocol:'https:', pathname:'/explore', search:'', hash:'', port:'', reload:function(){}, assign:function(){}, replace:function(){} });
      safeSet(g, 'document', { createElement:function(t){var e={style:{},tagName:t,setAttribute:function(){},getAttribute:function(){return null},appendChild:function(){},removeChild:function(){},addEventListener:function(){},innerHTML:'',textContent:''};if(t==='canvas'){e.getContext=function(){return{fillRect:function(){},fillText:function(){},measureText:function(){return{width:10}},getImageData:function(){return{data:new Uint8Array(100)}},canvas:{toDataURL:function(){return'data:,'}}}};e.toDataURL=function(){return'data:,'}}if(t==='a')e.href='';return e}, body:{appendChild:function(){},removeChild:function(){},style:{}}, head:{appendChild:function(){}}, querySelectorAll:function(){return[]}, querySelector:function(){return null}, getElementById:function(){return null}, getElementsByTagName:function(){return[]}, addEventListener:function(){}, removeEventListener:function(){}, createEvent:function(){return{initEvent:function(){}}}, cookie:'', documentElement:{style:{},getAttribute:function(){return null},clientWidth:1920,clientHeight:1080}, createTextNode:function(){return{}}, location:null, readyState:'complete', hidden:false, visibilityState:'visible', title:'' });
      g.document.location = g.location;
      safeSet(g, 'navigator', { userAgent:'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36', platform:'MacIntel', language:'zh-CN', languages:['zh-CN','zh'], hardwareConcurrency:8, deviceMemory:8, maxTouchPoints:0, vendor:'Google Inc.', appVersion:'5.0', cookieEnabled:true, plugins:{length:5,item:function(){return null},namedItem:function(){return null},refresh:function(){}}, mimeTypes:{length:2,item:function(){return null},namedItem:function(){return null}}, connection:{effectiveType:'4g',downlink:10,rtt:50}, webdriver:false, getBattery:function(){return Promise.resolve({charging:true,level:1})} });
      safeSet(g, 'screen', {width:1920,height:1080,availWidth:1920,availHeight:1050,colorDepth:24,pixelDepth:24});
      var _ls={}; safeSet(g,'localStorage',{getItem:function(k){return _ls[k]||null},setItem:function(k,v){_ls[k]=String(v)},removeItem:function(k){delete _ls[k]},length:0,key:function(){return null},clear:function(){_ls={}}});
      var _ss={}; safeSet(g,'sessionStorage',{getItem:function(k){return _ss[k]||null},setItem:function(k,v){_ss[k]=String(v)},removeItem:function(k){delete _ss[k]},length:0,key:function(){return null},clear:function(){_ss={}}});
      safeSet(g,'history',{length:2,pushState:function(){},replaceState:function(){},back:function(){},forward:function(){}});
      safeSet(g,'XMLHttpRequest',function(){this.open=function(){};this.send=function(){};this.setRequestHeader=function(){};this.addEventListener=function(){}});
      safeSet(g,'fetch',function(){return Promise.resolve({json:function(){return{}},text:function(){return''}})});
      safeSet(g,'crypto',{getRandomValues:function(a){var b=cryptoMod.randomBytes(a.length);for(var i=0;i<a.length;i++)a[i]=b[i];return a},subtle:{}});
      safeSet(g,'btoa',function(s){return Buffer.from(s,'binary').toString('base64')});
      safeSet(g,'atob',function(s){return Buffer.from(s,'base64').toString('binary')});
      safeSet(g,'requestAnimationFrame',function(cb){return setTimeout(cb,16)});
      safeSet(g,'cancelAnimationFrame',function(id){clearTimeout(id)});
      safeSet(g,'Image',function(){}); safeSet(g,'HTMLElement',function(){}); safeSet(g,'HTMLCanvasElement',function(){});
      safeSet(g,'Event',function(t){this.type=t}); safeSet(g,'CustomEvent',g.Event);
      safeSet(g,'MutationObserver',function(){this.observe=function(){};this.disconnect=function(){};this.takeRecords=function(){return[]}});
      safeSet(g,'performance',{now:function(){return Date.now()},timing:{navigationStart:Date.now()},getEntriesByType:function(){return[]},mark:function(){},measure:function(){}});
      safeSet(g,'chrome',{}); safeSet(g,'Reflect',Reflect); safeSet(g,'Proxy',Proxy);
      // 关键：eval 必须在全局作用域执行，否则 signV2Init 内部 eval(code) 无法设置 window.mnsv2
      // 使用间接 eval：(0, eval) 强制全局作用域
      var _globalEval = (0, eval);
      safeSet(g, 'eval', _globalEval);

      // 静默加载（设为 false 可调试）
      var _silent = false;
      var _log = console.log, _err = console.error;
      if (_silent) { console.log = function(){}; console.error = function(){}; }

      try {
        // require 会把代码包在 module wrapper 里，导致 eval 作用域不是全局
        // 用 vm.runInThisContext + 替换相对路径为绝对路径
        var vmMod = require('vm');
        var code = fs.readFileSync(join('run_mnsv2.js'), 'utf8');
        // 把 require('./xxx') 替换成 require('/absolute/path/xxx')
        code = code.replace(/require\('\.\/([^']+)'\)/g, function(match, file) {
          return "require('" + join(file).replace(/\\/g, '/') + "')";
        });
        // 用 new Function 但不 wrap 在 function scope 里 — 通过 (0,eval) 间接 eval 确保全局作用域
        // 先把 require 注入到 global
        g.require = require;
        g.__dirname = dir;
        var indirectEval = (0, eval);
        indirectEval(code);
      } catch(e) {
        console.log = _log; console.error = _err;
        console.log('[mnsv2] Init error:', e.message);
        console.log(e.stack && e.stack.split('\n').slice(0,3).join('\n'));
      }

      console.log = _log; console.error = _err;

      if (typeof g.mnsv2 === 'function') { _mnsv2Ready = true; return true; }
      _initError = 'mnsv2 function not created'; return false;
    },

    /**
     * 浏览器环境初始化（假设页面已加载小红书的 JS）
     */
    initFromBrowser: function() {
      if (typeof g.mnsv2 === 'function') {
        _mnsv2Ready = true;
        return true;
      }
      // 尝试通过 webpack chunk 初始化
      if (g.webpackChunkxhs_pc_web) {
        var capturedRequire = null;
        g.webpackChunkxhs_pc_web.push([['__init__'], {}, function(req) { capturedRequire = req; }]);
        if (capturedRequire) {
          try {
            var mod = capturedRequire(29230);
            if (mod && typeof mod.a === 'function') mod.a();
          } catch(e) {}
        }
        if (typeof g.mnsv2 === 'function') { _mnsv2Ready = true; return true; }
      }
      _initError = 'mnsv2 not found in browser context';
      return false;
    },

    /** 是否已初始化 */
    isReady: function() { return _mnsv2Ready; },

    /**
     * 生成签名 headers
     * @param {string} url - API 路径 (包含 query string)，如 /api/sns/red/live/web/feed/v1/squarefeed?source=13&...
     * @param {string|object|null} body - POST body（GET 传 null）
     * @param {object} [options] - 可选参数
     * @param {string} [options.a1] - cookie 中的 a1 值（生成 x-s-common 需要）
     * @param {string} [options.platform] - 平台，默认 "Mac OS"
     * @returns {{ "x-s": string, "x-t": string, "x-s-common": string }}
     */
    sign: function(url, body, options) {
      _ensureMnsv2();
      options = options || {};
      var platform = options.platform || "Mac OS";

      // 1. 构造 contentString (和 seccore_signv2 一致)
      var contentString = url;
      if (body !== null && body !== undefined) {
        if (typeof body === 'object') contentString += JSON.stringify(body);
        else if (typeof body === 'string') contentString += body;
      }

      // 2. 计算哈希
      var contentHash = md5hex(contentString);
      var urlHash = md5hex(url);

      // 3. 调用 mnsv2
      var mnsResult = g.mnsv2(contentString, contentHash, urlHash);

      // 4. 构造 XYS_ 签名
      var signData = {
        x0: "4.3.4",
        x1: "xhs-pc-web",
        x2: platform,
        x3: mnsResult,
        x4: body !== null && body !== undefined ? (typeof body === 'object' ? 'object' : typeof body) : ""
      };
      var xsValue = "XYS_" + customBase64Encode(encodeUtf8ToBytes(JSON.stringify(signData)));
      var xtValue = String(Date.now());

      // 5. 构造 X-s-common
      var a1 = options.a1 || "";
      var xscData = {
        s0: 3, s1: "",
        x0: "1", x1: "4.3.4", x2: platform,
        x3: "xhs-pc-web", x4: "6.5.0",
        x5: a1, x6: "", x7: "", x8: "",
        x9: crc32xor(""),
        x10: 0, x11: "normal"
      };
      var xscValue = customBase64Encode(encodeUtf8ToBytes(JSON.stringify(xscData)));

      return {
        "x-s": xsValue,
        "x-t": xtValue,
        "x-s-common": xscValue
      };
    },

    /**
     * 只生成 mnsv2 签名（底层调用）
     */
    signRaw: function(contentString, contentHash, urlHash) {
      _ensureMnsv2();
      return g.mnsv2(contentString, contentHash, urlHash);
    },

    /** MD5 工具 */
    md5: md5hex,
    /** 自定义 Base64 编码 */
    b64encode: function(str) { return customBase64Encode(encodeUtf8ToBytes(str)); },
    /** CRC32 工具 */
    crc32: crc32xor,
  };

  // ============================================================
  // 7. 导出
  // ============================================================
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { XhsMnsV2: XhsMnsV2 };
  }
  if (typeof root !== 'undefined') {
    root.XhsMnsV2 = XhsMnsV2;
  }

})(typeof window !== 'undefined' ? window : (typeof global !== 'undefined' ? global : this));
