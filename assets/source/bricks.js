// Shared drawing helpers for the brick signature: isometric solids (proj, bx, stud), flat bricks (fb), text and small marks.
var BR = {
  coral: ['#ff8a80', '#ff5a4e', '#c9443a'], violet: ['#a79eff', '#8d82ff', '#5b4bff'], lemon: ['#ffe680', '#ffd23f', '#c9a22a'],
  mint: ['#8ff0d2', '#34c9a0', '#239a78'], green: ['#b4ee8a', '#6cc84a', '#4a9a32'], white: ['#ffffff', '#eef4ff', '#c6d3ea']
};
var FLAT = { coral: '#ffb8b0', violet: '#d2ccff', lemon: '#ffeaa6', mint: '#a9efd8', green: '#cbf1ab', white: '#f3f7ff' };
var GREY = ['var(--gt)', 'var(--gl)', 'var(--gr)'];
var ONBRICK = '#0d2342';
var ease = function (x) { return 1 - Math.pow(1 - x, 3); };
var win = function (p, a, b) { return Math.min(1, Math.max(0, (p - a) / (b - a))); };
function esc(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

function proj(cx, cy, u) { var P = function (x, y, z) { return [cx + (x - y) * 0.866 * u, cy + (x + y) * 0.5 * u - z * u]; }; P.u = u; return P; }
function pts(P, list) { return list.map(function (q) { var a = P(q[0], q[1], q[2]); return a[0].toFixed(1) + ',' + a[1].toFixed(1); }).join(' '); }
function poly(P, list, fill, sw, extra) { return '<polygon points="' + pts(P, list) + '" fill="' + fill + '" stroke="var(--edge)" stroke-width="' + sw + '" stroke-linejoin="round" ' + (extra || '') + '/>'; }
function bx(P, x, y, z, w, d, h, c, sw) {
  return poly(P, [[x, y + d, z], [x + w, y + d, z], [x + w, y + d, z + h], [x, y + d, z + h]], c[1], sw) +
    poly(P, [[x + w, y, z], [x + w, y + d, z], [x + w, y + d, z + h], [x + w, y, z + h]], c[2], sw) +
    poly(P, [[x, y, z + h], [x + w, y, z + h], [x + w, y + d, z + h], [x, y + d, z + h]], c[0], sw);
}
function stud(P, x, y, z, r, fill, sw) { var a = P(x, y, z), u = P.u; return '<ellipse cx="' + a[0].toFixed(1) + '" cy="' + (a[1] - 0.14 * u).toFixed(1) + '" rx="' + (1.2247 * u * r).toFixed(1) + '" ry="' + (0.7071 * u * r).toFixed(1) + '" fill="' + fill + '" stroke="var(--edge)" stroke-width="' + sw + '"/>'; }
function studs(P, x, y, ztop, w, d, c, sw) {
  var nx = Math.max(1, Math.round(w / 1.05)), ny = Math.max(1, Math.round(d / 1.05)), r = Math.min(0.3, w / nx / 2.6, d / ny / 2.6), s = '', i, j;
  for (i = 0; i < nx; i++) for (j = 0; j < ny; j++) s += stud(P, x + (i + 0.5) * w / nx, y + (j + 0.5) * d / ny, ztop, r, c[0], sw * 0.6);
  return s;
}
function ghost(P, x, y, z, w, d, sw) { return '<polygon points="' + pts(P, [[x, y, z], [x + w, y, z], [x + w, y + d, z], [x, y + d, z]]) + '" fill="none" stroke="var(--edge)" stroke-width="' + sw + '" stroke-dasharray="5 5"/>'; }
function discI(P, x, y, z, n, o, k) { var a = P(x, y, z); return '<g transform="translate(' + a[0].toFixed(1) + ' ' + a[1].toFixed(1) + ') scale(' + k + ')" opacity="' + o.toFixed(2) + '"><circle r="14" fill="var(--ink)"/><text y="6" text-anchor="middle" font-family="DM Mono" font-size="17" font-weight="500" fill="var(--paper)">' + n + '</text></g>'; }
function lockI(P, x, y, z, k) { var a = P(x, y, z); return '<g transform="translate(' + a[0].toFixed(0) + ' ' + a[1].toFixed(0) + ') scale(' + k + ')"><rect x="-17" y="-4" width="34" height="27" rx="5" fill="#ffd23f" stroke="var(--edge)" stroke-width="1.6"/><path d="M-9 -4 v-9 a9 9 0 0 1 18 0 v9" fill="none" stroke="var(--edge)" stroke-width="4.4"/><circle cy="9" r="3.4" fill="var(--edge)"/></g>'; }
function building(P, sw, k) {
  var h = bx(P, 0, 0, 0, 4, 4, 7, GREY, sw), i, j;
  for (i = 0; i < 2; i++) for (j = 0; j < 3; j++) h += poly(P, [[0.6 + i * 1.6, 4, 1.2 + j * 2], [1.6 + i * 1.6, 4, 1.2 + j * 2], [1.6 + i * 1.6, 4, 2.4 + j * 2], [0.6 + i * 1.6, 4, 2.4 + j * 2]], 'var(--gl)', sw * 0.75, 'opacity=".9"');
  return h + lockI(P, 2, 4, 5.6, k);
}
function baseplate(P, x, y, w, d, sw) {
  var s = bx(P, x, y, 0, w, d, 0.55, BR.mint, sw), i, j;
  for (i = 0; i < Math.round(w / 1.05) - 1; i++) for (j = 0; j < Math.round(d / 1.05) - 1; j++) s += stud(P, x + 0.6 + i * 1.05, y + 0.6 + j * 1.05, 0.55, 0.28, 'var(--stud)', sw * 0.6);
  return s;
}

/* flat (front view) brick with studs on top; o.n studs, o.dash for an optional-looking outline */
function fb(x, y, w, h, fill, o) {
  o = o || {}; var n = o.n === undefined ? Math.max(2, Math.round(w / 70)) : o.n, sw = o.sw || 1.5, s = '', i, sp = w / Math.max(n, 1), dash = o.dash ? ' stroke-dasharray="7 6"' : '';
  for (i = 0; i < n; i++) s += '<rect x="' + (x + sp * i + sp / 2 - 12).toFixed(1) + '" y="' + (y - 9) + '" width="24" height="13" rx="4" fill="' + fill + '" stroke="var(--edge)" stroke-width="' + sw + '"' + dash + '/>';
  return s + '<rect x="' + x + '" y="' + y + '" width="' + w + '" height="' + h + '" rx="9" fill="' + fill + '" stroke="var(--edge)" stroke-width="' + sw + '"' + dash + '/>';
}
function T(x, y, s, size, o) { o = o || {}; return '<text x="' + x + '" y="' + y + '" font-family="' + (o.f || 'DM Mono') + '" font-size="' + size + '" font-weight="' + (o.w || 500) + '" fill="' + (o.fill || 'var(--ink)') + '" text-anchor="' + (o.a || 'start') + '"' + (o.ls ? ' letter-spacing="' + o.ls + '"' : '') + '>' + esc(s) + '</text>'; }
function H(x, y, s, size, o) { o = o || {}; o.f = 'Syne'; o.w = 800; return T(x, y, s, size, o); }
function D(x, y, n) { return '<g transform="translate(' + x + ' ' + y + ')"><circle r="16" fill="var(--ink)"/><text y="7" text-anchor="middle" font-family="DM Mono" font-size="19" font-weight="500" fill="var(--paper)">' + n + '</text></g>'; }
function LOCK(x, y, k) { return '<g transform="translate(' + x + ' ' + y + ') scale(' + (k || 1) + ')"><rect x="-13" y="-4" width="26" height="22" rx="4" fill="#ffd23f" stroke="var(--edge)" stroke-width="1.5"/><path d="M-8 -4 v-8 a8 8 0 0 1 16 0 v8" fill="none" stroke="var(--edge)" stroke-width="3.4"/></g>'; }
function dots(d, w) { return '<path d="' + d + '" fill="none" stroke="var(--edge)" stroke-width="' + (w || 3) + '" stroke-dasharray="1 8" stroke-linecap="round"/>'; }
function mount(id, html) { document.getElementById(id).innerHTML = html; }
