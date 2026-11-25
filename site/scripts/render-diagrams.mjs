import { readFileSync, writeFileSync } from 'node:fs';
import { render } from 'pele';

const dir = new URL('../../docs/diagrams/', import.meta.url);
for (const name of ['screen', 'session', 'entry', 'overlay']) {
  const source = readFileSync(new URL(`${name}.mmd`, dir), 'utf8');
  const { svg } = render(source, { idPrefix: name, responsive: false, fontFamily: 'sans-serif' });
  // A standalone SVG in a dark README cannot inherit the host's Pele theme.
  const standalone = svg.replace(/^(<svg\b[^>]*>)/, '$1<rect width="100%" height="100%" fill="var(--_bg)"/>');
  writeFileSync(new URL(`${name}.svg`, dir), `${standalone}\n`);
}
