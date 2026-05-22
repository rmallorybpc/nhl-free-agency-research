(function () {
  "use strict";

  const container = document.getElementById("ufaSpendChartCard");
  if (!container) {
    return;
  }

  const DATA_URL = "./data/team_seasons.json";
  const COVID_SEASONS = new Set([2020, 2021]);
  const DATA_FOLDER_LINK = "../../data/";
  const REPO_DATA_LINK = "https://github.com/rmallorybpc/nhl-free-agency-research/tree/main/data";

  function normalCdf(x) {
    const t = 1 / (1 + 0.2316419 * Math.abs(x));
    const d = 0.3989423 * Math.exp((-x * x) / 2);
    let p = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))));
    if (x > 0) {
      p = 1 - p;
    }
    return p;
  }

  function formatNum(value, digits) {
    if (!Number.isFinite(value)) {
      return "n/a";
    }
    return value.toFixed(digits);
  }

  function formatPValue(pValue) {
    if (!Number.isFinite(pValue)) {
      return "n/a";
    }
    if (pValue < 0.001) {
      return "< 0.001";
    }
    return pValue.toFixed(3);
  }

  function mean(values) {
    if (!values.length) {
      return 0;
    }
    return values.reduce(function (sum, v) { return sum + v; }, 0) / values.length;
  }

  function asNumber(value) {
    const n = Number(value);
    return Number.isFinite(n) ? n : null;
  }

  function transpose(matrix) {
    return matrix[0].map(function (_, colIndex) {
      return matrix.map(function (row) { return row[colIndex]; });
    });
  }

  function multiplyMatrices(a, b) {
    const rows = a.length;
    const cols = b[0].length;
    const inner = b.length;
    const out = Array.from({ length: rows }, function () { return Array(cols).fill(0); });

    for (let i = 0; i < rows; i += 1) {
      for (let k = 0; k < inner; k += 1) {
        for (let j = 0; j < cols; j += 1) {
          out[i][j] += a[i][k] * b[k][j];
        }
      }
    }

    return out;
  }

  function invertMatrix(matrix) {
    const n = matrix.length;
    const augmented = matrix.map(function (row, i) {
      const identity = Array.from({ length: n }, function (_, j) { return (i === j ? 1 : 0); });
      return row.slice().concat(identity);
    });

    for (let i = 0; i < n; i += 1) {
      let pivot = augmented[i][i];
      if (Math.abs(pivot) < 1e-12) {
        let swapRow = -1;
        for (let r = i + 1; r < n; r += 1) {
          if (Math.abs(augmented[r][i]) > 1e-12) {
            swapRow = r;
            break;
          }
        }
        if (swapRow === -1) {
          return null;
        }
        const tmp = augmented[i];
        augmented[i] = augmented[swapRow];
        augmented[swapRow] = tmp;
        pivot = augmented[i][i];
      }

      for (let c = 0; c < 2 * n; c += 1) {
        augmented[i][c] /= pivot;
      }

      for (let r = 0; r < n; r += 1) {
        if (r === i) {
          continue;
        }
        const factor = augmented[r][i];
        for (let c = 0; c < 2 * n; c += 1) {
          augmented[r][c] -= factor * augmented[i][c];
        }
      }
    }

    return augmented.map(function (row) { return row.slice(n); });
  }

  function makeGrid(minX, maxX, count) {
    if (count <= 1 || minX === maxX) {
      return [minX];
    }
    const out = [];
    const step = (maxX - minX) / (count - 1);
    for (let i = 0; i < count; i += 1) {
      out.push(minX + i * step);
    }
    return out;
  }

  function olsSimple(x, y) {
    const n = x.length;
    if (n < 3) {
      return null;
    }

    const xBar = mean(x);
    const yBar = mean(y);

    let sxx = 0;
    let sxy = 0;
    let tss = 0;

    for (let i = 0; i < n; i += 1) {
      const dx = x[i] - xBar;
      sxx += dx * dx;
      sxy += dx * (y[i] - yBar);
      tss += (y[i] - yBar) * (y[i] - yBar);
    }

    if (sxx <= 0) {
      return null;
    }

    const slope = sxy / sxx;
    const intercept = yBar - slope * xBar;

    let rss = 0;
    for (let i = 0; i < n; i += 1) {
      const resid = y[i] - (intercept + slope * x[i]);
      rss += resid * resid;
    }

    const dof = n - 2;
    if (dof <= 0) {
      return null;
    }

    const sigma2 = rss / dof;
    const seSlope = Math.sqrt(sigma2 / sxx);
    const tStat = slope / seSlope;
    const pValue = 2 * (1 - normalCdf(Math.abs(tStat)));
    const r2 = tss > 0 ? 1 - (rss / tss) : 0;

    return {
      n: n,
      dof: dof,
      xBar: xBar,
      sxx: sxx,
      slope: slope,
      intercept: intercept,
      sigma2: sigma2,
      pValue: pValue,
      r2: r2,
    };
  }

  function olsMultiple(xMatrix, yVector) {
    const n = xMatrix.length;
    const p = xMatrix[0] ? xMatrix[0].length : 0;
    if (n < 4 || p < 2 || n <= p) {
      return null;
    }

    const y = yVector.map(function (v) { return [v]; });
    const xt = transpose(xMatrix);
    const xtx = multiplyMatrices(xt, xMatrix);

    for (let i = 0; i < xtx.length; i += 1) {
      xtx[i][i] += 1e-10;
    }

    const xtxInv = invertMatrix(xtx);
    if (!xtxInv) {
      return null;
    }

    const xty = multiplyMatrices(xt, y);
    const betaMatrix = multiplyMatrices(xtxInv, xty);
    const beta = betaMatrix.map(function (row) { return row[0]; });

    const fitted = xMatrix.map(function (row) {
      return row.reduce(function (sum, value, idx) {
        return sum + value * beta[idx];
      }, 0);
    });

    const yBar = mean(yVector);
    let rss = 0;
    let tss = 0;
    for (let i = 0; i < n; i += 1) {
      const resid = yVector[i] - fitted[i];
      rss += resid * resid;
      tss += (yVector[i] - yBar) * (yVector[i] - yBar);
    }

    const dof = n - p;
    if (dof <= 0) {
      return null;
    }

    const sigma2 = rss / dof;
    const vcov = xtxInv.map(function (row) {
      return row.map(function (value) { return value * sigma2; });
    });

    const se = vcov.map(function (row, i) {
      return Math.sqrt(Math.max(row[i], 0));
    });

    const tStats = beta.map(function (coef, i) {
      return se[i] > 0 ? coef / se[i] : NaN;
    });

    const pValues = tStats.map(function (t) {
      return Number.isFinite(t) ? 2 * (1 - normalCdf(Math.abs(t))) : NaN;
    });

    const r2 = tss > 0 ? 1 - (rss / tss) : 0;

    return {
      n: n,
      p: p,
      dof: dof,
      beta: beta,
      se: se,
      pValues: pValues,
      sigma2: sigma2,
      vcov: vcov,
      r2: r2,
    };
  }

  function predictBandSimple(fit, xGrid) {
    const sigma = Math.sqrt(fit.sigma2);
    const yFit = [];
    const yUpper = [];
    const yLower = [];

    for (let i = 0; i < xGrid.length; i += 1) {
      const x0 = xGrid[i];
      const y0 = fit.intercept + fit.slope * x0;
      const seMean = sigma * Math.sqrt((1 / fit.n) + ((x0 - fit.xBar) * (x0 - fit.xBar)) / fit.sxx);
      const margin = 1.96 * seMean;
      yFit.push(y0);
      yUpper.push(y0 + margin);
      yLower.push(y0 - margin);
    }

    return { yFit: yFit, yUpper: yUpper, yLower: yLower };
  }

  function predictBandMultiple(model, xGrid, priorMean) {
    const yFit = [];
    const yUpper = [];
    const yLower = [];

    for (let i = 0; i < xGrid.length; i += 1) {
      const x0 = xGrid[i];
      const v = [1, x0, priorMean];
      const y0 = model.beta[0] + model.beta[1] * x0 + model.beta[2] * priorMean;

      let varMean = 0;
      for (let r = 0; r < v.length; r += 1) {
        for (let c = 0; c < v.length; c += 1) {
          varMean += v[r] * model.vcov[r][c] * v[c];
        }
      }
      const margin = 1.96 * Math.sqrt(Math.max(varMean, 0));

      yFit.push(y0);
      yUpper.push(y0 + margin);
      yLower.push(y0 - margin);
    }

    return { yFit: yFit, yUpper: yUpper, yLower: yLower };
  }

  function xFromRow(row, axisChoice) {
    if (axisChoice === "log") {
      return Math.log(row.ufa_spend + 1);
    }
    if (axisChoice === "mis") {
      return row.MIS;
    }
    return row.ufa_spend;
  }

  function axisLabel(axisChoice) {
    if (axisChoice === "log") {
      return "Log Total UFA spend";
    }
    if (axisChoice === "mis") {
      return "MIS";
    }
    return "Total UFA spend ($M)";
  }

  function buildUI() {
    container.innerHTML = [
      '<section class="tmg-card-wide ufa-spend-wrap" aria-label="UFA spending versus next-season change chart">',
      '  <h2 class="tmg-h2">UFA Spending vs Next-Season Change</h2>',
      '  <div class="ufa-spend-controls" role="group" aria-label="UFA spending chart controls">',
      '    <label class="ufa-spend-check">',
      '      <input type="checkbox" id="ufaExcludeCovid" aria-label="Exclude COVID seasons 2020 and 2021">',
      '      Exclude COVID seasons (2020, 2021)',
      '    </label>',
      '    <label class="ufa-spend-check">',
      '      <input type="checkbox" id="ufaControlPrior" aria-label="Control for prior finish">',
      '      Control for prior finish',
      '    </label>',
      '    <fieldset class="ufa-spend-radio" aria-label="X axis">',
      '      <legend>X axis</legend>',
      '      <label><input type="radio" name="ufaXAxis" value="total" checked> Total UFA $ (default)</label>',
      '      <label><input type="radio" name="ufaXAxis" value="log"> Log(UFA $)</label>',
      '      <label><input type="radio" name="ufaXAxis" value="mis"> MIS</label>',
      '    </fieldset>',
      '    <button id="ufaDownloadPng" type="button" class="tmg-btn-ghost" aria-label="Download chart as PNG">Download PNG</button>',
      '  </div>',
      '  <div class="ufa-spend-stats" id="ufaStats" aria-live="polite">',
      '    <span><strong>Slope (ufa_spend):</strong> <span id="ufaSlope">n/a</span></span>',
      '    <span><strong>p ≈</strong> <span id="ufaPValue">n/a</span></span>',
      '    <span><strong>N =</strong> <span id="ufaN">0</span></span>',
      '    <span><strong>R²:</strong> <span id="ufaR2">n/a</span></span>',
      '  </div>',
      '  <div id="ufaSpendStatus" class="ufa-spend-status" role="status">Loading team-season data...</div>',
      '  <div id="ufaSpendError" class="ufa-spend-error" role="alert" hidden></div>',
      '  <div id="ufaSpendPlot" class="ufa-spend-plot" role="img" aria-label="Scatter plot of UFA spending versus next-season performance change"></div>',
      '  <p class="tmg-body ufa-spend-caption" id="ufaSpendCaption">Awaiting data.</p>',
      '  <p class="tmg-body" style="margin-bottom:0;">',
      '    <a href="./methods.html#regression-specs">View regression specs</a>',
      '    &nbsp;·&nbsp;',
      '    <a href="./audit.html">Audit reproducibility checks</a>',
      '  </p>',
      '</section>'
    ].join("\n");
  }

  function normalizeRows(rows) {
    return rows
      .map(function (row) {
        const season = asNumber(row.season);
        const team = String(row.team || "").trim();
        const ufaSpend = asNumber(row.ufa_spend);
        const delta = asNumber(row.delta_performance);
        const prior = asNumber(row.prior_finish);
        const mis = asNumber(row.MIS);

        if (!team || season === null || delta === null || prior === null || ufaSpend === null) {
          return null;
        }

        return {
          season: season,
          team: team,
          ufa_spend: Math.max(0, ufaSpend),
          delta_performance: delta,
          prior_finish: prior,
          MIS: mis === null ? 0 : mis,
        };
      })
      .filter(function (row) { return row !== null; });
  }

  function showError(message) {
    const errorNode = document.getElementById("ufaSpendError");
    const statusNode = document.getElementById("ufaSpendStatus");
    if (statusNode) {
      statusNode.textContent = "";
    }
    if (errorNode) {
      errorNode.hidden = false;
      errorNode.innerHTML = message;
    }
  }

  function clearError() {
    const errorNode = document.getElementById("ufaSpendError");
    const statusNode = document.getElementById("ufaSpendStatus");
    if (errorNode) {
      errorNode.hidden = true;
      errorNode.textContent = "";
    }
    if (statusNode) {
      statusNode.textContent = "";
    }
  }

  function setSummary(slope, pValue, n, r2, controlled) {
    document.getElementById("ufaSlope").textContent = formatNum(slope, 3);
    document.getElementById("ufaPValue").textContent = formatPValue(pValue);
    document.getElementById("ufaN").textContent = String(n);
    document.getElementById("ufaR2").textContent = formatNum(r2, 3);

    const caption = document.getElementById("ufaSpendCaption");
    const controlText = controlled ? " with prior finish control" : "";
    caption.textContent =
      "Current view slope is " + formatNum(slope, 3) +
      ", p ≈ " + formatPValue(pValue) +
      ", N = " + n +
      " (R² = " + formatNum(r2, 3) + ")" + controlText + ".";
  }

  function getState() {
    const axisNode = document.querySelector('input[name="ufaXAxis"]:checked');
    return {
      excludeCovid: document.getElementById("ufaExcludeCovid").checked,
      controlPrior: document.getElementById("ufaControlPrior").checked,
      axisChoice: axisNode ? axisNode.value : "total",
    };
  }

  function renderInsufficient(axisChoice, n) {
    Plotly.react("ufaSpendPlot", [], {
      paper_bgcolor: "#ffffff",
      plot_bgcolor: "#ffffff",
      margin: { l: 70, r: 20, t: 20, b: 65 },
      xaxis: { title: { text: axisLabel(axisChoice) } },
      yaxis: { title: { text: "Next-season change (delta metric)" } },
      annotations: [{
        text: "Insufficient data for regression",
        x: 0.5,
        y: 0.5,
        xref: "paper",
        yref: "paper",
        showarrow: false,
      }],
    }, { responsive: true, displayModeBar: false });

    document.getElementById("ufaSlope").textContent = "n/a";
    document.getElementById("ufaPValue").textContent = "n/a";
    document.getElementById("ufaN").textContent = String(n);
    document.getElementById("ufaR2").textContent = "n/a";
    document.getElementById("ufaSpendCaption").textContent = "Insufficient data to estimate a stable regression in this view.";
  }

  function drawPlot(rows) {
    const state = getState();
    const filtered = rows.filter(function (row) {
      return !(state.excludeCovid && COVID_SEASONS.has(row.season));
    });

    if (filtered.length < 3) {
      renderInsufficient(state.axisChoice, filtered.length);
      return;
    }

    const xValues = filtered.map(function (row) {
      return xFromRow(row, state.axisChoice);
    });
    const yValues = filtered.map(function (row) {
      return row.delta_performance;
    });

    const minX = Math.min.apply(null, xValues);
    const maxX = Math.max.apply(null, xValues);
    const hasVariance = maxX > minX;

    if (!hasVariance) {
      renderInsufficient(state.axisChoice, filtered.length);
      return;
    }

    let slope = NaN;
    let pValue = NaN;
    let r2 = NaN;
    let yFit = [];
    let yUpper = [];
    let yLower = [];
    const xGrid = makeGrid(minX, maxX, 140);

    if (state.controlPrior) {
      const statsModelMatrix = filtered.map(function (row) {
        return [1, row.ufa_spend, row.prior_finish];
      });
      const statsModel = olsMultiple(statsModelMatrix, yValues);

      const plotModelMatrix = filtered.map(function (row, idx) {
        return [1, xValues[idx], row.prior_finish];
      });
      const plotModel = olsMultiple(plotModelMatrix, yValues);

      if (!statsModel || !plotModel) {
        renderInsufficient(state.axisChoice, filtered.length);
        return;
      }

      slope = statsModel.beta[1];
      pValue = statsModel.pValues[1];
      r2 = plotModel.r2;

      const priorMean = mean(filtered.map(function (row) { return row.prior_finish; }));
      const bands = predictBandMultiple(plotModel, xGrid, priorMean);
      yFit = bands.yFit;
      yUpper = bands.yUpper;
      yLower = bands.yLower;
    } else {
      const fit = olsSimple(xValues, yValues);
      if (!fit) {
        renderInsufficient(state.axisChoice, filtered.length);
        return;
      }
      slope = fit.slope;
      pValue = fit.pValue;
      r2 = fit.r2;

      const bands = predictBandSimple(fit, xGrid);
      yFit = bands.yFit;
      yUpper = bands.yUpper;
      yLower = bands.yLower;
    }

    const isMobile = window.innerWidth < 480;
    const hovertemplate = isMobile
      ? "<b>%{customdata[0]}</b><br>Season: %{customdata[1]}<br>x: %{x:.3f}<br>delta: %{y:.3f}<extra></extra>"
      : "<b>%{customdata[0]}</b><br>Season: %{customdata[1]}<br>UFA spend: $%{customdata[2]:.2f}M<br>MIS: %{customdata[3]:.2f}<br>Prior finish: %{customdata[4]:.3f}<br>Delta performance: %{customdata[5]:.3f}<extra></extra>";

    const pointTrace = {
      x: xValues,
      y: yValues,
      mode: "markers",
      type: "scatter",
      name: "Team-season",
      marker: {
        color: "rgba(52, 101, 164, 0.55)",
        size: isMobile ? 6 : 9,
        line: { color: "rgba(43, 82, 133, 0.85)", width: 0.5 },
      },
      customdata: filtered.map(function (row) {
        return [row.team, row.season, row.ufa_spend, row.MIS, row.prior_finish, row.delta_performance];
      }),
      hovertemplate: hovertemplate,
    };

    const upperTrace = {
      x: xGrid,
      y: yUpper,
      mode: "lines",
      line: { color: "rgba(170, 35, 54, 0)" },
      hoverinfo: "skip",
      showlegend: false,
      name: "95% CI",
    };

    const lowerTrace = {
      x: xGrid,
      y: yLower,
      mode: "lines",
      fill: "tonexty",
      fillcolor: "rgba(170, 35, 54, 0.15)",
      line: { color: "rgba(170, 35, 54, 0)" },
      hoverinfo: "skip",
      showlegend: false,
      name: "95% CI",
    };

    const lineTrace = {
      x: xGrid,
      y: yFit,
      mode: "lines",
      line: { color: "rgba(170, 35, 54, 0.95)", width: 3 },
      name: "Fitted line",
      hovertemplate: "Fit: %{y:.3f}<extra></extra>",
    };

    const layout = {
      margin: { l: 70, r: 20, t: 20, b: 70 },
      paper_bgcolor: "#ffffff",
      plot_bgcolor: "#ffffff",
      showlegend: false,
      xaxis: {
        title: { text: axisLabel(state.axisChoice) },
        zeroline: false,
        gridcolor: "rgba(0,0,0,0.08)",
      },
      yaxis: {
        title: { text: "Next-season change (delta metric)" },
        zeroline: true,
        zerolinecolor: "rgba(0,0,0,0.2)",
        gridcolor: "rgba(0,0,0,0.08)",
      },
    };

    Plotly.react("ufaSpendPlot", [upperTrace, lowerTrace, lineTrace, pointTrace], layout, {
      responsive: true,
      displayModeBar: false,
    });

    setSummary(slope, pValue, filtered.length, r2, state.controlPrior);
  }

  async function init() {
    buildUI();

    if (!window.Plotly) {
      showError("Plotly failed to load. Please refresh and try again.");
      return;
    }

    let parsedRows = [];
    try {
      const response = await fetch(DATA_URL, { cache: "no-store" });
      if (!response.ok) {
        throw new Error("HTTP " + response.status);
      }
      const raw = await response.json();
      parsedRows = normalizeRows(raw);
    } catch (error) {
      showError(
        "Could not load team-seasons data. Please check " +
        '<a href="' + DATA_FOLDER_LINK + '">/data/</a> or the ' +
        '<a href="' + REPO_DATA_LINK + '" target="_blank" rel="noopener noreferrer">GitHub repository data folder</a>. '
      );
      return;
    }

    if (!parsedRows.length) {
      showError(
        "Loaded the file, but no valid rows were found. Please validate team_seasons.json schema in " +
        '<a href="' + DATA_FOLDER_LINK + '">/data/</a>. '
      );
      return;
    }

    clearError();
    drawPlot(parsedRows);

    document.getElementById("ufaExcludeCovid").addEventListener("change", function () {
      drawPlot(parsedRows);
    });

    document.getElementById("ufaControlPrior").addEventListener("change", function () {
      drawPlot(parsedRows);
    });

    const axisInputs = document.querySelectorAll('input[name="ufaXAxis"]');
    axisInputs.forEach(function (input) {
      input.addEventListener("change", function () {
        drawPlot(parsedRows);
      });
    });

    document.getElementById("ufaDownloadPng").addEventListener("click", function () {
      Plotly.downloadImage("ufaSpendPlot", {
        format: "png",
        width: 1200,
        height: 720,
        filename: "ufa_spending_vs_next_season_change",
      });
    });

    window.addEventListener("resize", function () {
      Plotly.Plots.resize("ufaSpendPlot");
    });
  }

  init();
})();
