(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.AuditCore = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  const AUDIT_VERSION = '1.0';

  const PAGE_PATHS = [
    'welcome.html',
    'findings.html',
    'index.html',
    'team.html',
    'explorer.html',
    'audit.html'
  ];

  const MAIN_PAGE_PATHS = [
    'welcome.html',
    'findings.html',
    'index.html',
    'team.html',
    'explorer.html'
  ];

  const NAV_EXPECTED = ['welcome.html', 'findings.html', 'index.html', 'team.html', 'explorer.html', 'audit.html'];
  const ACRONYM_RULES = [
    { acronym: 'UFA', definition: 'unrestricted free agent', suggestion: 'define as unrestricted free agent on first use' },
    { acronym: 'RFA', definition: 'restricted free agent', suggestion: 'define as restricted free agent on first use' },
    { acronym: 'MIS', definition: 'movement impact score', suggestion: 'define as Movement Impact Score on first use' },
    { acronym: 'AAV', definition: 'average annual value', suggestion: 'define as average annual value on first use' },
    { acronym: 'ELC', definition: 'entry level contract', suggestion: 'define as entry level contract on first use' },
    { acronym: 'AHL', definition: 'american hockey league', suggestion: 'define as American Hockey League on first use' },
    { acronym: 'OTL', definition: 'overtime loss', suggestion: 'define as overtime loss on first use' },
    { acronym: 'LTIR', definition: 'long term injured reserve', suggestion: 'define as long term injured reserve on first use' },
    { acronym: 'ECHL', definition: 'echl', suggestion: 'define ECHL on first use' },
    { acronym: 'ATO', definition: 'amateur tryout', suggestion: 'define as amateur tryout on first use' },
    { acronym: 'PTO', definition: 'professional tryout', suggestion: 'define as professional tryout on first use' }
  ];

  const JARGON_RULES = [
    { term: 'coefficient', suggestion: 'effect size', severity: 'warning' },
    { term: 'regression', suggestion: 'model', severity: 'warning' },
    { term: 'variance', suggestion: 'spread', severity: 'warning' },
    { term: 'specification', suggestion: 'model setup', severity: 'warning' },
    { term: 'dependent variable', suggestion: 'outcome metric', severity: 'warning' },
    { term: 'independent variable', suggestion: 'input variable', severity: 'warning' },
    { term: 'control variable', suggestion: 'context variable', severity: 'warning' },
    { term: 'panel', suggestion: 'multi-season dataset', severity: 'warning' },
    { term: 'tier', suggestion: 'group', severity: 'info' },
    { term: 'moderator', suggestion: 'conditioning factor', severity: 'warning' },
    { term: 'estimator', suggestion: 'calculation method', severity: 'warning' },
    { term: 'season-over-season', suggestion: 'year over year', severity: 'warning' },
    { term: 'points percentage', suggestion: 'keep with quick context for non-specialists', severity: 'info' },
    { term: 'ols', suggestion: 'linear model', severity: 'warning' },
    { term: 'r-squared', suggestion: 'variance explained', severity: 'warning' },
    { term: 'p-value', suggestion: 'statistical confidence', severity: 'warning' }
  ];

  const STALE_DAYS = 183;

  const DATA_FRESHNESS_FILES = [
    'data/processed/nhl_signed_free_agents_clean.csv',
    'data/processed/nhl_team_season_performance_clean.csv',
    'data/processed/nhl_master_analysis_panel.csv',
    'output/tables/model_comparison_summary.csv',
    'output/tables/quartile_summary.csv',
    'output/tables/quartile_examples.csv',
    'output/tables/geography_overall_summary.csv'
  ];

  const CSV_EXPECTATIONS = [
    {
      file: 'data/processed/nhl_master_analysis_panel.csv',
      expected_rows: 252,
      key_columns: ['season_year', 'teamTriCode', 'points_percentage', 'prior_season_points_pct', 'total_mis']
    },
    {
      file: 'data/processed/nhl_signed_free_agents_clean.csv',
      expected_rows: 1858,
      key_columns: ['player_name', 'signing_team', 'spotrac_year', 'aav', 'position_filter']
    },
    {
      file: 'data/processed/nhl_team_season_performance_clean.csv',
      expected_rows: 282,
      key_columns: ['season_year', 'teamTriCode', 'points_percentage', 'gamesPlayed']
    },
    {
      file: 'output/tables/model_comparison_summary.csv',
      expected_rows: 4,
      key_columns: ['model_name']
    },
    {
      file: 'output/tables/quartile_summary.csv',
      expected_rows: 4,
      key_columns: ['quartile', 'mean_change']
    },
    {
      file: 'output/tables/quartile_examples.csv',
      expected_rows: 12,
      key_columns: ['quartile', 'teamCommonName', 'season_year']
    },
    {
      file: 'output/tables/geography_overall_summary.csv',
      expected_rows: 3,
      key_columns: ['movement_geography', 'mean_change']
    }
  ];

  function htmlToVisibleText(html) {
    if (!html) return '';
    let text = String(html)
      .replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<noscript[\s\S]*?<\/noscript>/gi, ' ')
      .replace(/<[^>]+>/g, ' ')
      .replace(/&nbsp;/gi, ' ')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/&#39;/gi, "'")
      .replace(/&quot;/gi, '"')
      .replace(/&amp;/gi, '&')
      .replace(/\s+/g, ' ')
      .trim();
    return text;
  }

  function extractMainHtml(html) {
    const match = /<main\b[\s\S]*?<\/main>/i.exec(html || '');
    return match ? match[0] : String(html || '');
  }

  function getMainVisibleText(html) {
    return htmlToVisibleText(extractMainHtml(html));
  }

  function extractMainSections(html) {
    const main = extractMainHtml(html);
    const sections = [];
    const regex = /<section\b[\s\S]*?<\/section>/gi;
    let match;
    while ((match = regex.exec(main))) {
      const sectionHtml = match[0];
      sections.push({
        html: sectionHtml,
        text: htmlToVisibleText(sectionHtml),
        heading_text: extractHeadingsText(sectionHtml)
      });
    }

    if (!sections.length) {
      sections.push({
        html: main,
        text: htmlToVisibleText(main),
        heading_text: extractHeadingsText(main)
      });
    }

    return sections;
  }

  function extractHeadingsText(html) {
    const headings = [];
    const regex = /<h[1-4][^>]*>([\s\S]*?)<\/h[1-4]>/gi;
    let match;
    while ((match = regex.exec(html || ''))) {
      headings.push(htmlToVisibleText(match[1] || ''));
    }
    return headings.join(' | ');
  }

  function lower(s) {
    return String(s || '').toLowerCase();
  }

  function countTerm(text, term) {
    const escaped = term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp('\\b' + escaped + '\\b', 'gi');
    const matches = text.match(regex);
    return matches ? matches.length : 0;
  }

  function firstTermIndex(text, term) {
    const escaped = term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp('\\b' + escaped + '\\b', 'i');
    const match = regex.exec(text);
    return match ? match.index : -1;
  }

  function findAllTermIndices(text, term) {
    const escaped = term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp('\\b' + escaped + '\\b', 'gi');
    const indices = [];
    let match;
    while ((match = regex.exec(text))) {
      indices.push(match.index);
    }
    return indices;
  }

  function isMethodologyContext(windowText) {
    const w = lower(windowText || '');
    return w.includes('methodology')
      || w.includes('data and methodology')
      || w.includes('model')
      || w.includes('sensitivity check')
      || w.includes('analysis window')
      || w.includes('controls');
  }

  function isMethodologySection(headingText) {
    const h = lower(headingText || '');
    if (!h) return false;
    return h.includes('methodology')
      || h.includes('data and methodology')
      || h.includes('model')
      || h.includes('sensitivity check')
      || h.includes('study scope')
      || h.includes('analysis window')
      || h.includes('controls');
  }

  function normalizeNavHref(href) {
    if (!href) return null;
    const clean = href.split('#')[0].split('?')[0].trim();
    if (!clean) return null;
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      const slash = clean.lastIndexOf('/');
      return slash >= 0 ? clean.slice(slash + 1) : clean;
    }
    if (clean.startsWith('./')) return clean.slice(2);
    if (clean.startsWith('/')) return clean.slice(clean.lastIndexOf('/') + 1);
    return clean;
  }

  function extractTitle(html) {
    const m = /<title>([\s\S]*?)<\/title>/i.exec(html || '');
    return m ? m[1].trim() : '';
  }

  function extractMetaDescription(html) {
    const m = /<meta\s+name=["']description["']\s+content=["']([\s\S]*?)["']\s*\/?>/i.exec(html || '');
    return m ? m[1].trim() : '';
  }

  function extractAllLinks(html) {
    const links = [];
    const regex = /<a\s+([^>]*?)>([\s\S]*?)<\/a>/gi;
    let match;
    while ((match = regex.exec(html || ''))) {
      const attrs = match[1] || '';
      const text = htmlToVisibleText(match[2] || '');
      const hrefMatch = /href\s*=\s*["']([^"']+)["']/i.exec(attrs);
      if (!hrefMatch) continue;
      links.push({ href: hrefMatch[1].trim(), text: text || '(no text)' });
    }
    return links;
  }

  function extractNavLinks(html) {
    const navMatch = /<div\s+class=["']tmg-page-links["'][^>]*>([\s\S]*?)<\/div>/i.exec(html || '');
    if (!navMatch) return [];
    return extractAllLinks(navMatch[1]).map(link => normalizeNavHref(link.href)).filter(Boolean);
  }

  function hasActivePage(html) {
    return /aria-current=["']page["']/i.test(html || '');
  }

  function hasFooterGithubLink(html) {
    const footerMatch = /<footer[\s\S]*?<\/footer>/i.exec(html || '');
    if (!footerMatch) return false;
    return /github\.com\/rmallorybpc\/nhl-free-agency-research/i.test(footerMatch[0]);
  }

  function hasTmgWrapper(html) {
    return /class=["'][^"']*tmg-page[^"']*["']/i.test(html || '') && /class=["'][^"']*tmg-container[^"']*["']/i.test(html || '');
  }

  function statusFromIssues(issues) {
    if (!issues.length) return 'pass';
    if (issues.some(issue => issue.severity === 'error')) return 'fail';
    return 'warning';
  }

  function makeCategory(name, checksRun, issues, notes) {
    return {
      name: name,
      status: statusFromIssues(issues),
      checks_run: checksRun,
      issues_found: issues.length,
      details: issues,
      notes: notes || []
    };
  }

  function summarize(categories) {
    const totalChecks = categories.reduce((sum, c) => sum + (Number(c.checks_run) || 0), 0);
    const passed = categories.filter(c => c.status === 'pass').length;
    const warnings = categories.filter(c => c.status === 'warning').length;
    const failures = categories.filter(c => c.status === 'fail').length;
    return {
      total_checks: totalChecks,
      passed: passed,
      warnings: warnings,
      failures: failures
    };
  }

  function checkPlainLanguage(pageDocs) {
    const issues = [];
    let checksRun = 0;

    for (const doc of pageDocs) {
      const visibleText = getMainVisibleText(doc.html || '');
      const visibleLower = lower(visibleText);
      const inMethodologyHeavyPage = doc.path === 'findings.html' || doc.path === 'audit.html';
      const sections = extractMainSections(doc.html || '').map(section => {
        return {
          text: section.text,
          lower_text: lower(section.text),
          heading_text: section.heading_text,
          methodology_section: isMethodologySection(section.heading_text)
        };
      });

      for (const rule of ACRONYM_RULES) {
        checksRun += 1;
        const firstAcronymIndex = firstTermIndex(visibleText, rule.acronym);
        if (firstAcronymIndex < 0) continue;

        const start = Math.max(0, firstAcronymIndex - 160);
        const end = Math.min(visibleText.length, firstAcronymIndex + 220);
        const window = lower(visibleText.slice(start, end));
        const hasNearbyDefinition = window.includes(lower(rule.definition));

        if (!hasNearbyDefinition) {
          issues.push({
            page: doc.path,
            severity: 'warning',
            message: "Acronym '" + rule.acronym + "' appears without first-use definition",
            context: rule.suggestion,
            term: rule.acronym,
            suggestion: rule.suggestion
          });
        }
      }

      for (const rule of JARGON_RULES) {
        checksRun += 1;
        let flaggedCount = 0;
        let exemptCount = 0;
        const termLower = lower(rule.term);

        for (const section of sections) {
          const sectionCount = countTerm(section.lower_text, termLower);
          if (!sectionCount) continue;

          if (section.methodology_section) {
            exemptCount += sectionCount;
            continue;
          }

          flaggedCount += sectionCount;
        }

        if (!flaggedCount) {
          continue;
        }

        if (inMethodologyHeavyPage && flaggedCount) {
          const indices = findAllTermIndices(visibleLower, termLower);
          let adjustedFlaggedCount = 0;
          for (const idx of indices) {
            const start = Math.max(0, idx - 160);
            const end = Math.min(visibleText.length, idx + 180);
            const window = visibleText.slice(start, end);
            const methodologicalWindow = isMethodologyContext(window);

            if ((rule.term === 'ols' || rule.term === 'r-squared' || rule.term === 'p-value') && methodologicalWindow) {
              exemptCount += 1;
              continue;
            }

            adjustedFlaggedCount += 1;
          }
          flaggedCount = adjustedFlaggedCount;
        }

        if (!flaggedCount) continue;

        issues.push({
          page: doc.path,
          severity: rule.severity,
          message: "Jargon term '" + rule.term + "' detected in user-facing content",
          context: rule.suggestion
            + (flaggedCount > 1 ? ' (' + flaggedCount + ' occurrences)' : '')
            + (exemptCount > 0 ? '; exempted ' + exemptCount + ' methodology-section occurrences' : ''),
          term: rule.term,
          suggestion: rule.suggestion
        });
      }
    }

    return makeCategory('Plain language compliance', checksRun, issues, [
      'Methodology-heavy terms are tolerated in methodology-focused sections.'
    ]);
  }

  function resolveInternalTarget(fromPagePath, href, siteBaseUrl) {
    const clean = (href || '').trim();
    if (!clean) return null;
    if (clean.startsWith('#') || clean.startsWith('mailto:') || clean.startsWith('tel:') || clean.startsWith('javascript:')) return null;

    let resolvedPath = null;

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      try {
        const url = new URL(clean);
        if (!siteBaseUrl) return null;
        const site = new URL(siteBaseUrl);
        if (url.origin !== site.origin) return null;
        const repoPrefix = site.pathname.endsWith('/') ? site.pathname : site.pathname + '/';
        if (!url.pathname.startsWith(repoPrefix)) return null;
        const relative = url.pathname.slice(repoPrefix.length);
        resolvedPath = relative || 'welcome.html';
      } catch (_err) {
        return null;
      }
    } else if (clean.startsWith('/')) {
      resolvedPath = clean.replace(/^\/+/, '');
      if (siteBaseUrl) {
        try {
          const site = new URL(siteBaseUrl);
          const repoPrefix = site.pathname.replace(/^\/+/, '').replace(/\/+$/, '');
          if (resolvedPath.startsWith(repoPrefix + '/')) {
            resolvedPath = resolvedPath.slice(repoPrefix.length + 1);
          }
        } catch (_err) {
          // no-op
        }
      }
    } else {
      const fromParts = fromPagePath.split('/');
      fromParts.pop();
      const hrefParts = clean.split('/');
      for (const part of hrefParts) {
        if (!part || part === '.') continue;
        if (part === '..') {
          if (fromParts.length) fromParts.pop();
        } else {
          fromParts.push(part);
        }
      }
      resolvedPath = fromParts.join('/');
    }

    if (!resolvedPath) return null;
    resolvedPath = resolvedPath.split('?')[0].split('#')[0];
    if (!resolvedPath) return null;
    return resolvedPath;
  }

  async function checkLinkIntegrity(pageDocs, options) {
    const issues = [];
    let checksRun = 0;
    const siteBaseUrl = options.site_base_url;
    const mode = options.mode || 'ci';

    for (const doc of pageDocs) {
      const links = extractAllLinks(doc.html || '');
      for (const link of links) {
        const target = resolveInternalTarget(doc.path, link.href, siteBaseUrl);
        if (!target) continue;
        checksRun += 1;

        let ok = false;
        let statusCode = 'n/a';

        if (typeof options.resolve_internal_path_status === 'function') {
          const status = await options.resolve_internal_path_status(target);
          ok = !!(status && status.ok);
          statusCode = status && status.status != null ? status.status : statusCode;
        }

        if (!ok) {
          issues.push({
            page: doc.path,
            severity: 'error',
            message: 'Broken internal link',
            context: "Link text: '" + link.text + "', target: '" + link.href + "'",
            link_text: link.text,
            link_target: link.href,
            resolved_target: target,
            status_code: statusCode
          });
        }
      }

      const githubLink = links.find(link => /github\.com\/rmallorybpc\/nhl-free-agency-research/i.test(link.href || ''));
      checksRun += 1;
      if (!githubLink) {
        issues.push({
          page: doc.path,
          severity: 'error',
          message: 'Footer GitHub link missing from link integrity scan',
          context: 'Expected a repository link in page footer.'
        });
      } else if (typeof options.resolve_external_url_status === 'function') {
        const extStatus = await options.resolve_external_url_status(githubLink.href);
        if (!extStatus || !extStatus.ok) {
          issues.push({
            page: doc.path,
            severity: 'error',
            message: 'Footer GitHub link unreachable',
            context: "Target '" + githubLink.href + "' returned status " + (extStatus && extStatus.status != null ? extStatus.status : 'unknown') + '.'
          });
        }
      } else if (mode === 'live') {
        issues.push({
          page: doc.path,
          severity: 'info',
          message: 'Footer GitHub link reachability not available in live mode',
          context: 'Browser live audits may be blocked from cross-origin status checks by CORS.'
        });
      }
    }

    return makeCategory('Link integrity', checksRun, issues);
  }

  function checkLoadingRemnants(pageDocs, options) {
    const issues = [];
    let checksRun = 0;
    const loadingRegex = /loading(?:\s+[a-z]+)?\.{0,3}/gi;

    for (const doc of pageDocs) {
      checksRun += 1;
      const visible = htmlToVisibleText(doc.html || '');
      const matches = visible.match(loadingRegex) || [];

      if (matches.length) {
        for (const snippet of matches.slice(0, 5)) {
          issues.push({
            page: doc.path,
            severity: options.mode === 'live' ? 'warning' : 'warning',
            message: "Loading placeholder text detected: '" + snippet + "'",
            context: options.mode === 'live'
              ? 'Placeholder remained in fetched page HTML during live audit.'
              : 'CI mode checks static HTML and cannot fully verify post-render replacement.'
          });
        }
      }
    }

    return makeCategory('Loading state remnants', checksRun, issues, [
      options.mode === 'live'
        ? 'Live mode inspects fetched HTML source and may miss client-side post-render removals.'
        : 'Static CI mode cannot execute dashboard JavaScript.'
    ]);
  }

  function checkDataFreshness(fileStats, nowIso, mode) {
    const issues = [];
    let checksRun = 0;
    const notes = [];

    if (mode === 'live') {
      for (const file of DATA_FRESHNESS_FILES) {
        checksRun += 1;
        issues.push({
          page: file,
          severity: 'info',
          message: 'Not available in live mode',
          context: 'Browser runtime cannot read repository file modification timestamps.'
        });
      }
      return makeCategory('Data freshness', checksRun, issues, notes);
    }

    const now = new Date(nowIso || new Date().toISOString());

    for (const file of DATA_FRESHNESS_FILES) {
      checksRun += 1;
      const stat = fileStats && fileStats[file];
      if (!stat || !stat.mtime) {
        issues.push({
          page: file,
          severity: 'error',
          message: 'Missing file metadata',
          context: 'Could not read last modified timestamp.'
        });
        continue;
      }

      const modified = new Date(stat.mtime);
      const ageDays = Math.floor((now.getTime() - modified.getTime()) / (1000 * 60 * 60 * 24));
      if (ageDays > STALE_DAYS) {
        issues.push({
          page: file,
          severity: 'warning',
          message: 'File may be stale (older than 6 months)',
          context: 'Last modified ' + modified.toISOString().slice(0, 10) + ' (' + ageDays + ' days old).'
        });
      }
    }

    notes.push('Staleness threshold: ' + STALE_DAYS + ' days.');
    return makeCategory('Data freshness', checksRun, issues, notes);
  }

  function checkEdgeCases(pageDocs) {
    const issues = [];
    let checksRun = 0;

    const byPath = {};
    for (const doc of pageDocs) byPath[doc.path] = doc;

    const teamHtml = (byPath['team.html'] && byPath['team.html'].html) || '';
    const explorerHtml = (byPath['explorer.html'] && byPath['explorer.html'].html) || '';
    const indexHtml = (byPath['index.html'] && byPath['index.html'].html) || '';

    const tests = [
      {
        url: '/team.html',
        expected: 'Prompt to select a team and season.',
        pass: /Select a team and season/i.test(teamHtml),
        actual: /Select a team and season/i.test(teamHtml)
          ? 'Selection prompt text found in template/script.'
          : 'Selection prompt text not found.'
      },
      {
        url: '/team.html?team=NONEXISTENT&season=2025',
        expected: 'Graceful invalid-team handling.',
        pass: /No data for selected team-season/i.test(teamHtml),
        actual: /No data for selected team-season/i.test(teamHtml)
          ? 'Invalid team fallback message found.'
          : 'No explicit invalid team fallback found.'
      },
      {
        url: '/team.html?team=BOS&season=2017',
        expected: 'Graceful out-of-scope season handling.',
        pass: /No data for selected team-season/i.test(teamHtml),
        actual: /No data for selected team-season/i.test(teamHtml)
          ? 'Out-of-scope fallback message found.'
          : 'No explicit out-of-scope fallback found.'
      },
      {
        url: '/explorer.html (filters yielding zero results)',
        expected: 'Clear zero-result empty state.',
        pass: /No signings match these filters/i.test(explorerHtml),
        actual: /No signings match these filters/i.test(explorerHtml)
          ? 'Zero-result message found.'
          : 'Zero-result message not found.'
      },
      {
        url: '/index.html (earliest available season)',
        expected: 'Page renders with season selector and data hooks.',
        pass: /initSeasonSelector\(/.test(indexHtml) && /seasonSelect/.test(indexHtml),
        actual: /initSeasonSelector\(/.test(indexHtml) && /seasonSelect/.test(indexHtml)
          ? 'Season selector initialization present.'
          : 'Could not confirm earliest-season render path.'
      }
    ];

    for (const test of tests) {
      checksRun += 1;
      if (!test.pass) {
        issues.push({
          page: test.url,
          severity: 'warning',
          message: 'Edge case behavior may not be graceful',
          context: 'Expected: ' + test.expected + ' | Actual: ' + test.actual
        });
      }
    }

    return makeCategory('Empty state and edge case handling', checksRun, issues);
  }

  function checkPageStructure(pageDocs) {
    const issues = [];
    let checksRun = 0;
    const titleMap = {};

    for (const doc of pageDocs) {
      const html = doc.html || '';
      const title = extractTitle(html);
      const metaDescription = extractMetaDescription(html);

      checksRun += 1;
      if (!title) {
        issues.push({
          page: doc.path,
          severity: 'error',
          message: 'Missing page title',
          context: 'Each page should define a unique <title>.'
        });
      } else if (titleMap[title]) {
        issues.push({
          page: doc.path,
          severity: 'warning',
          message: 'Duplicate page title',
          context: "Title duplicates " + titleMap[title] + "."
        });
      } else {
        titleMap[title] = doc.path;
      }

      checksRun += 1;
      if (!metaDescription) {
        issues.push({
          page: doc.path,
          severity: 'error',
          message: 'Missing meta description',
          context: 'Add <meta name="description" ...> for page context.'
        });
      }

      checksRun += 1;
      const navLinks = extractNavLinks(html);
      const missingNav = NAV_EXPECTED.filter(expected => !navLinks.includes(expected));
      if (missingNav.length) {
        issues.push({
          page: doc.path,
          severity: 'error',
          message: 'Navigation links missing expected pages',
          context: 'Missing: ' + missingNav.join(', ')
        });
      }

      checksRun += 1;
      if (!/TMG Tool Suite/i.test(html) || !/NHL Analysis/i.test(html)) {
        issues.push({
          page: doc.path,
          severity: 'error',
          message: 'TMG Tool Suite dropdown incomplete',
          context: 'Dropdown button and NHL Analysis link should both be present.'
        });
      }

      checksRun += 1;
      if (!hasActivePage(html)) {
        issues.push({
          page: doc.path,
          severity: 'warning',
          message: 'Active page marker missing',
          context: 'One nav link should set aria-current="page".'
        });
      }

      checksRun += 1;
      if (!hasFooterGithubLink(html)) {
        issues.push({
          page: doc.path,
          severity: 'error',
          message: 'Footer GitHub link missing',
          context: 'Footer should include repository link for transparency.'
        });
      }

      checksRun += 1;
      if (!hasTmgWrapper(html)) {
        issues.push({
          page: doc.path,
          severity: 'error',
          message: 'Missing tmg-page or tmg-container wrapper',
          context: 'Main content should be wrapped in tmg-page and tmg-container classes.'
        });
      }
    }

    return makeCategory('Page structure integrity', checksRun, issues);
  }

  function parseCsv(text) {
    const rows = [];
    let row = [];
    let value = '';
    let inQuotes = false;

    for (let i = 0; i < text.length; i += 1) {
      const ch = text[i];
      const next = text[i + 1];
      if (ch === '"') {
        if (inQuotes && next === '"') {
          value += '"';
          i += 1;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (ch === ',' && !inQuotes) {
        row.push(value);
        value = '';
        continue;
      }
      if ((ch === '\n' || ch === '\r') && !inQuotes) {
        if (ch === '\r' && next === '\n') i += 1;
        row.push(value);
        value = '';
        if (row.length > 1 || row[0] !== '') rows.push(row);
        row = [];
        continue;
      }
      value += ch;
    }
    if (value !== '' || row.length) {
      row.push(value);
      rows.push(row);
    }
    if (!rows.length) return { headers: [], records: [] };

    const headers = rows[0].map(h => String(h || '').trim());
    const records = rows.slice(1).map(cols => {
      const rec = {};
      headers.forEach((h, i) => {
        rec[h] = cols[i] != null ? String(cols[i]).trim() : '';
      });
      return rec;
    });
    return { headers: headers, records: records };
  }

  function isBlank(value) {
    if (value == null) return true;
    const v = String(value).trim();
    return !v || v.toLowerCase() === 'na' || v.toLowerCase() === 'null' || v.toLowerCase() === 'undefined';
  }

  function checkCsvIntegrity(csvMap, mode) {
    const issues = [];
    let checksRun = 0;
    const notes = [];

    for (const cfg of CSV_EXPECTATIONS) {
      checksRun += 1;
      const text = csvMap && csvMap[cfg.file];
      if (!text) {
        issues.push({
          page: cfg.file,
          severity: mode === 'live' ? 'info' : 'error',
          message: mode === 'live' ? 'CSV check not available in live mode for this file' : 'CSV file missing',
          context: mode === 'live' ? 'Live mode may be blocked by CORS or unavailable URL.' : 'Expected file could not be loaded.'
        });
        continue;
      }

      const parsed = parseCsv(text);
      const rowCount = parsed.records.length;
      if (rowCount !== cfg.expected_rows) {
        issues.push({
          page: cfg.file,
          severity: 'warning',
          message: 'Row count mismatch',
          context: 'Expected ' + cfg.expected_rows + ', found ' + rowCount + '.'
        });
      }

      for (const col of cfg.key_columns) {
        checksRun += 1;
        if (!parsed.headers.includes(col)) {
          issues.push({
            page: cfg.file,
            severity: 'error',
            message: "Missing key column '" + col + "'",
            context: 'Key columns are required for downstream analysis and dashboard rendering.'
          });
          continue;
        }

        const missing = parsed.records.reduce((sum, rec) => sum + (isBlank(rec[col]) ? 1 : 0), 0);
        if (missing > 0) {
          issues.push({
            page: cfg.file,
            severity: 'warning',
            message: "Missing values found in key column '" + col + "'",
            context: missing + ' rows are blank/NA in key column.'
          });
        }
      }

      checksRun += 1;
      const yearCol = parsed.headers.includes('spotrac_year')
        ? 'spotrac_year'
        : parsed.headers.includes('season_year')
          ? 'season_year'
          : null;

      if (yearCol) {
        const years = parsed.records
          .map(rec => Number(rec[yearCol]))
          .filter(n => Number.isFinite(n));
        if (years.length) {
          const minYear = Math.min.apply(null, years);
          const maxYear = Math.max.apply(null, years);
          if (minYear < 2017 || maxYear > 2025) {
            issues.push({
              page: cfg.file,
              severity: 'warning',
              message: 'Year range outside documented 2017-2025 window',
              context: 'Found years ' + minYear + '-' + maxYear + '.'
            });
          }
        }
      }
    }

    notes.push('Expected row counts are based on current project documentation and v1 audit baseline.');
    return makeCategory('CSV data integrity', checksRun, issues, notes);
  }

  async function runAudit(options) {
    const mode = options.mode || 'ci';
    const pageDocs = options.page_docs || [];
    const onProgress = typeof options.on_progress === 'function' ? options.on_progress : null;

    const categories = [];
    const steps = [
      { name: 'Plain language compliance', run: () => Promise.resolve(checkPlainLanguage(pageDocs)) },
      { name: 'Link integrity', run: () => checkLinkIntegrity(pageDocs, options) },
      { name: 'Loading state remnants', run: () => Promise.resolve(checkLoadingRemnants(pageDocs, options)) },
      { name: 'Data freshness', run: () => Promise.resolve(checkDataFreshness(options.file_stats || {}, options.now_iso, mode)) },
      { name: 'Empty state and edge case handling', run: () => Promise.resolve(checkEdgeCases(pageDocs)) },
      { name: 'Page structure integrity', run: () => Promise.resolve(checkPageStructure(pageDocs)) },
      { name: 'CSV data integrity', run: () => Promise.resolve(checkCsvIntegrity(options.csv_map || {}, mode)) }
    ];

    for (let i = 0; i < steps.length; i += 1) {
      const step = steps[i];
      if (onProgress) {
        onProgress({
          category: step.name,
          status: 'running',
          index: i + 1,
          total: steps.length
        });
      }

      const categoryResult = await step.run();
      categories.push(categoryResult);

      if (onProgress) {
        onProgress({
          category: step.name,
          status: 'completed',
          index: i + 1,
          total: steps.length,
          category_result: categoryResult
        });
      }
    }

    const report = {
      audit_timestamp: options.now_iso || new Date().toISOString(),
      audit_version: AUDIT_VERSION,
      site_base_url: options.site_base_url || '',
      mode: mode,
      summary: summarize(categories),
      categories: categories
    };

    return report;
  }

  return {
    AUDIT_VERSION: AUDIT_VERSION,
    PAGE_PATHS: PAGE_PATHS,
    MAIN_PAGE_PATHS: MAIN_PAGE_PATHS,
    DATA_FRESHNESS_FILES: DATA_FRESHNESS_FILES,
    CSV_EXPECTATIONS: CSV_EXPECTATIONS,
    runAudit: runAudit,
    htmlToVisibleText: htmlToVisibleText,
    extractAllLinks: extractAllLinks,
    resolveInternalTarget: resolveInternalTarget
  };
});
