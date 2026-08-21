// Validate every <pre class="mermaid"> block in an HTML report.
// Setup (once per environment):  npm install mermaid@11 jsdom
// Usage:                         node validate_mermaid.mjs report.html
// Exit code 1 + per-diagram errors if any block fails to parse.
// If npm install isn't possible (offline), fall back to the manual syntax
// checklist in references/visual-library.md.
import { JSDOM } from 'jsdom';
import fs from 'fs';

const dom = new JSDOM('<!DOCTYPE html><body></body>', { url: 'https://localhost/', pretendToBeVisual: true });
global.window = dom.window;
global.document = dom.window.document;
Object.defineProperty(global, 'navigator', { value: dom.window.navigator, configurable: true });

const mermaid = (await import('mermaid')).default;
mermaid.initialize({ startOnLoad: false });

const html = fs.readFileSync(process.argv[2], 'utf8');
const blocks = [...html.matchAll(/<pre class="mermaid">([\s\S]*?)<\/pre>/g)].map(m => m[1]);
if (!blocks.length) { console.log('no mermaid blocks found'); process.exit(1); }

let fail = 0;
for (let i = 0; i < blocks.length; i++) {
  const src = blocks[i].replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').trim();
  try {
    await mermaid.parse(src);
    console.log(`diagram ${i + 1}: OK   (${src.split('\n')[0]})`);
  } catch (e) {
    fail++;
    console.log(`diagram ${i + 1}: FAIL — ${String(e.message || e).split('\n')[0]}`);
  }
}
console.log(fail ? `${fail} FAILURES` : 'all diagrams parse');
process.exit(fail ? 1 : 0);
