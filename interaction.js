// Block DnD + Pan + Zoom + Snap interaction handler
export function setupInteraction(svgEl) {
  const state = {
    dragging: null,
    panning: false,
    panStart: { x: 0, y: 0 },
    viewBox: { x: 0, y: 0, w: 1000, h: 700 },
    zoom: 1.0,
    lastPinchDist: 0,
    highlightedSlots: [],
    nearestSlot: null,
  };

  const SNAP_DIST = 30;

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

  // Get block connector type from data-block-id element
  function getBlockType(blockEl) {
    // Check if it has expression-style path (rounded) or statement-style
    const path = blockEl.querySelector('path');
    if (!path) return 'unknown';
    const d = path.getAttribute('d') || '';
    // Expression blocks use arc (A command), statement blocks use notch
    return d.includes(' A ') ? 'expression' : 'statement';
  }

  // Highlight compatible empty slots
  function highlightSlots(draggedType) {
    clearHighlights();
    const slots = svgEl.querySelectorAll('.empty-slot');
    slots.forEach(slot => {
      const accepts = slot.dataset.accepts || 'expression';
      if (accepts === draggedType || accepts === 'any') {
        slot.setAttribute('fill', 'rgba(100,200,255,0.25)');
        slot.setAttribute('stroke', 'rgba(100,200,255,0.6)');
        slot.setAttribute('stroke-width', '2');
        slot.setAttribute('stroke-dasharray', '');
        state.highlightedSlots.push(slot);
      }
    });
  }

  function clearHighlights() {
    state.highlightedSlots.forEach(slot => {
      slot.setAttribute('fill', 'rgba(255,255,255,0.06)');
      slot.setAttribute('stroke', 'rgba(255,255,255,0.12)');
      slot.setAttribute('stroke-width', '1');
      slot.setAttribute('stroke-dasharray', '4 2');
    });
    state.highlightedSlots = [];
    if (state.nearestSlot) {
      state.nearestSlot = null;
    }
  }

  // Find nearest compatible slot to a point
  function findNearestSlot(pt, draggedType) {
    let nearest = null;
    let minDist = SNAP_DIST;

    state.highlightedSlots.forEach(slot => {
      const rect = slot.getBBox();
      // Get slot center in SVG coords
      let el = slot;
      let tx = 0, ty = 0;
      while (el && el !== svgEl) {
        const transform = el.getAttribute('transform');
        if (transform) {
          const m = transform.match(/translate\(([-\d.]+),\s*([-\d.]+)\)/);
          if (m) {
            tx += parseFloat(m[1]);
            ty += parseFloat(m[2]);
          }
        }
        el = el.parentElement;
      }

      const cx = tx + rect.x + rect.width / 2;
      const cy = ty + rect.y + rect.height / 2;
      const dx = pt.x - cx;
      const dy = pt.y - cy;
      const dist = Math.sqrt(dx * dx + dy * dy);

      if (dist < minDist) {
        minDist = dist;
        nearest = slot;
      }
    });

    return nearest;
  }

  // Update slot glow based on proximity
  function updateSlotGlow(pt, draggedType) {
    // Reset previous nearest
    if (state.nearestSlot) {
      state.nearestSlot.setAttribute('fill', 'rgba(100,200,255,0.25)');
      state.nearestSlot.setAttribute('stroke', 'rgba(100,200,255,0.6)');
      state.nearestSlot.setAttribute('stroke-width', '2');
    }

    const nearest = findNearestSlot(pt, draggedType);
    if (nearest) {
      nearest.setAttribute('fill', 'rgba(100,255,150,0.4)');
      nearest.setAttribute('stroke', 'rgba(100,255,150,0.9)');
      nearest.setAttribute('stroke-width', '3');
      state.nearestSlot = nearest;
    } else {
      state.nearestSlot = null;
    }
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
      const blockType = getBlockType(blockEl);
      state.dragging = { el: blockEl, ox: pt.x - bx, oy: pt.y - by, type: blockType };
      blockEl.style.cursor = 'grabbing';
      blockEl.style.opacity = '0.85';
      blockEl.parentElement.appendChild(blockEl);
      highlightSlots(blockType);
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
      updateSlotGlow(pt, state.dragging.type);
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

      // Snap to nearest slot if close enough
      if (state.nearestSlot) {
        const slot = state.nearestSlot;
        const parentId = slot.dataset.parent;
        const slotName = slot.dataset.slot;
        const blockId = state.dragging.el.dataset.blockId;
        console.log(`[snap] ${blockId} → ${parentId}.${slotName}`);
        // Visual feedback: flash green
        slot.setAttribute('fill', 'rgba(100,255,150,0.6)');
        setTimeout(() => {
          slot.setAttribute('fill', 'rgba(100,200,255,0.25)');
        }, 300);
      }

      clearHighlights();
      state.dragging = null;
    }
    state.panning = false;
    svgEl.style.cursor = 'default';
  });

  svgEl.addEventListener('pointerleave', () => {
    if (state.dragging) {
      state.dragging.el.style.cursor = 'grab';
      state.dragging.el.style.opacity = '1';
      clearHighlights();
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
