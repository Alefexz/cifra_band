// Run against an extracted AAB/APK. This checks actual ELF program headers,
// not NDK/Gradle configuration. Output is machine-readable evidence.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(process.argv[2]);
const expectedChannel = process.argv[3];
if (!['play','direct'].includes(expectedChannel)) throw new Error('Expected play or direct');
const files = [];
function walk(dir) { for (const item of fs.readdirSync(dir,{withFileTypes:true})) {
    const file=path.join(dir,item.name);if(item.isDirectory())walk(file);else files.push(file);
}}
walk(root);
const libraries=[];
for(const file of files.filter(file=>file.endsWith('.so'))) {
    const bytes=fs.readFileSync(file);
    if(bytes.readUInt32BE(0)!==0x7f454c46 || bytes[5]!==1) throw new Error(`Unsupported ELF ${file}`);
    const is64=bytes[4]===2;
    const offset=is64?Number(bytes.readBigUInt64LE(32)):bytes.readUInt32LE(28);
    const size=bytes.readUInt16LE(is64?54:42);const count=bytes.readUInt16LE(is64?56:44);
    const segments=[];
    for(let i=0;i<count;i++) {
        const start=offset+i*size;
        if(bytes.readUInt32LE(start)!==1)continue;
        const align=is64?Number(bytes.readBigUInt64LE(start+48)):bytes.readUInt32LE(start+28);
        const fileOffset=is64?Number(bytes.readBigUInt64LE(start+8)):bytes.readUInt32LE(start+4);
        const address=is64?Number(bytes.readBigUInt64LE(start+16)):bytes.readUInt32LE(start+8);
        segments.push({align,fileOffset,address,compatible16KB:align>=16384 && fileOffset%16384===address%16384});
    }
    libraries.push({file:path.relative(root,file),bits:is64?64:32,segments,
        compatible16KB:segments.length>0&&segments.every(s=>s.compatible16KB)});
}
const forbidden=['cifra_band/apk_installer','installApk',
    'https://api.github.com/repos/Alefexz/cifra_band/releases/latest',
    'Tamanho de APK invalido.', 'Arquivo recebido nao e um APK.'];
const playMarkers=['cifra_band/play_updates'];
const matches=[];
for(const file of files.filter(file=>file.endsWith('libapp.so') || /classes\d*\.dex$/.test(file))) {
    const bytes=fs.readFileSync(file);
    for(const marker of [...forbidden,...playMarkers]) {
        if(bytes.includes(Buffer.from(marker)) || bytes.includes(Buffer.from(marker,'utf16le'))) {
            matches.push({file:path.relative(root,file),marker});
        }
    }
}
const failedAlignment=libraries.some(l=>l.bits===64&&!l.compatible16KB);
const directFound=forbidden.filter(marker=>matches.some(m=>m.marker===marker));
const playFound=playMarkers.every(marker=>matches.some(m=>m.marker===marker));
const channelValid=expectedChannel==='play'?directFound.length===0&&playFound:directFound.length===forbidden.length&&!playFound;
console.log(JSON.stringify({root,expectedChannel,libraries,matches,failedAlignment,channelValid,
    limitation:'ELF alignment and identifiable updater markers only. ZIP alignment, manifest and runtime need separate checks.'},null,2));
if(failedAlignment||!channelValid)process.exitCode=1;
