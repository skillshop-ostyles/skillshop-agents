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

// A1: On Windows the filesystem is case-insensitive - the guard must reject
// every casing of ~/.claude, not just the exact one. This is the gap the
// original 12 tests + Rot-Probe missed (Review-Befund A1).
test('assertAllowedTarget rejects ~/.claude in every casing (A1)', (t) => {
  if (process.platform !== 'win32') {
    t.skip('case-insensitivity only applies to Windows filesystems');
    return;
  }
  const base = (process.env.USERPROFILE || os.homedir());
  const variants = [
    path.join(base, '.claude', 'skills', 'x'),
    path.join(base.toUpperCase(), '.claude', 'skills', 'x'),
    path.join(base, '.CLAUDE', 'skills', 'x'),
    path.join(base, '.claude', 'skills', 'x').toLowerCase(),
    path.join(base, '.Claude', 'Skills', 'X'),
  ];
  for (const v of variants) {
    assert.throws(() => assertAllowedTarget(v, FIXTURE_ROOT), InstallError, `Variante nicht blockiert: ${v}`);
  }
});

test('assertAllowedTarget rejects the AGENTS root in every casing (A1)', (t) => {
  if (process.platform !== 'win32') {
    t.skip('case-insensitivity only applies to Windows filesystems');
    return;
  }
  const variants = [
    FIXTURE_ROOT,
    FIXTURE_ROOT.toUpperCase(),
    FIXTURE_ROOT.toLowerCase(),
    path.join(FIXTURE_ROOT.toUpperCase(), 'DEMO-SKILL-A'),
  ];
  for (const v of variants) {
    assert.throws(() => assertAllowedTarget(v, FIXTURE_ROOT), InstallError, `Variante nicht blockiert: ${v}`);
  }
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

// A3: a failing overwrite-reinstall must restore the previous, working version -
// never leave the user with an empty folder.
test('install() overwrite restores the previous version when the copy fails (A3)', (t) => {
  const target = tmpTarget();
  install({ skillName: 'demo-skill-a', targetPath: target, rootDir: FIXTURE_ROOT });
  const skillsDir = path.join(target, '.claude', 'skills');
  const destDir = path.join(skillsDir, 'demo-skill-a');
  const marker = path.join(destDir, 'MY-LOCAL-EDIT.txt');
  fs.writeFileSync(marker, 'user work'); // prove the OLD version survives

  t.mock.method(fs, 'cpSync', () => { throw new Error('simulated disk full'); });

  assert.throws(
    () => install({ skillName: 'demo-skill-a', targetPath: target, rootDir: FIXTURE_ROOT, overwrite: true }),
    (err) => err instanceof InstallError && err.code === 'COPY_FAILED'
  );

  assert.ok(fs.existsSync(path.join(destDir, 'SKILL.md')), 'old SKILL.md must be restored');
  assert.ok(fs.existsSync(marker), 'the user edit must survive a failed reinstall');
  const leftoverBackups = fs.readdirSync(skillsDir).filter((n) => n.includes('.bak-'));
  assert.deepEqual(leftoverBackups, [], 'no leftover backup dir');
});

test('install() overwrite removes the backup on success (A3)', () => {
  const target = tmpTarget();
  install({ skillName: 'demo-skill-a', targetPath: target, rootDir: FIXTURE_ROOT });
  install({ skillName: 'demo-skill-a', targetPath: target, rootDir: FIXTURE_ROOT, overwrite: true });
  const skillsDir = path.join(target, '.claude', 'skills');
  const leftoverBackups = fs.readdirSync(skillsDir).filter((n) => n.includes('.bak-'));
  assert.deepEqual(leftoverBackups, [], 'a successful reinstall must leave no backup dir behind');
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
