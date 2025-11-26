import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const diagrams = JSON.parse(fs.readFileSync(path.join(__dirname, 'diagrams_to_validate.json'), 'utf8'));
const broken = [];

console.log(`Validating ${diagrams.length} diagrams using mmdc...\n`);

// Create temp directory for validation
const tmpDir = '/tmp/mermaid_validate';
if (!fs.existsSync(tmpDir)) {
  fs.mkdirSync(tmpDir, { recursive: true });
}

for (let i = 0; i < diagrams.length; i++) {
  const diagram = diagrams[i];
  const inputFile = path.join(tmpDir, `diagram_${i}.mmd`);
  const outputFile = path.join(tmpDir, `diagram_${i}.svg`);

  fs.writeFileSync(inputFile, diagram.source);

  try {
    execSync(`npx mmdc -i "${inputFile}" -o "${outputFile}" 2>&1`, {
      cwd: __dirname,
      timeout: 10000,
      stdio: 'pipe'
    });
  } catch (err) {
    const errorOutput = err.stderr?.toString() || err.stdout?.toString() || err.message;
    broken.push({
      id: diagram.id,
      title: diagram.title,
      error: errorOutput,
      source: diagram.source
    });
  }

  // Clean up temp files
  try { fs.unlinkSync(inputFile); } catch {}
  try { fs.unlinkSync(outputFile); } catch {}

  // Progress indicator
  if ((i + 1) % 20 === 0) {
    console.log(`Processed ${i + 1}/${diagrams.length}...`);
  }
}

console.log(`\n=== RESULTS ===`);
console.log(`Total: ${diagrams.length}`);
console.log(`Valid: ${diagrams.length - broken.length}`);
console.log(`Broken: ${broken.length}`);

if (broken.length > 0) {
  console.log(`\n=== BROKEN DIAGRAMS ===\n`);
  for (const b of broken) {
    console.log(`--- ${b.title} (${b.id}) ---`);
    console.log(`Error: ${b.error.substring(0, 500)}`);
    console.log(`Source:\n${b.source}`);
    console.log('');
  }
}

// Clean up temp directory
try { fs.rmdirSync(tmpDir); } catch {}
