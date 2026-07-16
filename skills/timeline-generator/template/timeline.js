(function () {
  'use strict';

  const DATA = JSON.parse(document.getElementById('timeline-data').textContent);
  const ROOT = document.getElementById('root');
  const TT = document.getElementById('drag-tooltip');
  const LS_KEY = 'tl_overrides_' + (DATA.meta.title || 'default').replace(/\s+/g, '_');
  const TOTAL_DAYS = DATA.meta.total_days;
  const COL_MAX = TOTAL_DAYS + 1;
  const BASE_DAY = new Date(DATA.meta.base_date + 'T00:00:00');

  // ── overrides (localStorage): { spans: {id: [s,e]}, deleted: [id,...] }
  function loadOverrides() {
    try {
      const raw = JSON.parse(localStorage.getItem(LS_KEY) || '{}');
      // backward-compat: old flat shape {barId: {span:[]}}
      if (raw && !raw.spans && !raw.deleted) {
        const spans = {};
        Object.keys(raw).forEach(k => { if (raw[k] && raw[k].span) spans[k] = raw[k].span; });
        return { spans, deleted: [] };
      }
      return { spans: raw.spans || {}, deleted: raw.deleted || [] };
    } catch (_) { return { spans: {}, deleted: [] }; }
  }
  function saveOverrides(o) { localStorage.setItem(LS_KEY, JSON.stringify(o)); }
  let overrides = loadOverrides();

  function applyOverride(bar) {
    const o = overrides.spans[bar.id];
    if (o && Array.isArray(o)) bar.span = o.slice();
    return bar;
  }
  function isDeleted(barId) { return overrides.deleted.indexOf(barId) >= 0; }
  function recordOverride(barId, span) {
    overrides.spans[barId] = span.slice();
    saveOverrides(overrides);
  }
  function recordDelete(barId) {
    if (!isDeleted(barId)) overrides.deleted.push(barId);
    saveOverrides(overrides);
  }

  // ── helpers
  function dayLabel(d) {
    const dt = new Date(BASE_DAY);
    dt.setDate(BASE_DAY.getDate() + (d - 1));
    return String(dt.getDate()).padStart(2,'0') + '/' + String(dt.getMonth()+1).padStart(2,'0');
  }
  function dayWeekday(d) {
    const dt = new Date(BASE_DAY);
    dt.setDate(BASE_DAY.getDate() + (d - 1));
    return ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb'][dt.getDay()];
  }
  function todayCol() {
    const today = new Date();
    today.setHours(0,0,0,0);
    const ms = today - BASE_DAY;
    return Math.floor(ms / 86400000) + 1;
  }
  function escapeHtml(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({
      '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'
    }[c]));
  }
  function statusEmoji(s) {
    return ({ done:'✅', 'in-progress':'⏳', 'in-review':'🔍', blocked:'🚧', pending:'⬜' }[s]) || '';
  }
  function statusBg(s, base) {
    if (s === 'done') return `linear-gradient(45deg, ${base}, ${base}aa) center/8px 8px repeating-linear-gradient(45deg, transparent, transparent 4px, rgba(0,0,0,.15) 4px, rgba(0,0,0,.15) 8px)`;
    return base;
  }

  // ── render: top meta
  function renderHeader() {
    const m = DATA.meta;
    const parts = [];
    parts.push(`<div class="eyebrow">${escapeHtml(m.subtitle || 'TIMELINE')}</div>`);
    parts.push(`<h1>${escapeHtml(m.title)}</h1>`);
    if (m.facts) {
      parts.push(`<div class="meta-row">${m.facts.map(f => `<span>${f}</span>`).join('')}</div>`);
    }
    if (m.links) {
      parts.push(`<div class="links-row">${m.links.map(l => `<a href="${escapeHtml(l.url)}" target="_blank">${escapeHtml(l.label)}</a>`).join(' · ')}</div>`);
    }
    return parts.join('');
  }

  // ── render: gantt headers (wrap em lane-row pra alinhar com swim lanes)
  function renderGanttHeaders() {
    const ms = DATA.meta.milestones || [];
    const gridStyle = `display:grid;grid-template-columns:repeat(${TOTAL_DAYS},1fr);gap:0;width:100%`;

    function wrapRow(inner, marginBottom = 3, trackHeight = 'auto') {
      return `<div class="lane-row" style="margin-bottom:${marginBottom}px">`
           + `<div class="lane-label" style="visibility:hidden">.</div>`
           + `<div class="lane-track" style="height:${trackHeight}">${inner}</div>`
           + `</div>`;
    }

    let html = '';

    if (ms.length) {
      let row = `<div style="${gridStyle}">`;
      ms.forEach(m => {
        row += `<div class="ms-header" style="grid-column:${m.span[0]}/${m.span[1]};color:${m.color};border-color:${m.color}88">${escapeHtml(m.label)}</div>`;
      });
      row += `</div>`;
      html += wrapRow(row, 3);
    }

    const months = computeMonthBands();
    let monthsRow = `<div style="${gridStyle}">`;
    months.forEach(mn => {
      monthsRow += `<div class="month-header" style="grid-column:${mn.start}/${mn.end}">${escapeHtml(mn.label)}</div>`;
    });
    monthsRow += `</div>`;
    html += wrapRow(monthsRow, 2);

    const weeks = Math.ceil(TOTAL_DAYS / 7);
    const today = todayCol();
    let weeksRow = `<div style="${gridStyle}">`;
    for (let i = 0; i < weeks; i++) {
      const start = i * 7 + 1;
      const end = Math.min(start + 7, TOTAL_DAYS + 1);
      const isCurrent = today >= start && today < end;
      weeksRow += `<div class="week-header${isCurrent ? ' current' : ''}" style="grid-column:${start}/${end}">S${i+1} <span class="wd">${dayLabel(start)}</span></div>`;
    }
    weeksRow += `</div>`;
    html += wrapRow(weeksRow, 8);

    return html;
  }

  function computeMonthBands() {
    const out = [];
    let cur = null;
    for (let d = 1; d <= TOTAL_DAYS; d++) {
      const dt = new Date(BASE_DAY);
      dt.setDate(BASE_DAY.getDate() + (d - 1));
      const key = `${dt.getMonth()}-${dt.getFullYear()}`;
      const lbl = ['JAN','FEV','MAR','ABR','MAI','JUN','JUL','AGO','SET','OUT','NOV','DEZ'][dt.getMonth()] + ' ' + dt.getFullYear();
      if (!cur || cur.key !== key) {
        if (cur) cur.end = d;
        cur = { key, label: lbl, start: d, end: d + 1 };
        out.push(cur);
      } else {
        cur.end = d + 1;
      }
    }
    return out;
  }

  // ── render: swim lanes
  function renderLanes() {
    const gridStyle = `display:grid;grid-template-columns:repeat(${TOTAL_DAYS},1fr);height:100%;gap:0`;
    let html = '<div style="display:flex;flex-direction:column;gap:8px">';
    DATA.lanes.forEach(lane => {
      html += `<div class="lane-row">`;
      html += `<div class="lane-label" style="color:${lane.color}">${escapeHtml(lane.label)}</div>`;
      html += `<div class="lane-track"><div class="gantt-lane" style="${gridStyle}" data-lane-id="${escapeHtml(lane.id)}">`;
      const bars = (lane.bars || []).filter(b => !isDeleted(b.id)).map(b => applyOverride({...b}));
      bars.sort((a,b) => a.span[0] - b.span[0]);
      let cursor = 1;
      bars.forEach(b => {
        if (b.span[0] > cursor) {
          html += `<div class="empty-cell" style="grid-column:${cursor}/${b.span[0]}"></div>`;
        }
        const link = (b.links && b.links[0] && b.links[0].url) || '#';
        const stat = statusEmoji(b.status);
        const bg = statusBg(b.status, `linear-gradient(90deg, ${lane.color}33, ${lane.color})`);
        html += `<a class="gantt-bar" href="${escapeHtml(link)}" target="_blank" `
              + `data-bar-id="${escapeHtml(b.id)}" data-status="${escapeHtml(b.status || 'pending')}" `
              + `data-label="${escapeHtml(b.label)}" `
              + `data-label-len="${(b.label || '').length}" `
              + `style="grid-column:${b.span[0]}/${b.span[1]};background:${bg};border:1px solid ${lane.color}66">`
              + `<span class="lbl">${escapeHtml(b.label)}</span>`
              + (stat ? `<span class="stat">${stat}</span>` : '')
              + `<div class="gh gh-l"></div><div class="gh gh-r"></div>`
              + `<div class="del">✕</div>`
              + `</a>`;
        cursor = b.span[1];
      });
      if (cursor < TOTAL_DAYS + 1) {
        html += `<div class="empty-cell" style="grid-column:${cursor}/${TOTAL_DAYS+1}"></div>`;
      }
      html += `</div></div></div>`;
    });
    html += '</div>';
    return html;
  }

  // ── render: pins (intervenções) — wrapped no lane-row pra alinhar com swim lanes
  function renderPins() {
    const pins = DATA.pins || [];
    if (!pins.length) return '';
    let inner = `<div class="pins-wrap">`;
    pins.forEach(p => {
      const leftPct = ((p.day - 0.5) / TOTAL_DAYS) * 100;
      const tone = p.tone || 'blue';
      const color = { red:'#e63946', blue:'#38bdf8', green:'#3fb950', orange:'#F4A261', purple:'#a78bfa', pink:'#f471b5', warn:'#fbbf24' }[tone] || '#38bdf8';
      inner += `<div class="pin" style="left:${leftPct}%;top:0">`
             + `<div class="pdot" style="background:${color};color:#000">${escapeHtml(p.label || 'PIN')}</div>`
             + `<div class="pline" style="background:${color}"></div>`
             + `<div class="ptxt" style="background:${color}1f;border:1px solid ${color}55;color:${color}">${p.text || ''}</div>`
             + `</div>`;
    });
    inner += `</div>`;
    return `<div class="lane-row" style="margin-top:6px">`
         + `<div class="lane-label" style="visibility:hidden">.</div>`
         + `<div class="lane-track" style="height:auto">${inner}</div>`
         + `</div>`;
  }

  // ── render: today marker (mede offset real do lane-track)
  function renderTodayMarker(inner) {
    const t = todayCol();
    if (t < 1 || t > TOTAL_DAYS) return;
    const firstTrack = inner.querySelector('.lane-track');
    if (!firstTrack) return;
    const innerBox = inner.getBoundingClientRect();
    const trackBox = firstTrack.getBoundingClientRect();
    const offsetLeft = trackBox.left - innerBox.left;
    const trackW = trackBox.width;
    const x = offsetLeft + ((t - 0.5) / TOTAL_DAYS) * trackW;
    const mk = document.createElement('div');
    mk.id = 'today-marker';
    mk.style.left = `${x}px`;
    mk.innerHTML = `<div class="tlbl">HOJE · ${dayLabel(t)} (${dayWeekday(t)})</div>`;
    inner.appendChild(mk);
  }

  // ── render: milestone cards (optional, if meta.show_milestones !== false)
  function renderMilestoneCards() {
    const ms = DATA.meta.milestones || [];
    if (!ms.length || DATA.meta.show_milestones === false) return '';
    let html = `<div class="ms-section"><div class="eyebrow" style="margin-bottom:14px">DETALHE POR MILESTONE</div><div class="ms-grid">`;
    ms.forEach(m => {
      // collect bars within milestone span
      const bars = [];
      DATA.lanes.forEach(lane => (lane.bars || []).forEach(b => {
        if (b.span[0] >= m.span[0] && b.span[1] <= m.span[1]) {
          bars.push({ ...b, lane });
        }
      }));
      html += `<div class="ms-card" style="border-color:${m.color}66" data-ms-id="${escapeHtml(m.id)}">`;
      html += `<h4 style="color:${m.color}">${escapeHtml(m.label)}</h4>`;
      const startD = dayLabel(m.span[0]), endD = dayLabel(m.span[1]-1);
      html += `<div class="ms-sub">${startD} → ${endD} · ${m.span[1]-m.span[0]} dias</div>`;
      html += `<div class="ms-bars">`;
      bars.slice(0, 8).forEach(b => {
        html += `<a class="ms-bar-pill" href="${escapeHtml((b.links && b.links[0] && b.links[0].url) || '#')}" target="_blank" style="background:${b.lane.color}22;color:${b.lane.color};border:1px solid ${b.lane.color}55">${statusEmoji(b.status)} ${escapeHtml(b.label)}</a>`;
      });
      if (bars.length > 8) html += `<span style="font-size:10px;color:var(--text-muted);align-self:center">+${bars.length-8}</span>`;
      html += `</div></div>`;
    });
    html += `</div></div>`;
    return html;
  }

  // ── render: bottom panel (now / next / done)
  function renderBottomPanel() {
    const t = todayCol();
    const now = [], next = [], done = [];
    DATA.lanes.forEach(lane => {
      (lane.bars || []).filter(b => !isDeleted(b.id)).map(b => applyOverride({...b})).forEach(b => {
        const [s, e] = b.span;
        const item = { ...b, lane };
        if (b.status === 'done' || e <= t) done.push(item);
        else if (s <= t && t < e) now.push(item);
        else if (s > t) next.push(item);
      });
    });
    now.sort((a,b) => a.span[1] - b.span[1]);
    next.sort((a,b) => a.span[0] - b.span[0]);
    done.sort((a,b) => b.span[1] - a.span[1]);

    function itemHtml(it, label) {
      const [s, e] = it.span;
      const links = (it.links || []).slice(0, 3).map(l => `<a href="${escapeHtml(l.url)}" target="_blank">${escapeHtml(l.label)}</a>`).join('');
      let meta = '';
      if (label === 'now') {
        const remaining = e - t;
        meta = `${it.lane.label} · ${remaining} ${remaining===1?'dia':'dias'} restantes`;
      } else if (label === 'next') {
        const wait = s - t;
        meta = `${it.lane.label} · começa em ${wait} ${wait===1?'dia':'dias'} (${dayLabel(s)})`;
      } else {
        meta = `${it.lane.label} · terminou ${dayLabel(e-1)}`;
      }
      return `<div class="task-item"><div class="tdot" style="background:${it.lane.color}"></div><div class="tbody"><div>${statusEmoji(it.status)} ${escapeHtml(it.label)}</div><div class="tmeta">${links} ${meta}</div></div></div>`;
    }

    let html = `<div class="bottom-panel">`;
    html += `<div class="panel-card now"><h3>🔥 Em execução agora <span style="color:var(--text-muted);font-weight:400;font-size:11px">${dayLabel(t)} (${dayWeekday(t)})</span></h3>`;
    html += now.length ? now.map(it => itemHtml(it, 'now')).join('') : `<div style="color:var(--text-muted);font-size:12px">Nenhuma tarefa em execução hoje.</div>`;
    html += `</div>`;
    html += `<div class="panel-card next"><h3>📋 Próximas</h3>`;
    html += next.length ? next.slice(0, 6).map(it => itemHtml(it, 'next')).join('') : `<div style="color:var(--text-muted);font-size:12px">Sem tarefas futuras.</div>`;
    html += `</div>`;
    html += `<div class="panel-card done"><h3>✅ Concluídas</h3>`;
    html += done.length ? done.slice(0, 6).map(it => itemHtml(it, 'done')).join('') : `<div style="color:var(--text-muted);font-size:12px">Nenhuma tarefa concluída ainda.</div>`;
    html += `</div></div>`;
    return html;
  }

  function renderFooter() {
    const upd = DATA.meta.updated_at ? new Date(DATA.meta.updated_at).toLocaleString('pt-BR') : '—';
    document.getElementById('footer-note').textContent = `Última atualização: ${upd} · ${TOTAL_DAYS} dias · ${DATA.lanes.length} lanes · ${DATA.lanes.reduce((a,l)=>a+(l.bars||[]).length,0)} tarefas`;
  }

  // ── obstáculos no lane (outras bars excluindo a atual)
  function getObstacles(laneEl, barEl) {
    return Array.from(laneEl.querySelectorAll('.gantt-bar'))
      .filter(b => b !== barEl)
      .map(b => parseGrid(b))
      .filter(Boolean)
      .sort((a, b) => a.start - b.start);
  }

  // ── checa se [s, e) está livre dado obstáculos
  function isFree(obstacles, s, e) {
    return !obstacles.some(o => !(e <= o.start || s >= o.end));
  }

  // ── clamp move: tenta levar target pra direção desejada; trava em obstáculo
  function clampMove(obstacles, targetStart, span, prevStart) {
    let s = targetStart;
    let blocked = obstacles.find(o => !(s + span <= o.start || s >= o.end));
    if (!blocked) return s;
    // Decide lado pelo sentido do drag relativo à última posição válida
    if (targetStart >= prevStart) {
      // indo pra direita → encosta antes do obstáculo
      s = Math.max(1, blocked.start - span);
    } else {
      // indo pra esquerda → encosta depois do obstáculo
      s = Math.min(COL_MAX - span, blocked.end);
    }
    // re-check (pode haver outro obstáculo encadeado); se ainda bloqueado, mantém prev
    if (!isFree(obstacles, s, s + span)) return prevStart;
    return s;
  }

  // ── clamp resize-left: limita s tal que [s, eCol) fica livre
  function clampResizeLeft(obstacles, targetS, eCol, prevS) {
    if (isFree(obstacles, targetS, eCol)) return targetS;
    const blocker = obstacles.filter(o => o.end <= eCol)
      .sort((a, b) => b.end - a.end)[0];
    return blocker ? Math.max(blocker.end, targetS) : prevS;
  }

  // ── clamp resize-right: limita e tal que [sCol, e) fica livre
  function clampResizeRight(obstacles, sCol, targetE, prevE) {
    if (isFree(obstacles, sCol, targetE)) return targetE;
    const blocker = obstacles.filter(o => o.start >= sCol)
      .sort((a, b) => a.start - b.start)[0];
    return blocker ? Math.min(blocker.start, targetE) : prevE;
  }

  // ── recalcula empty-cells (gaps) de um swim lane após mover/resize bar
  function recomputeLaneGaps(laneEl) {
    laneEl.querySelectorAll('.empty-cell').forEach(c => c.remove());
    const spans = Array.from(laneEl.querySelectorAll('.gantt-bar'))
      .map(b => parseGrid(b)).filter(Boolean)
      .sort((a, b) => a.start - b.start);
    let cursor = 1;
    spans.forEach(s => {
      if (s.start > cursor) {
        const el = document.createElement('div');
        el.className = 'empty-cell';
        el.style.gridColumn = `${cursor}/${s.start}`;
        laneEl.appendChild(el);
      }
      cursor = Math.max(cursor, s.end);
    });
    if (cursor < COL_MAX) {
      const el = document.createElement('div');
      el.className = 'empty-cell';
      el.style.gridColumn = `${cursor}/${COL_MAX}`;
      laneEl.appendChild(el);
    }
    // reorder DOM by visual start so :last-child box-shadow rule applies to true rightmost cell
    const ordered = Array.from(laneEl.children).sort((a, b) => {
      const sa = parseGrid(a); const sb = parseGrid(b);
      return (sa ? sa.start : 1e9) - (sb ? sb.start : 1e9);
    });
    ordered.forEach(c => laneEl.appendChild(c));
  }

  // ── auto-fit: medir width real das bars e classificar em níveis "narrow"
  function autoFitBars() {
    document.querySelectorAll('.gantt-bar').forEach(bar => {
      const w = bar.getBoundingClientRect().width;
      const labelLen = +bar.dataset.labelLen || 0;
      // chars-cabíveis estimado por width / 6.5px (font 11)
      const cap = Math.floor(w / 7);
      let lvl = '0';
      if (w < 50 || labelLen > cap * 3) lvl = '2';
      else if (w < 90 || labelLen > cap * 2) lvl = '1';
      bar.dataset.narrow = lvl;
    });
  }

  // ── render orchestrator
  function render() {
    let html = '';
    html += renderHeader();
    html += `<div class="gantt-wrap"><div class="gantt-inner" id="gantt-inner">`;
    html += renderGanttHeaders();
    html += renderLanes();
    html += renderPins();
    html += `</div></div>`;
    html += renderMilestoneCards();
    html += renderBottomPanel();
    ROOT.innerHTML = html;
    renderTodayMarker(document.getElementById('gantt-inner'));
    renderFooter();
    wireDrag();
    autoFitBars();
    // re-fit em resize (debounced)
    let rT;
    window.addEventListener('resize', () => {
      clearTimeout(rT);
      rT = setTimeout(autoFitBars, 120);
    });
  }

  // ── drag (bars + cards)
  function showTT(html, x, y) {
    TT.innerHTML = html;
    TT.style.display = 'block';
    TT.style.left = (x + 14) + 'px';
    TT.style.top  = (y + 14) + 'px';
  }
  function hideTT() { TT.style.display = 'none'; }
  function parseGrid(el) {
    const m = (el.style.gridColumn || '').match(/^(\d+)\s*\/\s*(\d+)/);
    return m ? { start: +m[1], end: +m[2] } : null;
  }
  function setGrid(el, s, e) { el.style.gridColumn = s + '/' + e; }
  function fmtRange(s, e) {
    const startD = s, endD = e - 1, dur = e - s;
    if (startD === endD)
      return `<strong>D${startD} · ${dayWeekday(startD)}</strong><div class="tt-range">${dayLabel(startD)} · 1 dia</div>`;
    return `<strong>${dayLabel(startD)} → ${dayLabel(endD)}</strong><div class="tt-range">D${startD} (${dayWeekday(startD)}) → D${endD} (${dayWeekday(endD)}) · ${dur} dias</div>`;
  }

  function wireDrag() {
    // Gantt bars
    document.querySelectorAll('.gantt-lane').forEach(lane => {
      Array.from(lane.children).forEach(bar => {
        if (!bar.classList.contains('gantt-bar')) return;
        bar.setAttribute('draggable', 'false');
        bar.ondragstart = () => false;

        // Custom tooltip on hover (label completo + range) — substitui title nativo
        bar.addEventListener('mouseenter', e => {
          if (mode) return; // não atropela tooltip de drag em curso
          const lbl = bar.dataset.label || '';
          const g = parseGrid(bar);
          if (g) showTT(`<strong>${escapeHtml(lbl)}</strong><div class="tt-range">${dayLabel(g.start)} → ${dayLabel(g.end-1)} · ${g.end-g.start} dias</div>`, e.clientX, e.clientY);
        });
        bar.addEventListener('mousemove', e => { if (!mode && TT.style.display === 'block') { TT.style.left = (e.clientX+14)+'px'; TT.style.top = (e.clientY+14)+'px'; } });
        bar.addEventListener('mouseleave', () => { if (!mode) hideTT(); });

        let mode = null, startX = 0, sCol = 0, eCol = 0, cellW = 0, moved = false, suppressClick = false;

        function start(e, m) {
          if (e.button !== undefined && e.button !== 0) return;
          e.preventDefault(); e.stopPropagation();
          mode = m;
          const cur = parseGrid(bar);
          sCol = cur.start; eCol = cur.end; startX = e.clientX; moved = false;
          cellW = lane.getBoundingClientRect().width / TOTAL_DAYS;
          bar.classList.add(m === 'move' ? 'moving' : 'resizing');
          showTT(fmtRange(sCol, eCol), e.clientX, e.clientY);
          document.addEventListener('mousemove', onMove);
          document.addEventListener('mouseup', onUp);
        }
        function onMove(e) {
          if (!mode) return;
          const dx = e.clientX - startX;
          if (Math.abs(dx) > 3) moved = true;
          const dCol = Math.round(dx / cellW);
          const obstacles = getObstacles(lane, bar);
          const cur = parseGrid(bar) || { start: sCol, end: eCol };
          let s = cur.start, en = cur.end;
          let blockedFeedback = '';
          if (mode === 'move') {
            const span = eCol - sCol;
            const target = Math.max(1, Math.min(COL_MAX - span, sCol + dCol));
            const final = clampMove(obstacles, target, span, cur.start);
            if (final !== target) blockedFeedback = ' <span style="color:#fbbf24">⊘ obstáculo</span>';
            s = final;
            en = final + span;
          } else if (mode === 'resize-l') {
            const target = Math.max(1, Math.min(eCol - 1, sCol + dCol));
            const final = clampResizeLeft(obstacles, target, eCol, cur.start);
            if (final !== target) blockedFeedback = ' <span style="color:#fbbf24">⊘ obstáculo</span>';
            s = final; en = eCol;
          } else {
            const target = Math.max(sCol + 1, Math.min(COL_MAX, eCol + dCol));
            const final = clampResizeRight(obstacles, sCol, target, cur.end);
            if (final !== target) blockedFeedback = ' <span style="color:#fbbf24">⊘ obstáculo</span>';
            s = sCol; en = final;
          }
          setGrid(bar, s, en);
          recomputeLaneGaps(lane);
          showTT(fmtRange(s, en) + blockedFeedback, e.clientX, e.clientY);
        }
        function onUp() {
          document.removeEventListener('mousemove', onMove);
          document.removeEventListener('mouseup', onUp);
          bar.classList.remove('moving','resizing');
          hideTT();
          if (moved) {
            const cur = parseGrid(bar);
            recordOverride(bar.dataset.barId, [cur.start, cur.end]);
            suppressClick = true;
            setTimeout(() => { suppressClick = false; }, 80);
            recomputeLaneGaps(lane);
            // refresh bottom panel + reapply auto-fit
            const bottom = document.querySelector('.bottom-panel');
            if (bottom) bottom.outerHTML = renderBottomPanel();
            autoFitBars();
          }
          mode = null;
        }

        bar.addEventListener('mousedown', e => {
          const cls = e.target && e.target.classList ? e.target.classList : null;
          if (cls && cls.contains('del')) return; // delete tem handler próprio
          if (cls && cls.contains('gh-l')) return start(e, 'resize-l');
          if (cls && cls.contains('gh-r')) return start(e, 'resize-r');
          start(e, 'move');
        });
        bar.addEventListener('click', e => {
          if (suppressClick) { e.preventDefault(); e.stopPropagation(); }
        }, true);

        const delBtn = bar.querySelector('.del');
        if (delBtn) {
          delBtn.addEventListener('mousedown', e => { e.stopPropagation(); e.preventDefault(); });
          delBtn.addEventListener('click', e => {
            e.preventDefault();
            e.stopPropagation();
            const id = bar.dataset.barId;
            const label = bar.querySelector('.lbl')?.textContent || id;
            if (!confirm(`Excluir tarefa "${label}"?\n\n(Persiste em localStorage. Use Reset ou Import para restaurar.)`)) return;
            recordDelete(id);
            render();
          });
        }
      });
    });

    // Milestone cards drag-to-reorder
    document.querySelectorAll('.ms-grid').forEach(grid => {
      Array.from(grid.children).forEach(card => {
        if (!card.classList.contains('ms-card')) return;
        card.setAttribute('draggable', 'true');
        card.addEventListener('dragstart', e => {
          card.classList.add('dragging');
          e.dataTransfer.effectAllowed = 'move';
          try { e.dataTransfer.setData('text/plain', 'c'); } catch (_) {}
        });
        card.addEventListener('dragend', () => {
          card.classList.remove('dragging');
          grid.querySelectorAll('.drop-target').forEach(t => t.classList.remove('drop-target'));
        });
        card.addEventListener('dragenter', e => {
          const dr = grid.querySelector('.ms-card.dragging');
          if (!dr || dr === card) return;
          e.preventDefault();
          card.classList.add('drop-target');
        });
        card.addEventListener('dragleave', () => card.classList.remove('drop-target'));
        card.addEventListener('dragover', e => e.preventDefault());
        card.addEventListener('drop', e => {
          e.preventDefault();
          const dr = grid.querySelector('.ms-card.dragging');
          if (!dr || dr === card) return;
          const rect = card.getBoundingClientRect();
          const before = e.clientX < rect.left + rect.width / 2;
          grid.insertBefore(dr, before ? card : card.nextSibling);
          card.classList.remove('drop-target');
        });
      });
    });
  }

  // ── public API
  window.__tl = {
    reset() {
      if (!confirm('Limpar drag overrides + exclusões e voltar ao estado original?')) return;
      overrides = { spans: {}, deleted: [] };
      localStorage.removeItem(LS_KEY);
      render();
    },
    exportOverrides() {
      const blob = new Blob([JSON.stringify(overrides, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = (DATA.meta.title || 'timeline').replace(/\s+/g,'_') + '_overrides.json';
      document.body.appendChild(a); a.click(); a.remove();
      URL.revokeObjectURL(url);
    },
    importOverrides() {
      const input = document.createElement('input');
      input.type = 'file';
      input.accept = '.json,application/json';
      input.onchange = ev => {
        const file = ev.target.files[0];
        if (!file) return;
        const reader = new FileReader();
        reader.onload = e => {
          try {
            const obj = JSON.parse(e.target.result);
            if (typeof obj !== 'object' || obj === null) throw new Error('JSON deve ser objeto');
            // accept new shape {spans, deleted} OR old flat {id:{span:[]}}
            if (obj.spans || obj.deleted) {
              overrides = { spans: obj.spans || {}, deleted: obj.deleted || [] };
            } else {
              const spans = {};
              Object.keys(obj).forEach(k => { if (obj[k] && obj[k].span) spans[k] = obj[k].span; });
              overrides = { spans, deleted: [] };
            }
            saveOverrides(overrides);
            render();
          } catch (err) { alert('Import falhou: ' + err.message); }
        };
        reader.readAsText(file);
      };
      input.click();
    }
  };

  render();
})();
