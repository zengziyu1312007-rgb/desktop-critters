const assert=require('node:assert/strict');
const {detectDevice}=require('../docs/platform.js');
const cases=[
 [{userAgent:'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',platform:'Win32'},'windows'],
 [{hints:{platform:'Windows',architecture:'x86',bitness:'64'}},'windows'],
 [{hints:{platform:'Windows',architecture:'arm'}},'windows-arm'],
 [{userAgent:'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',platform:'MacIntel'},'mac'],
 [{platform:'MacIntel',maxTouchPoints:5,userAgent:'Mozilla/5.0 (Macintosh)'},'mobile'],
 [{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18)'},'mobile'],
 [{userAgent:'Mozilla/5.0 (Linux; Android 16)'},'mobile'],
 [{platform:'Linux x86_64',userAgent:'Mozilla/5.0 (X11; Linux x86_64)'},'unknown'],
 [{},'unknown']
];
for(const [input,expected] of cases)assert.equal(detectDevice(input),expected);
console.log(`${cases.length} platform detection checks passed`);
