// modules/food-logs.js — Log Makanan (Read + Export XLSX)
import { db } from '../firebase.js';
import {
  collection, getDocs, query, orderBy, where,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';
import {
  showToast, openModal, fmtDate, diseaseBadge,
  paginate, renderPagination,
} from '../dashboard.js';

const PER_PAGE = 12;

let allUsers    = [];
let allLogs     = []; // flat: setiap entry = satu baris
let flatEntries = [];
let filtered    = [];
let curPage     = 1;
let searchQ     = '';
let filterMeal  = 'all';

const MEALS = ['all', 'breakfast', 'lunch', 'dinner', 'snack'];
const MEAL_LABELS = {
  all:       'Semua',
  breakfast: 'Sarapan',
  lunch:     'Makan Siang',
  dinner:    'Makan Malam',
  snack:     'Snack',
};

export async function initFoodLogs() {
  const main = document.getElementById('mainContent');
  main.innerHTML = `
    <div class="section-header">
      <div><h2>Log Makanan</h2><p>Riwayat konsumsi makanan seluruh pengguna.</p></div>
      <button class="btn btn-success btn-sm" id="btnExportLogs">
        <i class="fa fa-file-excel"></i> Export XLSX
      </button>
    </div>

    <div class="card" style="margin-bottom:1rem">
      <div class="card-body" style="padding:.75rem 1rem">
        <div class="toolbar">
          <div class="search-box">
            <i class="icon fa fa-search"></i>
            <input type="text" id="logSearch" placeholder="Cari nama / makanan..." />
          </div>
          <div class="filter-chips" id="mealChips">
            ${MEALS.map(m =>
              `<span class="chip ${m === 'all' ? 'active' : ''}" data-m="${m}">${MEAL_LABELS[m]}</span>`
            ).join('')}
          </div>
        </div>
      </div>
    </div>

    <div class="card">
      <div class="card-header"><h3 id="logCount">Log</h3></div>
      <div class="card-body no-pad">
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>#</th><th>Pengguna</th><th>Tanggal</th><th>Meal</th>
                <th>Makanan</th><th>Gram</th><th>Energi</th>
                <th>Protein</th><th>Karbo</th><th>Lemak</th><th>Aksi</th>
              </tr>
            </thead>
            <tbody id="logTbody">
              <tr><td colspan="11" class="table-empty"><div class="table-loading"><div class="spinner"></div>Memuat...</div></td></tr>
            </tbody>
          </table>
        </div>
        <div class="pagination" id="logPagination"></div>
      </div>
    </div>`;

  document.getElementById('logSearch').addEventListener('input', (e) => {
    searchQ = e.target.value.toLowerCase(); curPage = 1; applyFilter();
  });
  document.getElementById('mealChips').addEventListener('click', (e) => {
    const chip = e.target.closest('.chip');
    if (!chip) return;
    filterMeal = chip.dataset.m;
    document.querySelectorAll('#mealChips .chip').forEach(c => c.classList.remove('active'));
    chip.classList.add('active');
    curPage = 1; applyFilter();
  });
  document.getElementById('btnExportLogs').addEventListener('click', exportLogs);

  await loadLogs();
}

async function loadLogs() {
  try {
    // Fetch users untuk mapping uid → name/email
    const usersSnap = await getDocs(collection(db, 'users'));
    allUsers = usersSnap.docs.map(d => ({ id: d.id, ...d.data() }));
    const userMap = Object.fromEntries(allUsers.map(u => [u.id, u]));

    // Fetch semua food_logs (doc id = uid_YYYY-MM-DD)
    const logsSnap = await getDocs(
      query(collection(db, 'food_logs'), orderBy('date', 'desc'))
    );

    flatEntries = [];
    logsSnap.docs.forEach(d => {
      const logDoc = d.data();
      const uid  = logDoc.uid ?? '';
      const date = logDoc.date ?? '';
      const user = userMap[uid];
      const entries = logDoc.entries ?? [];
      entries.forEach(entry => {
        flatEntries.push({
          _docId:      d.id,
          _uid:        uid,
          _date:       date,
          _userName:   user?.name ?? user?.email ?? uid,
          _userEmail:  user?.email ?? '-',
          _disease:    user?.diseaseType ?? '',
          ...entry,
        });
      });
    });

    // Sort by date desc, then loggedAt desc
    flatEntries.sort((a, b) => {
      if (b._date !== a._date) return b._date.localeCompare(a._date);
      const ta = a.loggedAt?.toDate ? a.loggedAt.toDate().getTime() : 0;
      const tb = b.loggedAt?.toDate ? b.loggedAt.toDate().getTime() : 0;
      return tb - ta;
    });

    applyFilter();
  } catch (err) {
    document.getElementById('logTbody').innerHTML =
      `<tr><td colspan="11" class="table-empty">Gagal memuat: ${err.message}</td></tr>`;
  }
}

function applyFilter() {
  filtered = flatEntries.filter(e => {
    const matchM = filterMeal === 'all' || e.mealType === filterMeal;
    const q = searchQ;
    const matchQ = !q ||
      e._userName.toLowerCase().includes(q) ||
      (e.foodName ?? '').toLowerCase().includes(q) ||
      e._userEmail.toLowerCase().includes(q);
    return matchM && matchQ;
  });
  document.getElementById('logCount').textContent = `${filtered.length} Entri Log`;
  renderTable();
}

function renderTable() {
  const { items } = paginate(filtered, curPage, PER_PAGE);
  const tbody = document.getElementById('logTbody');

  if (items.length === 0) {
    tbody.innerHTML = `<tr><td colspan="11" class="table-empty">Tidak ada data.</td></tr>`;
    document.getElementById('logPagination').innerHTML = '';
    return;
  }

  const start = (curPage - 1) * PER_PAGE;
  tbody.innerHTML = items.map((e, i) => {
    let displayName = e.foodName ?? '-';
    if (e.cookingMethodName && e.cookingMethodName !== 'Mentah (Tidak Diolah)') {
      displayName += ` (${e.cookingMethodName})`;
    }
    if (e.additives && e.additives.length > 0) {
      const addNames = e.additives.map(a => a.additiveName).join(', ');
      displayName += ` + ${addNames}`;
    }
    return `
    <tr>
      <td class="muted">${start + i + 1}</td>
      <td>
        <div class="fw-600">${e._userName}</div>
        ${diseaseBadge(e._disease)}
      </td>
      <td class="muted text-sm">${e._date}</td>
      <td><span class="badge badge-neutral">${MEAL_LABELS[e.mealType] ?? e.mealType ?? '-'}</span></td>
      <td><strong>${displayName}</strong></td>
      <td class="muted">${e.grams ?? '-'} g</td>
      <td class="muted">${e.energi ? Math.round(e.energi) : '-'} kkal</td>
      <td class="muted">${e.protein ?? '-'} g</td>
      <td class="muted">${e.karbohidrat ?? '-'} g</td>
      <td class="muted">${e.lemak ?? '-'} g</td>
      <td>
        <button class="btn btn-ghost btn-sm btn-view" title="Detail" data-idx="${start + i}">
          <i class="fa fa-eye"></i>
        </button>
      </td>
    </tr>`}).join('');

  tbody.querySelectorAll('.btn-view').forEach(b =>
    b.addEventListener('click', () => viewEntry(filtered[Number(b.dataset.idx)])));

  renderPagination('logPagination', curPage, filtered.length, PER_PAGE, (p) => {
    curPage = p; renderTable();
  });
}

function viewEntry(e) {
  const loggedAt = e.loggedAt?.toDate ? e.loggedAt.toDate().toLocaleString('id-ID') : '-';
  const additivesStr = e.additives && e.additives.length > 0
    ? e.additives.map(a => `${a.additiveName} (${a.jumlahUnit} URT)`).join(', ')
    : 'Tidak ada';

  openModal(
    `Detail Log — ${e.foodName ?? '-'}`,
    `<div class="detail-grid">
       <div class="detail-item"><label>Pengguna</label><span>${e._userName}</span></div>
       <div class="detail-item"><label>Email</label><span>${e._userEmail}</span></div>
       <div class="detail-item"><label>Tanggal</label><span>${e._date}</span></div>
       <div class="detail-item"><label>Waktu Log</label><span>${loggedAt}</span></div>
       <div class="detail-item"><label>Meal</label><span>${MEAL_LABELS[e.mealType] ?? e.mealType ?? '-'}</span></div>
       <div class="detail-item"><label>Makanan</label><span>${e.foodName ?? '-'}</span></div>
       <div class="detail-item"><label>Porsi</label><span>${e.grams ?? '-'} gram</span></div>
       <div class="detail-item"><label>Cara Masak</label><span>${e.cookingMethodName ?? 'Mentah (Tidak Diolah)'}</span></div>
       <div class="detail-item"><label>Bahan Tambahan</label><span>${additivesStr}</span></div>
     </div>
     <div class="detail-section-title">Nilai Gizi</div>
     <div class="detail-grid">
       <div class="detail-item"><label>Energi</label><span>${e.energi ? Math.round(e.energi) : '-'} kkal</span></div>
       <div class="detail-item"><label>Protein</label><span>${e.protein ?? '-'} g</span></div>
       <div class="detail-item"><label>Lemak</label><span>${e.lemak ?? '-'} g</span></div>
       <div class="detail-item"><label>Karbohidrat</label><span>${e.karbohidrat ?? '-'} g</span></div>
       <div class="detail-item"><label>Serat</label><span>${e.serat ?? '-'} g</span></div>
       <div class="detail-item"><label>Natrium</label><span>${e.natrium ?? '-'} mg</span></div>
       <div class="detail-item"><label>Kalium</label><span>${e.kalium ?? '-'} mg</span></div>
       <div class="detail-item"><label>Fosfor</label><span>${e.fosfor ?? '-'} mg</span></div>
       <div class="detail-item"><label>Indeks Glikemik</label><span>${e.indeksGlikemik ?? '-'}</span></div>
     </div>`,
    `<button class="btn btn-outline" onclick="document.getElementById('modalOverlay').classList.remove('show')">Tutup</button>`,
    true,
  );
}

async function exportLogs() {
  if (typeof XLSX === 'undefined') {
    await loadScript('https://cdn.sheetjs.com/xlsx-0.20.1/package/dist/xlsx.full.min.js');
  }
  const rows = filtered.map((e, i) => ({
    No:         i + 1,
    Nama:       e._userName,
    Email:      e._userEmail,
    Penyakit:   e._disease,
    Tanggal:    e._date,
    Meal:       MEAL_LABELS[e.mealType] ?? e.mealType ?? '',
    Makanan:    e.foodName ?? '',
    Gram:       e.grams ?? '',
    'Energi (kkal)':    e.energi ? Math.round(e.energi) : '',
    'Protein (g)':  e.protein ?? '',
    'Lemak (g)':    e.lemak ?? '',
    'Karbo (g)':    e.karbohidrat ?? '',
    'Serat (g)':    e.serat ?? '',
    'Natrium (mg)': e.natrium ?? '',
    'Kalium (mg)':  e.kalium ?? '',
    'GI':           e.indeksGlikemik ?? '',
  }));
  const ws = XLSX.utils.json_to_sheet(rows);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Food Logs');
  XLSX.writeFile(wb, `direka_food_logs_${today()}.xlsx`);
  showToast('Export berhasil!', 'success');
}

function today() { return new Date().toISOString().slice(0, 10); }
function loadScript(src) {
  return new Promise((res, rej) => {
    const s = document.createElement('script');
    s.src = src; s.onload = res; s.onerror = rej;
    document.head.appendChild(s);
  });
}
