// dashboard.js — Router utama, home stats, utils (toast, modal, confirm)
import { requireAdmin, logoutAdmin } from './auth.js';
import { db } from './firebase.js';
import {
  collection, getDocs, query, orderBy, limit,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';

import { initUsers }       from './modules/users.js';
import { initFoodCatalog } from './modules/food-catalog.js';
import { initEducation }   from './modules/education.js';
import { initPatientDetail } from './modules/patient-detail.js';
import { initHealth }      from './modules/health.js';
import { initFoodLogs }    from './modules/food-logs.js';
import { initBroadcast }   from './modules/broadcast.js';

// ── State ──────────────────────────────────────────────────────────
let currentPage = 'home';

// ── Boot ───────────────────────────────────────────────────────────
requireAdmin(async (user) => {
  document.getElementById('userEmail').textContent = user.email;
  document.getElementById('userAvatar').textContent =
    user.email.charAt(0).toUpperCase();
  startClock();
  wireNav();
  wireLogout();
  wireMobileMenu();
  wireRefresh();
  wireModal();
  navigateTo('home');
});

// ── Navigation ─────────────────────────────────────────────────────
function wireNav() {
  document.querySelectorAll('.nav-item[data-page]').forEach((btn) => {
    btn.addEventListener('click', () => {
      navigateTo(btn.dataset.page);
      closeSidebar();
    });
  });
}

export function navigateTo(page) {
  currentPage = page;
  // Active state
  document.querySelectorAll('.nav-item[data-page]').forEach((b) => {
    b.classList.toggle('active', b.dataset.page === page);
  });
  // Page title
  const titles = {
    home:             'Beranda',
    users:            'Manajemen User',
    'food-catalog':   'Katalog Makanan',
    education:        'Edukasi Kesehatan',
    'patient-detail': 'Detail Pasien',
    health:           'Semua Rekam Medis',
    'food-logs':      'Semua Log Makanan',
    broadcast:        'Broadcast Notifikasi',
  };
  document.getElementById('pageTitle').textContent = titles[page] ?? page;

  // Load module
  const main = document.getElementById('mainContent');
  main.innerHTML = `<div class="table-loading"><div class="spinner spinner-lg"></div><span>Memuat...</span></div>`;

  const loaders = {
    home:             loadHome,
    users:            initUsers,
    'food-catalog':   initFoodCatalog,
    education:        initEducation,
    'patient-detail': initPatientDetail,
    health:           initHealth,
    'food-logs':      initFoodLogs,
    broadcast:        initBroadcast,
  };
  (loaders[page] ?? (() => main.innerHTML = '<div class="table-empty">Halaman tidak ditemukan.</div>'))();
}

// ── Home / Dashboard ───────────────────────────────────────────────
async function loadHome() {
  const main = document.getElementById('mainContent');

  try {
    // Fetch semua users
    const usersSnap = await getDocs(collection(db, 'users'));
    const users = usersSnap.docs.map(d => d.data());
    const total = users.length;

    const byDisease = { dm: 0, kidney: 0, heart: 0, ht: 0, other: 0 };
    users.forEach(u => {
      const dt = u.diseaseType ?? '';
      if (dt === 'type2_diabetes_mellitus') byDisease.dm++;
      else if (dt === 'chronic_kidney_disease') byDisease.kidney++;
      else if (dt === 'heart_failure') byDisease.heart++;
      else if (dt === 'hypertension') byDisease.ht++;
      else byDisease.other++;
    });

    // Fetch food_catalog count
    const catalogSnap = await getDocs(collection(db, 'food_catalog'));
    const catalogCount = catalogSnap.size;

    // Fetch education_posts count
    const eduSnap = await getDocs(collection(db, 'education_posts'));
    const eduCount = eduSnap.size;

    // Recent registered users (last 5)
    const recentQ = query(collection(db, 'users'), orderBy('createdAt', 'desc'), limit(5));
    const recentSnap = await getDocs(recentQ);
    const recentUsers = recentSnap.docs.map(d => d.data());

    main.innerHTML = `
      <!-- Stat cards -->
      <div class="section-header">
        <div>
          <h2>Ringkasan Sistem</h2>
          <p>Data real-time dari Firebase Firestore</p>
        </div>
      </div>

      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-icon blue">👥</div>
          <div class="stat-info">
            <strong>${total}</strong>
            <span>Total Pengguna</span>
          </div>
        </div>
        <div class="stat-card" style="cursor:pointer" onclick="window.navigateToPage('food-catalog')">
          <div class="stat-icon green">🍎</div>
          <div class="stat-info">
            <strong>${catalogCount}</strong>
            <span>Katalog Makanan</span>
          </div>
        </div>
        <div class="stat-card" style="cursor:pointer" onclick="window.navigateToPage('education')">
          <div class="stat-icon purple">📚</div>
          <div class="stat-info">
            <strong>${eduCount}</strong>
            <span>Konten Edukasi</span>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon orange">🩺</div>
          <div class="stat-info">
            <strong>${byDisease.dm}</strong>
            <span>Pasien Diabetes</span>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon red">🫘</div>
          <div class="stat-info">
            <strong>${byDisease.kidney}</strong>
            <span>Penyakit Ginjal</span>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon pink">❤️</div>
          <div class="stat-info">
            <strong>${byDisease.heart}</strong>
            <span>Gagal Jantung</span>
          </div>
        </div>
      </div>

      <!-- Disease distribution -->
      <div class="home-double-col" style="display:grid;grid-template-columns:1fr 1fr;gap:1rem;margin-bottom:1.5rem;">
        <div class="card">
          <div class="card-header"><h3>Distribusi Penyakit</h3></div>
          <div class="card-body">
            <div class="disease-bars">
              ${diseaseBar('Diabetes Mellitus', byDisease.dm, total, '#FF8F00')}
              ${diseaseBar('Ginjal Kronis',     byDisease.kidney, total, '#E53935')}
              ${diseaseBar('Gagal Jantung',     byDisease.heart, total, '#EC407A')}
              ${diseaseBar('Hipertensi',        byDisease.ht, total, '#7B1FA2')}
              ${byDisease.other > 0 ? diseaseBar('Lainnya', byDisease.other, total, '#9AA0A6') : ''}
            </div>
          </div>
        </div>

        <!-- Recent users -->
        <div class="card">
          <div class="card-header">
            <h3>Pengguna Terbaru</h3>
            <button class="btn btn-outline btn-sm" onclick="window.navigateToPage('users')">
              <i class="fa fa-arrow-right"></i> Lihat Semua
            </button>
          </div>
          <div class="card-body no-pad">
            <table>
              <thead><tr><th>Nama</th><th>Penyakit</th><th>Daftar</th></tr></thead>
              <tbody>
                ${recentUsers.map(u => `
                  <tr>
                    <td><div class="truncate">${u.name ?? '-'}</div>
                        <div class="text-xs text-muted truncate">${u.email ?? ''}</div></td>
                    <td>${diseaseBadge(u.diseaseType)}</td>
                    <td class="muted text-sm">${fmtDate(u.createdAt)}</td>
                  </tr>`).join('')}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- Quick actions -->
      <div class="card">
        <div class="card-header"><h3>Aksi Cepat</h3></div>
        <div class="card-body">
          <div class="flex gap-3" style="flex-wrap:wrap">
            <button class="btn btn-primary" onclick="window.navigateToPage('users')">
              <i class="fa fa-users"></i> Kelola User
            </button>
            <button class="btn btn-success" onclick="window.navigateToPage('food-catalog')">
              <i class="fa fa-utensils"></i> Tambah Makanan
            </button>
            <button class="btn btn-outline" onclick="window.navigateToPage('education')">
              <i class="fa fa-book-open"></i> Tambah Edukasi
            </button>
            <button class="btn btn-warning" onclick="window.navigateToPage('broadcast')">
              <i class="fa fa-bullhorn"></i> Kirim Broadcast
            </button>
          </div>
        </div>
      </div>
    `;

    // Expose navigateTo untuk onclick html
    window.navigateToPage = navigateTo;

  } catch (err) {
    main.innerHTML = `<div class="table-empty">Gagal memuat data: ${err.message}</div>`;
  }
}

function diseaseBar(label, count, total, color) {
  const pct = total > 0 ? Math.round((count / total) * 100) : 0;
  return `
    <div class="disease-bar-row">
      <span class="disease-bar-label">${label}</span>
      <div class="disease-bar-track">
        <div class="disease-bar-fill" style="width:${pct}%;background:${color}"></div>
      </div>
      <span class="disease-bar-count">${count}</span>
    </div>`;
}

// ── Logout ─────────────────────────────────────────────────────────
function wireLogout() {
  document.getElementById('btnLogout').addEventListener('click', async () => {
    showConfirm('Keluar?', 'Anda akan logout dari admin dashboard.', async () => {
      await logoutAdmin();
    }, 'Keluar', 'btn-danger');
  });
}

// ── Mobile menu ────────────────────────────────────────────────────
function wireMobileMenu() {
  const toggle  = document.getElementById('menuToggle');
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('sidebarOverlay');

  toggle?.addEventListener('click', () => {
    const isOpen = sidebar.classList.toggle('open');
    overlay?.classList.toggle('show', isOpen);
    // Ubah ikon hamburger ↔ X
    const icon = toggle.querySelector('i');
    if (icon) icon.className = isOpen ? 'fa fa-xmark' : 'fa fa-bars';
  });

  // Klik overlay → tutup sidebar
  overlay?.addEventListener('click', closeSidebar);
}

function closeSidebar() {
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('sidebarOverlay');
  const toggle  = document.getElementById('menuToggle');
  sidebar?.classList.remove('open');
  overlay?.classList.remove('show');
  const icon = toggle?.querySelector('i');
  if (icon) icon.className = 'fa fa-bars';
}

// ── Refresh ────────────────────────────────────────────────────────
function wireRefresh() {
  document.getElementById('btnRefresh').addEventListener('click', () => {
    navigateTo(currentPage);
  });
}

// ── Clock ──────────────────────────────────────────────────────────
function startClock() {
  const el = document.getElementById('headerTime');
  const tick = () => {
    el.textContent = new Date().toLocaleString('id-ID', {
      weekday: 'short', day: 'numeric', month: 'short',
      hour: '2-digit', minute: '2-digit',
    });
  };
  tick();
  setInterval(tick, 30_000);
}

// ================================================================
// ── MODAL UTILS (exported for modules) ──────────────────────────
// ================================================================
function wireModal() {
  const overlay = document.getElementById('modalOverlay');
  document.getElementById('modalClose').addEventListener('click', closeModal);
  overlay.addEventListener('click', (e) => { if (e.target === overlay) closeModal(); });

  const covr = document.getElementById('confirmOverlay');
  document.getElementById('confirmClose').addEventListener('click', closeConfirm);
  document.getElementById('confirmCancel').addEventListener('click', closeConfirm);
  covr.addEventListener('click', (e) => { if (e.target === covr) closeConfirm(); });
}

export function openModal(title, bodyHtml, footerHtml = '', large = false) {
  document.getElementById('modalTitle').textContent = title;
  document.getElementById('modalBody').innerHTML = bodyHtml;
  document.getElementById('modalFooter').innerHTML = footerHtml;
  const modal = document.getElementById('modal');
  modal.classList.toggle('modal-lg', large);
  document.getElementById('modalOverlay').classList.add('show');
}
export function closeModal() {
  document.getElementById('modalOverlay').classList.remove('show');
}

export function showConfirm(title, message, onOk, okLabel = 'Hapus', okClass = 'btn-danger') {
  document.getElementById('confirmTitle').textContent = title;
  document.getElementById('confirmBody').innerHTML = `<p>${message}</p>`;
  const okBtn = document.getElementById('confirmOk');
  okBtn.textContent = okLabel;
  okBtn.className = `btn ${okClass}`;
  const newOk = okBtn.cloneNode(true);
  okBtn.replaceWith(newOk);
  newOk.addEventListener('click', async () => {
    closeConfirm();
    await onOk();
  });
  document.getElementById('confirmOverlay').classList.add('show');
}
function closeConfirm() {
  document.getElementById('confirmOverlay').classList.remove('show');
}

// ================================================================
// ── TOAST UTILS (exported) ───────────────────────────────────────
// ================================================================
export function showToast(message, type = 'info', duration = 3500) {
  const icons = { success: '✅', error: '❌', warning: '⚠️', info: 'ℹ️' };
  const container = document.getElementById('toastContainer');
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `<span class="toast-icon">${icons[type]}</span><span class="toast-msg">${message}</span>`;
  container.appendChild(toast);
  toast.addEventListener('click', () => toast.remove());
  setTimeout(() => toast.remove(), duration);
}

// ================================================================
// ── SHARED HELPERS (exported for modules) ───────────────────────
// ================================================================
export function fmtDate(ts) {
  if (!ts) return '-';
  const d = ts.toDate ? ts.toDate() : new Date(ts);
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' });
}

export function diseaseBadge(dt) {
  const map = {
    type2_diabetes_mellitus: ['badge-dm',     'Diabetes'],
    chronic_kidney_disease:  ['badge-kidney', 'Ginjal'],
    heart_failure:           ['badge-heart',  'Jantung'],
    hypertension:            ['badge-ht',     'Hipertensi'],
  };
  const [cls, label] = map[dt] ?? ['badge-neutral', dt ?? '-'];
  return `<span class="badge ${cls}">${label}</span>`;
}

export function paginate(arr, page, perPage) {
  const start = (page - 1) * perPage;
  return { items: arr.slice(start, start + perPage), total: arr.length };
}

export function renderPagination(containerId, currentPage, totalItems, perPage, onPageChange) {
  const totalPages = Math.ceil(totalItems / perPage);
  const el = document.getElementById(containerId);
  if (!el) return;
  const start = (currentPage - 1) * perPage + 1;
  const end   = Math.min(currentPage * perPage, totalItems);
  el.innerHTML = `
    <span>Menampilkan ${start}–${end} dari ${totalItems}</span>
    <div class="pagination-pages">
      <button class="page-btn" ${currentPage <= 1 ? 'disabled' : ''} data-p="${currentPage - 1}">‹</button>
      ${Array.from({ length: Math.min(totalPages, 7) }, (_, i) => {
        const p = i + 1;
        return `<button class="page-btn ${p === currentPage ? 'active' : ''}" data-p="${p}">${p}</button>`;
      }).join('')}
      <button class="page-btn" ${currentPage >= totalPages ? 'disabled' : ''} data-p="${currentPage + 1}">›</button>
    </div>`;
  el.querySelectorAll('.page-btn[data-p]').forEach(b =>
    b.addEventListener('click', () => onPageChange(Number(b.dataset.p))));
}
