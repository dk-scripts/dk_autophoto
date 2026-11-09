/* ============================================================================
   dk_autophoto — NUI logic (vanilla JS, sem build)
   Comunicação: JS -> Lua via fetch(https://<resource>/<callback>)
                Lua -> JS via window 'message' { action, data }
   ========================================================================== */

(() => {
    "use strict";

    const RESOURCE = (typeof GetParentResourceName === "function")
        ? GetParentResourceName() : "dk_autophoto";

    // estado local da UI
    const ui = {
        loc: {},                 // textos (uiPack)
        categories: {},          // category -> { isProp, slot }
        order: [],               // ordem das categorias
        selected: {},            // category -> bool
        counts: {},              // category -> nº de drawables (de getCounts)
        variations: {},          // category -> Set<number> de drawables marcados explicitamente
        expanded: null,          // categoria aberta no acordeão (uma por vez)
        anchor: null,            // { category, index } para o cálculo do Shift
        pendingDrag: null,       // { category, index, total, mark } drag armado (ainda não iniciou)
        dragging: null,          // { category, mark } durante o drag real
        dragJustEnded: false,    // engole o click "fantasma" logo após um drag
        textures: "first",
        camera: {},              // camState atual
        squareSize: 0.62,
        lock: "free",            // trava "prender câmera" atual
        lockTargets: [],         // keys das opções do dropdown (em ordem)
        cameraMode: "auto",      // "auto" | "fixed"
        activeCategory: null,    // categoria cujo perfil está em edição/preview
        running: false,
        paused: false,
    };

    // ---- helpers ---------------------------------------------------------
    const $ = (id) => document.getElementById(id);
    const app = $("app");

    async function post(name, body) {
        try {
            const res = await fetch(`https://${RESOURCE}/${name}`, {
                method: "POST",
                headers: { "Content-Type": "application/json; charset=UTF-8" },
                body: JSON.stringify(body || {}),
            });
            return await res.json();
        } catch (e) {
            return { success: false, error: "nui_fetch_failed" };
        }
    }

    function t(key, fallback) {
        return (ui.loc && ui.loc[key]) || fallback || key;
    }

    let toastTimer = null;
    function toast(msg) {
        let el = $("toast");
        if (!el) {
            el = document.createElement("div");
            el.id = "toast";
            el.className = "toast";
            document.body.appendChild(el);
        }
        el.textContent = msg;
        el.classList.add("show");
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => el.classList.remove("show"), 2200);
    }

    // ---- tema ------------------------------------------------------------
    function applyTheme(theme) {
        if (!theme) return;
        const root = document.documentElement.style;
        for (const [k, v] of Object.entries(theme)) {
            root.setProperty(`--dk-${k}`, v);
        }
    }

    // ---- i18n nos elementos estáticos ------------------------------------
    function applyLabels() {
        const map = {
            title: "title", subtitle: "subtitle",
            tabCategories: "tabCategories", tabCamera: "tabCamera", tabCapture: "tabCapture",
            btnSelectAll: "selectAll", btnSelectNone: "selectNone",
            lblComponents: "components", lblProps: "props",
            lblGender: "gender", optMale: "male", optFemale: "female",
            btnReposition: "reposition", btnResetCamera: "resetCamera",
            repositionHint: "repositionHint", lblTextures: "texturesLabel",
            lblLockCamera: "lockCamera",
            lblCameraMode: "cameraMode", optModeAuto: "cameraAuto", optModeFixed: "cameraFixed",
            lblActiveCategory: "activeCategory", btnSaveProfile: "saveCategoryProfile",
            optTexFirst: "texFirst", optTexAll: "texAll",
            btnStart: "start", btnPause: "pause", btnResume: "resume",
            btnStop: "stop", btnRetry: "retryFailed",
            lblSaved: "saved", lblFailed: "failed", lblRemaining: "remaining", lblEta: "eta",
            selectionHint: "selectionHint",
        };
        for (const [id, key] of Object.entries(map)) {
            const el = $(id);
            if (el && ui.loc[key]) el.textContent = ui.loc[key];
        }
    }

    // ---- categorias (acordeão + grade de variações) ----------------------
    function catName(cat) {
        return (ui.loc.categories && ui.loc.categories[cat]) || cat;
    }

    function isAllSelected(cat) {
        // categoria marcada + sem variações explícitas = todas
        const set = ui.variations[cat];
        return ui.selected[cat] && (!set || set.size === 0);
    }

    function selectedCount(cat) {
        const total = ui.counts[cat] || 0;
        if (!ui.selected[cat]) return 0;
        if (isAllSelected(cat)) return total;
        return ui.variations[cat].size;
    }

    function ensureSet(cat) {
        if (!ui.variations[cat]) ui.variations[cat] = new Set();
        return ui.variations[cat];
    }

    function buildCategories() {
        const comp = $("gridComponents");
        const props = $("gridProps");
        comp.innerHTML = "";
        props.innerHTML = "";

        ui.order.forEach((cat) => {
            const def = ui.categories[cat];
            if (!def) return;
            const item = buildAccItem(cat);
            (def.isProp ? props : comp).appendChild(item);
        });
    }

    function buildAccItem(cat) {
        const total = ui.counts[cat] || 0;
        const item = document.createElement("div");
        item.className = "acc-item"
            + (ui.selected[cat] ? " on" : "")
            + (ui.expanded === cat ? " expanded" : "");
        item.dataset.cat = cat;

        const head = document.createElement("div");
        head.className = "acc-head";
        head.innerHTML = `
            <span class="acc-check">${ui.selected[cat] ? "✓" : ""}</span>
            <span class="acc-name">${catName(cat)}</span>
            <span class="acc-count">${selectedCount(cat)} / ${total}</span>
            <span class="acc-caret">▸</span>`;

        // checkbox: liga/desliga a categoria inteira
        head.querySelector(".acc-check").addEventListener("click", (e) => {
            e.stopPropagation();
            ui.selected[cat] = !ui.selected[cat];
            if (!ui.selected[cat]) ui.variations[cat] = new Set();
            buildCategories();
        });
        // resto do cabeçalho: expande/colapsa
        head.addEventListener("click", () => {
            ui.expanded = (ui.expanded === cat) ? null : cat;
            buildCategories();
        });

        item.appendChild(head);

        if (ui.expanded === cat) {
            item.appendChild(buildAccBody(cat, total));
        }
        return item;
    }

    function buildAccBody(cat, total) {
        const body = document.createElement("div");
        body.className = "acc-body";

        const actions = document.createElement("div");
        actions.className = "var-actions";
        actions.innerHTML = `
            <button class="ghost" data-act="all">${t("markAllInCategory", "All")}</button>
            <button class="ghost" data-act="none">${t("clearCategory", "None")}</button>
            <span class="spacer"></span>
            <span class="count">${selectedCount(cat)} / ${total}</span>`;
        actions.querySelector('[data-act="all"]').addEventListener("click", () => {
            ui.selected[cat] = true;
            const set = ensureSet(cat); set.clear();
            for (let i = 0; i < total; i++) set.add(i);
            buildCategories();
        });
        actions.querySelector('[data-act="none"]').addEventListener("click", () => {
            ui.selected[cat] = false;
            ui.variations[cat] = new Set();
            buildCategories();
        });
        body.appendChild(actions);

        const grid = document.createElement("div");
        grid.className = "var-grid";
        grid.tabIndex = 0; // permite Ctrl+A com a grade focada
        for (let i = 0; i < total; i++) grid.appendChild(buildCell(cat, i, total));
        bindGridShortcuts(grid, cat, total);
        body.appendChild(grid);
        return body;
    }

    function cellMarked(cat, idx) {
        if (isAllSelected(cat)) return true; // "todas" => visualmente tudo marcado
        const set = ui.variations[cat];
        return !!(set && set.has(idx));
    }

    function buildCell(cat, idx, total) {
        const cell = document.createElement("button");
        cell.className = "var-cell" + (cellMarked(cat, idx) ? " on" : "");
        cell.dataset.cat = cat;
        cell.dataset.idx = String(idx);
        cell.type = "button";
        cell.innerHTML = `<span class="var-num">${idx}</span>`;

        cell.addEventListener("click", (e) => onCellClick(e, cat, idx, total));
        cell.addEventListener("mousedown", (e) => onCellMouseDown(e, cat, idx, total));
        cell.addEventListener("mouseenter", () => onCellMouseEnter(cat, idx, total));
        return cell;
    }

    // converte o estado implícito "todas" num Set explícito, para poder desmarcar 1 a 1
    function materialize(cat, total) {
        const set = ensureSet(cat);
        if (isAllSelected(cat)) {
            set.clear();
            for (let i = 0; i < total; i++) set.add(i);
        }
        ui.selected[cat] = true;
        return set;
    }

    function setCell(cat, idx, total, mark) {
        const set = materialize(cat, total);
        if (mark) set.add(idx); else set.delete(idx);
        // se esvaziou tudo, mantém categoria marcada (regra "todas" volta a valer)
    }

    // Atualiza UMA célula e os contadores no lugar (sem reconstruir o acordeão).
    // Usado durante o drag: manter o DOM estável garante que o mouseup dispare.
    function paintCellInPlace(cat, idx) {
        const cell = document.querySelector(
            `.acc-item[data-cat="${cat}"] .var-cell[data-idx="${idx}"]`);
        if (cell) cell.classList.toggle("on", cellMarked(cat, idx));
    }

    function refreshCountsInPlace(cat) {
        const total = ui.counts[cat] || 0;
        const item = document.querySelector(`.acc-item[data-cat="${cat}"]`);
        if (!item) return;
        const txt = `${selectedCount(cat)} / ${total}`;
        const head = item.querySelector(".acc-count");
        if (head) head.textContent = txt;
        const body = item.querySelector(".var-actions .count");
        if (body) body.textContent = txt;
        item.classList.toggle("on", !!ui.selected[cat]);
    }

    function onCellClick(e, cat, idx, total) {
        // se um drag de verdade acabou de acontecer, engole este click "fantasma"
        if (ui.dragJustEnded) { ui.dragJustEnded = false; return; }

        if (e.shiftKey && ui.anchor && ui.anchor.category === cat) {
            const a = ui.anchor.index, b = idx;
            const lo = Math.min(a, b), hi = Math.max(a, b);
            const mark = !cellMarked(cat, idx); // estado-alvo = inverso do clicado
            for (let i = lo; i <= hi; i++) setCell(cat, i, total, mark);
        } else {
            const mark = !cellMarked(cat, idx);
            setCell(cat, idx, total, mark);
            ui.anchor = { category: cat, index: idx };
        }
        buildCategories();
    }

    // mousedown apenas ARMA um drag em potencial; não pinta nem mostra o cursor de
    // pintura. Um clique simples (sem mover para outra célula) é tratado só no click.
    function onCellMouseDown(e, cat, idx, total) {
        // nova interação começa: nunca herda o "engole click" de um drag anterior
        // (um drag que termina em célula diferente da origem pode não disparar click).
        ui.dragJustEnded = false;
        if (e.shiftKey) return; // shift é tratado no click
        const mark = !cellMarked(cat, idx);
        ui.pendingDrag = { category: cat, index: idx, total, mark };
    }

    function onCellMouseEnter(cat, idx, total) {
        // promove o drag em potencial a um drag real ao entrar em OUTRA célula
        if (ui.pendingDrag && !ui.dragging && ui.pendingDrag.category === cat
            && idx !== ui.pendingDrag.index) {
            const pd = ui.pendingDrag;
            ui.dragging = { category: cat, mark: pd.mark };
            document.body.classList.add("is-dragging");
            // pinta a célula de origem (onde o mouse desceu) e depois esta — IN PLACE
            setCell(cat, pd.index, pd.total, pd.mark);
            ui.anchor = { category: cat, index: pd.index };
            paintCellInPlace(cat, pd.index);
            setCell(cat, idx, total, pd.mark);
            paintCellInPlace(cat, idx);
            refreshCountsInPlace(cat);
            return;
        }
        if (!ui.dragging || ui.dragging.category !== cat) return;
        setCell(cat, idx, total, ui.dragging.mark);
        paintCellInPlace(cat, idx);
        refreshCountsInPlace(cat);
    }

    function bindGridShortcuts(grid, cat, total) {
        grid.addEventListener("keydown", (e) => {
            if ((e.ctrlKey || e.metaKey) && (e.key === "a" || e.key === "A")) {
                e.preventDefault();
                const set = ensureSet(cat); set.clear();
                for (let i = 0; i < total; i++) set.add(i);
                ui.selected[cat] = true;
                buildCategories();
                // re-foca a grade recém-reconstruída
                const g = document.querySelector(`.acc-item[data-cat="${cat}"] .var-grid`);
                if (g) g.focus();
            }
        });
    }

    function setAll(value) {
        ui.order.forEach((cat) => {
            ui.selected[cat] = value;
            ui.variations[cat] = new Set(); // value=true => "todas" (regra); value=false => nenhuma
        });
        buildCategories();
    }

    // ---- sliders da câmera -----------------------------------------------
    const SLIDERS = [
        { key: "fov",        label: "fov",        min: 12, max: 70, step: 1,    suffix: "°" },
        { key: "distance",   label: "distance",   min: 0.6, max: 4, step: 0.05, suffix: "m" },
        { key: "height",     label: "height",     min: -0.6, max: 1.2, step: 0.02, suffix: "m" },
        { key: "pitch",      label: "pitch",      min: -45, max: 45, step: 1,    suffix: "°" },
        { key: "sideAngle",  label: "angle",      min: 0,  max: 359, step: 3,    suffix: "°" },
        { key: "heightOffset", label: "heightOffset", min: -0.5, max: 0.5, step: 0.02, suffix: "m" },
        { key: "sideOffset",   label: "sideOffset",   min: -0.5, max: 0.5, step: 0.02, suffix: "m" },
    ];

    function buildSliders() {
        const wrap = $("sliders");
        wrap.innerHTML = "";
        SLIDERS.forEach((s) => {
            const row = document.createElement("div");
            row.className = "slider-row";
            const val = ui.camera[s.key] ?? s.min;
            row.innerHTML = `
                <label>${t(s.label, s.label)}</label>
                <input type="range" min="${s.min}" max="${s.max}" step="${s.step}" value="${val}" data-key="${s.key}" />
                <output>${fmt(val, s.suffix)}</output>`;
            const range = row.querySelector("input");
            const out = row.querySelector("output");
            range.addEventListener("input", () => {
                const v = parseFloat(range.value);
                ui.camera[s.key] = v;
                out.textContent = fmt(v, s.suffix);
                pushCameraDebounced();
            });
            wrap.appendChild(row);
        });
        addSquareSizeSlider(wrap);
        // reflete a trava atual (esconde o slider de altura se travado numa parte)
        applyLockToHeightSlider();
    }

    function addSquareSizeSlider(wrap) {
        const row = document.createElement("div");
        row.className = "slider-row";
        const val = ui.squareSize;
        row.innerHTML = `
            <label>${t("squareSize", "Frame")}</label>
            <input type="range" min="0.2" max="1" step="0.02" value="${val}" data-key="square" />
            <output>${Math.round(val * 100)}%</output>`;
        const range = row.querySelector("input");
        const out = row.querySelector("output");
        range.addEventListener("input", () => {
            const v = parseFloat(range.value);
            ui.squareSize = v;
            out.textContent = Math.round(v * 100) + "%";
            // o quadro real é desenhado pelo jogo; aqui só avisamos o tamanho
            post("setSquareSize", { value: v });
        });
        wrap.appendChild(row);
    }

    function fmt(v, suffix) {
        const n = (Math.abs(v) < 10 && suffix === "m") ? v.toFixed(2) : Math.round(v);
        return `${n}${suffix}`;
    }

    let camTimer = null;
    function pushCameraDebounced() {
        clearTimeout(camTimer);
        camTimer = setTimeout(() => post("setCamera", ui.camera), 60);
    }

    // ---- prender câmera (dropdown de partes do corpo) --------------------
    // label de uma key de trava: lock<Key> no locale (ex.: "chest" -> lockChest).
    function lockLabel(key) {
        const cap = key.charAt(0).toUpperCase() + key.slice(1);
        return t("lock" + cap, key);
    }

    function buildLockSelect() {
        const sel = $("lockCamera");
        if (!sel) return;
        sel.innerHTML = "";
        ui.lockTargets.forEach((key) => {
            const opt = document.createElement("option");
            opt.value = key;
            opt.textContent = lockLabel(key);
            sel.appendChild(opt);
        });
        sel.value = ui.lock;
        applyLockToHeightSlider();
    }

    // quando travado numa parte (lock != "free"): a altura é ditada pelo bone
    // (escondemos o slider de altura manual) e os offsets fino (vertical/lateral)
    // passam a fazer sentido, pois só se somam à mira de um bone (ver resolveTarget
    // em capture.lua) — em modo livre eles não têm efeito, então ficam ocultos.
    function applyLockToHeightSlider() {
        const locked = ui.lock !== "free";
        const hide = (key, whenLocked) => {
            const input = document.querySelector(`#sliders input[data-key="${key}"]`);
            const row = input && input.closest(".slider-row");
            if (row) row.hidden = whenLocked ? !locked : locked;
        };
        hide("height", false);
        hide("heightOffset", true);
        hide("sideOffset", true);
    }

    // ---- tabs ------------------------------------------------------------
    function initTabs() {
        document.querySelectorAll(".tab").forEach((tab) => {
            tab.addEventListener("click", () => {
                document.querySelectorAll(".tab").forEach((x) => x.classList.remove("is-active"));
                document.querySelectorAll(".panel").forEach((x) => x.classList.remove("is-active"));
                tab.classList.add("is-active");
                document.querySelector(`.panel[data-panel="${tab.dataset.tab}"]`).classList.add("is-active");
            });
        });
    }

    // ---- modo da câmera (auto x fixa) + peça em foco ---------------------
    function buildActiveCategorySelect() {
        const sel = $("activeCategorySel");
        if (!sel) return;
        sel.innerHTML = "";
        ui.order.forEach((cat) => {
            const opt = document.createElement("option");
            opt.value = cat;
            opt.textContent = catName(cat);
            sel.appendChild(opt);
        });
        if (ui.activeCategory) sel.value = ui.activeCategory;
    }

    // aplica o modo na UI: marca o segmented e liga/desliga a classe mode-fixed
    // (o CSS esconde "peça em foco" e "salvar" no modo fixo).
    function applyCameraModeUI() {
        document.querySelectorAll('.seg-opt[data-mode]').forEach((x) =>
            x.classList.toggle("is-active", x.dataset.mode === ui.cameraMode));
        const panel = document.querySelector('.panel[data-panel="camera"]');
        if (panel) panel.classList.toggle("mode-fixed", ui.cameraMode === "fixed");
    }

    // ---- controles de captura --------------------------------------------
    function selectedList() {
        const out = {};
        let any = false;
        for (const cat of ui.order) {
            if (!ui.selected[cat]) continue;
            any = true;
            const set = ui.variations[cat];
            if (set && set.size > 0) {
                out[cat] = Array.from(set).sort((a, b) => a - b);
            } else {
                out[cat] = true; // sem variações marcadas = a categoria inteira
            }
        }
        return any ? out : null;
    }

    function setRunningUI(running, paused) {
        ui.running = running;
        ui.paused = paused;
        $("btnStart").hidden = running;
        $("btnStop").hidden = !running;
        $("btnPause").hidden = !running || paused;
        $("btnResume").hidden = !running || !paused;
    }

    // ---- aplicar snapshot de progresso -----------------------------------
    const STATUS_TEXT = () => ({
        idle: t("statusIdle", "Ready"),
        running: t("statusRunning", "Capturing…"),
        paused: t("statusPaused", "Paused"),
        done: t("statusDone", "Done"),
        error: t("statusError", "Error"),
    });

    function applyProgress(p) {
        const total = p.total || 0;
        const idx = p.index || 0;
        const pct = total > 0 ? Math.min(100, (idx / total) * 100) : 0;

        $("bar").style.width = pct + "%";
        $("capCounter").textContent = `${idx} / ${total}`;
        $("stSaved").textContent = p.saved ?? 0;
        $("stFailed").textContent = p.failed ?? 0;
        $("stRemaining").textContent = p.remaining ?? 0;
        $("stEta").textContent = p.eta != null ? msToClock(p.eta) : "—";

        const pill = $("capStatus");
        pill.textContent = (STATUS_TEXT())[p.status] || p.status;
        pill.className = "status-pill " + (p.status === "running" ? "running" : p.status === "paused" ? "paused" : p.status === "done" ? "done" : "");

        // viewfinder readout
        const dot = $("vfStatusDot");
        dot.className = "vf-dot " + (p.status === "running" ? "live" : p.status === "done" ? "done" : "");
        $("vfStatus").textContent = (p.status || "ready").toUpperCase();
        $("vfCurrent").textContent = p.current
            ? `${p.current.category} · #${p.current.drawable}/${p.current.texture}`
            : "—";

        const running = p.status === "running" || p.status === "paused";
        setRunningUI(running, p.status === "paused");
        $("btnRetry").hidden = !(p.status === "done" && (p.failed || 0) > 0) && !((p.status === "idle") && (p.failed||0) > 0);
    }

    function msToClock(ms) {
        const s = Math.round(ms / 1000);
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m > 0 ? `${m}m${r.toString().padStart(2, "0")}s` : `${r}s`;
    }

    // ---- wire dos botões -------------------------------------------------
    function bindButtons() {
        $("btnClose").addEventListener("click", close);
        $("btnSelectAll").addEventListener("click", () => setAll(true));
        $("btnSelectNone").addEventListener("click", () => setAll(false));

        document.querySelectorAll(".seg-opt[data-gender]").forEach((b) => {
            b.addEventListener("click", async () => {
                document.querySelectorAll(".seg-opt[data-gender]").forEach((x) => x.classList.remove("is-active"));
                b.classList.add("is-active");
                const r = await post("setGender", { gender: b.dataset.gender });
                // a câmera realinha à parte travada do novo ped; refletimos o
                // novo camState e o estado da trava na UI. As contagens de
                // variações também mudam com o modelo, então reconstruímos a lista.
                if (r.success && r.data) {
                    if (r.data.camera) ui.camera = r.data.camera;
                    if (r.data.lock) ui.lock = r.data.lock;
                    if (r.data.counts) ui.counts = r.data.counts;
                    buildSliders();
                    buildCategories();
                }
            });
        });
        document.querySelectorAll(".seg-opt[data-tex]").forEach((b) => {
            b.addEventListener("click", () => {
                document.querySelectorAll(".seg-opt[data-tex]").forEach((x) => x.classList.remove("is-active"));
                b.classList.add("is-active");
                ui.textures = b.dataset.tex;
                // o client guarda a escolha em config.shared.textures; aqui só a refletimos.
                post("setTextures", { value: b.dataset.tex });
            });
        });

        $("lockCamera").addEventListener("change", async (e) => {
            const r = await post("setLock", { value: e.target.value });
            if (r.success && r.data) {
                ui.lock = r.data.lock || ui.lock;
                if (r.data.camera) ui.camera = r.data.camera;
                applyLockToHeightSlider();
            }
        });

        document.querySelectorAll(".seg-opt[data-mode]").forEach((b) => {
            b.addEventListener("click", async () => {
                const mode = b.dataset.mode;
                if (mode === ui.cameraMode) return;
                const r = await post("setCameraMode", { mode });
                if (r.success && r.data) {
                    ui.cameraMode = r.data.mode || mode;
                    if (r.data.camera) ui.camera = r.data.camera;
                    if (r.data.lock) ui.lock = r.data.lock;
                    if (r.data.activeCategory) ui.activeCategory = r.data.activeCategory;
                    applyCameraModeUI();
                    buildSliders();
                    buildLockSelect();
                    if (ui.activeCategory) $("activeCategorySel").value = ui.activeCategory;
                }
            });
        });

        $("activeCategorySel").addEventListener("change", async (e) => {
            const r = await post("setActiveCategory", { category: e.target.value });
            if (r.success && r.data) {
                ui.activeCategory = r.data.category || e.target.value;
                if (r.data.camera) ui.camera = r.data.camera;
                if (r.data.lock) ui.lock = r.data.lock;
                buildSliders();
                buildLockSelect();
            }
        });

        $("btnSaveProfile").addEventListener("click", async () => {
            if (!ui.activeCategory) return;
            const r = await post("saveCategoryProfile", { category: ui.activeCategory });
            if (r.success) toast(t("profileSaved", "Saved."));
            else toast(r.error || "error");
        });

        $("btnReposition").addEventListener("click", () => {
            post("reposition", {});
            toast(t("repositionHint", "Use arrows / scroll. Enter confirms."));
        });
        $("btnResetCamera").addEventListener("click", async () => {
            const r = await post("resetCamera", {});
            if (r.success && r.data.camera) { ui.camera = r.data.camera; buildSliders(); }
        });

        $("btnStart").addEventListener("click", async () => {
            const sel = selectedList();
            if (!sel) return toast(t("noSelection", "Select at least one category."));
            const r = await post("start", { selected: sel });
            if (!r.success) toast(r.error || "error");
        });
        $("btnPause").addEventListener("click", () => post("pause", {}));
        $("btnResume").addEventListener("click", () => post("resume", {}));
        $("btnStop").addEventListener("click", () => post("stop", {}));
        $("btnRetry").addEventListener("click", async () => {
            const r = await post("retryFailed", {});
            if (!r.success) toast(r.error || "error");
        });
    }

    // ---- open / close ----------------------------------------------------
    function open(data) {
        ui.loc = data.locale || {};
        ui.categories = data.categories || {};
        ui.order = data.order || Object.keys(ui.categories);
        ui.selected = Object.assign({}, data.defaults || {});
        ui.textures = data.textures || "first";
        ui.camera = data.camera || {};
        ui.squareSize = data.squareSize ?? 0.62;
        ui.lockTargets = data.lockTargets || [];
        ui.lock = data.lock || "free";
        ui.cameraMode = data.cameraMode || "auto";
        ui.activeCategory = data.activeCategory || (ui.order && ui.order[0]) || null;

        // seleção de variações: reseta entre aberturas
        ui.counts = {};
        ui.variations = {};
        ui.expanded = null;
        ui.anchor = null;
        ui.pendingDrag = null;
        ui.dragging = null;
        ui.dragJustEnded = false;

        applyTheme(data.theme);
        applyLabels();
        buildCategories();
        buildSliders();
        buildLockSelect();
        buildActiveCategorySelect();
        applyCameraModeUI();

        // reflete gênero/textura iniciais nos segmenteds
        const g = data.gender || "male";
        document.querySelectorAll(".seg-opt[data-gender]").forEach((x) =>
            x.classList.toggle("is-active", x.dataset.gender === g));
        document.querySelectorAll(".seg-opt[data-tex]").forEach((x) =>
            x.classList.toggle("is-active", x.dataset.tex === ui.textures));

        app.hidden = false;
        post("ready", {});

        // contagens vêm do ped (callback separado p/ não travar o open)
        fetchCounts();
    }

    async function fetchCounts() {
        const r = await post("getCounts", {});
        if (r && r.success && r.data) {
            ui.counts = r.data.counts || {};
            buildCategories();
        }
    }

    function close() {
        app.hidden = true;
        post("close", {});
    }

    // ---- recorte quadrado (canvas, sem libs) -----------------------------
    // Recebe o data URI da tela cheia + o crop (x,y,w,h em fração 0..1) e devolve
    // um data URI webp já recortado e redimensionado para size×size.
    function cropToSquare(dataUri, crop, size, encoding, quality) {
        return new Promise((resolve) => {
            const img = new Image();
            img.onload = () => {
                try {
                    const sx = Math.round(crop.x * img.width);
                    const sy = Math.round(crop.y * img.height);
                    const sw = Math.round(crop.w * img.width);
                    // a área é quadrada no mundo, mas em pixels o crop.w/h diferem
                    // pelo aspecto; usamos o menor lado em px para um quadrado exato.
                    const sh = Math.round(crop.h * img.height);
                    const side = Math.min(sw, sh);
                    // re-centraliza dentro da área do quadro-guia
                    const cx = sx + Math.round((sw - side) / 2);
                    const cy = sy + Math.round((sh - side) / 2);

                    const canvas = document.createElement("canvas");
                    canvas.width = size;
                    canvas.height = size;
                    const ctx = canvas.getContext("2d");
                    ctx.imageSmoothingQuality = "high";
                    ctx.drawImage(img, cx, cy, side, side, 0, 0, size, size);

                    const mime = encoding === "png" ? "image/png"
                        : encoding === "jpg" ? "image/jpeg" : "image/webp";
                    resolve(canvas.toDataURL(mime, quality));
                } catch (e) {
                    resolve(null);
                }
            };
            img.onerror = () => resolve(null);
            img.src = dataUri;
        });
    }

    // ---- listener de mensagens do Lua ------------------------------------
    window.addEventListener("message", (event) => {
        const { action, data } = event.data || {};
        if (!action) return;

        switch (action) {
            case "open": open(data || {}); break;
            case "close": app.hidden = true; break;
            case "progress": applyProgress(data || {}); break;
            case "repositionEnd":
                if (data && data.camera) { ui.camera = data.camera; buildSliders(); }
                toast(data && data.confirmed ? "✓" : "✕");
                break;
            case "crop":
                // recorta e devolve ao Lua pelo callback 'cropped' (casado por ticket)
                cropToSquare(data.image, data.crop, data.size, data.encoding, data.quality)
                    .then((out) => post("cropped", { ticket: data.ticket, image: out }));
                break;
        }
    });

    // ESC fecha
    window.addEventListener("keydown", (e) => {
        if (e.key === "Escape" && !app.hidden) close();
    });

    // encerra o drag de seleção em qualquer lugar que soltar o mouse
    window.addEventListener("mouseup", () => {
        if (ui.dragging) {
            // houve drag real: o click "fantasma" que vem a seguir deve ser ignorado
            ui.dragJustEnded = true;
            ui.dragging = null;
            document.body.classList.remove("is-dragging");
            // ressincroniza tudo de uma vez (durante o drag só pintamos no lugar)
            buildCategories();
        }
        ui.pendingDrag = null;
    });

    // ---- init ------------------------------------------------------------
    initTabs();
    bindButtons();
})();
