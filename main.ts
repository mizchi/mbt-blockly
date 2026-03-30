import 'mbt:mizchi/mbt-blockly/app';
import { setupInteraction } from './interaction.js';

// Wait for MoonBit to render SVG, then attach interaction
requestAnimationFrame(() => {
  const svg = document.querySelector('svg');
  if (svg) setupInteraction(svg);
});
