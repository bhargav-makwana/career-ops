import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const modeText = readFileSync(join(ROOT, 'modes', 'discover-jobs.md'), 'utf8');
const agentsText = readFileSync(join(ROOT, 'AGENTS.md'), 'utf8');

test('discover-jobs mode documents skill-based (not title-based) query construction', () => {
  assert.match(modeText, /never.*job title/i);
  assert.match(modeText, /SAP S\/4HANA/);
});

test('discover-jobs mode documents tool-availability branching (Nimble vs WebSearch)', () => {
  assert.match(modeText, /Nimble Web Search Agent/);
  assert.match(modeText, /WebSearch/);
});

test('discover-jobs mode documents dedup on company+title', () => {
  assert.match(modeText, /\(company, job title\)/);
});

test('discover-jobs mode documents the 4-value Status column and Not Applied default', () => {
  assert.match(modeText, /Not Applied/);
  for (const status of ['Applied', 'Interview', 'Rejected']) {
    assert.match(modeText, new RegExp(status));
  }
});

test('discover-jobs mode explicitly excludes scoring at discovery time', () => {
  assert.match(modeText, /do not score/i);
});

test('AGENTS.md Skill Modes table points job search at discover-jobs', () => {
  assert.match(agentsText, /`discover-jobs`/);
});
