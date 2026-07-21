'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { install, InstallError, assertAllowedTarget, verifyInstalledCopy } = require('../src/installer');
const { computeFolderHash } = require('../src/importer');

const FIXTURE_ROOT = path.join(__dirname, 'fixture', 'root'); // has demo-skill-a/, demo-skill-b/ with real SKILL.md

function tmpTarget() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'shop-install-target-'));
}

test('assertAllowedTarget rejects ~/.claude itself', () => {
  const claudeDir = path.join(process.env.USERPROFILE || os.homedir(), '.claude');
  assert.throws(() => assertAllowedTarget(claudeDir, FIXTURE_ROOT), InstallError);
});

test('assertAllowedTarget rejects a subfolder of ~/.claude', () => {
  const sub = path.join(process.env.USERPROFILE || os.homedir(), '.claude', 'skills', 'whatever');
  assert.throws(() => assertAllowedTarget(sub, FIXTURE_ROOT), InstallError);
});

test('assertAllowedTarget rejects the tilde-written form ~/.claude', () => {
  assert.throws(() => assertAllowedTarget('~/.claude/sub', FIXTURE_ROOT), InstallError);
});

test('assertAllowedTarget rejects paths inside the AGENTS root', () => {
  assert.throws(() => assertAllowedTarget(FIXTURE_ROOT, FIXTURE_ROOT), InstallError);
  assert.throws(() => assertAllowedTarget(path.join(FIXTURE_ROOT, 'demo-skill-a'), FIXTURE_ROOT), InstallError);
});

test('assertAllowedTarget allows a normal external directory', () => {
  const target = tmpTarget();
  assert.doesNotThrow(() => assertAllowedTarget(target, FIXTURE_ROOT));
});

test('install() rejects a target directory that does not exist', () => {
  const target = path.join(tmpTarget(), 'does-not-exist-yet');
  assert.throws(
    () => install({ skillName: 'demo-skill-a', targetPath: target, rootDir: FIXTURE_ROOT }),
    (err) => err instanceof InstallError && err.code === 'NO_TARGET'
  );
});

test('install() copies the full skill folder and verifies the hash', () => {
  const target = tmpTarget();
  const result = install({ skillName: 'demo-skill-a', targetPath: target, rootDir: FIXTURE_ROOT });

  const destDir = path.join(target, '.claude', 'skills', 'demo-skill-a');
  assert.equal(result.destDir, destDir);
  assert.ok(fs.existsSync(path.join(destDir, 'SKILL.md')));
  assert.equal(computeFolderHash(destDir), computeFolderHash(path.join(FIXTURE_ROOT, 'demo-skill-a')));
  assert.equal(result.files, 1); // just SKILL.md in the fixture
});

test('install() without overwrite fails with EXISTS if already installed', () => {
  const target = tmpTarget();
  install({ skillName: 'demo-skill-a', targetPath: target, rootDir: FIXTURE_ROOT });
  assert.throws(
    () => install({ skillName: 'demo-skill-a', targetPath: target, rootDir: FIXTURE_ROOT }),
    (err) => err instanceof InstallError && err.code === 'EXISTS'
  );
});

test('install() with overwrite replaces the existing folder', () => {
  const target = tmpTarget();
  install({ skillName: 'demo-skill-a', targetPath: target, rootDir: FIXTURE_ROOT });
  const destDir = path.join(target, '.claude', 'skills', 'demo-skill-a');
  fs.writeFileSync(path.join(destDir, 'stale-file.txt'), 'should be gone after overwrite');

  install({ skillName: 'demo-skill-a', targetPath: target, rootDir: FIXTURE_ROOT, overwrite: true });
  assert.equal(fs.existsSync(path.join(destDir, 'stale-file.txt')), false);
  assert.ok(fs.existsSync(path.join(destDir, 'SKILL.md')));
});

test('install() rejects a skill without a source folder (planned, not yet built)', () => {
  const target = tmpTarget();
  assert.throws(
    () => install({ skillName: 'demo-skill-c', targetPath: target, rootDir: FIXTURE_ROOT }),
    (err) => err instanceof InstallError && err.code === 'NO_SOURCE'
  );
});

test('verifyInstalledCopy rolls back and throws on hash mismatch', () => {
  const target = tmpTarget();
  const destDir = path.join(target, 'copy');
  fs.mkdirSync(destDir, { recursive: true });
  fs.writeFileSync(path.join(destDir, 'a.txt'), 'some content');

  assert.throws(
    () => verifyInstalledCopy(destDir, 'deliberately-wrong-hash', 'test-skill'),
    (err) => err instanceof InstallError && err.code === 'VERIFY_FAILED'
  );
  assert.equal(fs.existsSync(destDir), false, 'destDir must be removed after a failed verification');
});

test('verifyInstalledCopy succeeds and reports file count when the hash matches', () => {
  const target = tmpTarget();
  const destDir = path.join(target, 'copy');
  fs.mkdirSync(destDir, { recursive: true });
  fs.writeFileSync(path.join(destDir, 'a.txt'), 'some content');
  const realHash = computeFolderHash(destDir);

  const result = verifyInstalledCopy(destDir, realHash, 'test-skill');
  assert.equal(result.folderHash, realHash);
  assert.equal(result.files, 1);
  assert.ok(fs.existsSync(destDir), 'destDir must survive a successful verification');
});
