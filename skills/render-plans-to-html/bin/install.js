#!/usr/bin/env node
// Cross-platform installer for the render-plans-to-html skill.
// Registers SKILL.md + the CLI for Claude Code, Codex, or both.
//
// Usage:
//   npx render-plans-to-html-install                 # auto-detect
//   npx render-plans-to-html-install --claude        # Claude Code only
//   npx render-plans-to-html-install --codex         # Codex only
//   npx render-plans-to-html-install --all           # both
//   npx render-plans-to-html-install --uninstall     # remove
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PACKAGE_ROOT = path.resolve(__dirname, '..');
const SKILL_NAME = 'render-plans-to-html';

const HOME = os.homedir();
const CLAUDE_SKILLS_DIR = process.env.CLAUDE_SKILLS_DIR || path.join(HOME, '.claude', 'skills');
const CODEX_SKILLS_DIR = process.env.CODEX_SKILLS_DIR || path.join(HOME, '.agents', 'skills');
const BIN_DIR = process.env.BIN_DIR || path.join(HOME, '.local', 'bin');

const args = process.argv.slice(2);
const flag = args[0] || '--auto';

const COPY_INCLUDES = ['bin', 'src', 'package.json', 'README.md', 'README.pt-BR.md', 'LICENSE'];

async function copyPackage(dest) {
  await fsp.rm(dest, { recursive: true, force: true });
  await fsp.mkdir(dest, { recursive: true });
  for (const entry of COPY_INCLUDES) {
    const from = path.join(PACKAGE_ROOT, entry);
    if (!fs.existsSync(from)) continue;
    const to = path.join(dest, entry);
    await fsp.cp(from, to, { recursive: true });
  }
  await fsp.copyFile(
    path.join(PACKAGE_ROOT, 'skill', 'SKILL.md'),
    path.join(dest, 'SKILL.md'),
  );
  await fsp.mkdir(path.join(dest, 'skill'), { recursive: true });
  await fsp.copyFile(
    path.join(PACKAGE_ROOT, 'skill', 'SKILL.md'),
    path.join(dest, 'skill', 'SKILL.md'),
  );
}

function npmInstallProd(dest) {
  execFileSync('npm', ['install', '--omit=dev', '--no-audit', '--no-fund', '--silent'], {
    cwd: dest,
    stdio: ['ignore', 'inherit', 'inherit'],
  });
}

async function ensureExecutable(file) {
  if (process.platform === 'win32') return;
  try { await fsp.chmod(file, 0o755); } catch {}
}

async function symlinkCli(installedDir) {
  await fsp.mkdir(BIN_DIR, { recursive: true });
  const target = path.join(installedDir, SKILL_NAME, 'bin', 'render-plans.js');
  const linkPath = path.join(BIN_DIR, 'render-plans');
  try { await fsp.unlink(linkPath); } catch {}
  if (process.platform === 'win32') {
    await fsp.copyFile(target, linkPath + '.cmd');
  } else {
    await fsp.symlink(target, linkPath);
  }
  console.log(`==> Linked CLI at ${linkPath}`);
}

async function installTarget(label, baseDir) {
  const dest = path.join(baseDir, SKILL_NAME);
  console.log(`==> Installing ${label} skill at ${dest}`);
  await copyPackage(dest);
  npmInstallProd(dest);
  await ensureExecutable(path.join(dest, 'bin', 'render-plans.js'));
}

async function uninstallTarget(label, baseDir) {
  const dest = path.join(baseDir, SKILL_NAME);
  if (fs.existsSync(dest)) {
    console.log(`==> Removing ${label} skill at ${dest}`);
    await fsp.rm(dest, { recursive: true, force: true });
  }
}

async function autoTargets() {
  const targets = [];
  if (fs.existsSync(path.join(HOME, '.claude'))) {
    targets.push(['Claude Code', CLAUDE_SKILLS_DIR]);
  }
  if (fs.existsSync(path.join(HOME, '.agents')) || fs.existsSync(path.join(HOME, '.codex'))) {
    targets.push(['Codex', CODEX_SKILLS_DIR]);
  }
  return targets;
}

async function main() {
  switch (flag) {
    case '--claude': {
      await installTarget('Claude Code', CLAUDE_SKILLS_DIR);
      await symlinkCli(CLAUDE_SKILLS_DIR);
      break;
    }
    case '--codex': {
      await installTarget('Codex', CODEX_SKILLS_DIR);
      await symlinkCli(CODEX_SKILLS_DIR);
      break;
    }
    case '--all': {
      await installTarget('Claude Code', CLAUDE_SKILLS_DIR);
      await installTarget('Codex', CODEX_SKILLS_DIR);
      await symlinkCli(CLAUDE_SKILLS_DIR);
      break;
    }
    case '--uninstall': {
      await uninstallTarget('Claude Code', CLAUDE_SKILLS_DIR);
      await uninstallTarget('Codex', CODEX_SKILLS_DIR);
      const link = path.join(BIN_DIR, 'render-plans');
      if (fs.existsSync(link) || fs.existsSync(link + '.cmd')) {
        try { await fsp.unlink(link); } catch {}
        try { await fsp.unlink(link + '.cmd'); } catch {}
        console.log(`==> Removed CLI link at ${link}`);
      }
      break;
    }
    case '--auto':
    case undefined: {
      const targets = await autoTargets();
      if (targets.length === 0) {
        console.error('No agent home detected (~/.claude or ~/.agents/~/.codex).');
        console.error('Re-run with --claude, --codex, or --all to force a target.');
        process.exit(1);
      }
      for (const [label, dir] of targets) await installTarget(label, dir);
      await symlinkCli(targets[targets.length - 1][1]);
      break;
    }
    default:
      console.error(`Unknown flag: ${flag}`);
      console.error('Valid flags: --claude | --codex | --all | --uninstall');
      process.exit(2);
  }
  console.log('Done. Try: render-plans --help');
}

main().catch(err => {
  console.error(err.message || err);
  process.exit(1);
});
