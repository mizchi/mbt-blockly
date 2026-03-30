// Block DnD + Pan + Zoom interaction handler
export function setupInteraction(svgEl) {
  const state = {
    dragging: null,
    panning: false,
    panStart: { x: 0, y: 0 },
    viewBox: { x: 0, y: 0, w: 1000, h: 700 },
    zoom: 1.0,
    lastPinchDist: 0,
  };

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
    pt.x = cx;
    pt.y = cy;
    return pt.matrixTransform(svgEl.getScreenCTM().inverse());
  }

  // Pointer events
  svgEl.addEventListener('pointerdown', (e) => {
    const blockEl = getBlockGroup(e.target);
    if (blockEl) {
      e.preventDefault();
      svgEl.setPointerCapture(e.pointerId);
      const pt = svgPoint(e.clientX, e.clientY);
      const m = (blockEl.getAttribute('transform') || '').match(/translate\(([-\d.]+),\s*([-\d.]+)\)/);
      const bx = m ? parseFloat(m[1]) : 0;
      const by = m ? parseFloat(m[2]) : 0;
      state.dragging = { el: blockEl, ox: pt.x - bx, oy: pt.y - by };
      blockEl.style.cursor = 'grabbing';
      blockEl.style.opacity = '0.85';
      blockEl.parentElement.appendChild(blockEl);
    } else {
      state.panning = true;
      state.panStart = { x: e.clientX, y: e.clientY };
      svgEl.style.cursor = 'move';
    }
  });

  svgEl.addEventListener('pointermove', (e) => {
    if (state.dragging) {
      e.preventDefault();
      const pt = svgPoint(e.clientX, e.clientY);
      const nx = pt.x - state.dragging.ox;
      const ny = pt.y - state.dragging.oy;
      state.dragging.el.setAttribute('transform', `translate(${nx},${ny})`);
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
      state.dragging.el.style.cursor = 'grab';
      state.dragging.el.style.opacity = '1';
      state.dragging = null;
    }
    state.panning = false;
    svgEl.style.cursor = 'default';
  });

  svgEl.addEventListener('pointerleave', () => {
    if (state.dragging) {
      state.dragging.el.style.cursor = 'grab';
      state.dragging.el.style.opacity = '1';
      state.dragging = null;
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
    state.viewBox.w = Math.max(200, Math.min(5000, state.viewBox.w));
    state.viewBox.h = Math.max(140, Math.min(3500, state.viewBox.h));
    updateViewBox();
  }, { passive: false });

  // Touch pinch zoom
  svgEl.addEventListener('touchstart', (e) => {
    if (e.touches.length === 2) {
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      state.lastPinchDist = Math.sqrt(dx * dx + dy * dy);
    }
  });

  svgEl.addEventListener('touchmove', (e) => {
    if (e.touches.length === 2) {
      e.preventDefault();
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      const dist = Math.sqrt(dx * dx + dy * dy);
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
        state.viewBox.w = Math.max(200, Math.min(5000, state.viewBox.w));
        state.viewBox.h = Math.max(140, Math.min(3500, state.viewBox.h));
        updateViewBox();
      }
      state.lastPinchDist = dist;
    }
  }, { passive: false });

  svgEl.addEventListener('touchend', () => { state.lastPinchDist = 0; });
}
