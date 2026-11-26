/* vivo-memc WebUI：所有系统操作都排队异步执行，不阻塞界面。 */
(function () {
  "use strict";

  const BIN = "/data/adb/modules/vivo-xfold-frame-interpolation/bin/vivo-memc.sh";
  const $ = (id) => document.getElementById(id);

  /* ---------------- KernelSU exec ---------------- */

  function exec(cmd) {
    return new Promise((resolve, reject) => {
      if (typeof ksu === "undefined" || typeof ksu.exec !== "function") {
        reject(new Error("当前管理器没有提供 ksu.exec"));
        return;
      }
      const name = "vivo_memc_cb_" + Date.now() + "_" + Math.floor(Math.random() * 1e6);
      let settled = false;
      window[name] = (errno, stdout, stderr) => {
        settled = true;
        delete window[name];
        resolve({ errno: errno, stdout: stdout || "", stderr: stderr || "" });
      };
      try {
        ksu.exec(cmd, "{}", name);
      } catch (e) {
        delete window[name];
        reject(e);
        return;
      }
      setTimeout(() => {
        if (!settled) {
          delete window[name];
          reject(new Error("命令超时（25s）"));
        }
      }, 25000);
    });
  }

  async function runRaw(args) {
    const r = await exec("sh " + BIN + " " + args + " 2>&1");
    const out = (r.stdout || "").trim();
    if (out.indexOf("ERROR:") === 0) throw new Error(out.slice(6).trim());
    return out;
  }

  /* ---------------- 串行任务队列 + 状态条 ---------------- */

  let chain = Promise.resolve();
  let pending = 0;

  function setJob(text) {
    if (text) {
      $("jobText").textContent = text;
      $("job").classList.remove("hidden");
    } else {
      $("job").classList.add("hidden");
    }
  }

  function enqueue(label, task, opts) {
    const quiet = opts && opts.quiet;
    pending++;
    if (!quiet) setJob(label + "…");
    chain = chain.then(async () => {
      try {
        const res = await task();
        if (res && !quiet) toast(res);
        return res;
      } catch (e) {
        toast("失败：" + e.message);
        throw e;
      } finally {
        pending--;
        if (pending === 0) setJob("");
      }
    }).catch(() => {});
    return chain;
  }

  /* ---------------- 提示 / 确认 ---------------- */

  let toastTimer = null;
  function toast(msg) {
    const el = $("toast");
    el.textContent = msg;
    el.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove("show"), 2400);
  }

  function confirmBox(title, body) {
    return new Promise((resolve) => {
      $("dlgTitle").textContent = title;
      $("dlgBody").textContent = body;
      $("mask").classList.remove("hidden");
      requestAnimationFrame(() => $("mask").classList.add("show"));
      const done = (v) => {
        $("mask").classList.remove("show");
        setTimeout(() => {
          if (!$("mask").classList.contains("show")) $("mask").classList.add("hidden");
        }, 180);
        $("dlgOk").onclick = null;
        $("dlgCancel").onclick = null;
        resolve(v);
      };
      $("dlgOk").onclick = () => done(true);
      $("dlgCancel").onclick = () => done(false);
    });
  }

  /* ---------------- 状态 ---------------- */

  async function refreshStatus() {
    try {
      const out = await runRaw("status");
      const kv = {};
      out.split("\n").forEach((line) => {
        const i = line.indexOf("=");
        if (i > 0) kv[line.slice(0, i)] = line.slice(i + 1).trim();
      });
      $("stMemc").textContent = kv.memc === "1" ? "已就绪" : (kv.memc || "-");
      $("stIni").textContent = kv.ini === "1" ? "已声明" : "缺失";
      $("stReq").textContent = kv.req || "-";
      $("stEff").textContent = kv.eff || "-";
      $("subLine").textContent = "vivo X Fold2 · " + (kv.ic || "IC 未知");

      const badge = $("capBadge");
      if (kv.memc === "1" && kv.ini === "1") {
        badge.textContent = "能力已就绪";
        badge.className = "badge badge-ok";
      } else {
        badge.textContent = "能力缺失";
        badge.className = "badge badge-bad";
      }
    } catch (e) {
      $("capBadge").textContent = "读取失败";
      $("capBadge").className = "badge badge-bad";
    }
  }

  /* ---------------- 已导入应用 ---------------- */

  let games = [];
  let labels = {};

  async function refreshGames() {
    try {
      const out = await runRaw("games");
      games = out.split("\n").filter(Boolean).map((line) => {
        const [pkg, label, mode, flags] = line.split("\t");
        return { pkg, label, mode, flags: (flags || "").trim().split(/\s+/).filter(Boolean) };
      });
      $("gameCount").textContent = games.length;
      importedSet = new Set(games.map((g) => g.pkg));
      renderGames();
    } catch (e) {
      $("gameList").innerHTML = '<div class="empty">读取失败：' + e.message + "</div>";
    }
  }

  function renderGames() {
    const box = $("gameList");
    if (!games.length) {
      box.innerHTML = '<div class="empty">还没有导入应用，点上面的「导入应用」</div>';
      return;
    }
    box.innerHTML = "";
    games.forEach((g) => box.appendChild(renderGame(g)));
  }

  function renderGame(g) {
    const el = document.createElement("div");
    el.className = "game card-in";

    const head = document.createElement("div");
    head.className = "game-head";
    const info = document.createElement("div");
    info.className = "game-info";
    info.innerHTML =
      '<div class="game-name">' + esc(g.label || g.pkg) + "</div>" +
      '<div class="game-pkg">' + esc(g.pkg) + "</div>";
    const del = document.createElement("button");
    del.className = "btn btn-sm btn-ghost";
    del.textContent = "移除";
    del.onclick = async () => {
      const ok = await confirmBox("移除应用", "将删除 " + (g.label || g.pkg) + " 的插帧配置行，应用本身不受影响。");
      if (!ok) return;
      enqueue("移除 " + (g.label || g.pkg), async () => {
        await runRaw("remove " + g.pkg);
        await refreshGames();
        if (!$("importSheet").classList.contains("hidden")) renderCandidates();
        return "已移除";
      });
    };
    head.appendChild(info);
    head.appendChild(del);
    el.appendChild(head);

    return el;
  }

  /* ---------------- 导入面板 ---------------- */

  let installed = [];
  let importedSet = new Set();
  let showSystem = false;

  function isSystemPkg(p) {
    return p === "android" || p.indexOf("android.") === 0 ||
      p.indexOf("com.android.") === 0 || p.indexOf("com.google.android.") === 0 ||
      p.indexOf("com.vivo.") === 0 || p.indexOf("com.bbk.") === 0 ||
      p.indexOf("com.qualcomm.") === 0 || p.indexOf("com.qti.") === 0;
  }

  let sheetOpen = false;
  let historyPushed = false;

  function showSheet() {
    const el = $("importSheet");
    el.classList.remove("hidden");
    void el.offsetWidth;
    el.classList.add("open");
    document.body.classList.add("sheet-open");
  }

  function hideSheet() {
    const el = $("importSheet");
    el.classList.remove("open");
    document.body.classList.remove("sheet-open");
    setTimeout(() => {
      if (!el.classList.contains("open")) el.classList.add("hidden");
    }, 280);
  }

  async function openImport() {
    if (sheetOpen) return;
    sheetOpen = true;
    showSheet();
    // 让系统返回键回到模块主页：压入一条历史记录，返回时触发 popstate
    try {
      history.pushState({ vivo: "import" }, "");
      historyPushed = true;
    } catch (e) {}
    $("candidateList").innerHTML = '<div class="empty">加载中…</div>';
    enqueue("读取已安装应用", async () => {
      await loadInstalled();
      renderCandidates();
      return null;
    }, { quiet: true }).catch(() => {});
  }

  function closeImport() {
    if (!sheetOpen) return;
    sheetOpen = false;
    hideSheet();
    if (historyPushed) {
      historyPushed = false;
      try { history.back(); } catch (e) {}
    }
  }

  window.addEventListener("popstate", () => {
    if (sheetOpen) {
      sheetOpen = false;
      historyPushed = false;
      hideSheet();
    }
  });

  async function loadInstalled() {
    const out = await runRaw("installed");
    installed = out.split("\n").map((s) => s.trim()).filter(Boolean);
    await loadLabels(installed);
  }

  async function loadLabels(pkgs) {
    if (typeof ksu === "undefined" || typeof ksu.getPackagesInfo !== "function") return;
    const batch = 100;
    for (let i = 0; i < pkgs.length; i += batch) {
      const slice = pkgs.slice(i, i + batch);
      try {
        const info = JSON.parse(ksu.getPackagesInfo(JSON.stringify(slice)) || "[]");
        info.forEach((it) => {
          const pkg = it.packageName || it.package;
          if (pkg) labels[pkg] = it.label || it.appLabel || "";
        });
      } catch (e) {
        /* 拿不到 label 就用包名 */
      }
    }
  }

  function renderCandidates() {
    const box = $("candidateList");
    const q = ($("search").value || "").trim().toLowerCase();
    let pool = showSystem ? installed : installed.filter((p) => !isSystemPkg(p));
    const list = pool.filter((p) => {
      if (!q) return true;
      const label = (labels[p] || "").toLowerCase();
      return p.toLowerCase().indexOf(q) >= 0 || label.indexOf(q) >= 0;
    });
    $("sheetCount").textContent = list.length + " / " + pool.length;
    if (!list.length) {
      box.innerHTML = '<div class="empty">没有匹配的应用</div>';
      return;
    }
    box.innerHTML = "";
    list.slice(0, 500).forEach((pkg) => {
      const row = document.createElement("div");
      row.className = "cand";
      const name = document.createElement("div");
      name.className = "cand-name";
      name.innerHTML =
        '<div class="cand-label">' + esc(labels[pkg] || pkg) + "</div>" +
        '<div class="cand-pkg">' + esc(pkg) + "</div>";
      row.appendChild(name);

      if (importedSet.has(pkg)) {
        const tag = document.createElement("span");
        tag.className = "tag tag-on";
        tag.textContent = "已导入";
        row.appendChild(tag);
      } else {
        const btn = document.createElement("button");
        btn.className = "btn btn-sm";
        btn.textContent = "导入";
        btn.onclick = () => {
          btn.disabled = true;
          btn.textContent = "…";
          const lbl = labels[pkg] || "";
          enqueue("导入 " + (lbl || pkg), async () => {
            const safe = (lbl || "").replace(/'/g, "");
            await runRaw("add " + pkg + (safe ? " '" + safe + "'" : ""));
            await refreshGames();
            renderCandidates();
            return "已导入 " + (lbl || pkg);
          });
        };
        row.appendChild(btn);
      }
      box.appendChild(row);
    });
  }

  /* ---------------- 工具 ---------------- */

  function esc(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  }

  // 把 DB 里 label 还是包名的应用补成真实应用名
  async function backfillLabels() {
    if (typeof ksu === "undefined" || typeof ksu.getPackagesInfo !== "function") return;
    const need = games.filter((g) => !g.label || g.label === g.pkg).map((g) => g.pkg);
    if (!need.length) return;
    await loadLabels(need);
    let changed = 0;
    for (const pkg of need) {
      const lbl = labels[pkg];
      if (lbl && lbl !== pkg) {
        try {
          await runRaw("set-label " + pkg + " '" + lbl.replace(/'/g, "") + "'");
          changed++;
        } catch (e) { /* ignore */ }
      }
    }
    if (changed) await refreshGames();
  }

  /* ---------------- 事件 ---------------- */

  $("importCard").onclick = openImport;
  $("sheetClose").onclick = closeImport;
  $("search").oninput = renderCandidates;
  $("showSystem").onchange = (e) => {
    showSystem = e.target.checked;
    renderCandidates();
  };

  $("btnRefresh").onclick = () => {
    enqueue("刷新", async () => {
      await refreshStatus();
      await refreshGames();
      return "已刷新";
    });
  };

  $("btnRestartGc").onclick = () => {
    enqueue("重启游戏助手", async () => {
      await runRaw("restart-gc");
      await refreshStatus();
      return "游戏助手已重启";
    });
  };

  $("btnReapply").onclick = async () => {
    const ok = await confirmBox("重新应用能力", "会重新挂载配置声明并重启配置 HAL 与系统界面（约 30 秒）。仅在能力缺失时使用。");
    if (!ok) return;
    enqueue("重新应用能力", async () => {
      await runRaw("reapply-cap");
      return "已下发，界面会短暂重建";
    });
  };

  $("btnResetGc").onclick = async () => {
    const ok = await confirmBox("恢复游戏魔盒初始设置",
      "会清空游戏魔盒的全部应用数据：已导入的插帧配置、游戏魔盒自己的「支持游戏」名单、悬浮窗设置全部回到出厂状态，之后需要重新导入应用。确定继续？");
    if (!ok) return;
    enqueue("恢复游戏魔盒初始设置", async () => {
      await runRaw("reset-gc");
      await refreshGames();
      await refreshStatus();
      return "已恢复出厂，请重新导入应用";
    });
  };

  /* ---------------- 启动 ---------------- */

  (async function boot() {
    await refreshStatus();

    try {
      const r = await runRaw("prune");
      const m = /deleted=(\d+)/.exec(r);
      if (m && m[1] !== "0") toast("已清理 " + m[1] + " 个未安装的预置游戏");
    } catch (e) {
      toast("清理失败：" + e.message);
    }

    await refreshGames();
    await backfillLabels();

    if (typeof ksu !== "undefined" && typeof ksu.fullScreen === "function") {
      try { ksu.fullScreen(false); } catch (e) {}
    }
  })();
})();
