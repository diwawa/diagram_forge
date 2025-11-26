import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const inputFile = '/tmp/fixed_diagrams_for_validation.json';

if (!fs.existsSync(inputFile)) {
  console.error(`Error: ${inputFile} not found. Run the AI fix script first.`);
  process.exit(1);
}

const diagrams = JSON.parse(fs.readFileSync(inputFile, 'utf8'));
const stillBroken = [];
const nowValid = [];

console.log(`Validating ${diagrams.length} fixed diagrams using mmdc...\n`);

// Create temp directory for validation
const tmpDir = '/tmp/mermaid_validate_fixed';
if (!fs.existsSync(tmpDir)) {
  fs.mkdirSync(tmpDir, { recursive: true });
}

for (let i = 0; i < diagrams.length; i++) {
  const diagram = diagrams[i];
  const inputMmd = path.join(tmpDir, `diagram_${i}.mmd`);
  const outputSvg = path.join(tmpDir, `diagram_${i}.svg`);

  fs.writeFileSync(inputMmd, diagram.source);

  try {
    execSync(`npx mmdc -i "${inputMmd}" -o "${outputSvg}" 2>&1`, {
      cwd: __dirname,
      timeout: 10000,
      stdio: 'pipe'
    });
    nowValid.push({
      id: diagram.id,
      title: diagram.title
    });
  } catch (err) {
    const errorOutput = err.stderr?.toString() || err.stdout?.toString() || err.message;
    stillBroken.push({
      id: diagram.id,
      title: diagram.title,
      error: errorOutput,
      source: diagram.source
    });
  }

  // Clean up temp files
  try { fs.unlinkSync(inputMmd); } catch {}
  try { fs.unlinkSync(outputSvg); } catch {}
}

console.log(`\n=== VALIDATION RESULTS ===`);
console.log(`Total fixed by AI: ${diagrams.length}`);
console.log(`Now valid: ${nowValid.length}`);
console.log(`Still broken: ${stillBroken.length}`);

if (nowValid.length > 0) {
  console.log(`\n=== NOW VALID (${nowValid.length}) ===`);
  for (const v of nowValid) {
    console.log(`✓ ${v.title} (${v.id})`);
  }
}

if (stillBroken.length > 0) {
  console.log(`\n=== STILL BROKEN (${stillBroken.length}) ===`);
  for (const b of stillBroken) {
    console.log(`\n--- ${b.title} (${b.id}) ---`);
    console.log(`Error: ${b.error.substring(0, 300)}`);
    console.log(`Source:\n${b.source}`);
  }
}

// Clean up temp directory
try { fs.rmdirSync(tmpDir); } catch {}

// Write still broken to file for further analysis
if (stillBroken.length > 0) {
  fs.writeFileSync('/tmp/still_broken_after_ai_fix.json', JSON.stringify(stillBroken, null, 2));
  console.log(`\nStill broken diagrams written to /tmp/still_broken_after_ai_fix.json`);
}

console.log(`\n=== SUCCESS RATE: ${Math.round(nowValid.length / diagrams.length * 100)}% ===`);
