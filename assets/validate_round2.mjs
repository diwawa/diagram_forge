import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const inputFile = '/tmp/fixed_diagrams_round2.json';
const diagrams = JSON.parse(fs.readFileSync(inputFile, 'utf8'));

console.log(`Validating ${diagrams.length} round 2 fixed diagrams...\n`);

const tmpDir = '/tmp/mermaid_validate_r2';
if (!fs.existsSync(tmpDir)) fs.mkdirSync(tmpDir, { recursive: true });

let valid = 0, broken = 0;

for (let i = 0; i < diagrams.length; i++) {
  const d = diagrams[i];
  const inputMmd = path.join(tmpDir, `d${i}.mmd`);
  const outputSvg = path.join(tmpDir, `d${i}.svg`);

  fs.writeFileSync(inputMmd, d.source);

  try {
    execSync(`npx mmdc -i "${inputMmd}" -o "${outputSvg}" 2>&1`, {
      cwd: __dirname, timeout: 10000, stdio: 'pipe'
    });
    console.log(`✓ ${d.title}`);
    valid++;
  } catch (err) {
    console.log(`✗ ${d.title}`);
    console.log(`  Error: ${(err.stderr?.toString() || err.message).substring(0, 200)}`);
    broken++;
  }

  try { fs.unlinkSync(inputMmd); } catch {}
  try { fs.unlinkSync(outputSvg); } catch {}
}

try { fs.rmdirSync(tmpDir); } catch {}

console.log(`\nValid: ${valid}/${diagrams.length}, Broken: ${broken}/${diagrams.length}`);
