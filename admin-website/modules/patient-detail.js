// modules/patient-detail.js — Pilih user lalu lihat detail log makanan dan rekam medisnya
import { db } from '../firebase.js';
import {
  collection, getDocs, query, orderBy, where,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';
import {
  fmtDate, diseaseBadge, paginate, renderPagination, showToast
} from '../dashboard.js';

const PER_PAGE = 10;

let allUsers = [];
let filtered = [];
let curPage  = 1;
let searchQ  = '';

export async function initPatientDetail() {
  const main = document.getElementById('mainContent');
  main.innerHTML = `
    <div class="section-header">
      <div><h2>Data Klinis per Pasien</h2><p>Pilih pasien untuk melihat riwayat lengkap makanan dan medisnya.</p></div>
    </div>

    <!-- UI Pemilihan User -->
    <div id="patientSelectorView">
      <div class="card" style="margin-bottom:1rem">
        <div class="card-body" style="padding:.75rem 1rem">
          <div class="search-box" style="max-width:400px">
            <i class="icon fa fa-search"></i>
            <input type="text" id="patientSearch" placeholder="Cari nama / email pasien..." />
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card-header"><h3 id="patientCount">Pilih Pasien</h3></div>
        <div class="card-body no-pad">
          <div class="table-wrap">
            <table>
              <thead>
                <tr><th>#</th><th>Nama</th><th>Email</th><th>Penyakit</th><th>Aksi</th></tr>
              </thead>
              <tbody id="patientTbody">
                <tr><td colspan="5" class="table-empty"><div class="table-loading"><div class="spinner"></div>Memuat data...</div></td></tr>
              </tbody>
            </table>
          </div>
          <div class="pagination" id="patientPagination"></div>
        </div>
      </div>
    </div>

    <!-- UI Detail Pasien (disembunyikan secara default) -->
    <div id="patientDetailView" style="display:none">
      <button class="btn btn-outline mb-3" id="btnBackToPatients">
        <i class="fa fa-arrow-left"></i> Kembali ke Daftar Pasien
      </button>

      <div class="card mb-3">
        <div class="card-body flex items-center justify-between" style="flex-wrap:wrap;gap:1rem">
          <div>
            <h3 style="font-size:1.1rem;margin-bottom:.2rem" id="pdName">-</h3>
            <div class="text-sm text-muted" id="pdEmail">-</div>
          </div>
          <div id="pdDisease"></div>
        </div>
      </div>

      <!-- Tab Buttons -->
      <div class="flex gap-2 mb-3" style="border-bottom:2px solid var(--color-divider);padding-bottom:.5rem">
        <button class="btn btn-primary" id="tabFoodBtn"><i class="fa fa-utensils"></i> Log Makanan</button>
        <button class="btn btn-outline" id="tabHealthBtn"><i class="fa fa-notes-medical"></i> Rekam Medis</button>
      </div>

      <!-- Tab: Log Makanan -->
      <div id="pdFoodTab">
        <div class="card">
          <div class="card-header">
            <h3>Riwayat Log Makanan</h3>
            <button class="btn btn-success btn-sm" id="btnExportPatientFood">
              <i class="fa fa-file-excel"></i> Export XLSX
            </button>
          </div>
          <div class="card-body no-pad">
            <div class="table-wrap">
              <table>
                <thead>
                  <tr><th>Tanggal</th><th>Waktu</th><th>Meal</th><th>Makanan</th><th>Gram</th><th>Kalori</th></tr>
                </thead>
                <tbody id="pdFoodTbody">
                  <tr><td colspan="6" class="table-empty"><div class="table-loading"><div class="spinner"></div>Memuat...</div></td></tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <!-- Tab: Rekam Medis -->
      <div id="pdHealthTab" style="display:none">
        <div class="card">
          <div class="card-header">
            <h3>Riwayat Rekam Medis</h3>
            <button class="btn btn-success btn-sm" id="btnExportPatientHealth">
              <i class="fa fa-file-excel"></i> Export XLSX
            </button>
          </div>
          <div class="card-body no-pad">
            <div class="table-wrap">
              <table>
                <thead>
                  <tr><th>Tgl Rekam</th><th>Tgl Input</th><th>Kategori</th><th>Ringkasan / Detail</th></tr>
                </thead>
                <tbody id="pdHealthTbody">
                  <tr><td colspan="4" class="table-empty"><div class="table-loading"><div class="spinner"></div>Memuat...</div></td></tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  `;

  document.getElementById('patientSearch').addEventListener('input', (e) => {
    searchQ = e.target.value.toLowerCase(); curPage = 1; applyFilter();
  });
  
  document.getElementById('btnBackToPatients').addEventListener('click', () => {
    document.getElementById('patientDetailView').style.display = 'none';
    document.getElementById('patientSelectorView').style.display = 'block';
  });

  document.getElementById('tabFoodBtn').addEventListener('click', () => switchTab('food'));
  document.getElementById('tabHealthBtn').addEventListener('click', () => switchTab('health'));
  
  document.getElementById('btnExportPatientFood').addEventListener('click', exportPatientFoodLogs);
  document.getElementById('btnExportPatientHealth').addEventListener('click', exportPatientHealthRecords);

  await loadUsers();
}

async function loadUsers() {
  try {
    const snap = await getDocs(query(collection(db, 'users'), orderBy('createdAt', 'desc')));
    allUsers = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    applyFilter();
  } catch (err) {
    document.getElementById('patientTbody').innerHTML = 
      `<tr><td colspan="5" class="table-empty">Gagal memuat: ${err.message}</td></tr>`;
  }
}

function applyFilter() {
  filtered = allUsers.filter(u => {
    if (!searchQ) return true;
    return (u.name ?? '').toLowerCase().includes(searchQ) ||
           (u.email ?? '').toLowerCase().includes(searchQ);
  });
  document.getElementById('patientCount').textContent = `${filtered.length} Pasien ditemukan`;
  renderTable();
}

function renderTable() {
  const { items } = paginate(filtered, curPage, PER_PAGE);
  const tbody = document.getElementById('patientTbody');

  if (items.length === 0) {
    tbody.innerHTML = `<tr><td colspan="5" class="table-empty">Tidak ada pasien yang cocok.</td></tr>`;
    document.getElementById('patientPagination').innerHTML = '';
    return;
  }

  const start = (curPage - 1) * PER_PAGE;
  tbody.innerHTML = items.map((u, i) => `
    <tr>
      <td class="muted">${start + i + 1}</td>
      <td class="fw-600">${u.name ?? '-'}</td>
      <td class="muted">${u.email ?? '-'}</td>
      <td>${diseaseBadge(u.diseaseType)}</td>
      <td>
        <button class="btn btn-outline btn-sm btn-open-detail" data-id="${u.id}">
          <i class="fa fa-folder-open"></i> Lihat Data
        </button>
      </td>
    </tr>
  `).join('');

  tbody.querySelectorAll('.btn-open-detail').forEach(b => {
    b.addEventListener('click', () => openPatientDetail(b.dataset.id));
  });

  renderPagination('patientPagination', curPage, filtered.length, PER_PAGE, (p) => {
    curPage = p; renderTable();
  });
}

// ── Detail Pasien ──────────────────────────────────────────────────

let currentPatient = null;
let currentFoodLogs = [];
let currentHealthRecords = [];

async function openPatientDetail(uid) {
  currentPatient = allUsers.find(u => u.id === uid);
  if (!currentPatient) return;

  document.getElementById('patientSelectorView').style.display = 'none';
  document.getElementById('patientDetailView').style.display = 'block';

  document.getElementById('pdName').textContent = currentPatient.name ?? 'Tanpa Nama';
  document.getElementById('pdEmail').textContent = currentPatient.email ?? '-';
  document.getElementById('pdDisease').innerHTML = diseaseBadge(currentPatient.diseaseType);

  switchTab('food');
  await fetchPatientData(uid);
}

function switchTab(tab) {
  const fBtn = document.getElementById('tabFoodBtn');
  const hBtn = document.getElementById('tabHealthBtn');
  const fDiv = document.getElementById('pdFoodTab');
  const hDiv = document.getElementById('pdHealthTab');

  if (tab === 'food') {
    fBtn.className = 'btn btn-primary';
    hBtn.className = 'btn btn-outline';
    fDiv.style.display = 'block';
    hDiv.style.display = 'none';
  } else {
    hBtn.className = 'btn btn-primary';
    fBtn.className = 'btn btn-outline';
    hDiv.style.display = 'block';
    fDiv.style.display = 'none';
  }
}

async function fetchPatientData(uid) {
  // Loading state
  document.getElementById('pdFoodTbody').innerHTML = `<tr><td colspan="6" class="table-empty"><div class="table-loading"><div class="spinner"></div>Mengambil log makanan...</div></td></tr>`;
  document.getElementById('pdHealthTbody').innerHTML = `<tr><td colspan="4" class="table-empty"><div class="table-loading"><div class="spinner"></div>Mengambil rekam medis...</div></td></tr>`;

  try {
    // 1. Ambil Food Logs dimana uid == id pasien
    const qFood = query(collection(db, 'food_logs'), where('uid', '==', uid));
    const snapFood = await getDocs(qFood);
    
    let flatFoods = [];
    snapFood.docs.forEach(d => {
      const data = d.data();
      const dateStr = data.date;
      (data.entries ?? []).forEach(e => {
        flatFoods.push({ date: dateStr, ...e });
      });
    });
    // Sort food by tanggal & waktu
    flatFoods.sort((a, b) => {
      if (b.date !== a.date) return b.date.localeCompare(a.date);
      const ta = a.loggedAt?.toDate ? a.loggedAt.toDate().getTime() : 0;
      const tb = b.loggedAt?.toDate ? b.loggedAt.toDate().getTime() : 0;
      return tb - ta;
    });

    currentFoodLogs = flatFoods;
    renderFoodLogs(flatFoods);

    // 2. Ambil Rekam Medis (dari subcollection yang sesuai penyakitnya)
    let records = [];
    const diseaseMap = {
      type2_diabetes_mellitus: 'diabetes_health_records',
      chronic_kidney_disease:  'kidney_health_records',
      heart_failure:           'heart_health_records',
      hypertension:            'hypertension_health_records',
    };
    const colName = diseaseMap[currentPatient.diseaseType];
    
    if (colName) {
      const snapHealth = await getDocs(collection(db, 'users', uid, colName));
      records = snapHealth.docs.map(d => ({ id: d.id, ...d.data() }));
      records.sort((a, b) => {
        const da = a.date?.toDate ? a.date.toDate() : new Date(0);
        const db_ = b.date?.toDate ? b.date.toDate() : new Date(0);
        return db_ - da;
      });
    }

    currentHealthRecords = records;
    renderHealthRecords(records);

  } catch (err) {
    document.getElementById('pdFoodTbody').innerHTML = `<tr><td colspan="6" class="table-empty text-error">Error: ${err.message}</td></tr>`;
    document.getElementById('pdHealthTbody').innerHTML = `<tr><td colspan="4" class="table-empty text-error">Error: ${err.message}</td></tr>`;
  }
}

function renderFoodLogs(entries) {
  const tbody = document.getElementById('pdFoodTbody');
  if (entries.length === 0) {
    tbody.innerHTML = `<tr><td colspan="6" class="table-empty">Belum ada log makanan.</td></tr>`;
    return;
  }
  
  const mealMap = { breakfast: 'Sarapan', lunch: 'Makan Siang', dinner: 'Makan Malam', snack: 'Snack' };
  
  tbody.innerHTML = entries.map(e => {
    const loggedAt = e.loggedAt?.toDate ? e.loggedAt.toDate().toLocaleTimeString('id-ID', {hour:'2-digit', minute:'2-digit'}) : '-';
    return `
    <tr>
      <td class="text-sm">${e.date}</td>
      <td class="muted text-sm">${loggedAt}</td>
      <td><span class="badge badge-neutral">${mealMap[e.mealType] ?? e.mealType ?? '-'}</span></td>
      <td class="fw-600">${e.foodName ?? '-'}</td>
      <td class="muted">${e.grams ?? '-'} g</td>
      <td class="muted">${e.energi ? Math.round(e.energi) : '-'} kkal</td>
    </tr>
  `}).join('');
}

function renderHealthRecords(records) {
  const tbody = document.getElementById('pdHealthTbody');
  if (records.length === 0) {
    tbody.innerHTML = `<tr><td colspan="4" class="table-empty">Belum ada rekam medis.</td></tr>`;
    return;
  }

  tbody.innerHTML = records.map(r => {
    const dStr = fmtDate(r.date);
    const inStr = fmtDate(r.createdAt);
    const badgeType = `<span class="badge badge-info">${typeLabel(r.type)}</span>`;
    
    // Format payload jadi string rapi
    const p = r.payload ?? {};
    const lines = Object.entries(p).map(([k,v]) => `<span class="text-xs"><strong class="text-muted">${k}:</strong> ${v}</span>`).join(' • ');

    return `
      <tr>
        <td class="text-sm" style="white-space:nowrap">${dStr}</td>
        <td class="muted text-sm" style="white-space:nowrap">${inStr}</td>
        <td>${badgeType}</td>
        <td style="line-height:1.6">${lines || '-'}</td>
      </tr>
    `;
  }).join('');
}

function typeLabel(type) {
  const map = {
    pemeriksaan:  'Pemeriksaan',
    insulin:      'Insulin',
    aktivitas:    'Aktivitas',
    obat:         'Obat',
    hemodialisa:  'Hemodialisa',
    gejala:       'Gejala',
    berat_badan:  'Berat Badan',
    tekanan_darah:'Tekanan Darah',
  };
  return map[type] ?? type ?? '-';
}

// ── Export ─────────────────────────────────────────────────────────

async function exportPatientFoodLogs() {
  if (currentFoodLogs.length === 0) {
    showToast('Tidak ada log makanan untuk diexport.', 'warning');
    return;
  }
  if (typeof XLSX === 'undefined') {
    await loadScript('https://cdn.sheetjs.com/xlsx-0.20.1/package/dist/xlsx.full.min.js');
  }
  const mealMap = { breakfast: 'Sarapan', lunch: 'Makan Siang', dinner: 'Makan Malam', snack: 'Snack' };
  
  const rows = currentFoodLogs.map((e, i) => ({
    No: i + 1,
    Tanggal: e.date ?? '',
    'Waktu Log': e.loggedAt?.toDate ? e.loggedAt.toDate().toLocaleString('id-ID') : '',
    Meal: mealMap[e.mealType] ?? e.mealType ?? '',
    Makanan: e.foodName ?? '',
    'Porsi (g)': e.grams ?? '',
    'Energi (kkal)': e.energi ? Math.round(e.energi) : '',
    'Protein (g)': e.protein ?? '',
    'Lemak (g)': e.lemak ?? '',
    'Karbohidrat (g)': e.karbohidrat ?? '',
    'Serat (g)': e.serat ?? '',
    'Natrium (mg)': e.natrium ?? '',
    'Kalium (mg)': e.kalium ?? '',
    'Indeks Glikemik': e.indeksGlikemik ?? '',
  }));
  
  const ws = XLSX.utils.json_to_sheet(rows);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Log Makanan');
  
  const safeName = (currentPatient?.name ?? 'pasien').replace(/[^a-z0-9]/gi, '_').toLowerCase();
  XLSX.writeFile(wb, `direka_food_${safeName}_${today()}.xlsx`);
  showToast('Export log makanan berhasil!', 'success');
}

async function exportPatientHealthRecords() {
  if (currentHealthRecords.length === 0) {
    showToast('Tidak ada rekam medis untuk diexport.', 'warning');
    return;
  }
  if (typeof XLSX === 'undefined') {
    await loadScript('https://cdn.sheetjs.com/xlsx-0.20.1/package/dist/xlsx.full.min.js');
  }
  const rows = currentHealthRecords.map((r, i) => {
    const p = r.payload ?? {};
    return {
      No: i + 1,
      'Tgl Rekam': fmtDate(r.date),
      'Tgl Input': fmtDate(r.createdAt),
      Kategori: typeLabel(r.type),
      ...Object.fromEntries(Object.entries(p).map(([k, v]) => [k, JSON.stringify(v)])),
    };
  });
  
  const ws = XLSX.utils.json_to_sheet(rows);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Rekam Medis');
  
  const safeName = (currentPatient?.name ?? 'pasien').replace(/[^a-z0-9]/gi, '_').toLowerCase();
  XLSX.writeFile(wb, `direka_health_${safeName}_${today()}.xlsx`);
  showToast('Export rekam medis berhasil!', 'success');
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
