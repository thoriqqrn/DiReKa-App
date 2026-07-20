// modules/health.js — Rekam Medis (Read + Delete per record, Export XLSX)
import { db } from '../firebase.js';
import {
  collection, getDocs, doc, deleteDoc,
  query, orderBy,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';
import {
  showToast, openModal, closeModal, showConfirm,
  fmtDate, diseaseBadge, paginate, renderPagination,
} from '../dashboard.js';

const PER_PAGE = 12;

let allUsers   = [];
let allRecords = []; // flat: {uid, userName, userEmail, diseaseType, id, type, date, payload, ...}
let filtered   = [];
let curPage    = 1;
let searchQ    = '';
let filterDisease = 'all';
let filterType    = 'all';

export async function initHealth() {
  const main = document.getElementById('mainContent');
  main.innerHTML = `
    <div class="section-header">
      <div><h2>Rekam Medis</h2><p>Seluruh rekam kesehatan pengguna.</p></div>
      <button class="btn btn-success btn-sm" id="btnExportHealth">
        <i class="fa fa-file-excel"></i> Export XLSX
      </button>
    </div>

    <div class="card" style="margin-bottom:1rem">
      <div class="card-body" style="padding:.75rem 1rem">
        <div class="toolbar" style="flex-wrap:wrap;gap:.5rem">
          <div class="search-box">
            <i class="icon fa fa-search"></i>
            <input type="text" id="healthSearch" placeholder="Cari nama / email..." />
          </div>
          <div class="filter-chips" id="healthDiseaseChips">
            <span class="chip active" data-d="all">Semua</span>
            <span class="chip" data-d="type2_diabetes_mellitus">Diabetes</span>
            <span class="chip" data-d="chronic_kidney_disease">Ginjal</span>
            <span class="chip" data-d="heart_failure">Jantung</span>
            <span class="chip" data-d="hypertension">Hipertensi</span>
          </div>
        </div>
      </div>
    </div>

    <div class="card">
      <div class="card-header"><h3 id="healthCount">Rekam</h3></div>
      <div class="card-body no-pad">
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>#</th><th>Pasien</th><th>Penyakit</th>
                <th>Kategori</th><th>Jenis</th><th>Tgl Rekam</th>
                <th>Ringkasan</th><th>Aksi</th>
              </tr>
            </thead>
            <tbody id="healthTbody">
              <tr><td colspan="8" class="table-empty"><div class="table-loading"><div class="spinner"></div>Memuat data semua user...</div></td></tr>
            </tbody>
          </table>
        </div>
        <div class="pagination" id="healthPagination"></div>
      </div>
    </div>`;

  document.getElementById('healthSearch').addEventListener('input', (e) => {
    searchQ = e.target.value.toLowerCase(); curPage = 1; applyFilter();
  });
  document.getElementById('healthDiseaseChips').addEventListener('click', (e) => {
    const chip = e.target.closest('.chip');
    if (!chip) return;
    filterDisease = chip.dataset.d;
    document.querySelectorAll('#healthDiseaseChips .chip').forEach(c => c.classList.remove('active'));
    chip.classList.add('active');
    curPage = 1; applyFilter();
  });
  document.getElementById('btnExportHealth').addEventListener('click', exportHealth);

  await loadAllRecords();
}

async function loadAllRecords() {
  try {
    // Ambil semua users
    const usersSnap = await getDocs(collection(db, 'users'));
    allUsers = usersSnap.docs.map(d => ({ id: d.id, ...d.data() }));
    allRecords = [];

    const diseaseCollMap = {
      type2_diabetes_mellitus: 'diabetes_health_records',
      chronic_kidney_disease:  'kidney_health_records',
      heart_failure:           'heart_health_records',
      hypertension:            'hypertension_health_records',
    };

    // Fetch subcollection per user (parallel)
    await Promise.all(allUsers.map(async (u) => {
      const colName = diseaseCollMap[u.diseaseType];
      if (!colName) return;
      const snap = await getDocs(
        query(collection(db, 'users', u.id, colName), orderBy('date', 'desc'))
      );
      snap.docs.forEach(d => {
        allRecords.push({
          _uid:       u.id,
          _userName:  u.name ?? u.email ?? '-',
          _userEmail: u.email ?? '-',
          _disease:   u.diseaseType,
          _colName:   colName,
          id:         d.id,
          ...d.data(),
        });
      });
    }));

    // Sort by date desc
    allRecords.sort((a, b) => {
      const da = a.date?.toDate ? a.date.toDate() : new Date(0);
      const db_ = b.date?.toDate ? b.date.toDate() : new Date(0);
      return db_ - da;
    });

    applyFilter();
  } catch (err) {
    document.getElementById('healthTbody').innerHTML =
      `<tr><td colspan="8" class="table-empty">Gagal memuat: ${err.message}</td></tr>`;
  }
}

function applyFilter() {
  filtered = allRecords.filter(r => {
    const matchD = filterDisease === 'all' || r._disease === filterDisease;
    const q = searchQ;
    const matchQ = !q ||
      r._userName.toLowerCase().includes(q) ||
      r._userEmail.toLowerCase().includes(q);
    return matchD && matchQ;
  });
  document.getElementById('healthCount').textContent = `${filtered.length} Rekam Medis`;
  renderTable();
}

function renderTable() {
  const { items } = paginate(filtered, curPage, PER_PAGE);
  const tbody = document.getElementById('healthTbody');

  if (items.length === 0) {
    tbody.innerHTML = `<tr><td colspan="8" class="table-empty">Tidak ada data.</td></tr>`;
    document.getElementById('healthPagination').innerHTML = '';
    return;
  }

  const start = (curPage - 1) * PER_PAGE;
  tbody.innerHTML = items.map((r, i) => {
    const summary = buildSummary(r);
    const typeLabel = r.type ?? '-';
    return `<tr>
      <td class="muted">${start + i + 1}</td>
      <td>
        <div class="fw-600">${r._userName}</div>
        <div class="text-xs text-muted">${r._userEmail}</div>
      </td>
      <td>${diseaseBadge(r._disease)}</td>
      <td><span class="badge badge-neutral">${typeLabelHuman(r.type, r._disease)}</span></td>
      <td class="muted text-sm">${typeLabel}</td>
      <td class="muted text-sm">${fmtDate(r.date)}</td>
      <td class="muted text-sm" style="max-width:200px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${summary}</td>
      <td>
        <div class="actions">
          <button class="btn btn-ghost btn-sm btn-view" title="Detail" data-idx="${start + i}">
            <i class="fa fa-eye"></i>
          </button>
          <button class="btn btn-ghost btn-sm btn-del" title="Hapus" data-uid="${r._uid}" data-col="${r._colName}" data-id="${r.id}">
            <i class="fa fa-trash"></i>
          </button>
        </div>
      </td>
    </tr>`;
  }).join('');

  tbody.querySelectorAll('.btn-view').forEach(b =>
    b.addEventListener('click', () => viewRecord(filtered[Number(b.dataset.idx)])));
  tbody.querySelectorAll('.btn-del').forEach(b =>
    b.addEventListener('click', () =>
      showConfirm('Hapus Rekam Medis?', 'Rekam ini akan dihapus permanen.',
        () => deleteRecord(b.dataset.uid, b.dataset.col, b.dataset.id))));

  renderPagination('healthPagination', curPage, filtered.length, PER_PAGE, (p) => {
    curPage = p; renderTable();
  });
}

function viewRecord(r) {
  const p = r.payload ?? {};
  const entries = Object.entries(p).map(([k, v]) =>
    `<div class="detail-item"><label>${k}</label><span>${JSON.stringify(v)}</span></div>`
  ).join('');

  openModal(
    `Detail Rekam — ${r._userName}`,
    `<div class="detail-grid mb-3">
       <div class="detail-item"><label>Pasien</label><span>${r._userName}</span></div>
       <div class="detail-item"><label>Email</label><span>${r._userEmail}</span></div>
       <div class="detail-item"><label>Penyakit</label>${diseaseBadge(r._disease)}</div>
       <div class="detail-item"><label>Tipe Input</label><span>${r.type ?? '-'}</span></div>
       <div class="detail-item"><label>Tanggal Rekam</label><span>${fmtDate(r.date)}</span></div>
       <div class="detail-item"><label>Diinput Pada</label><span>${fmtDate(r.createdAt)}</span></div>
     </div>
     <div class="detail-section-title">Payload</div>
     <div class="detail-grid">${entries || '<span class="text-muted">Kosong</span>'}</div>`,
    `<button class="btn btn-outline" onclick="document.getElementById('modalOverlay').classList.remove('show')">Tutup</button>`,
    true,
  );
}

async function deleteRecord(uid, colName, id) {
  try {
    await deleteDoc(doc(db, 'users', uid, colName, id));
    allRecords = allRecords.filter(r => !(r._uid === uid && r._colName === colName && r.id === id));
    applyFilter();
    showToast('Rekam dihapus.', 'success');
  } catch (err) {
    showToast('Gagal hapus: ' + err.message, 'error');
  }
}

async function exportHealth() {
  if (typeof XLSX === 'undefined') {
    await loadScript('https://cdn.sheetjs.com/xlsx-0.20.1/package/dist/xlsx.full.min.js');
  }
  const rows = filtered.map((r, i) => {
    const p = r.payload ?? {};
    
    // Rangkum atribut spesifik
    let namaItem = '';
    let hasilNilai = '';
    let statusKategori = p.category ?? p.status ?? '';
    let catatanLain = p.note ?? p.complaint ?? p.catatan ?? '';

    if (r.type === 'tekanan_darah') {
      namaItem = 'Tekanan Darah (Sistol/Diastol)';
      hasilNilai = p.result ?? `${p.systolic}/${p.diastolic} mmHg`;
      statusKategori = p.category ?? (p.systolic >= 140 || p.diastolic >= 90 ? 'Tidak Terkontrol' : 'Terkontrol');
    } else if (r.type === 'pemeriksaan') {
      namaItem = p.exam || p.examType || '';
      hasilNilai = p.result ? `${p.result} ${p.unit || ''}` : '';
    } else if (r.type === 'aktivitas') {
      namaItem = p.activityName || '';
      hasilNilai = p.duration ? `${p.duration} mnt` : '';
      if (p.intensity) statusKategori = `Intensitas: ${p.intensity}`;
    } else if (r.type === 'obat') {
      namaItem = p.medicationName || p.name || '';
      hasilNilai = p.dose || '';
    } else if (r.type === 'gejala' || r.type === 'stres') {
      namaItem = p.symptom || p.mood || '';
      hasilNilai = p.intensity || p.stressScore || '';
    } else if (r.type === 'berat_badan') {
      namaItem = 'Berat Badan';
      hasilNilai = p.weight ? `${p.weight} kg` : '';
    }

    // Jika kosong, kumpulkan sisanya yang tidak tertangkap
    const sisaJSON = Object.fromEntries(Object.entries(p).filter(([k]) => !['systolic','diastolic','result','category','status','note','complaint','catatan','exam','examType','unit','activityName','duration','intensity','medicationName','name','dose','symptom','mood','stressScore','weight'].includes(k)));
    if (Object.keys(sisaJSON).length > 0) {
      catatanLain += (catatanLain ? ' | ' : '') + JSON.stringify(sisaJSON);
    }

    return {
      No:          i + 1,
      Nama:        r._userName,
      Email:       r._userEmail,
      Penyakit:    r._disease ?? '',
      'Tipe Input': typeLabelHuman(r.type, r._diseaseType) ?? r.type ?? '',
      'Tgl Rekam': fmtDate(r.date),
      'Tgl Input': fmtDate(r.createdAt),
      'Pemeriksaan / Aktivitas': namaItem,
      'Hasil / Nilai': hasilNilai,
      'Status / Kategori': statusKategori,
      'Catatan / Tambahan': catatanLain,
    };
  });
  const ws = XLSX.utils.json_to_sheet(rows);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Health Records');
  XLSX.writeFile(wb, `direka_health_${today()}.xlsx`);
  showToast('Export berhasil!', 'success');
}

// ── Helpers ────────────────────────────────────────────────────────
function buildSummary(r) {
  const p = r.payload ?? {};
  if (p.examType && p.result) return `${p.examType}: ${p.result} ${p.unit ?? ''}`;
  if (p.activityName) return `${p.activityName} ${p.duration ?? ''} mnt`;
  if (p.name) return `${p.name} ${p.dose ?? ''} ${p.doseUnit ?? ''}`;
  if (p.symptom) return p.symptom;
  if (p.weight) return `BB: ${p.weight} kg`;
  const first = Object.values(p)[0];
  return first ? String(first).slice(0, 60) : '-';
}

function typeLabelHuman(type, disease) {
  const map = {
    pemeriksaan:  'Pemeriksaan',
    insulin:      'Analisis Insulin',
    aktivitas:    'Aktivitas Fisik',
    obat:         'Obat',
    hemodialisa:  'Hemodialisa',
    gejala:       'Gejala',
    berat_badan:  'Berat Badan',
    tekanan_darah:'Tekanan Darah',
  };
  return map[type] ?? type ?? '-';
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
