// Block DnD + Pan + Zoom + Notch-based snap
export function setupInteraction(svgEl) {
  const state = {
    dragging: null,
    panning: false,
    panStart: { x: 0, y: 0 },
    viewBox: { x: 0, y: 0, w: 1200, h: 800 },
    zoom: 1.0,
    lastPinchDist: 0,
    snapTarget: null,
  };

  const SNAP_DIST = 40;
  const NOTCH_X = 28; // notch center x offset
  const api = () => window.__mbt;

  function updateViewBox() {
    svgEl.setAttribute('viewBox',
      `${state.viewBox.x} ${state.viewBox.y} ${state.viewBox.w} ${state.viewBox.h}`);
  }

  function getBlockGroup(target) {
    let el = target;
    while (el && el !== svgEl) {
      if (el.dataset && el.dataset.blockId) return el;
      el = el.parentElement;
    }
    return null;
  }

  function svgPoint(cx, cy) {
    const pt = svgEl.createSVGPoint();
    pt.x = cx; pt.y = cy;
    return pt.matrixTransform(svgEl.getScreenCTM().inverse());
  }

  function getAbsoluteTranslate(el) {
    let tx = 0, ty = 0, node = el;
    while (node && node !== svgEl) {
      const transform = node.getAttribute('transform');
      if (transform) {
        const m = transform.match(/translate\(([-\d.]+),\s*([-\d.]+)\)/);
        if (m) { tx += parseFloat(m[1]); ty += parseFloat(m[2]); }
      }
      node = node.parentElement;
    }
    return { x: tx, y: ty };
  }

  // --- Glow feedback ---
  function setBlockGlow(el, on) {
    if (!el) return;
    const path = el.querySelector('path');
    if (!path) return;
    if (on) {
      path._sv = [path.getAttribute('stroke'), path.getAttribute('stroke-width')];
      path.setAttribute('stroke', 'rgba(100,255,150,0.9)');
      path.setAttribute('stroke-width', '3');
      el.style.filter = 'drop-shadow(0 0 6px rgba(100,255,150,0.5))';
    } else {
      if (path._sv) {
        path.setAttribute('stroke', path._sv[0]);
        path.setAttribute('stroke-width', path._sv[1]);
      }
      el.style.filter = '';
    }
  }

  function setSlotGlow(el, on) {
    if (!el) return;
    if (on) {
      el.setAttribute('fill', 'rgba(100,255,150,0.35)');
      el.setAttribute('stroke', 'rgba(100,255,150,0.9)');
      el.setAttribute('stroke-width', '2.5');
      el.setAttribute('stroke-dasharray', '');
    } else {
      el.setAttribute('fill', 'rgba(255,255,255,0.06)');
      el.setAttribute('stroke', 'rgba(255,255,255,0.12)');
      el.setAttribute('stroke-width', '1');
      el.setAttribute('stroke-dasharray', '4 2');
    }
  }

  // --- Snap detection ---
  // ドラッグ中ブロックの top-notch 位置 (= 絶対座標の左上 + notch offset)
  function getDragTopNotch() {
    if (!state.dragging) return null;
    return { x: state.dragging.lastX + NOTCH_X, y: state.dragging.lastY };
  }

  // 全接続ターゲットを探す
  function findSnapTarget(dragId, dragType) {
    const topNotch = getDragTopNotch();
    if (!topNotch) return null;

    let best = null;
    let bestDist = SNAP_DIST;

    // 1) Statement → bottom notch of another statement (凸凹接続)
    if (dragType === 'statement') {
      svgEl.querySelectorAll('[data-block-id][data-has-next="true"][data-conn="statement"]').forEach(el => {
        const bid = el.dataset.blockId;
        if (bid === dragId) return;
        const h = parseFloat(el.dataset.height) || 0;
        if (h === 0) return;
        const pos = getAbsoluteTranslate(el);
        // bottom notch position
        const bx = pos.x + NOTCH_X;
        const by = pos.y + h;
        const dist = Math.hypot(topNotch.x - bx, topNotch.y - by);
        if (dist < bestDist) {
          bestDist = dist;
          best = { type: 'next', el, bid, x: bx, y: by };
        }
      });
    }

    // 2) Empty slot (expression or statement)
    svgEl.querySelectorAll('.empty-slot').forEach(slot => {
      const accepts = slot.dataset.accepts || 'expression';
      if (accepts !== dragType && accepts !== 'any') return;
      const pos = getAbsoluteTranslate(slot);
      const rect = slot.getBBox();
      const cx = pos.x + rect.x + rect.width / 2;
      const cy = pos.y + rect.y + rect.height / 2;
      const dist = Math.hypot(topNotch.x - cx, topNotch.y - cy);
      if (dist < bestDist) {
        bestDist = dist;
        best = { type: 'slot', el: slot, parentId: slot.dataset.parent, slotName: slot.dataset.slot };
      }
    });

    // 3) Drop zone (insert between statements)
    if (dragType === 'statement') {
      svgEl.querySelectorAll('.drop-zone').forEach(dz => {
        const pos = getAbsoluteTranslate(dz);
        const rect = dz.getBBox();
        const cx = pos.x + rect.x + rect.width / 2;
        const cy = pos.y + rect.y + rect.height / 2;
        const dist = Math.hypot(topNotch.x - cx, topNotch.y - cy);
        if (dist < bestDist) {
          bestDist = dist;
          best = { type: 'insert', el: dz, afterId: dz.dataset.insertAfter };
        }
      });
    }

    return best;
  }

  function updateSnap() {
    if (!state.dragging) return;
    // Clear previous
    if (state.snapTarget) {
      if (state.snapTarget.type === 'slot' || state.snapTarget.type === 'insert') {
        setSlotGlow(state.snapTarget.el, false);
      } else {
        setBlockGlow(state.snapTarget.el, false);
      }
    }
    // Find new
    const target = findSnapTarget(state.dragging.blockId, state.dragging.type);
    if (target) {
      if (target.type === 'slot' || target.type === 'insert') {
        setSlotGlow(target.el, true);
      } else {
        setBlockGlow(target.el, true);
      }
    }
    state.snapTarget = target;
  }

  function clearSnap() {
    if (state.snapTarget) {
      if (state.snapTarget.type === 'slot' || state.snapTarget.type === 'insert') {
        setSlotGlow(state.snapTarget.el, false);
      } else {
        setBlockGlow(state.snapTarget.el, false);
      }
    }
    state.snapTarget = null;
  }

  // --- Pointer Events ---
  svgEl.addEventListener('pointerdown', (e) => {
    const blockEl = getBlockGroup(e.target);
    if (blockEl) {
      e.preventDefault();
      e.stopPropagation();
      svgEl.setPointerCapture(e.pointerId);

      const blockId = blockEl.dataset.blockId;
      const blockType = api()?.getBlockType(blockId) || 'unknown';
      const absPos = getAbsoluteTranslate(blockEl);
      const pt = svgPoint(e.clientX, e.clientY);

      // viewport 直下に移動 (視覚的に切り離し)
      const viewport = svgEl.querySelector('#viewport');
      if (viewport) {
        blockEl.setAttribute('transform', `translate(${absPos.x},${absPos.y})`);
        viewport.appendChild(blockEl);
      }

      // ドラッグ glow
      blockEl.style.cursor = 'grabbing';
      blockEl.style.filter = 'drop-shadow(0 0 6px rgba(130,200,255,0.7))';
      const mainPath = blockEl.querySelector('path');
      if (mainPath) {
        mainPath._origStroke = mainPath.getAttribute('stroke');
        mainPath._origStrokeWidth = mainPath.getAttribute('stroke-width');
        mainPath.setAttribute('stroke', 'rgba(130,200,255,0.9)');
        mainPath.setAttribute('stroke-width', '2.5');
      }

      state.dragging = {
        blockId, type: blockType, el: blockEl,
        ox: pt.x - absPos.x, oy: pt.y - absPos.y,
        startX: absPos.x, startY: absPos.y,
        lastX: absPos.x, lastY: absPos.y,
      };
    } else {
      state.panning = true;
      state.panStart = { x: e.clientX, y: e.clientY };
      svgEl.style.cursor = 'move';
    }
  });

  svgEl.addEventListener('pointermove', (e) => {
    if (state.dragging?.el) {
      e.preventDefault();
      const pt = svgPoint(e.clientX, e.clientY);
      const nx = pt.x - state.dragging.ox;
      const ny = pt.y - state.dragging.oy;
      state.dragging.el.setAttribute('transform', `translate(${nx},${ny})`);
      state.dragging.lastX = nx;
      state.dragging.lastY = ny;
      updateSnap();
    } else if (state.panning) {
      const dx = (e.clientX - state.panStart.x) / state.zoom;
      const dy = (e.clientY - state.panStart.y) / state.zoom;
      state.viewBox.x -= dx;
      state.viewBox.y -= dy;
      state.panStart = { x: e.clientX, y: e.clientY };
      updateViewBox();
    }
  });

  svgEl.addEventListener('pointerup', () => {
    if (state.dragging) {
      const { blockId, lastX, lastY, el: dragEl } = state.dragging;

      // 視覚リセット
      if (dragEl) {
        dragEl.style.cursor = '';
        dragEl.style.filter = '';
        const mp = dragEl.querySelector('path');
        if (mp && mp._origStroke) {
          mp.setAttribute('stroke', mp._origStroke);
          mp.setAttribute('stroke-width', mp._origStrokeWidth || '1.5');
        }
      }

      // 開始位置と同じなら何もしない
      const dx = lastX - state.dragging.startX;
      const dy = lastY - state.dragging.startY;
      if (Math.hypot(dx, dy) < 1 && !state.snapTarget) {
        clearSnap();
        state.dragging = null;
        const savedVB = { ...state.viewBox };
        api()?.rerender();
        requestAnimationFrame(() => {
          const s = document.querySelector('svg');
          if (s) { s.setAttribute('viewBox', `${savedVB.x} ${savedVB.y} ${savedVB.w} ${savedVB.h}`); setupInteraction(s); }
        });
        return;
      }

      // モデル更新
      api()?.detach(blockId);

      if (state.snapTarget) {
        const t = state.snapTarget;
        if (t.type === 'slot') {
          api()?.connect(t.parentId, t.slotName, blockId);
          api()?.moveBlock(blockId, 0, 0);
        } else if (t.type === 'next') {
          api()?.connectNext(t.bid, blockId);
          api()?.moveBlock(blockId, 0, 0);
        } else if (t.type === 'insert') {
          api()?.insertAfter(t.afterId, blockId);
          api()?.moveBlock(blockId, 0, 0);
        }
      } else {
        api()?.moveBlock(blockId, lastX, lastY);
      }

      clearSnap();
      state.dragging = null;

      const savedVB = { ...state.viewBox };
      api()?.rerender();
      requestAnimationFrame(() => {
        const s = document.querySelector('svg');
        if (s) { s.setAttribute('viewBox', `${savedVB.x} ${savedVB.y} ${savedVB.w} ${savedVB.h}`); setupInteraction(s); }
      });
      return;
    }
    state.panning = false;
    svgEl.style.cursor = 'default';
  });

  // Wheel zoom
  svgEl.addEventListener('wheel', (e) => {
    e.preventDefault();
    const d = e.deltaY > 0 ? 1.08 : 0.92;
    const pt = svgPoint(e.clientX, e.clientY);
    state.viewBox.w *= d; state.viewBox.h *= d;
    state.viewBox.x += (pt.x - state.viewBox.x) * (1 - d);
    state.viewBox.y += (pt.y - state.viewBox.y) * (1 - d);
    state.zoom /= d;
    state.viewBox.w = Math.max(200, Math.min(6000, state.viewBox.w));
    state.viewBox.h = Math.max(133, Math.min(4000, state.viewBox.h));
    updateViewBox();
  }, { passive: false });

  // Touch pinch
  svgEl.addEventListener('touchstart', (e) => {
    if (e.touches.length === 2) {
      state.lastPinchDist = Math.hypot(
        e.touches[0].clientX - e.touches[1].clientX,
        e.touches[0].clientY - e.touches[1].clientY);
    }
  });
  svgEl.addEventListener('touchmove', (e) => {
    if (e.touches.length === 2) {
      e.preventDefault();
      const dist = Math.hypot(
        e.touches[0].clientX - e.touches[1].clientX,
        e.touches[0].clientY - e.touches[1].clientY);
      if (state.lastPinchDist > 0) {
        const s = state.lastPinchDist / dist;
        const cx = (e.touches[0].clientX + e.touches[1].clientX) / 2;
        const cy = (e.touches[0].clientY + e.touches[1].clientY) / 2;
        const pt = svgPoint(cx, cy);
        state.viewBox.w *= s; state.viewBox.h *= s;
        state.viewBox.x += (pt.x - state.viewBox.x) * (1 - s);
        state.viewBox.y += (pt.y - state.viewBox.y) * (1 - s);
        state.zoom /= s;
        state.viewBox.w = Math.max(200, Math.min(6000, state.viewBox.w));
        state.viewBox.h = Math.max(133, Math.min(4000, state.viewBox.h));
        updateViewBox();
      }
      state.lastPinchDist = dist;
    }
  }, { passive: false });
  svgEl.addEventListener('touchend', () => { state.lastPinchDist = 0; });
}
