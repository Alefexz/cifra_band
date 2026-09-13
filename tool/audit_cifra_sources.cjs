const { inspectSongUrl } = require('../functions/server');
const { analyzeChordContent } = require('../functions/lib/chord-content');
(async () => {
  for (const [artist, track, url] of [
    ['Harpa Crista', 'Porque Ele Vive', 'https://www.cifraclub.com.br/harpa-crista/porque-ele-vive/'],
    ['Nossa Harpa', 'Porque Ele Vive - Hc 545', 'https://www.cifraclub.com.br/harpa-crista/porque-ele-vive/'],
    ['Fernandinho', 'Galileu', 'https://www.cifraclub.com.br/fernandinho/galileu/'],
    ['Isaias Saad', 'Bondade de Deus', 'https://www.cifraclub.com.br/isaias-saad/bondade-de-deus/'],
  ]) {
    const start = Date.now();
    const song = await inspectSongUrl(url, artist, track);
    console.log(JSON.stringify({artist, track, accepted: Boolean(song), elapsedMs: Date.now() - start,
      title: song?.title, key: song?.originalKey, quality: song ? analyzeChordContent(song.content) : null}));
  }
})().catch(e => { console.error(e.message); process.exitCode = 1; });
