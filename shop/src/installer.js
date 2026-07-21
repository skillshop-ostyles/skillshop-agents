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
 * Guard: targetPath must never be ~/.claude (or a subfolder of it), and must
 * never be the AGENTS repo itself (or a subfolder of it) - the shop sells
 * outward, not into itself. Throws InstallError('SCHUTZ', ...) and writes
 * nothing on violation.
 */
function assertAllowedTarget(targetPath, rootDir) {
  const normTarget = normalizePath(targetPath);
  const claudeRoot = normalizePath(path.join(process.env.USERPROFILE || os.homedir(), '.claude'));
  if (normTarget === claudeRoot || normTarget.startsWith(claudeRoot + path.sep)) {
    throw new InstallError('SCHUTZ', `SCHUTZ: Zielverzeichnis liegt unter ${claudeRoot} - Installation abgelehnt.`);
  }
  const normRoot = normalizePath(rootDir);
  if (normTarget === normRoot || normTarget.startsWith(normRoot + path.sep)) {
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
  if (alreadyExists && overwrite) {
    fs.rmSync(destDir, { recursive: true, force: true });
  }

  fs.mkdirSync(path.dirname(destDir), { recursive: true });
  try {
    fs.cpSync(folder.folderPath, destDir, { recursive: true });
  } catch (err) {
    fs.rmSync(destDir, { recursive: true, force: true });
    throw new InstallError('COPY_FAILED', `Kopieren fehlgeschlagen fuer '${skillName}': ${err.message}`);
  }

  const { folderHash, files } = verifyInstalledCopy(destDir, folder.folderHash, skillName);
  return { name: skillName, destDir, folderHash, files };
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
