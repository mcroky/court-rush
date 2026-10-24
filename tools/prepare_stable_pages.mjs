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
  // Render old entry URLs directly: a cached root redirect must not cause a loop.
  // Pin the asset base before updating the address without a network navigation.
  const stableName = name === 'index.html' ? '' : name;
  const normalizeAddress = `<script>(()=>{const assets=new URL('./',location.href);const entry=new URL(${JSON.stringify('../' + stableName)},location.href);entry.search=location.search;entry.hash=location.hash;const base=document.createElement('base');base.href=assets.href;document.head.append(base);history.replaceState(history.state,'',entry.href);})();</script>`;
  const versionEntry = html.replace(`<base href="./v${version}/">`, normalizeAddress);
  writeFileSync(join(pages, `v${version}`, name), versionEntry);
}
console.log(`Stable entries prepared; engine assets remain in v${version}/.`);
