/* ===== Poker Clock — app logic ===== */
(() => {
  'use strict';

  /* ---------- i18n ---------- */
  const I18N = {
    cs: {
      'home.title':'Turnaje','home.subtitle':'Naplánuj a spusť svůj pokerový turnaj.',
      'home.saved':'Uložené turnaje','home.new':'+ Nový turnaj',
      'preset.turbo':'Turbo','preset.turbo.desc':'Rychlé levely',
      'preset.standard':'Standard','preset.standard.desc':'Vyvážená struktura',
      'preset.deepstack':'Deepstack','preset.deepstack.desc':'Dlouhé levely',
      'editor.title':'Editor struktury','common.back':'← Zpět','editor.start':'▶ Spustit',
      'editor.name':'Název turnaje','editor.players':'Počet hráčů','editor.buyin':'Buy-in',
      'editor.stack':'Startovní stack','editor.structtype':'Typ struktury',
      'editor.recommend':'🤖 Doporučit odpočet a žetony','editor.features':'Funkce',
      'feature.breaks':'Přestávky','feature.rebuy':'Rebuy','feature.addon':'Add-on',
      'feature.chips':'Žetony / chip-race','feature.prize':'Prize pool',
      'rebuy.until':'Do levelu','rebuy.price':'Cena','rebuy.chips':'Žetony',
      'addon.atbreak':'U přestávky č.',
      'editor.levels':'Levely','editor.addlevel':'+ Level','editor.addbreak':'+ Přestávka',
      'lvl.sb':'SB','lvl.bb':'BB','lvl.ante':'Ante','lvl.min':'Min',
      'editor.chips':'Žetony','editor.addchip':'+ Žeton',
      'timer.edit':'⚙ Editor','timer.level':'Level','timer.next':'Příští','timer.break':'☕ Přestávka',
      'reco.done':'Doporučeno pro {n} hráčů ({type}): {lvls} levelů × {min} min, stack {stack}.',
      'chip.total':'Celkem žetonů na sadu (stack × hráči + rezerva): {n}',
      'chip.perplayer':'Na hráče: {n} žetonů',
      'prize.pool':'Prize pool','prize.entries':'Vstupy','prize.payouts':'Výplaty',
      'confirm.del':'Smazat tento turnaj?','t.untitled':'Turnaj bez názvu',
      'timer.players':'Hráči','timer.avg':'Prům. stack','timer.totalchips':'Žetonů celkem','timer.pool':'Prize pool',
      'rebuy.open':'REBUY OTEVŘENÝ','rebuy.closed':'REBUY UZAVŘENÝ','common.run':'Spustit',
      'common.edit':'Upravit','common.del':'Smazat','break':'Přestávka','min':'min',
    },
    en: {
      'home.title':'Tournaments','home.subtitle':'Plan and run your poker tournament.',
      'home.saved':'Saved tournaments','home.new':'+ New tournament',
      'preset.turbo':'Turbo','preset.turbo.desc':'Fast levels',
      'preset.standard':'Standard','preset.standard.desc':'Balanced structure',
      'preset.deepstack':'Deepstack','preset.deepstack.desc':'Long levels',
      'editor.title':'Structure editor','common.back':'← Back','editor.start':'▶ Start',
      'editor.name':'Tournament name','editor.players':'Players','editor.buyin':'Buy-in',
      'editor.stack':'Starting stack','editor.structtype':'Structure type',
      'editor.recommend':'🤖 Recommend timing & chips','editor.features':'Features',
      'feature.breaks':'Breaks','feature.rebuy':'Rebuy','feature.addon':'Add-on',
      'feature.chips':'Chips / chip-race','feature.prize':'Prize pool',
      'rebuy.until':'Until level','rebuy.price':'Price','rebuy.chips':'Chips',
      'addon.atbreak':'At break #',
      'editor.levels':'Levels','editor.addlevel':'+ Level','editor.addbreak':'+ Break',
      'lvl.sb':'SB','lvl.bb':'BB','lvl.ante':'Ante','lvl.min':'Min',
      'editor.chips':'Chips','editor.addchip':'+ Chip',
      'timer.edit':'⚙ Editor','timer.level':'Level','timer.next':'Next','timer.break':'☕ Break',
      'reco.done':'Recommended for {n} players ({type}): {lvls} levels × {min} min, stack {stack}.',
      'chip.total':'Total chips for the set (stack × players + buffer): {n}',
      'chip.perplayer':'Per player: {n} chips',
      'prize.pool':'Prize pool','prize.entries':'Entries','prize.payouts':'Payouts',
      'confirm.del':'Delete this tournament?','t.untitled':'Untitled tournament',
      'timer.players':'Players','timer.avg':'Avg stack','timer.totalchips':'Total chips','timer.pool':'Prize pool',
      'rebuy.open':'REBUY OPEN','rebuy.closed':'REBUY CLOSED','common.run':'Run',
      'common.edit':'Edit','common.del':'Delete','break':'Break','min':'min',
    }
  };
  let lang = localStorage.getItem('pc_lang') || 'cs';
  const t = (k, vars) => {
    let s = (I18N[lang] && I18N[lang][k]) || k;
    if (vars) for (const [kk,vv] of Object.entries(vars)) s = s.replace(`{${kk}}`, vv);
    return s;
  };
  function applyI18n(){
    document.querySelectorAll('[data-i18n]').forEach(el=>{ el.textContent = t(el.dataset.i18n); });
    document.documentElement.lang = lang;
    document.getElementById('langSwitch').textContent = lang === 'cs' ? 'EN' : 'CZ';
  }

  /* ---------- Storage ---------- */
  const KEY = 'pc_tournaments';
  const loadAll = () => { try { return JSON.parse(localStorage.getItem(KEY)) || []; } catch { return []; } };
  const saveAll = (arr) => localStorage.setItem(KEY, JSON.stringify(arr));
  const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2,6);

  /* ---------- Structure recommender ---------- */
  // returns {levelMin, levels} based on players + type
  function recommend(players, type){
    const base = { turbo:{min:10, mult:0.8}, standard:{min:20, mult:1}, deepstack:{min:30, mult:1.4} }[type] || {min:20,mult:1};
    // more players -> a bit more levels
    let levels = Math.round((12 + Math.min(players,40)/5) * base.mult);
    levels = Math.max(8, Math.min(levels, 30));
    let levelMin = base.min;
    if (players >= 30) levelMin += 5;
    // recommended starting stack
    const stack = type === 'deepstack' ? 30000 : type === 'turbo' ? 5000 : 10000;
    return { levelMin, levels, stack };
  }
  // standard blind ladder
  const LADDER = [
    [25,50,0],[50,100,0],[75,150,0],[100,200,0],[150,300,0],[200,400,50],
    [300,600,75],[400,800,100],[500,1000,100],[600,1200,200],[800,1600,200],
    [1000,2000,300],[1500,3000,400],[2000,4000,500],[3000,6000,1000],
    [4000,8000,1000],[5000,10000,2000],[8000,16000,2000],[10000,20000,3000],
    [15000,30000,4000],[20000,40000,5000],[30000,60000,10000],[40000,80000,10000],
    [50000,100000,15000],[75000,150000,20000],[100000,200000,30000],[150000,300000,40000],
    [200000,400000,50000],[300000,600000,75000],[400000,800000,100000]
  ];
  function buildLevels(levelCount, levelMin, withBreaks, anteOn){
    const out = [];
    for (let i=0;i<levelCount;i++){
      const [sb,bb,ante] = LADDER[Math.min(i, LADDER.length-1)];
      out.push({ type:'level', sb, bb, ante: anteOn?ante:0, durationMin: levelMin });
      if (withBreaks && (i+1)%4===0 && i<levelCount-1) out.push({ type:'break', durationMin:15 });
    }
    return out;
  }
  function recommendChips(stack){
    if (stack <= 6000) return [{value:25,color:'#27c06a'},{value:100,color:'#2b6cb0'},{value:500,color:'#1a1205'}];
    if (stack <= 15000) return [{value:25,color:'#27c06a'},{value:100,color:'#2b6cb0'},{value:500,color:'#1a1205'},{value:1000,color:'#d4af37'}];
    return [{value:25,color:'#27c06a'},{value:100,color:'#2b6cb0'},{value:500,color:'#1a1205'},{value:1000,color:'#d4af37'},{value:5000,color:'#e0506a'}];
  }

  /* ---------- App state ---------- */
  let current = null;          // tournament being edited
  let run = null;              // RunState
  let ticker = null;
  let soundOn = localStorage.getItem('pc_sound') !== '0';

  function newTournament(preset){
    const players = 9;
    const type = preset || 'standard';
    const r = recommend(players, type);
    return {
      id: uid(), name:'', createdAt: Date.now(),
      players, buyIn:1000, startingStack: r.stack, structType: type,
      features:{ breaks:true, rebuy:false, addon:false, chips:true, prize:false },
      levels: buildLevels(r.levels, r.levelMin, true, true),
      rebuy:{ untilLevel:6, price:1000, chips:10000 },
      addon:{ atBreak:1, price:1000, chips:15000 },
      chips: recommendChips(r.stack),
      counts:{ rebuys:0, addons:0 }
    };
  }

  /* ---------- View routing ---------- */
  const views = ['home','editor','timer'];
  function show(v){
    views.forEach(x => document.getElementById('view-'+x).hidden = (x!==v));
    if (v!=='timer') stopTick();
  }

  /* ---------- HOME ---------- */
  function renderHome(){
    const list = document.getElementById('tournamentList');
    const arr = loadAll();
    list.innerHTML = '';
    if (!arr.length){ list.innerHTML = `<div class="empty">—</div>`; return; }
    arr.sort((a,b)=>b.createdAt-a.createdAt).forEach(tn=>{
      const div = document.createElement('div');
      div.className = 't-item';
      const lvls = tn.levels.filter(l=>l.type==='level').length;
      div.innerHTML = `
        <div>
          <div><b>${escapeHtml(tn.name||t('t.untitled'))}</b></div>
          <div class="t-meta">${tn.players} ${t('editor.players').toLowerCase()} · ${lvls} ${t('editor.levels').toLowerCase()} · ${tn.startingStack} ${t('feature.chips').split(' ')[0].toLowerCase()}</div>
        </div>
        <div class="t-item-actions">
          <button class="btn btn-gold" data-run="${tn.id}">▶</button>
          <button class="btn" data-edit="${tn.id}">${t('common.edit')}</button>
          <button class="btn btn-danger" data-del="${tn.id}">✕</button>
        </div>`;
      list.appendChild(div);
    });
  }

  /* ---------- EDITOR ---------- */
  function openEditor(tn){
    current = tn;
    show('editor');
    const $ = id => document.getElementById(id);
    $('t-name').value = tn.name;
    $('t-players').value = tn.players;
    $('t-buyin').value = tn.buyIn;
    $('t-stack').value = tn.startingStack;
    $('t-structtype').value = tn.structType;
    $('f-breaks').checked = tn.features.breaks;
    $('f-rebuy').checked = tn.features.rebuy;
    $('f-addon').checked = tn.features.addon;
    $('f-chips').checked = tn.features.chips;
    $('f-prize').checked = tn.features.prize;
    $('rb-until').value = tn.rebuy.untilLevel;
    $('rb-price').value = tn.rebuy.price;
    $('rb-chips').value = tn.rebuy.chips;
    $('ao-break').value = tn.addon.atBreak;
    $('ao-price').value = tn.addon.price;
    $('ao-chips').value = tn.addon.chips;
    document.getElementById('recoHint').hidden = true;
    renderLevels();
    renderChips();
    syncFeatureBlocks();
    renderPrize();
    applyI18n();
  }
  function collectEditor(){
    const $ = id => document.getElementById(id);
    current.name = $('t-name').value.trim();
    current.players = +$('t-players').value || 0;
    current.buyIn = +$('t-buyin').value || 0;
    current.startingStack = +$('t-stack').value || 0;
    current.structType = $('t-structtype').value;
    current.features = {
      breaks:$('f-breaks').checked, rebuy:$('f-rebuy').checked, addon:$('f-addon').checked,
      chips:$('f-chips').checked, prize:$('f-prize').checked
    };
    current.rebuy = { untilLevel:+$('rb-until').value||1, price:+$('rb-price').value||0, chips:+$('rb-chips').value||0 };
    current.addon = { atBreak:+$('ao-break').value||1, price:+$('ao-price').value||0, chips:+$('ao-chips').value||0 };
  }
  function persistCurrent(){
    collectEditor();
    const arr = loadAll();
    const i = arr.findIndex(x=>x.id===current.id);
    if (i>=0) arr[i]=current; else arr.push(current);
    saveAll(arr);
  }

  function renderLevels(){
    const body = document.getElementById('levelsBody');
    body.innerHTML = '';
    let n = 0;
    current.levels.forEach((lv, idx)=>{
      const tr = document.createElement('tr');
      if (lv.type==='break'){
        tr.className = 'is-break';
        tr.innerHTML = `
          <td class="row-num">—</td>
          <td colspan="3" class="break-cell">${t('break')}</td>
          <td><input type="number" min="1" value="${lv.durationMin}" data-idx="${idx}" data-k="durationMin"></td>
          <td><button class="del-row" data-del-row="${idx}">✕</button></td>`;
      } else {
        n++;
        tr.innerHTML = `
          <td class="row-num">${n}</td>
          <td><input type="number" min="0" value="${lv.sb}" data-idx="${idx}" data-k="sb"></td>
          <td><input type="number" min="0" value="${lv.bb}" data-idx="${idx}" data-k="bb"></td>
          <td><input type="number" min="0" value="${lv.ante}" data-idx="${idx}" data-k="ante"></td>
          <td><input type="number" min="1" value="${lv.durationMin}" data-idx="${idx}" data-k="durationMin"></td>
          <td><button class="del-row" data-del-row="${idx}">✕</button></td>`;
      }
      body.appendChild(tr);
    });
  }

  function renderChips(){
    const wrap = document.getElementById('chipsList');
    wrap.innerHTML = '';
    current.chips.forEach((c, idx)=>{
      const row = document.createElement('div');
      row.className = 'chip-row';
      row.innerHTML = `
        <span class="chip-dot" style="background:${c.color}"></span>
        <input type="number" min="1" value="${c.value}" data-cidx="${idx}" data-ck="value">
        <input type="color" value="${c.color}" data-cidx="${idx}" data-ck="color">
        <button class="del-row" data-del-chip="${idx}">✕</button>`;
      wrap.appendChild(row);
    });
    renderChipStats();
  }
  function renderChipStats(){
    const el = document.getElementById('chipStats');
    const stack = +document.getElementById('t-stack').value || current.startingStack;
    const players = +document.getElementById('t-players').value || current.players;
    const total = stack*players + (current.features.rebuy ? stack*Math.ceil(players/2) : 0);
    el.innerHTML = `${t('chip.perplayer',{n:stack.toLocaleString()})}<br>${t('chip.total',{n:total.toLocaleString()})}`;
  }

  function renderPrize(){
    const el = document.getElementById('prizeInfo');
    const players = +document.getElementById('t-players').value || current.players;
    const buyIn = +document.getElementById('t-buyin').value || current.buyIn;
    const rebuys = current.counts.rebuys||0, addons = current.counts.addons||0;
    const pool = players*buyIn + rebuys*current.rebuy.price + addons*current.addon.price;
    const places = players<=8?2:players<=18?3:players<=30?4:5;
    const pcts = { 2:[65,35], 3:[50,30,20], 4:[45,27,18,10], 5:[40,25,18,12,5] }[places];
    let rows = pcts.map((p,i)=>`<div>${i+1}. — <b>${Math.round(pool*p/100).toLocaleString()}</b> (${p}%)</div>`).join('');
    el.innerHTML = `<div>${t('prize.pool')}: <b>${pool.toLocaleString()}</b></div>
      <div>${t('prize.entries')}: ${players}${rebuys?` + ${rebuys} rebuy`:''}${addons?` + ${addons} add-on`:''}</div>
      <div style="margin-top:8px">${t('prize.payouts')}:</div>${rows}`;
  }

  function syncFeatureBlocks(){
    const f = {
      breaks:document.getElementById('f-breaks').checked,
      rebuy:document.getElementById('f-rebuy').checked,
      addon:document.getElementById('f-addon').checked,
      chips:document.getElementById('f-chips').checked,
      prize:document.getElementById('f-prize').checked,
    };
    document.querySelectorAll('.feature-block').forEach(el=>{
      el.hidden = !f[el.dataset.feature];
    });
  }

  /* ---------- Recommend button ---------- */
  function doRecommend(){
    const players = +document.getElementById('t-players').value || 9;
    const type = document.getElementById('t-structtype').value;
    const r = recommend(players, type);
    document.getElementById('t-stack').value = r.stack;
    current.startingStack = r.stack;
    current.levels = buildLevels(r.levels, r.levelMin, document.getElementById('f-breaks').checked, true);
    current.chips = recommendChips(r.stack);
    renderLevels(); renderChips(); renderChipStats();
    const hint = document.getElementById('recoHint');
    hint.hidden = false;
    hint.textContent = t('reco.done',{ n:players, type:t('preset.'+type), lvls:r.levels, min:r.levelMin, stack:r.stack.toLocaleString() });
  }

  /* ---------- TIMER ---------- */
  function startRun(tn){
    current = tn;
    run = { idx:0, remaining: stepSeconds(tn,0), running:false, totalElapsed:0 };
    show('timer');
    document.getElementById('timerName').textContent = tn.name || t('t.untitled');
    renderTimer();
  }
  const stepSeconds = (tn,i) => (tn.levels[i] ? tn.levels[i].durationMin*60 : 0);
  function currentLevelNumber(tn, idx){
    let n=0; for (let i=0;i<=idx;i++){ if (tn.levels[i] && tn.levels[i].type==='level') n++; } return n;
  }
  function nextLevelObj(tn, idx){
    for (let i=idx+1;i<tn.levels.length;i++){ if (tn.levels[i].type==='level') return tn.levels[i]; }
    return null;
  }
  function fmt(sec){
    sec = Math.max(0, Math.round(sec));
    const h = Math.floor(sec/3600), m = Math.floor((sec%3600)/60), s = sec%60;
    const mm = String(m).padStart(2,'0'), ss = String(s).padStart(2,'0');
    return h>0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
  }
  function fmtH(sec){
    sec=Math.max(0,Math.round(sec));
    const h=Math.floor(sec/3600),m=Math.floor((sec%3600)/60),s=sec%60;
    return [h,m,s].map(x=>String(x).padStart(2,'0')).join(':');
  }
  function renderTimer(){
    const tn = current, lv = tn.levels[run.idx];
    const clock = document.getElementById('bigClock');
    clock.textContent = fmt(run.remaining);
    clock.className = 'big-clock' + (run.remaining<=10?' danger':run.remaining<=60?' warn':'');
    document.getElementById('totalElapsed').textContent = fmtH(run.totalElapsed);

    const blindsBox = document.getElementById('blindsBox');
    const breakBox = document.getElementById('breakBox');
    const lvlLabel = document.getElementById('levelNum').parentElement;
    if (lv && lv.type==='break'){
      blindsBox.hidden = true; breakBox.hidden = false; lvlLabel.style.visibility='hidden';
    } else if (lv){
      blindsBox.hidden = false; breakBox.hidden = true; lvlLabel.style.visibility='visible';
      document.getElementById('levelNum').textContent = currentLevelNumber(tn, run.idx);
      document.getElementById('curSB').textContent = lv.sb;
      document.getElementById('curBB').textContent = lv.bb;
      const anteEl = document.querySelector('.bl-ante');
      anteEl.style.display = lv.ante ? '' : 'none';
      document.getElementById('curAnte').textContent = lv.ante;
      const nx = nextLevelObj(tn, run.idx);
      document.getElementById('nextBlinds').textContent = nx ? `${nx.sb} / ${nx.bb}` : '—';
    }

    // rebuy badge
    const badge = document.getElementById('rebuyBadge');
    if (tn.features.rebuy){
      const lvlNo = currentLevelNumber(tn, run.idx);
      const open = lvlNo <= tn.rebuy.untilLevel && (!lv || lv.type==='level');
      badge.hidden = false;
      badge.textContent = open ? t('rebuy.open') : t('rebuy.closed');
      badge.className = 'rebuy-badge ' + (open?'open':'closed');
    } else badge.hidden = true;

    renderTimerStats();
    document.getElementById('playBtn').textContent = run.running ? '⏸' : '▶';
  }
  function renderTimerStats(){
    const tn = current, el = document.getElementById('timerStats');
    const parts = [];
    parts.push(`<span class="st">${t('timer.players')}: <b>${tn.players}</b></span>`);
    const totalChips = tn.startingStack*tn.players + (tn.counts.rebuys||0)*tn.rebuy.chips + (tn.counts.addons||0)*tn.addon.chips;
    if (tn.features.chips){
      const avg = tn.players? Math.round(totalChips/tn.players):0;
      parts.push(`<span class="st">${t('timer.avg')}: <b>${avg.toLocaleString()}</b></span>`);
      parts.push(`<span class="st">${t('timer.totalchips')}: <b>${totalChips.toLocaleString()}</b></span>`);
    }
    if (tn.features.prize){
      const pool = tn.players*tn.buyIn + (tn.counts.rebuys||0)*tn.rebuy.price + (tn.counts.addons||0)*tn.addon.price;
      parts.push(`<span class="st">${t('timer.pool')}: <b>${pool.toLocaleString()}</b></span>`);
    }
    el.innerHTML = parts.join('');
  }

  function tick(){
    run.remaining -= 1; run.totalElapsed += 1;
    if (run.remaining <= 0){
      beep(2);
      goto(run.idx+1, false);
      return;
    }
    if (run.remaining === 60 || run.remaining === 10) beep(1);
    renderTimer();
  }
  function startTick(){ if (!ticker) ticker = setInterval(tick, 1000); }
  function stopTick(){ if (ticker){ clearInterval(ticker); ticker=null; } }
  function togglePlay(){
    run.running = !run.running;
    if (run.running) startTick(); else stopTick();
    renderTimer();
  }
  function goto(idx, resetSame){
    if (idx < 0) idx = 0;
    if (idx >= current.levels.length){ // tournament finished
      run.running=false; stopTick(); run.idx = current.levels.length-1; run.remaining=0; renderTimer(); return;
    }
    run.idx = idx;
    run.remaining = stepSeconds(current, idx);
    renderTimer();
  }

  /* ---------- sound ---------- */
  let audioCtx = null;
  function beep(times){
    if (!soundOn) return;
    try{
      audioCtx = audioCtx || new (window.AudioContext||window.webkitAudioContext)();
      for (let i=0;i<times;i++){
        const o = audioCtx.createOscillator(), g = audioCtx.createGain();
        o.connect(g); g.connect(audioCtx.destination);
        o.frequency.value = 880; o.type='sine';
        const start = audioCtx.currentTime + i*0.22;
        g.gain.setValueAtTime(0.001, start);
        g.gain.exponentialRampToValueAtTime(0.3, start+0.02);
        g.gain.exponentialRampToValueAtTime(0.001, start+0.18);
        o.start(start); o.stop(start+0.2);
      }
    }catch(e){}
  }

  /* ---------- helpers ---------- */
  function escapeHtml(s){ return String(s).replace(/[&<>"']/g, c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }

  /* ---------- events ---------- */
  document.addEventListener('click', e=>{
    const a = e.target.closest('[data-action]');
    if (a){
      const act = a.dataset.action;
      if (act==='home'){ renderHome(); show('home'); }
      else if (act==='new'){ openEditor(newTournament('standard')); }
      else if (act==='start'){ persistCurrent(); startRun(current); }
      else if (act==='edit'){ stopTick(); openEditor(current); }
      return;
    }
    // presets
    const p = e.target.closest('[data-preset]');
    if (p){ openEditor(newTournament(p.dataset.preset)); return; }
    // home item buttons
    const runId = e.target.closest('[data-run]'); if (runId){ const tn=loadAll().find(x=>x.id===runId.dataset.run); if(tn) startRun(tn); return; }
    const edId = e.target.closest('[data-edit]'); if (edId){ const tn=loadAll().find(x=>x.id===edId.dataset.edit); if(tn) openEditor(tn); return; }
    const delId = e.target.closest('[data-del]'); if (delId){ if(confirm(t('confirm.del'))){ saveAll(loadAll().filter(x=>x.id!==delId.dataset.del)); renderHome(); } return; }
    // editor buttons
    if (e.target.id==='recommendBtn'){ doRecommend(); return; }
    if (e.target.id==='addLevel'){ const last=[...current.levels].reverse().find(l=>l.type==='level')||{sb:25,bb:50,ante:0,durationMin:20}; current.levels.push({type:'level',sb:last.bb,bb:last.bb*2,ante:last.ante,durationMin:last.durationMin}); renderLevels(); return; }
    if (e.target.id==='addBreak'){ current.levels.push({type:'break',durationMin:15}); renderLevels(); return; }
    if (e.target.id==='addChip'){ current.chips.push({value:5000,color:'#e0506a'}); renderChips(); return; }
    const dr = e.target.closest('[data-del-row]'); if (dr){ current.levels.splice(+dr.dataset.delRow,1); renderLevels(); return; }
    const dc = e.target.closest('[data-del-chip]'); if (dc){ current.chips.splice(+dc.dataset.delChip,1); renderChips(); return; }
    // timer controls
    if (e.target.id==='playBtn'){ togglePlay(); return; }
    if (e.target.id==='prevBtn'){ goto(run.idx-1); return; }
    if (e.target.id==='nextBtn'){ beep(1); goto(run.idx+1); return; }
    if (e.target.id==='resetBtn'){ run.remaining = stepSeconds(current,run.idx); renderTimer(); return; }
  });

  // editor inputs
  document.addEventListener('input', e=>{
    const idx = e.target.dataset.idx;
    if (idx!==undefined){ current.levels[+idx][e.target.dataset.k] = +e.target.value||0; return; }
    const cidx = e.target.dataset.cidx;
    if (cidx!==undefined){
      const k = e.target.dataset.ck;
      current.chips[+cidx][k] = k==='value' ? (+e.target.value||0) : e.target.value;
      const dot = e.target.closest('.chip-row').querySelector('.chip-dot');
      if (k==='color') dot.style.background = e.target.value;
      return;
    }
    if (['t-players','t-stack','t-buyin'].includes(e.target.id)){ renderChipStats(); renderPrize(); }
  });
  document.addEventListener('change', e=>{
    if (e.target.matches('#f-breaks,#f-rebuy,#f-addon,#f-chips,#f-prize')){
      collectEditor(); syncFeatureBlocks(); renderChipStats(); renderPrize();
    }
  });

  // top bar
  document.getElementById('langSwitch').addEventListener('click', ()=>{
    lang = lang==='cs'?'en':'cs'; localStorage.setItem('pc_lang',lang);
    applyI18n(); renderHome();
    if (!document.getElementById('view-editor').hidden) renderPrize();
    if (!document.getElementById('view-timer').hidden) renderTimer();
  });
  const soundBtn = document.getElementById('soundToggle');
  function updSound(){ soundBtn.textContent = soundOn?'🔊':'🔇'; soundBtn.classList.toggle('off',!soundOn); }
  soundBtn.addEventListener('click', ()=>{ soundOn=!soundOn; localStorage.setItem('pc_sound',soundOn?'1':'0'); updSound(); });

  /* ---------- init ---------- */
  applyI18n(); updSound(); renderHome(); show('home');
})();
