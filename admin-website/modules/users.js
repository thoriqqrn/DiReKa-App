// modules/users.js — Manajemen User CRUD
import { db } from '../firebase.js';
import {
  collection, getDocs, doc, deleteDoc,
  query, orderBy,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';
import {
  showToast, openModal, closeModal, showConfirm,
  fmtDate, diseaseBadge, paginate, renderPagination,
} from '../dashboard.js';

const COL = 'users';
const PER_PAGE = 10;

let allUsers   = [];
let filtered   = [];
let curPage    = 1;
let filterDisease = 'all';
let searchQ    = '';

export async function initUsers() {
  const main = document.getElementById('mainContent');
  main.innerHTML = `
    <div class="section-header">
      <div><h2>Manajemen User</h2><p>Daftar seluruh pengguna terdaftar.</p></div>
      <button class="btn btn-success btn-sm" id="btnExportUsers">
        <i class="fa fa-file-excel"></i> Export XLSX
      </button>
    </div>

    <!-- Toolbar -->
    <div class="card" style="margin-bottom:1rem">
      <div class="card-body" style="padding:.75rem 1rem">
        <div class="toolbar">
          <div class="search-box">
            <i class="icon fa fa-search"></i>
            <input type="text" id="userSearch" placeholder="Cari nama / email..." />
          </div>
          <div class="filter-chips" id="diseaseChips">
            <span class="chip active" data-d="all">Semua</span>
            <span class="chip" data-d="type2_diabetes_mellitus">Diabetes</span>
            <span class="chip" data-d="chronic_kidney_disease">Ginjal</span>
            <span class="chip" data-d="heart_failure">Jantung</span>
            <span class="chip" data-d="hypertension">Hipertensi</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Table -->
    <div class="card">
      <div class="card-header">
        <h3 id="userCount">Pengguna</h3>
      </div>
      <div class="card-body no-pad">
        <div class="table-wrap">
          <table id="userTable">
            <thead>
              <tr>
                <th>#</th><th>Nama</th><th>Email</th><th>Penyakit</th>
                <th>Usia</th><th>IMT</th><th>Akun</th><th>Daftar</th><th>Aksi</th>
              </tr>
            </thead>
            <tbody id="userTbody">
              <tr><td colspan="9" class="table-empty"><div class="table-loading"><div class="spinner"></div>Memuat...</div></td></tr>
            </tbody>
          </table>
        </div>
        <div class="pagination" id="userPagination"></div>
      </div>
    </div>`;

  // Wire events
  document.getElementById('userSearch').addEventListener('input', (e) => {
    searchQ = e.target.value.toLowerCase();
    curPage = 1; applyFilter();
  });
  document.getElementById('diseaseChips').addEventListener('click', (e) => {
    const chip = e.target.closest('.chip');
    if (!chip) return;
    filterDisease = chip.dataset.d;
    document.querySelectorAll('#diseaseChips .chip').forEach(c => c.classList.remove('active'));
    chip.classList.add('active');
    curPage = 1; applyFilter();
  });
  document.getElementById('btnExportUsers').addEventListener('click', exportUsers);

  // Load
  await loadUsers();
}

async function loadUsers() {
  try {
    const snap = await getDocs(query(collection(db, COL), orderBy('createdAt', 'desc')));
    allUsers = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    applyFilter();
  } catch (err) {
    document.getElementById('userTbody').innerHTML =
      `<tr><td colspan="9" class="table-empty">Gagal memuat: ${err.message}</td></tr>`;
  }
}

function applyFilter() {
  filtered = allUsers.filter(u => {
    const matchD = filterDisease === 'all' || u.diseaseType === filterDisease;
    const q = searchQ;
    const matchQ = !q ||
      (u.name ?? '').toLowerCase().includes(q) ||
      (u.email ?? '').toLowerCase().includes(q);
    return matchD && matchQ;
  });
  document.getElementById('userCount').textContent = `${filtered.length} Pengguna`;
  renderTable();
}

function renderTable() {
  const { items } = paginate(filtered, curPage, PER_PAGE);
  const tbody = document.getElementById('userTbody');

  if (items.length === 0) {
    tbody.innerHTML = `<tr><td colspan="9" class="table-empty">Tidak ada data.</td></tr>`;
    document.getElementById('userPagination').innerHTML = '';
    return;
  }

  const start = (curPage - 1) * PER_PAGE;
  tbody.innerHTML = items.map((u, i) => {
    const age = calcAge(u.dateOfBirth);
    const isFam = u.isFamilyAccount ? '<span class="badge badge-warning">Keluarga</span>' : '';
    return `<tr>
      <td class="muted">${start + i + 1}</td>
      <td>
        <div class="fw-600">${u.name ?? '-'}</div>
        ${isFam}
      </td>
      <td class="muted text-sm"><div class="truncate">${u.email ?? '-'}</div></td>
      <td>${diseaseBadge(u.diseaseType)}</td>
      <td class="muted">${age ?? '-'}</td>
      <td class="muted">${u.bmi ? Number(u.bmi).toFixed(1) : '-'}</td>
      <td><span class="badge badge-neutral">${u.gender ?? '-'}</span></td>
      <td class="muted text-sm">${fmtDate(u.createdAt)}</td>
      <td>
        <div class="actions">
          <button class="btn btn-ghost btn-sm btn-view" title="Detail" data-id="${u.id}">
            <i class="fa fa-eye"></i>
          </button>
          <button class="btn btn-ghost btn-sm btn-del" title="Hapus" data-id="${u.id}" data-name="${u.name ?? u.email}">
            <i class="fa fa-trash"></i>
          </button>
        </div>
      </td>
    </tr>`;
  }).join('');

  // Wire row actions
  tbody.querySelectorAll('.btn-view').forEach(btn =>
    btn.addEventListener('click', () => viewUser(btn.dataset.id)));
  tbody.querySelectorAll('.btn-del').forEach(btn =>
    btn.addEventListener('click', () =>
      showConfirm('Hapus User?',
        `Hapus akun <strong>${btn.dataset.name}</strong>? Tindakan ini tidak dapat dibatalkan.`,
        () => deleteUser(btn.dataset.id))));

  renderPagination('userPagination', curPage, filtered.length, PER_PAGE, (p) => {
    curPage = p; renderTable();
  });
}

function viewUser(uid) {
  const u = allUsers.find(x => x.id === uid);
  if (!u) return;
  const age = calcAge(u.dateOfBirth);

  const body = `
    <div class="detail-section-title">Informasi Pribadi</div>
    <div class="detail-grid">
      ${di('Nama Lengkap', u.name)}
      ${di('Email', u.email)}
      ${di('Gender', u.gender)}
      ${di('Tgl Lahir', fmtDate(u.dateOfBirth))}
      ${di('Usia', age ? age + ' tahun' : '-')}
      ${di('Pendidikan', u.education)}
      ${di('Pekerjaan', u.occupation)}
    </div>

    <div class="detail-section-title">Domisili</div>
    <div class="detail-grid">
      ${di('Desa/Kel', u.addressVillage)}
      ${di('Kecamatan', u.addressDistrict)}
      ${di('Kota/Kab', u.addressCity)}
      ${di('Provinsi', u.addressProvince)}
    </div>

    <div class="detail-section-title">Parameter Klinis</div>
    <div class="detail-grid">
      ${di('Penyakit', diseaseBadge(u.diseaseType))}
      ${di('Berat Badan', u.weight ? u.weight + ' kg' : '-')}
      ${di('Tinggi Badan', u.height ? u.height + ' cm' : '-')}
      ${di('IMT', u.bmi ? Number(u.bmi).toFixed(1) : '-')}
      ${di('Berat Badan Ideal', u.bbi ? u.bbi + ' kg' : '-')}
      ${di('Level Aktivitas', u.activityLevel ?? '-')}
    </div>

    ${u.diseaseType === 'type2_diabetes_mellitus' ? `
    <div class="detail-section-title">Data Diabetes</div>
    <div class="detail-grid">
      ${di('Lama DM', u.diabetesDurationYears ? u.diabetesDurationYears + ' tahun' : '-')}
      ${di('Terapi Insulin', u.usesInsulinTherapy ? 'Ya' : 'Tidak')}
      ${u.usesInsulinTherapy ? di('Lama Insulin', u.insulinDurationYears + ' tahun') : ''}
    </div>` : ''}

    ${u.diseaseType === 'chronic_kidney_disease' ? `
    <div class="detail-section-title">Data Ginjal</div>
    <div class="detail-grid">
      ${di('Output Urin', u.urinOutput ? u.urinOutput + ' ml/hari' : '-')}
      ${di('Edema', u.hasEdema ? 'Ya' : 'Tidak')}
    </div>` : ''}

    ${u.diseaseType === 'heart_failure' ? `
    <div class="detail-section-title">Data Jantung</div>
    <div class="detail-grid">
      ${di('Lama Penyakit', u.heartDiseaseDurationYears ? u.heartDiseaseDurationYears + ' tahun' : '-')}
    </div>` : ''}

    ${u.diseaseType === 'hypertension' ? `
    <div class="detail-section-title">Data Hipertensi</div>
    <div class="detail-grid">
      ${di('Lama HT', u.hypertensionDurationYears ? u.hypertensionDurationYears + ' tahun' : '-')}
      ${di('Riwayat Keluarga', u.hypertensionFamilyHistory ? 'Ya' : 'Tidak')}
      ${di('Rutin Minum Obat', u.hypertensionRoutineMeds ? 'Ya' : 'Tidak')}
      ${di('Hamil', u.isPregnant ? 'Ya (trimester ' + (u.pregnancyTrimester ?? '?') + ')' : 'Tidak')}
    </div>` : ''}

    <div class="detail-section-title">Info Akun</div>
    <div class="detail-grid">
      ${di('UID', `<span class="text-xs text-muted">${u.id}</span>`)}
      ${di('Tipe Akun', u.isFamilyAccount ? '<span class="badge badge-warning">Keluarga</span>' : 'Utama')}
      ${di('Streak Saat Ini', u.currentStreak ?? '-')}
      ${di('Streak Terpanjang', u.longestStreak ?? '-')}
      ${di('Tgl Daftar', fmtDate(u.createdAt))}
      ${di('Login Terakhir', fmtDate(u.lastLoginDate))}
    </div>`;

  openModal(`Detail User — ${u.name ?? u.email}`, body,
    `<button class="btn btn-danger" onclick="window._deleteUser('${u.id}','${u.name ?? u.email}')">
       <i class="fa fa-trash"></i> Hapus Akun
     </button>
     <button class="btn btn-outline" onclick="window._closeModal()">Tutup</button>`,
    true);

  window._deleteUser = (id, name) => {
    closeModal();
    showConfirm('Hapus User?',
      `Hapus akun <strong>${name}</strong>? Tidak dapat dibatalkan.`,
      () => deleteUser(id));
  };
  window._closeModal = closeModal;
}

async function deleteUser(uid) {
  try {
    await deleteDoc(doc(db, COL, uid));
    allUsers = allUsers.filter(u => u.id !== uid);
    applyFilter();
    showToast('Akun berhasil dihapus.', 'success');
  } catch (err) {
    showToast('Gagal hapus: ' + err.message, 'error');
  }
}

// ── Export XLSX (menggunakan SheetJS via CDN) ─────────────────────
async function exportUsers() {
  if (typeof XLSX === 'undefined') {
    await loadScript('https://cdn.sheetjs.com/xlsx-0.20.1/package/dist/xlsx.full.min.js');
  }
  const rows = filtered.map((u, i) => ({
    No: i + 1,
    Nama: u.name ?? '',
    Email: u.email ?? '',
    Gender: u.gender ?? '',
    'Tgl Lahir': fmtDate(u.dateOfBirth),
    Usia: calcAge(u.dateOfBirth) ?? '',
    Penyakit: u.diseaseType ?? '',
    'BB (kg)': u.weight ?? '',
    'TB (cm)': u.height ?? '',
    IMT: u.bmi ? Number(u.bmi).toFixed(1) : '',
    'Level Aktivitas': u.activityLevel ?? '',
    'Tipe Akun': u.isFamilyAccount ? 'Keluarga' : 'Utama',
    'Tgl Daftar': fmtDate(u.createdAt),
  }));
  const ws = XLSX.utils.json_to_sheet(rows);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Users');
  XLSX.writeFile(wb, `direka_users_${today()}.xlsx`);
  showToast('Export berhasil!', 'success');
}

// ── Helpers ────────────────────────────────────────────────────────
function di(label, value) {
  return `<div class="detail-item"><label>${label}</label><span>${value ?? '-'}</span></div>`;
}
function calcAge(dob) {
  if (!dob) return null;
  const d = dob.toDate ? dob.toDate() : new Date(dob);
  const diff = Date.now() - d.getTime();
  return Math.floor(diff / (1000 * 60 * 60 * 24 * 365.25));
}
function today() {
  return new Date().toISOString().slice(0, 10);
}
function loadScript(src) {
  return new Promise((res, rej) => {
    const s = document.createElement('script');
    s.src = src; s.onload = res; s.onerror = rej;
    document.head.appendChild(s);
  });
}
