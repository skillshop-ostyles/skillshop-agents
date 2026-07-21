'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { scanSkillFolders, computeFolderHash, listFilesSorted } = require('./importer');

class InstallError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

/** ~-expansion + absolute resolution, mirrors the PowerShell Normalize() helper from BIBEL § 2.2. */
function normalizePath(p) {
  const base = process.env.USERPROFILE || os.homedir();
  const expanded = p.startsWith('~') ? path.join(base, p.slice(1)) : p;
  return path.resolve(expanded);
}

/**
 * Path comparison for the guard. On Windows the filesystem is case-insensitive,
 * so `C:\USERS\OSTOL\.claude` and `C:\Users\ostol\.claude` are the SAME folder -
 * a case-sensitive compare would let the uppercase form slip past the guard and
 * write into the protected directory (Review-Befund A1). We therefore lowercase
 * both sides on win32; POSIX stays case-sensitive, as its filesystem is.
 */
function forCompare(normalizedAbsPath) {
  return process.platform === 'win32' ? normalizedAbsPath.toLowerCase() : normalizedAbsPath;
}

/** True if `child` equals `parent` or lies inside it, case-correct per platform. */
function isInsideOrEqual(child, parent) {
  const c = forCompare(child);
  const p = forCompare(parent);
  return c === p || c.startsWith(p + path.sep);
}

/**
 * Guard: targetPath must never be ~/.claude (or a subfolder of it), and must
 * never be the AGENTS repo itself (or a subfolder of it) - the shop sells
 * outward, not into itself. Throws InstallError('SCHUTZ', ...) and writes
 * nothing on violation. Comparison is case-insensitive on Windows (A1).
 */
function assertAllowedTarget(targetPath, rootDir) {
  const normTarget = normalizePath(targetPath);
  const claudeRoot = normalizePath(path.join(process.env.USERPROFILE || os.homedir(), '.claude'));
  if (isInsideOrEqual(normTarget, claudeRoot)) {
    throw new InstallError('SCHUTZ', `SCHUTZ: Zielverzeichnis liegt unter ${claudeRoot} - Installation abgelehnt.`);
  }
  const normRoot = normalizePath(rootDir);
  if (isInsideOrEqual(normTarget, normRoot)) {
    throw new InstallError('SCHUTZ', `SCHUTZ: Zielverzeichnis liegt innerhalb von ${normRoot} - Installation abgelehnt.`);
  }
  return normTarget;
}

/**
 * Installs one skill folder into <targetPath>/.claude/skills/<skillName>/.
 * Read-only towards the source (AGENTS repo); writes only inside targetPath.
 *
 * @param {object} opts
 * @param {string} opts.skillName
 * @param {string} opts.targetPath
 * @param {string} opts.rootDir AGENTS repo root (source of skill folders)
 * @param {boolean} [opts.overwrite]
 * @returns {{name: string, destDir: string, folderHash: string, files: number}}
 */
function install({ skillName, targetPath, rootDir, overwrite = false }) {
  const normTarget = assertAllowedTarget(targetPath, rootDir);

  if (!fs.existsSync(normTarget) || !fs.statSync(normTarget).isDirectory()) {
    throw new InstallError('NO_TARGET', `Zielverzeichnis existiert nicht oder ist keine Ordner: ${normTarget}`);
  }

  const folders = scanSkillFolders(rootDir);
  const folder = folders.get(skillName);
  if (!folder) {
    throw new InstallError('NO_SOURCE', `Skill '${skillName}' hat keinen Quell-Ordner (noch nicht implementiert)`);
  }

  const destDir = path.join(normTarget, '.claude', 'skills', skillName);
  const alreadyExists = fs.existsSync(destDir);
  if (alreadyExists && !overwrite) {
    throw new InstallError('EXISTS', `Skill '${skillName}' ist bereits installiert unter ${destDir}`);
  }

  // Backup-vor-Overwrite (Review-Befund A3): bei overwrite den bestehenden Ordner
  // NICHT sofort loeschen, sondern beiseite renamen. Schlaegt Kopie/Verifikation
  // fehl, wird die alte, funktionierende Version wiederhergestellt - ein Reinstall
  // darf den User nie mit einem leeren Ordner zuruecklassen.
  let backupDir = null;
  if (alreadyExists && overwrite) {
    backupDir = `${destDir}.bak-${Date.now()}`;
    fs.renameSync(destDir, backupDir);
  }

  const restoreBackup = () => {
    fs.rmSync(destDir, { recursive: true, force: true });
    if (backupDir && fs.existsSync(backupDir)) {
      fs.renameSync(backupDir, destDir);
    }
  };

  fs.mkdirSync(path.dirname(destDir), { recursive: true });
  try {
    fs.cpSync(folder.folderPath, destDir, { recursive: true });
  } catch (err) {
    restoreBackup();
    throw new InstallError('COPY_FAILED', `Kopieren fehlgeschlagen fuer '${skillName}': ${err.message}`);
  }

  let result;
  try {
    result = verifyInstalledCopy(destDir, folder.folderHash, skillName);
  } catch (err) {
    // verifyInstalledCopy hat destDir bereits entfernt; jetzt das Backup zuruecksetzen.
    if (backupDir && fs.existsSync(backupDir)) {
      fs.renameSync(backupDir, destDir);
    }
    throw err;
  }

  if (backupDir) {
    fs.rmSync(backupDir, { recursive: true, force: true });
  }
  return { name: skillName, destDir, folderHash: result.folderHash, files: result.files };
}

/**
 * Verifies that destDir's content hash matches expectedHash. On mismatch (or
 * any read error), rolls back by deleting destDir entirely and throws
 * InstallError('VERIFY_FAILED', ...) - an install must never leave a partial
 * or corrupted skill folder behind. Extracted as its own function so the
 * rollback path is directly testable without needing a real copy failure.
 */
function verifyInstalledCopy(destDir, expectedHash, skillName = path.basename(destDir)) {
  let destHash;
  let fileCount;
  try {
    destHash = computeFolderHash(destDir);
    fileCount = listFilesSorted(destDir).length;
  } catch (err) {
    fs.rmSync(destDir, { recursive: true, force: true });
    throw new InstallError('VERIFY_FAILED', `Verifikation fehlgeschlagen fuer '${skillName}': ${err.message}`);
  }
  if (destHash !== expectedHash) {
    fs.rmSync(destDir, { recursive: true, force: true });
    throw new InstallError('VERIFY_FAILED', `Verifikation fehlgeschlagen fuer '${skillName}' - Installation zurueckgerollt.`);
  }
  return { folderHash: destHash, files: fileCount };
}

module.exports = { InstallError, install, assertAllowedTarget, normalizePath, verifyInstalledCopy };
