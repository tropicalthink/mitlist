const fmt = {
  usd: (n) => `$${(n || 0).toFixed(4)}`,
  num: (n) => (n || 0).toLocaleString(),
  bytes: (n) => {
    if (n < 1024) return `${n} B`;
    if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
    return `${(n / 1024 / 1024).toFixed(1)} MB`;
  },
  time: (iso) => iso ? new Date(iso).toLocaleString() : '—',
};

let refreshTimer = null;
let isRunning = false;

// ── Controls ────────────────────────────────────────────────────────────────

const ctrlPrompt = document.getElementById('ctrl-prompt');
const ctrlMode = document.getElementById('ctrl-mode');
const ctrlCategoryWrap = document.getElementById('ctrl-category-wrap');
const ctrlBatchWrap = document.getElementById('ctrl-batch-wrap');
const ctrlCategory = document.getElementById('ctrl-category');
const ctrlBatch = document.getElementById('ctrl-batch');
const ctrlTemp = document.getElementById('ctrl-temp');
const ctrlForce = document.getElementById('ctrl-force');
const btnStart = document.getElementById('btn-start');
const btnStop = document.getElementById('btn-stop');
const btnPipeline = document.getElementById('btn-pipeline');
const btnP45Parallel = document.getElementById('btn-p45-parallel');

ctrlMode.addEventListener('change', () => {
  const mode = ctrlMode.value;
  ctrlCategoryWrap.classList.toggle('hidden', mode !== 'category');
  ctrlBatchWrap.classList.toggle('hidden', mode !== 'batch');
  if (mode === 'category') ctrlPrompt.value = '1';
});

ctrlPrompt.addEventListener('change', () => {
  if (ctrlPrompt.value !== '1' && ctrlMode.value === 'category') {
    ctrlMode.value = 'pending';
    ctrlCategoryWrap.classList.add('hidden');
  }
});

