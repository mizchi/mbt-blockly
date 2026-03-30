// Block DnD + Pan + Zoom + Snap + Model update
export function setupInteraction(svgEl) {
  const state = {
    dragging: null,
    panning: false,
    panStart: { x: 0, y: 0 },
    viewBox: { x: 0, y: 0, w: 1200, h: 800 },
    zoom: 1.0,
    lastPinchDist: 0,
    highlightedSlots: [],
    nearestSlot: null,
  };

  const SNAP_DIST = 40;
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

  function highlightSlots(draggedType) {
    clearHighlights();
    svgEl.querySelectorAll('.empty-slot').forEach(slot => {
      const accepts = slot.dataset.accepts || 'expression';
      if (accepts === draggedType || accepts === 'any') {
        slot.setAttribute('fill', 'rgba(100,200,255,0.25)');
        slot.setAttribute('stroke', 'rgba(100,200,255,0.6)');
        slot.setAttribute('stroke-width', '2');
        slot.setAttribute('stroke-dasharray', '');
        state.highlightedSlots.push(slot);
      }
    });
    // ドロップゾーン (statement chain 挿入)
    if (draggedType === 'statement') {
      svgEl.querySelectorAll('.drop-zone').forEach(dz => {
        state.highlightedSlots.push(dz);
      });
    }
  }

  function clearHighlights() {
    state.highlightedSlots.forEach(slot => {
      slot.setAttribute('fill', 'rgba(255,255,255,0.06)');
      slot.setAttribute('stroke', 'rgba(255,255,255,0.12)');
      slot.setAttribute('stroke-width', '1');
      slot.setAttribute('stroke-dasharray', '4 2');
    });
    state.highlightedSlots = [];
    if (state.nearestSlot && !state.nearestSlot._isRect) {
      setBlockGlow(state.nearestSlot.el, false);
    }
    state.nearestSlot = null;
  }

  function findNearestSlot(pt) {
    let nearest = null, minDist = SNAP_DIST;
    state.highlightedSlots.forEach(slot => {
      const pos = getAbsoluteTranslate(slot);
      const rect = slot.getBBox();
      const cx = pos.x + rect.x + rect.width / 2;
      const cy = pos.y + rect.y + rect.height / 2;
      const dist = Math.hypot(pt.x - cx, pt.y - cy);
      if (dist < minDist) { minDist = dist; nearest = slot; }
    });
    return nearest;
  }

  // ブロックの bottom connector 位置を取得
  function findNearestBottomConnector(pt, draggedId, draggedType) {
    if (draggedType !== 'statement') return null;
    let nearest = null, minDist = SNAP_DIST;
    svgEl.querySelectorAll('[data-block-id][data-has-next="true"][data-conn="statement"]').forEach(el => {
      const bid = el.dataset.blockId;
      if (bid === draggedId) return;
      const h = parseFloat(el.dataset.height) || 0;
      if (h === 0) return;
      const pos = getAbsoluteTranslate(el);
      // bottom center = notch position
      const bx = pos.x + 28; // notch x center
      const by = pos.y + h;
      const dist = Math.hypot(pt.x - bx, pt.y - by);
      if (dist < minDist) { minDist = dist; nearest = { el, bid, bx, by }; }
    });
    return nearest;
  }

  // 視覚フィードバック: 接続先ブロックの path を光らせる
  function setBlockGlow(el, on) {
    const path = el.querySelector('path');
    if (!path) return;
    if (on) {
      path._savedStroke = path.getAttribute('stroke');
      path._savedStrokeW = path.getAttribute('stroke-width');
      path.setAttribute('stroke', 'rgba(100,255,150,0.9)');
      path.setAttribute('stroke-width', '3');
      el.style.filter = 'drop-shadow(0 0 4px rgba(100,255,150,0.5))';
    } else {
      if (path._savedStroke) path.setAttribute('stroke', path._savedStroke);
      if (path._savedStrokeW) path.setAttribute('stroke-width', path._savedStrokeW);
      el.style.filter = '';
    }
  }

  function updateSnapTarget(pt) {
    // クリア前の状態をリセット
    if (state.nearestSlot) {
      if (state.nearestSlot._isRect) {
        state.nearestSlot.el.setAttribute('fill', 'rgba(100,200,255,0.25)');
        state.nearestSlot.el.setAttribute('stroke', 'rgba(100,200,255,0.6)');
        state.nearestSlot.el.setAttribute('stroke-width', '2');
      } else {
        setBlockGlow(state.nearestSlot.el, false);
      }
    }

    // 1) 空スロットへの接続判定
    const nearestRect = findNearestSlot(pt);
    // 2) bottom connector への接続判定
    const nearestBottom = state.dragging
      ? findNearestBottomConnector(pt, state.dragging.blockId, state.dragging.type)
      : null;

    // どちらが近いか
    let target = null;
    if (nearestRect && nearestBottom) {
      const rPos = getAbsoluteTranslate(nearestRect);
      const rRect = nearestRect.getBBox();
      const rd = Math.hypot(pt.x - (rPos.x + rRect.x + rRect.width/2), pt.y - (rPos.y + rRect.y + rRect.height/2));
      const bd = Math.hypot(pt.x - nearestBottom.bx, pt.y - nearestBottom.by);
      if (rd < bd) {
        const isDropZone = nearestRect.classList.contains('drop-zone');
        target = isDropZone
          ? { type: 'insert', el: nearestRect, afterId: nearestRect.dataset.insertAfter, _isRect: true }
          : { type: 'slot', el: nearestRect, _isRect: true };
      } else {
        target = { type: 'next', el: nearestBottom.el, bid: nearestBottom.bid, _isRect: false };
      }
    } else if (nearestRect) {
      const isDropZone = nearestRect.classList.contains('drop-zone');
      target = isDropZone
        ? { type: 'insert', el: nearestRect, afterId: nearestRect.dataset.insertAfter, _isRect: true }
        : { type: 'slot', el: nearestRect, _isRect: true };
    } else if (nearestBottom) {
      target = { type: 'next', el: nearestBottom.el, bid: nearestBottom.bid, _isRect: false };
    }

    if (target) {
      if (target._isRect) {
        target.el.setAttribute('fill', 'rgba(100,255,150,0.4)');
        target.el.setAttribute('stroke', 'rgba(100,255,150,0.9)');
        target.el.setAttribute('stroke-width', '3');
      } else {
        setBlockGlow(target.el, true);
      }
    }
    state.nearestSlot = target;
  }

  // --- Pointer Events ---
  // Drag は DOM 操作のみ。モデル更新は pointerup で一括。
  svgEl.addEventListener('pointerdown', (e) => {
    const blockEl = getBlockGroup(e.target);
    if (blockEl) {
      e.preventDefault();
      e.stopPropagation();
      svgEl.setPointerCapture(e.pointerId);

      const blockId = blockEl.dataset.blockId;
      const blockType = api()?.getBlockType(blockId) || 'unknown';

      // ブロックの絶対位置を計算
      const absPos = getAbsoluteTranslate(blockEl);
      const pt = svgPoint(e.clientX, e.clientY);

      // DOM 上で viewport 直下に移動 (親から視覚的に切り離す)
      const viewport = svgEl.querySelector('#viewport');
      if (viewport) {
        // 絶対座標で再配置
        blockEl.setAttribute('transform', `translate(${absPos.x},${absPos.y})`);
        viewport.appendChild(blockEl);
      }

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
        blockId,
        type: blockType,
        el: blockEl,
        ox: pt.x - absPos.x,
        oy: pt.y - absPos.y,
        lastX: absPos.x,
        lastY: absPos.y,
      };

      highlightSlots(blockType);
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
      updateSnapTarget(pt);
    } else if (state.panning) {
      const dx = (e.clientX - state.panStart.x) / state.zoom;
      const dy = (e.clientY - state.panStart.y) / state.zoom;
      state.viewBox.x -= dx;
      state.viewBox.y -= dy;
      state.panStart = { x: e.clientX, y: e.clientY };
      updateViewBox();
    }
  });

  svgEl.addEventListener('pointerup', (e) => {
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

      // モデル更新: まず親から切断
      api()?.detach(blockId);

      if (state.nearestSlot) {
        if (state.nearestSlot.type === 'slot') {
          // 空スロットにスナップ
          const parentId = state.nearestSlot.el.dataset.parent;
          const slotName = state.nearestSlot.el.dataset.slot;
          api()?.connect(parentId, slotName, blockId);
          api()?.moveBlock(blockId, 0, 0);
        } else if (state.nearestSlot.type === 'next') {
          // bottom connector にスナップ → connectNext
          api()?.connectNext(state.nearestSlot.bid, blockId);
          api()?.moveBlock(blockId, 0, 0);
        } else if (state.nearestSlot.type === 'insert') {
          // chain の間に挿入
          api()?.insertAfter(state.nearestSlot.afterId, blockId);
          api()?.moveBlock(blockId, 0, 0);
        }
      } else {
        // 空白にドロップ: トップレベルとして配置
        api()?.moveBlock(blockId, lastX, lastY);
      }

      clearHighlights();
      state.dragging = null;

      // 再描画 + インタラクション再初期化
      const savedVB = { ...state.viewBox };
      const savedZoom = state.zoom;
      api()?.rerender();

      requestAnimationFrame(() => {
        const newSvg = document.querySelector('svg');
        if (newSvg) {
          newSvg.setAttribute('viewBox',
            `${savedVB.x} ${savedVB.y} ${savedVB.w} ${savedVB.h}`);
          setupInteraction(newSvg);
          // Restore zoom state (hacky but works)
          // The new setupInteraction creates fresh state, but viewBox is set
        }
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
    state.viewBox.w *= d;
    state.viewBox.h *= d;
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
        state.viewBox.w *= s;
        state.viewBox.h *= s;
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
