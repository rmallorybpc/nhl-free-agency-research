(function () {
  "use strict";

  const container = document.getElementById("meanReversionChartContainer");
  if (!container) {
    return;
  }

  const DATA_URL = "./data/team_seasons.json";
  const COVID_SEASONS = new Set([2020, 2021]);

  function normalCdf(x) {
    const t = 1 / (1 + 0.2316419 * Math.abs(x));
    const d = 0.3989423 * Math.exp((-x * x) / 2);
    let p = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))));
    if (x > 0) {
      p = 1 - p;
    }
    return p;
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
    return values.reduce(function (sum, v) { return sum + v; }, 0) / values.length;
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

  function transpose(matrix) {
    return matrix[0].map(function (_, colIndex) {
      return matrix.map(function (row) { return row[colIndex]; });
    });
  }

  function residualize(target, controls) {
    const y = target.map(function (v) { return [v]; });
    const Xt = transpose(controls);
    const XtX = multiplyMatrices(Xt, controls);

    // Add tiny ridge for numerical stability.
    for (let i = 0; i < XtX.length; i += 1) {
      XtX[i][i] += 1e-10;
    }

    const XtXInv = invertMatrix(XtX);
    if (!XtXInv) {
      return null;
    }

    const XtY = multiplyMatrices(Xt, y);
    const beta = multiplyMatrices(XtXInv, XtY);
    const fitted = multiplyMatrices(controls, beta).map(function (row) { return row[0]; });
    return target.map(function (v, idx) { return v - fitted[idx]; });
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
    for (let i = 0; i < n; i += 1) {
      const dx = x[i] - xBar;
      sxx += dx * dx;
      sxy += dx * (y[i] - yBar);
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
    const sigma2 = rss / dof;
    const seSlope = Math.sqrt(sigma2 / sxx);
    const tStat = slope / seSlope;
    const pValue = 2 * (1 - normalCdf(Math.abs(tStat)));

    return {
      n: n,
      xBar: xBar,
      sxx: sxx,
      slope: slope,
      intercept: intercept,
      sigma2: sigma2,
      pValue: pValue,
    };
  }

  function makeGrid(min, max, count) {
    const out = [];
    const step = (max - min) / (count - 1);
    for (let i = 0; i < count; i += 1) {
      out.push(min + i * step);
    }
    return out;
  }

  function buildUI() {
    container.innerHTML = [
      '<section class="tmg-card-wide mean-reversion-wrap" aria-label="Mean reversion chart">',
      '  <h2 class="tmg-h2">Mean reversion check</h2>',
      '  <div class="mean-reversion-controls" role="group" aria-label="Mean reversion controls">',
      '    <label class="mean-reversion-check">',
      '      <input type="checkbox" id="mrExcludeCovid" aria-label="Exclude COVID seasons 2020 and 2021">',
      '      Exclude COVID seasons (2020, 2021)',
      '    </label>',
      '    <fieldset class="mean-reversion-fit" aria-label="Fit type">',
      '      <legend>Fit type</legend>',
      '      <label><input type="radio" name="mrFitType" value="unadjusted" checked> Unadjusted fit</label>',
      '      <label><input type="radio" name="mrFitType" value="adjusted"> Spending-adjusted fit</label>',
      '    </fieldset>',
      '    <button id="mrDownloadPng" type="button" class="tmg-btn-ghost" aria-label="Download chart as PNG">Download PNG</button>',
      '  </div>',
      '  <div class="mean-reversion-stats" id="mrStats" aria-live="polite">',
      '    <span><strong>Spec:</strong> <span id="mrSpec" class="mean-reversion-spec-badge">Full sample · Unadjusted fit</span></span>',
      '    <span><strong>Slope:</strong> <span id="mrSlope">n/a</span></span>',
      '    <span><strong>p-value:</strong> <span id="mrPValue">n/a</span></span>',
      '    <span><strong>N:</strong> <span id="mrN">0</span></span>',
      '  </div>',
      '  <div id="meanReversionPlot" class="mean-reversion-plot" role="img" aria-label="Scatter plot of prior-season finish versus next-season performance change with regression fit"></div>',
      '  <p class="tmg-body mean-reversion-caption">Scatter of prior-season finish vs next-season change. Fitted slope ≈ −0.42 indicates mean reversion; toggle to exclude COVID seasons or view spending-adjusted fit.</p>',
      '  <p class="tmg-body" style="margin-bottom:0;">',
      '    <a href="./methods.html#regression-specs">View regression specs</a>',
      '    &nbsp;·&nbsp;',
      '    <a href="./audit.html">Audit reproducibility checks</a>',
      '  </p>',
      '</section>'
    ].join("\n");
  }

  function asNumber(value) {
    const n = Number(value);
    return Number.isFinite(n) ? n : null;
  }

  function normalizeRows(rows) {
    return rows
      .map(function (row) {
        const season = asNumber(row.season);
        const priorFinish = asNumber(row.prior_finish);
        const deltaPerformance = asNumber(row.delta_performance);
        const ufaSpend = asNumber(row.ufa_spend);
        const mis = asNumber(row.MIS);
        const team = String(row.team || "").trim();
        if (!team || season === null || priorFinish === null || deltaPerformance === null) {
          return null;
        }
        return {
          season: season,
          team: team,
          prior_finish: priorFinish,
          delta_performance: deltaPerformance,
          ufa_spend: ufaSpend === null ? 0 : ufaSpend,
          MIS: mis === null ? 0 : mis,
        };
      })
      .filter(function (row) { return row !== null; });
  }

  function renderError(message) {
    container.innerHTML =
      '<section class="tmg-card-wide mean-reversion-wrap">' +
      '  <h2 class="tmg-h2">Mean reversion check</h2>' +
      '  <p class="tmg-body" role="status">' + message + '</p>' +
      '  <p class="tmg-body" style="margin-bottom:0;">' +
      '    <a href="../../data/">Open data folder</a> &nbsp;·&nbsp; <a href="./audit.html">Audit reproducibility checks</a>' +
      '  </p>' +
      '</section>';
  }

  function drawPlot(rows) {
    const excludeCovid = document.getElementById("mrExcludeCovid").checked;
    const fitTypeNode = document.querySelector('input[name="mrFitType"]:checked');
    const fitType = fitTypeNode ? fitTypeNode.value : "unadjusted";
    const fitLabel = fitType === "adjusted" ? "Spending-adjusted fit" : "Unadjusted fit";
    const sampleLabel = excludeCovid ? "Ex-COVID seasons" : "Full sample";

    const filtered = rows.filter(function (row) {
      return !(excludeCovid && COVID_SEASONS.has(row.season));
    });

    if (filtered.length < 3) {
      document.getElementById("mrSpec").textContent = sampleLabel + " \u00B7 " + fitLabel;
      document.getElementById("mrSlope").textContent = "n/a";
      document.getElementById("mrPValue").textContent = "n/a";
      document.getElementById("mrN").textContent = String(filtered.length);
      Plotly.react("meanReversionPlot", [], {
        paper_bgcolor: "#ffffff",
        plot_bgcolor: "#ffffff",
        xaxis: { title: { text: "Prior-season finish" } },
        yaxis: { title: { text: "Next-season change" } },
        annotations: [{
          text: "Not enough observations for regression",
          x: 0.5,
          y: 0.5,
          xref: "paper",
          yref: "paper",
          showarrow: false
        }],
      }, { responsive: true, displayModeBar: false });
      return;
    }

    const xRaw = filtered.map(function (r) { return r.prior_finish; });
    const yRaw = filtered.map(function (r) { return r.delta_performance; });

    let xForFit = xRaw.slice();
    let yForFit = yRaw.slice();
    let xLabel = "Prior-season finish";
    let yLabel = "Next-season performance change";

    if (fitType === "adjusted") {
      const controls = filtered.map(function (r) { return [1, r.ufa_spend, r.MIS]; });
      const xResidual = residualize(xRaw, controls);
      const yResidual = residualize(yRaw, controls);
      if (xResidual && yResidual) {
        xForFit = xResidual;
        yForFit = yResidual;
        xLabel = "Prior-season finish (residualized by spend and MIS)";
        yLabel = "Next-season change (residualized by spend and MIS)";
      }
    }

    const fit = olsSimple(xForFit, yForFit);
    if (!fit) {
      document.getElementById("mrSpec").textContent = sampleLabel + " \u00B7 " + fitLabel;
      document.getElementById("mrSlope").textContent = "n/a";
      document.getElementById("mrPValue").textContent = "n/a";
      document.getElementById("mrN").textContent = String(filtered.length);
      return;
    }

    const minX = Math.min.apply(null, xForFit);
    const maxX = Math.max.apply(null, xForFit);
    const xGrid = makeGrid(minX, maxX, 120);

    const yFit = [];
    const yUpper = [];
    const yLower = [];
    const sigma = Math.sqrt(fit.sigma2);

    for (let i = 0; i < xGrid.length; i += 1) {
      const x0 = xGrid[i];
      const y0 = fit.intercept + fit.slope * x0;
      const seMean = sigma * Math.sqrt((1 / fit.n) + ((x0 - fit.xBar) * (x0 - fit.xBar)) / fit.sxx);
      const margin = 1.96 * seMean;
      yFit.push(y0);
      yUpper.push(y0 + margin);
      yLower.push(y0 - margin);
    }

    const pointTrace = {
      x: xForFit,
      y: yForFit,
      mode: "markers",
      type: "scatter",
      name: "Team-season",
      marker: {
        color: "rgba(31, 119, 180, 0.75)",
        size: 8,
        line: { color: "rgba(31, 119, 180, 1)", width: 0.5 },
      },
      customdata: filtered.map(function (r) {
        return [r.team, r.season, r.ufa_spend, r.MIS];
      }),
      hovertemplate:
        "<b>%{customdata[0]}</b><br>" +
        "Season: %{customdata[1]}<br>" +
        "UFA spend: $%{customdata[2]:.2f}M<br>" +
        "MIS: %{customdata[3]:.2f}<br>" +
        "x: %{x:.3f}<br>" +
        "y: %{y:.3f}<extra></extra>",
    };

    const upperTrace = {
      x: xGrid,
      y: yUpper,
      mode: "lines",
      line: { color: "rgba(214, 39, 40, 0)" },
      hoverinfo: "skip",
      showlegend: false,
      name: "95% CI",
    };

    const lowerTrace = {
      x: xGrid,
      y: yLower,
      mode: "lines",
      fill: "tonexty",
      fillcolor: "rgba(214, 39, 40, 0.15)",
      line: { color: "rgba(214, 39, 40, 0)" },
      hoverinfo: "skip",
      showlegend: false,
      name: "95% CI",
    };

    const lineTrace = {
      x: xGrid,
      y: yFit,
      mode: "lines",
      line: { color: "rgba(214, 39, 40, 0.95)", width: 3 },
      name: "Fitted line",
      hovertemplate: "Fit: %{y:.3f}<extra></extra>",
    };

    const layout = {
      margin: { l: 70, r: 20, t: 20, b: 65 },
      paper_bgcolor: "#ffffff",
      plot_bgcolor: "#ffffff",
      showlegend: false,
      xaxis: {
        title: { text: xLabel },
        zeroline: false,
        gridcolor: "rgba(0,0,0,0.08)",
      },
      yaxis: {
        title: { text: yLabel },
        zeroline: true,
        zerolinecolor: "rgba(0,0,0,0.2)",
        gridcolor: "rgba(0,0,0,0.08)",
      },
    };

    Plotly.react("meanReversionPlot", [upperTrace, lowerTrace, lineTrace, pointTrace], layout, {
      responsive: true,
      displayModeBar: false,
    });

    document.getElementById("mrSpec").textContent = sampleLabel + " \u00B7 " + fitLabel;
    document.getElementById("mrSlope").textContent = fit.slope.toFixed(2);
    document.getElementById("mrPValue").textContent = formatPValue(fit.pValue);
    document.getElementById("mrN").textContent = String(filtered.length);
  }

  async function init() {
    if (!window.Plotly) {
      renderError("Chart library failed to load. Please refresh the page or check your internet connection.");
      return;
    }

    buildUI();

    let rows;
    try {
      const response = await fetch(DATA_URL, { cache: "no-store" });
      if (!response.ok) {
        throw new Error("HTTP " + response.status);
      }
      rows = normalizeRows(await response.json());
    } catch (error) {
      renderError("Could not load chart data from ./data/team_seasons.json. Please verify the file exists.");
      return;
    }

    if (!rows.length) {
      renderError("Chart data loaded, but no valid rows were found. Please validate the JSON schema.");
      return;
    }

    drawPlot(rows);

    document.getElementById("mrExcludeCovid").addEventListener("change", function () {
      drawPlot(rows);
    });

    const fitInputs = document.querySelectorAll('input[name="mrFitType"]');
    fitInputs.forEach(function (input) {
      input.addEventListener("change", function () {
        drawPlot(rows);
      });
    });

    document.getElementById("mrDownloadPng").addEventListener("click", function () {
      Plotly.downloadImage("meanReversionPlot", {
        format: "png",
        width: 1200,
        height: 700,
        filename: "mean_reversion_chart",
      });
    });

    window.addEventListener("resize", function () {
      Plotly.Plots.resize("meanReversionPlot");
    });
  }

  init();
})();
