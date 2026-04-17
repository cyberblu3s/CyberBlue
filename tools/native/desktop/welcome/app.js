/* app.js — renders the welcome dashboard from CATALOG + STATUS.
 *
 *   CATALOG  = static tool/category definitions      (catalog.js)
 *   STATUS   = auto-generated container health data  (status.js)
 *              { host: "18.x.x.x", ts: 1713393..., containers: { name: { state, health } } }
 *
 * If STATUS is missing (file not yet generated) we degrade gracefully.
 */

(function () {
  'use strict';

  const STATUS  = window.STATUS  || { host: window.location.hostname || 'localhost', ts: 0, containers: {} };
  const CATALOG = window.CATALOG;

  const hostEl    = document.getElementById('host');
  const updatedEl = document.getElementById('updated');
  const healthEl  = document.getElementById('health-pill');
  const filtersEl = document.getElementById('filters');
  const gridEl    = document.getElementById('grid-web');
  const cntWebEl  = document.getElementById('count-web');
  const cntNatEl  = document.getElementById('count-native');
  const groupsEl  = document.getElementById('native-groups');
  const searchEl  = document.getElementById('search-input');
  const searchHintEl = document.getElementById('search-hint');

  const IP = STATUS.host || window.location.hostname || 'localhost';
  hostEl.textContent = IP;
  updatedEl.textContent = STATUS.ts
    ? new Date(STATUS.ts * 1000).toLocaleTimeString()
    : 'never';

  // -------------------- header health pill --------------------

  function renderHealth() {
    const allContainers = CATALOG.web.map(t => t.container).filter(Boolean);
    let running = 0, total = allContainers.length;
    for (const name of allContainers) {
      const c = STATUS.containers[name];
      if (c && (c.state === 'running' || c.state === 'healthy')) running++;
    }
    healthEl.textContent = `${running}/${total} services up`;
    healthEl.className = 'pill ' +
      (running === total ? 'ok' : running === 0 ? 'err' : 'warn');
  }

  // -------------------- filter bar --------------------

  let activeCat = 'all';
  let searchQ  = '';

  function renderFilters() {
    const counts = { all: CATALOG.web.length };
    for (const t of CATALOG.web) counts[t.cat] = (counts[t.cat] || 0) + 1;

    const items = [
      { id: 'all', label: 'All', ico: '✨' },
      ...CATALOG.categories.filter(c => counts[c.id] > 0),
    ];

    filtersEl.innerHTML = items.map(c =>
      `<button data-cat="${c.id}" class="${c.id === activeCat ? 'active' : ''}">
         <span>${c.ico}</span><span>${c.label}</span><span class="n">${counts[c.id] || 0}</span>
       </button>`
    ).join('');

    filtersEl.querySelectorAll('button').forEach(btn => {
      btn.addEventListener('click', () => {
        activeCat = btn.dataset.cat;
        filtersEl.querySelectorAll('button').forEach(b =>
          b.classList.toggle('active', b === btn));
        applyFilter();
      });
    });
  }

  // Normalize an item's searchable text once so each keystroke is O(1).
  // The haystack concatenates everything a user might type: tool name,
  // binary, description, category label, group label. All lowercased.
  function haystack(el) {
    return (el.dataset.search || '').toLowerCase();
  }

  function matchQuery(el) {
    if (!searchQ) return true;
    return haystack(el).includes(searchQ);
  }

  function applyFilter() {
    // --- Web cards: filtered by category + search ---
    let shownWeb = 0, totalWeb = 0;
    gridEl.querySelectorAll('.card').forEach(c => {
      totalWeb++;
      const catOk = activeCat === 'all' || c.dataset.cat === activeCat;
      const qOk   = matchQuery(c);
      const match = catOk && qOk;
      c.classList.toggle('is-hidden', !match);
      if (match) shownWeb++;
    });
    cntWebEl.textContent = (activeCat === 'all' && !searchQ)
      ? `${totalWeb} tools`
      : `${shownWeb} of ${totalWeb} tools`;

    // --- Native tools: filtered by search only (no web categories map
    // cleanly onto forensic-function groups like "Disk Forensics"), so a
    // category selection leaves native groups visible unless the user is
    // also typing a query. Groups with zero visible tools auto-collapse.
    let shownNat = 0, totalNat = 0;
    groupsEl.querySelectorAll('.native-group').forEach(g => {
      let gVisible = 0, gTotal = 0;
      g.querySelectorAll('[data-search]').forEach(t => {
        gTotal++; totalNat++;
        const ok = matchQuery(t);
        t.classList.toggle('is-hidden', !ok);
        if (ok) { gVisible++; shownNat++; }
      });
      g.classList.toggle('is-hidden', gVisible === 0);
      const nEl = g.querySelector('h3 .n');
      if (nEl) {
        nEl.textContent = (searchQ && gVisible !== gTotal)
          ? `${gVisible} of ${gTotal} tools`
          : `${gTotal} tools`;
      }
    });
    cntNatEl.textContent = searchQ
      ? `${shownNat} of ${totalNat} tools`
      : `${totalNat} tools`;

    // Hint to the user when a search returns nothing anywhere.
    if (searchQ && shownWeb === 0 && shownNat === 0) {
      searchHintEl.textContent = `no tool matches “${searchQ}”`;
      searchHintEl.classList.add('miss');
    } else if (searchQ) {
      searchHintEl.textContent = `${shownWeb + shownNat} match${shownWeb + shownNat === 1 ? '' : 'es'}`;
      searchHintEl.classList.remove('miss');
    } else {
      searchHintEl.textContent = '';
      searchHintEl.classList.remove('miss');
    }
  }

  // -------------------- web tool cards --------------------

  function statusFor(container) {
    const c = STATUS.containers[container];
    if (!c) return { cls: 'unknown', txt: 'unknown' };
    if (c.state === 'running' && c.health === 'healthy') return { cls: 'running', txt: 'healthy' };
    if (c.state === 'running' && c.health === 'starting') return { cls: 'unhealthy', txt: 'starting' };
    if (c.state === 'running' && c.health === 'unhealthy') return { cls: 'unhealthy', txt: 'unhealthy' };
    if (c.state === 'running') return { cls: 'running', txt: 'running' };
    if (c.state === 'exited' || c.state === 'stopped' || c.state === 'dead')
      return { cls: 'stopped', txt: c.state };
    return { cls: 'unknown', txt: c.state || 'unknown' };
  }

  function catLabel(id) {
    const c = CATALOG.categories.find(x => x.id === id);
    return c ? c.label : id;
  }

  function renderWeb() {
    gridEl.innerHTML = CATALOG.web.map(t => {
      const url    = t.url.replace('{{IP}}', IP);
      const status = statusFor(t.container);
      const hasCreds = !!t.creds;
      const ds = [t.name, t.container || '', catLabel(t.cat), t.desc, t.url]
        .join(' ').toLowerCase();
      return `
        <div class="card" data-cat="${t.cat}" data-search="${esc(ds)}">
          <div class="row1">
            <div class="icon" style="background:${t.color}">${t.icon}</div>
            <div style="flex:1;min-width:0">
              <h3>${t.name}</h3>
              <div class="cat-chip">${catLabel(t.cat)}</div>
            </div>
          </div>
          <p class="desc">${t.desc}</p>
          <div class="row2">
            <span class="status-dot ${status.cls}" title="${status.txt}"></span>
            <span class="status-txt">${status.txt}</span>
            <div class="actions">
              ${hasCreds ? `<button class="btn" data-creds='${encodeURIComponent(JSON.stringify({n:t.name,...t.creds}))}'>Creds</button>` : ''}
              <a class="btn primary" href="${url}" target="_blank" rel="noreferrer">Open ↗</a>
            </div>
          </div>
        </div>
      `;
    }).join('');

    gridEl.querySelectorAll('button[data-creds]').forEach(b => {
      b.addEventListener('click', () => {
        const d = JSON.parse(decodeURIComponent(b.dataset.creds));
        alert(`${d.n}\n\nUser: ${d.user}\nPass: ${d.pass}`);
      });
    });

    cntWebEl.textContent = `${CATALOG.web.length} tools`;
  }

  // -------------------- native toolkit --------------------

  function renderNative() {
    let total = 0;
    groupsEl.innerHTML = CATALOG.nativeGroups.map(g => {
      total += g.tools.length;
      const isGuiGroup = g.gui;
      // data-search lives on each tool element so `applyFilter` can hide
      // individual items without re-rendering the whole group. We bake in
      // the group label too so typing a group name (e.g. "cloud",
      // "adversary", "beaconing") also matches.
      const mkDs = t => esc(
        [t.name, t.bin, t.desc, g.label].join(' ').toLowerCase());

      const body = isGuiGroup
        ? g.tools.map(t => {
            const ds = mkDs(t);
            if (t.gui) {
              return `<a class="tool-card" data-search="${ds}" href="app://${t.bin}" onclick="return launchApp('${t.bin}')">
                        <div class="ico">🖥️</div>
                        <div class="tt"><div class="nm">${t.name}</div><div class="dd">${t.desc}</div></div>
                      </a>`;
            }
            return `<a class="tool-card" data-search="${ds}" href="cli://${t.bin}" onclick="return launchCli('${t.bin}')">
                      <div class="ico">▸</div>
                      <div class="tt"><div class="nm">${t.name}</div><div class="dd">${t.desc}</div></div>
                    </a>`;
          }).join('')
        : g.tools.map(t =>
            `<a class="chip" data-search="${mkDs(t)}" title="${t.desc}" href="cli://${t.bin}" onclick="return launchCli('${t.bin}')">
               <span class="ico">▸</span>${t.bin}
             </a>`
          ).join('');
      return `
        <div class="native-group ${isGuiGroup ? 'gui' : 'cli'}">
          <h3><span class="ico">${g.ico}</span>${g.label}<span class="n">${g.tools.length} tools</span></h3>
          <div class="tools">${body}</div>
        </div>`;
    }).join('');
    cntNatEl.textContent = `${total} tools`;
  }

  // -------------------- launchers (file:// can't exec; we use custom URI
  //      handlers registered as .desktop/xdg-mime by install-desktop.sh,
  //      but the dashboard also works fine in a "read-only / no launch" mode
  //      -- falling back to clipboard copy.) --------------------

  window.launchApp = function (bin) {
    // Try the xdg mime handler we registered (see cyberbluesoc-app.desktop).
    // Browsers on Linux will follow it silently. On failure fall back to copy.
    try {
      const iframe = document.createElement('iframe');
      iframe.style.display = 'none';
      iframe.src = 'cbsoc-app://' + encodeURIComponent(bin);
      document.body.appendChild(iframe);
      setTimeout(() => iframe.remove(), 2000);
    } catch (e) { /* ignore */ }
    return false;
  };
  window.launchCli = function (bin) {
    try {
      const iframe = document.createElement('iframe');
      iframe.style.display = 'none';
      iframe.src = 'cbsoc-cli://' + encodeURIComponent(bin);
      document.body.appendChild(iframe);
      setTimeout(() => iframe.remove(), 2000);
    } catch (e) { /* ignore */ }
    return false;
  };

  // -------------------- all-credentials modal --------------------
  //
  // A single table of every web tool's default login, including tools that
  // ship no creds (e.g. Portainer) so users know where the "set password
  // on first visit" flows are. Rendered from CATALOG.web on first open.
  //
  // Password text is click-to-copy: selecting+copying is the common case,
  // but we also wire a one-click "Copy" button because password fields
  // with symbols don't always triple-click cleanly.

  function esc(s) {
    return String(s || '').replace(/[&<>"']/g,
      c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  }

  function renderCredsTable() {
    const rows = [
      `<div class="creds-th">Tool</div>`,
      `<div class="creds-th">URL</div>`,
      `<div class="creds-th">Username</div>`,
      `<div class="creds-th">Password</div>`,
      `<div class="creds-th"></div>`,
    ];
    const entries = CATALOG.web.slice().sort((a, b) =>
      a.name.localeCompare(b.name));
    for (const t of entries) {
      const user = t.creds && t.creds.user;
      const pass = t.creds && t.creds.pass;
      const hasCreds = !!(user && pass);
      const url  = (t.url || '').replace('{{IP}}', IP);
      rows.push(
        `<div class="creds-td name">${esc(t.name)}</div>`,
        `<div class="creds-td url"><a href="${esc(url)}" target="_blank">${esc(url)}</a></div>`,
        `<div class="creds-td user">${esc(user || '—')}</div>`,
        hasCreds
          ? `<div class="creds-td pass" title="Click to copy">${esc(pass)}</div>`
          : `<div class="creds-td pass none">${esc((t.creds && t.creds.note) || 'set on first visit')}</div>`,
        hasCreds
          ? `<div class="creds-td copy-btn"><button class="creds-copy" data-pass="${esc(pass)}">Copy</button></div>`
          : `<div class="creds-td copy-btn"></div>`,
      );
    }
    document.getElementById('creds-table').innerHTML = rows.join('');

    // Wire Copy buttons.
    document.querySelectorAll('.creds-copy').forEach(btn => {
      btn.addEventListener('click', async () => {
        const pw = btn.getAttribute('data-pass');
        try {
          await navigator.clipboard.writeText(pw);
          btn.textContent = 'Copied';
          btn.classList.add('copied');
          setTimeout(() => {
            btn.textContent = 'Copy';
            btn.classList.remove('copied');
          }, 1400);
        } catch (e) {
          // clipboard api fails on file:// in some configs — fall back to
          // selecting the password cell so the user can ctrl-C.
          const cell = btn.closest('.creds-row') ||
                       btn.parentElement.previousElementSibling;
          if (cell) {
            const range = document.createRange();
            range.selectNodeContents(cell);
            const sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(range);
          }
        }
      });
    });
  }

  (function wireCredsModal() {
    const modal = document.getElementById('creds-modal');
    const openBtn = document.getElementById('open-creds-sheet');
    const closeBtn = document.getElementById('close-creds-sheet');
    if (!modal || !openBtn || !closeBtn) return;

    let rendered = false;
    const open = () => {
      if (!rendered) { renderCredsTable(); rendered = true; }
      modal.hidden = false;
    };
    const close = () => { modal.hidden = true; };

    openBtn.addEventListener('click', open);
    closeBtn.addEventListener('click', close);
    // Click the dimmer (but not the card) to close.
    modal.addEventListener('click', (e) => {
      if (e.target === modal) close();
    });
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && !modal.hidden) close();
    });

    // Deep-link: the Firefox bookmark "🔐 Credentials" points to
    // index.html#credentials, so opening it from the bookmarks toolbar
    // lands on the dashboard with the modal already showing.
    if (window.location.hash === '#credentials') open();
    window.addEventListener('hashchange', () => {
      if (window.location.hash === '#credentials') open();
    });
  })();

  // -------------------- auto-refresh --------------------

  // status.js is regenerated every 30s by systemd. A simple page reload picks
  // up both the script and any dashboard improvements.
  setTimeout(() => window.location.reload(), 60 * 1000);

  // -------------------- go --------------------

  renderFilters();
  renderWeb();
  renderHealth();
  renderNative();

  // -------------------- search wiring --------------------
  //
  // Debounce so long queries don't trigger a re-filter on every keystroke.
  // 60 ms is fast enough to feel instant and slow enough to coalesce the
  // "typing a 9-letter tool name" case into a couple of filter passes.

  if (searchEl) {
    let t = null;
    const trigger = () => {
      searchQ = searchEl.value.trim().toLowerCase();
      applyFilter();
    };
    searchEl.addEventListener('input', () => {
      clearTimeout(t);
      t = setTimeout(trigger, 60);
    });
    // Pressing "/" anywhere on the page focuses the search box — power-user
    // muscle memory from GitHub / Gmail / Slack. Ignore when the user is
    // already typing in a field so we don't hijack the creds modal.
    document.addEventListener('keydown', (e) => {
      if (e.key === '/' && !/^(INPUT|TEXTAREA)$/.test(document.activeElement.tagName)) {
        e.preventDefault();
        searchEl.focus();
        searchEl.select();
      }
      if (e.key === 'Escape' && document.activeElement === searchEl) {
        searchEl.value = '';
        trigger();
        searchEl.blur();
      }
    });
  }

  // One initial pass so counts reflect any pre-filled query (e.g. from a
  // future deep-link like `#search=zui`).
  applyFilter();
})();
