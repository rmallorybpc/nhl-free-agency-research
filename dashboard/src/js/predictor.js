(function () {
  'use strict';

  const DEFAULT_BASE = '/nhl-free-agency-research';
  const FALLBACK_RESIDUAL_SE = 0.057;

  function getPathPrefix() {
    const marker = '/dashboard/src/';
    const idx = window.location.pathname.indexOf(marker);
    if (idx === -1) return '';
    return window.location.pathname.slice(0, idx);
  }

  function fetchTextWithFallback(basePath) {
    const suffixMarker = '/output/tables/';
    const suffixIdx = basePath.indexOf(suffixMarker);
    const suffix = suffixIdx >= 0 ? basePath.slice(suffixIdx + suffixMarker.length) : '';
    const pathPrefix = getPathPrefix();

    const candidatePaths = [basePath];
    if (suffix) {
      candidatePaths.push(`${pathPrefix}/output/tables/${suffix}`);
      candidatePaths.push(`/output/tables/${suffix}`);
      candidatePaths.push(`../../output/tables/${suffix}`);
      candidatePaths.push(`./../../output/tables/${suffix}`);
      candidatePaths.push(`../output/tables/${suffix}`);
      candidatePaths.push(`./output/tables/${suffix}`);
      candidatePaths.push(`${pathPrefix}/dashboard/src/data/${suffix}`);
      candidatePaths.push(`/dashboard/src/data/${suffix}`);
      candidatePaths.push(`../../dashboard/src/data/${suffix}`);
      candidatePaths.push(`./../../dashboard/src/data/${suffix}`);
      candidatePaths.push(`./data/${suffix}`);
      candidatePaths.push(`data/${suffix}`);
      candidatePaths.push(`../data/${suffix}`);
      candidatePaths.push(`../../data/${suffix}`);
    }

    const uniquePaths = [...new Set(candidatePaths.filter(Boolean))];

    return uniquePaths.reduce((chain, path) => {
      return chain.catch(errs => {
        return fetch(path).then(resp => {
          if (resp.ok) return resp.text();
          return Promise.reject([...errs, { path, status: resp.status }]);
        }).catch(fetchErr => {
          if (Array.isArray(fetchErr)) throw fetchErr;
          return Promise.reject([...errs, { path, status: 'network_error' }]);
        });
      });
    }, Promise.reject([])).catch(errs => {
      const detail = errs.map(e => `${e.path} (${e.status})`).join(' and ');
      throw new Error(`Failed to load ${detail}`);
    });
  }

  function parseCSVLine(line) {
    const cols = [];
    let cur = '';
    let inQuotes = false;

    for (let i = 0; i < line.length; i += 1) {
      const ch = line[i];
      const next = line[i + 1];

      if (ch === '"') {
        if (inQuotes && next === '"') {
          cur += '"';
          i += 1;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch === ',' && !inQuotes) {
        cols.push(cur);
        cur = '';
      } else {
        cur += ch;
      }
    }

    cols.push(cur);
    return cols;
  }

  function parseCSV(text) {
    const lines = String(text || '').trim().split(/\r?\n/);
    if (lines.length < 2) return [];

    const headers = parseCSVLine(lines[0]).map(h => h.replace(/^\uFEFF/, '').trim());

    return lines.slice(1).filter(line => line.trim()).map(line => {
      const cols = parseCSVLine(line);
      const row = {};

      headers.forEach((header, idx) => {
        row[header] = (cols[idx] || '').trim();
      });

      return row;
    });
  }

  function toNum(value, fallback = NaN) {
    const n = Number(value);
    return Number.isFinite(n) ? n : fallback;
  }

  function clamp01(value) {
    if (!Number.isFinite(value)) return value;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  const predictor = {
    coefficients: null,

    async loadCoefficients(options) {
      if (this.coefficients) return this.coefficients;

      const base = options && options.base ? options.base : DEFAULT_BASE;
      const text = await fetchTextWithFallback(`${base}/output/tables/model_b_full_coefficients.csv`);
      const parsed = parseCSV(text);

      const interceptRow = parsed.find(r => r.term === '(Intercept)');
      const meanReversionRow = parsed.find(r => r.term === 'prior_season_points_pct');

      const intercept = toNum(interceptRow && interceptRow.estimate);
      const meanReversion = toNum(meanReversionRow && meanReversionRow.estimate);

      if (!Number.isFinite(intercept) || !Number.isFinite(meanReversion)) {
        throw new Error('Model B coefficients are missing required terms.');
      }

      this.coefficients = {
        intercept,
        meanReversion,
        coefficientStdError: toNum(meanReversionRow && (meanReversionRow.std_error || meanReversionRow['std.error'])),
        residualSE: FALLBACK_RESIDUAL_SE
      };

      return this.coefficients;
    },

    predict(currentPointsPct) {
      if (!this.coefficients) {
        throw new Error('Predictor coefficients not loaded.');
      }

      const current = Number(currentPointsPct);
      if (!Number.isFinite(current)) {
        throw new Error('Current points percentage must be numeric.');
      }

      const predictedRaw = this.coefficients.intercept + (1 + this.coefficients.meanReversion) * current;
      const ci95HalfWidth = 1.96 * this.coefficients.residualSE;

      const predicted = clamp01(predictedRaw);
      const lower = clamp01(predictedRaw - ci95HalfWidth);
      const upper = clamp01(predictedRaw + ci95HalfWidth);
      const change = predicted - current;

      return {
        current,
        predicted,
        lower,
        upper,
        change,
        ci95HalfWidth,
        expectedPoints: Math.round(predicted * 164),
        expectedPointsLow: Math.round(lower * 164),
        expectedPointsHigh: Math.round(upper * 164)
      };
    }
  };

  window.NHLPredictor = predictor;
})();
