import {readFileSync, writeFileSync} from 'node:fs';
import {resolve, join} from 'node:path';

const [buildArg, pagesArg, version] = process.argv.slice(2);
if (!buildArg || !pagesArg || !/^\d+\.\d+\.\d+$/.test(version ?? '')) {
  throw new Error('Usage: node tools/prepare_stable_pages.mjs <build/web> <pages> <version>');
}
const build = resolve(buildArg), pages = resolve(pagesArg);
for (const name of ['index.html', 'motion-lab.html', 'character-lab.html']) {
  const destination = name === 'index.html' ? '../' : '../' + name;
  let html = readFileSync(join(build, name), 'utf8');
  if (!html.includes('class="roky-support-footer"')) throw new Error(`Missing bottom support entry: ${name}`);
  if (/<base\b/i.test(html)) throw new Error(`Unexpected base URL in source: ${name}`);
  // Keep the browser at the stable entry URL while assets retain versioned URLs.
  html = html.replace(/<head\b[^>]*>/i, head => head + `\n<base href="./v${version}/">\n<link rel="canonical" href="${destination}">`);
  html = html.replace(/(<a\b[^>]*\bhref=")([^"]*)(")/g, (all, before, href, after) => {
    if (/^(?:[a-z][a-z\d+.-]*:|\/)/i.test(href)) return all;
    return before + '../' + href.replace(/^\.\//, '') + after;
  });
  writeFileSync(join(pages, name), html);
  // Existing links to the active version should also show the stable address.
  writeFileSync(join(pages, `v${version}`, name), `<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>코트러시 · COURT RUSH</title><link rel="canonical" href="${destination}"><meta http-equiv="refresh" content="0;url=${destination}"></head><body><script>location.replace(${JSON.stringify(destination)}+location.search+location.hash)</script><a href="${destination}">코트러시 열기 →</a></body></html>\n`);
}
console.log(`Stable entries prepared; engine assets remain in v${version}/.`);
