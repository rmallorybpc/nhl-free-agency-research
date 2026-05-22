#!/usr/bin/env node

const fs = require('fs/promises');
const path = require('path');
const AuditCore = require('../dashboard/src/audit_core.js');

const REPO_ROOT = path.resolve(__dirname, '..');
const DASHBOARD_DIR = path.join(REPO_ROOT, 'dashboard', 'src');
const OUTPUT_FILE = path.join(REPO_ROOT, 'output', 'tables', 'audit_report.json');
const SITE_BASE_URL = 'https://rmallorybpc.github.io/nhl-free-agency-research';

function toPosix(p) {
  return p.replace(/\\/g, '/');
}

async function safeRead(filePath) {
  try {
    return await fs.readFile(filePath, 'utf8');
  } catch (_err) {
    return null;
  }
}

async function loadPageDocs() {
  const docs = [];
  for (const rel of AuditCore.PAGE_PATHS) {
    const abs = path.join(DASHBOARD_DIR, rel);
    const html = await safeRead(abs);
    if (html == null) continue;
    docs.push({
      path: rel,
      html: html,
      source: toPosix(path.relative(REPO_ROOT, abs)),
      url: SITE_BASE_URL.replace(/\/+$/, '') + '/' + rel
    });
  }
  return docs;
}

async function resolveInternalPathStatus(target) {
  const candidates = [
    path.join(DASHBOARD_DIR, target),
    path.join(REPO_ROOT, target)
  ];

  for (const abs of candidates) {
    try {
      const stat = await fs.stat(abs);
      if (stat.isFile()) {
        return { ok: true, status: 200 };
      }
    } catch (_err) {
      // continue trying candidates
    }
  }

  return { ok: false, status: 404 };
}

async function loadFileStats() {
  const stats = {};
  for (const rel of AuditCore.DATA_FRESHNESS_FILES) {
    const abs = path.join(REPO_ROOT, rel);
    try {
      const stat = await fs.stat(abs);
      stats[rel] = { mtime: stat.mtime.toISOString() };
    } catch (_err) {
      stats[rel] = null;
    }
  }
  return stats;
}

async function loadCsvMap() {
  const csvMap = {};
  for (const cfg of AuditCore.CSV_EXPECTATIONS) {
    const abs = path.join(REPO_ROOT, cfg.file);
    const content = await safeRead(abs);
    if (content != null) {
      csvMap[cfg.file] = content;
    }
  }
  return csvMap;
}

async function resolveExternalUrlStatus(url) {
  try {
    const response = await fetch(url, {
      method: 'GET',
      redirect: 'follow'
    });
    return { ok: response.ok, status: response.status };
  } catch (_err) {
    return { ok: false, status: 'network_error' };
  }
}

async function writeReport(report) {
  await fs.mkdir(path.dirname(OUTPUT_FILE), { recursive: true });
  const text = JSON.stringify(report, null, 2) + '\n';
  await fs.writeFile(OUTPUT_FILE, text, 'utf8');
}

async function main() {
  const nowIso = new Date().toISOString();
  const pageDocs = await loadPageDocs();
  const fileStats = await loadFileStats();
  const csvMap = await loadCsvMap();

  const report = await AuditCore.runAudit({
    mode: 'ci',
    now_iso: nowIso,
    site_base_url: SITE_BASE_URL,
    page_docs: pageDocs,
    file_stats: fileStats,
    csv_map: csvMap,
    resolve_internal_path_status: resolveInternalPathStatus,
    resolve_external_url_status: resolveExternalUrlStatus
  });

  await writeReport(report);

  const summary = report.summary;
  console.log('Audit report written to output/tables/audit_report.json');
  console.log(
    'Summary: checks=' + summary.total_checks +
    ', pass=' + summary.passed +
    ', warnings=' + summary.warnings +
    ', failures=' + summary.failures
  );

  if (summary.failures > 0) {
    process.exitCode = 1;
  }
}

main().catch(err => {
  console.error('Audit run failed:', err);
  process.exit(1);
});