async function apiPost(path, body = {}) {
  const res = await fetch(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return res.json();
}

btnStart.addEventListener('click', async () => {
  const body = {
    prompt: parseInt(ctrlPrompt.value, 10),
    mode: ctrlMode.value,
    force: ctrlForce.checked,
  };
  const temp = parseFloat(ctrlTemp.value);
  if (!isNaN(temp)) body.temperature = temp;
  if (ctrlMode.value === 'category') body.category = ctrlCategory.value.trim();
  if (ctrlMode.value === 'batch') body.batch = ctrlBatch.value.trim();

  btnStart.disabled = true;
  const result = await apiPost('/api/job/start', body);
  btnStart.disabled = false;
  if (!result.ok) alert(result.error || 'Failed to start');
  else refresh();
});

btnStop.addEventListener('click', async () => {
  btnStop.disabled = true;
  await apiPost('/api/job/stop');
  refresh();
});

btnPipeline.addEventListener('click', async () => {
  if (!confirm('Run full pipeline P1→P2→P5→P3→P4 (pending batches only)?')) return;
  btnPipeline.disabled = true;
  const result = await apiPost('/api/job/pipeline');
  btnPipeline.disabled = false;
  if (!result.ok) alert(result.error || 'Failed to start pipeline');
  else refresh();
});

btnP45Parallel.addEventListener('click', async () => {
  if (!confirm('Run P4 + P5 in parallel (both OpenRouter)?')) return;
  btnP45Parallel.disabled = true;
  const result = await apiPost('/api/job/parallel', {
    prompts: ['4', '5'],
    mode: ctrlMode.value === 'all' ? 'all' : 'pending',
    force: ctrlForce.checked,
  });
  btnP45Parallel.disabled = false;
  if (!result.ok) alert(result.error || 'Failed to start parallel job');
  else refresh();
});

// Per-prompt quick actions (delegated)
document.getElementById('prompt-bars').addEventListener('click', async (e) => {
  const btn = e.target.closest('[data-action]');
  if (!btn) return;
  const prompt = parseInt(btn.dataset.prompt, 10);
  const mode = btn.dataset.action;
  const result = await apiPost('/api/job/start', { prompt, mode, force: ctrlForce.checked });
  if (!result.ok) alert(result.error || 'Failed to start');
  else refresh();
});

// ── Render ──────────────────────────────────────────────────────────────────

async function refresh() {
  try {
    const res = await fetch('/api/stats');
    const data = await res.json();
    render(data);
    scheduleRefresh(data.job?.status);
  } catch (e) {
    console.error('Failed to fetch stats:', e);
  }
}

function scheduleRefresh(jobStatus) {
  const running = jobStatus === 'running' || jobStatus === 'queued';
  if (running !== isRunning) {
    isRunning = running;
    if (refreshTimer) clearInterval(refreshTimer);
    refreshTimer = setInterval(refresh, running ? 2000 : 5000);
  }
}

function render(data) {
  const t = data.totals || {};
  document.getElementById('total-cost').textContent = fmt.usd(t.total_cost_usd);
  document.getElementById('total-rows').textContent = fmt.num(t.total_rows);
  document.getElementById('batch-progress').textContent =
    `${t.completed || 0} / ${t.total_batches || 0}`;
  document.getElementById('total-tokens').textContent =
    `${fmt.num(t.prompt_tokens)} / ${fmt.num(t.completion_tokens)}`;
  const orModel = data.openrouter_model || 'openrouter';
  document.getElementById('model-badge').textContent =
    `P1–2: ${data.deepseek_model || 'deepseek-chat'} · P3–5: ${orModel}`;
  document.getElementById('updated-at').textContent = fmt.time(data.updated_at);

  // API key warning
  const warn = document.getElementById('api-warning');
  const keysOk = data.api_key_set && data.openrouter_key_set;
  warn.classList.toggle('hidden', keysOk);
  if (!data.api_key_set) warn.textContent = 'DEEPSEEK_API_KEY not set in .env';
  else if (!data.openrouter_key_set) warn.textContent = 'OPENROUTER_API_KEY not set in .env (required for P3–P5)';

  // Job status
  const job = data.job || {};
  const jobRunning = job.status === 'running' || job.status === 'queued';
  const indicator = document.getElementById('job-indicator');
  indicator.textContent = job.status || 'idle';
  indicator.className = `job-indicator ${job.status || 'idle'}`;

  btnStart.disabled = jobRunning;
  btnStop.disabled = !jobRunning;
  btnPipeline.disabled = jobRunning;
  btnP45Parallel.disabled = jobRunning;

  const jobPanel = document.getElementById('job-status');
  jobPanel.classList.toggle('hidden', job.status === 'idle' && !job.logs?.length);

  if (job.status && job.status !== 'idle') {
    const p = job.progress || {};
    const promptLabel = (job.prompt_ids?.length > 1)
      ? job.prompt_ids.map((p) => `P${p}`).join('+')
      : `P${job.prompt_id || '?'}`;
    const parallelTag = job.parallel ? ' · parallel' : '';
    document.getElementById('job-label').textContent =
      `${promptLabel} · ${job.mode || '—'}${parallelTag} · ${job.current_batch || 'starting…'}`;
    document.getElementById('job-progress-text').textContent =
      `${p.index || 0}/${p.total || 0} · ${p.completed || 0} ok · ${p.failed || 0} fail · ${p.skipped || 0} skip`;
    const pct = p.total ? Math.round((p.index / p.total) * 100) : 0;
    document.getElementById('job-progress-fill').style.width = `${pct}%`;
  }

  const logEl = document.getElementById('job-log');
  logEl.textContent = (job.logs || []).join('\n');
  logEl.scrollTop = logEl.scrollHeight;

  // Prompt progress bars with quick actions
  const targets = data.batch_targets || {};
  const byPrompt = {};
  (data.by_prompt || []).forEach((r) => { byPrompt[r.prompt_id] = r; });

  const barsEl = document.getElementById('prompt-bars');
  const jobBusy = jobRunning;
  barsEl.innerHTML = Object.entries(targets).map(([pid, meta]) => {
    const row = byPrompt[pid] || { completed: 0, rows: 0, cost: 0 };
    const total = meta.total_batches || 1;
    const pct = Math.round((row.completed / total) * 100);
    const disabled = jobBusy ? 'disabled' : '';
    return `
      <div class="progress-row">
        <div class="progress-header">
          <span>P${pid} — ${meta.name}</span>
          <span>${row.completed}/${total} · ${fmt.num(row.rows)} rows · ${fmt.usd(row.cost)}</span>
        </div>
        <div class="progress-bar"><div class="progress-fill" style="width:${pct}%"></div></div>
        <div class="prompt-actions">
          <button class="btn-sm" data-prompt="${pid}" data-action="pending" ${disabled}>Run pending</button>
          <button class="btn-sm outline" data-prompt="${pid}" data-action="all" ${disabled}>Run all</button>
        </div>
      </div>`;
  }).join('');

  // Data files
  const filesTbody = document.querySelector('#data-files tbody');
  const files = data.data_files || {};
  filesTbody.innerHTML = Object.entries(files).map(([name, f]) =>
    `<tr><td>${name}</td><td>${fmt.num(f.rows)}</td><td>${fmt.bytes(f.bytes)}</td></tr>`
  ).join('') || '<tr><td colspan="3">No data yet</td></tr>';

  // Model versions
  const modelsEl = document.getElementById('model-versions');
  modelsEl.innerHTML = (data.models || []).map((m) => `
    <div class="model-card">
      <h3>${m.name}</h3>
      <div class="ver">v${m.version} · <span class="status ${m.status}">${m.status}</span></div>
      <div class="detail">
        ${m.base_model ? `Base: ${m.base_model}<br>` : ''}
        ${m.top1_accuracy != null ? `Top-1: ${(m.top1_accuracy * 100).toFixed(1)}% · ` : ''}
        ${m.top5_accuracy != null ? `Top-5: ${(m.top5_accuracy * 100).toFixed(1)}% · ` : ''}
        ${m.trained_on ? `Trained: ${fmt.time(m.trained_on)}` : 'Not trained yet'}
      </div>
    </div>
  `).join('') || '<p class="muted">No models trained yet</p>';

  // Recent batches
  const recentTbody = document.querySelector('#recent-batches tbody');
  recentTbody.innerHTML = (data.recent_batches || []).map((b) => `
    <tr>
      <td>P${b.prompt_id}</td>
      <td>${b.batch_key}</td>
      <td><span class="status ${b.status}">${b.status}</span></td>
      <td>${fmt.num(b.rows_generated)}</td>
      <td>${fmt.usd(b.cost_usd)}</td>
      <td>${fmt.time(b.completed_at)}</td>
    </tr>
  `).join('') || '<tr><td colspan="6">No batches yet</td></tr>';
}

refresh();
refreshTimer = setInterval(refresh, 5000);
