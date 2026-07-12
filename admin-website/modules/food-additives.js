// modules/food-additives.js — CRUD Bahan Tambahan Makanan
// Koleksi Firestore: food_additives
// Dokumen: { id, name, category, unitLabel (cth: "Sendok Makan"),
//   gramPerUnit (gram per 1 unitLabel),
//   calPerUnit, fatPerUnit, karboPerUnit, proteinPerUnit,
//   natriumPerUnit, kaliumPerUnit, fosforPerUnit,
//   description, createdAt, updatedAt }
//
// Logika: saat user input "2 SDM Gula Pasir",
//   total tambahan = (jumlahUnit × calPerUnit), dst.

import { db } from '../firebase.js';
import {
  collection, getDocs, doc, setDoc, deleteDoc, addDoc,
  query, orderBy, serverTimestamp,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';
import {
  showToast, openModal, closeModal, showConfirm,
  paginate, renderPagination,
} from '../dashboard.js';

const COL = 'food_additives';
const PER_PAGE = 14;

let allAdditives = [];
let filtered     = [];
let curPage      = 1;
let searchQ      = '';
let filterCat    = 'all';

const ADDITIVE_CATS = ['Lemak & Minyak', 'Pemanis', 'Tepung & Pati', 'Bumbu & Rempah',
  'Saus & Kecap', 'Susu & Santan', 'Garam', 'Lainnya'];

export async function initFoodAdditives() {
  const main = document.getElementById('mainContent');
  main.innerHTML = `
    <div class="section-header">
      <div>
        <h2>Bahan Tambahan Makanan</h2>
        <p>Database bahan tambahan (minyak, gula, tepung, kecap, santan, dll) beserta nilai gizinya per satuan ukuran.</p>
      </div>
      <div class="flex gap-2">
        <button class="btn btn-primary" id="btnAddAdditive">
          <i class="fa fa-plus"></i> Tambah Bahan
        </button>
      </div>
    </div>

    <div class="card mb-3">
      <div class="card-body" style="padding:.75rem 1rem">
        <div class="toolbar">
          <div class="search-box" style="max-width:320px">
            <i class="icon fa fa-search"></i>
            <input type="text" id="addSearch" placeholder="Cari nama bahan..." />
          </div>
          <div class="filter-chips" id="addCatChips">
            <span class="chip active" data-c="all">Semua</span>
            ${ADDITIVE_CATS.map(c => `<span class="chip" data-c="${c}">${c}</span>`).join('')}
          </div>
        </div>
      </div>
    </div>

    <div class="card">
      <div class="card-header"><h3 id="addCount">Bahan Tambahan</h3></div>
      <div class="card-body no-pad">
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>#</th><th>Nama Bahan</th><th>Kategori</th>
                <th>Satuan (URT)</th><th>Gram/Satuan</th>
                <th>Kalori/Satuan</th><th>Lemak/Sat</th><th>Karbo/Sat</th>
                <th>Natrium/Sat</th><th>Aksi</th>
              </tr>
            </thead>
            <tbody id="addTbody">
              <tr><td colspan="10" class="table-empty">
                <div class="table-loading"><div class="spinner"></div>Memuat...</div>
              </td></tr>
            </tbody>
          </table>
        </div>
        <div class="pagination" id="addPagination"></div>
      </div>
    </div>`;

  document.getElementById('addSearch').addEventListener('input', (e) => {
    searchQ = e.target.value.toLowerCase(); curPage = 1; applyFilter();
  });
  document.getElementById('addCatChips').addEventListener('click', (e) => {
    const chip = e.target.closest('.chip'); if (!chip) return;
    filterCat = chip.dataset.c;
    document.querySelectorAll('#addCatChips .chip').forEach(c => c.classList.remove('active'));
    chip.classList.add('active');
    curPage = 1; applyFilter();
  });
  document.getElementById('btnAddAdditive').addEventListener('click', () => openForm());

  await loadAdditives();
}

async function loadAdditives() {
  try {
    const snap = await getDocs(collection(db, COL));
    allAdditives = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    
    // Sort in-memory to avoid index requirement
    allAdditives.sort((a, b) => {
      const catComp = (a.category ?? '').localeCompare(b.category ?? '');
      if (catComp !== 0) return catComp;
      return (a.name ?? '').localeCompare(b.name ?? '');
    });
    
    applyFilter();
  } catch (err) {
    document.getElementById('addTbody').innerHTML =
      `<tr><td colspan="10" class="table-empty">Gagal memuat: ${err.message}</td></tr>`;
  }
}

function applyFilter() {
  filtered = allAdditives.filter(a => {
    const matchCat = filterCat === 'all' || a.category === filterCat;
    const matchQ = !searchQ || (a.name ?? '').toLowerCase().includes(searchQ);
    return matchCat && matchQ;
  });
  document.getElementById('addCount').textContent = `${filtered.length} Bahan Tambahan`;
  renderTable();
}

function renderTable() {
  const { items } = paginate(filtered, curPage, PER_PAGE);
  const tbody = document.getElementById('addTbody');
  if (items.length === 0) {
    tbody.innerHTML = `<tr><td colspan="10" class="table-empty">Tidak ada data.</td></tr>`;
    document.getElementById('addPagination').innerHTML = '';
    return;
  }
  const start = (curPage - 1) * PER_PAGE;
  tbody.innerHTML = items.map((a, i) => `<tr>
    <td class="muted">${start + i + 1}</td>
    <td class="fw-600">${a.name ?? '-'}</td>
    <td><span class="badge badge-neutral">${a.category ?? '-'}</span></td>
    <td class="muted">${a.unitLabel ?? '-'}</td>
    <td class="muted">${a.gramPerUnit ?? 0} g</td>
    <td class="muted">${a.calPerUnit ?? 0} kkal</td>
    <td class="muted">${a.fatPerUnit ?? 0} g</td>
    <td class="muted">${a.karboPerUnit ?? 0} g</td>
    <td class="muted">${a.natriumPerUnit ?? 0} mg</td>
    <td>
      <div class="actions">
        <button class="btn btn-ghost btn-sm btn-edit" data-id="${a.id}" title="Edit"><i class="fa fa-pen"></i></button>
        <button class="btn btn-ghost btn-sm btn-del" data-id="${a.id}" data-name="${a.name}" title="Hapus"><i class="fa fa-trash"></i></button>
      </div>
    </td>
  </tr>`).join('');

  tbody.querySelectorAll('.btn-edit').forEach(b =>
    b.addEventListener('click', () => openForm(allAdditives.find(a => a.id === b.dataset.id))));
  tbody.querySelectorAll('.btn-del').forEach(b =>
    b.addEventListener('click', () =>
      showConfirm('Hapus Bahan?', `Hapus <strong>${b.dataset.name}</strong>?`,
        () => deleteAdditive(b.dataset.id))));

  renderPagination('addPagination', curPage, filtered.length, PER_PAGE, (p) => {
    curPage = p; renderTable();
  });
}

function openForm(additive = null) {
  const isEdit = !!additive;
  const body = `
    <div class="form-row">
      <div class="form-group">
        <label>Nama Bahan *</label>
        <input id="aName" value="${additive?.name ?? ''}" placeholder="cth: Gula Pasir, Minyak Goreng..." />
      </div>
      <div class="form-group">
        <label>Kategori</label>
        <select id="aCat">
          ${ADDITIVE_CATS.map(c => `<option ${additive?.category === c ? 'selected' : ''} value="${c}">${c}</option>`).join('')}
        </select>
      </div>
    </div>

    <div class="form-row">
      <div class="form-group">
        <label>Satuan / URT *</label>
        <input id="aUnit" value="${additive?.unitLabel ?? ''}" placeholder="cth: Sendok Makan, Sendok Teh, Gelas..." />
      </div>
      <div class="form-group">
        <label>Gram per 1 Satuan (g)</label>
        <input id="aGram" type="number" step="0.1" value="${additive?.gramPerUnit ?? ''}" placeholder="cth: 15" />
      </div>
    </div>

    <div class="detail-section-title">Nilai Gizi per 1 Satuan (URT)</div>
    <div class="form-row">
      <div class="form-group"><label>Kalori (kkal)</label><input id="aCal" type="number" step="0.1" value="${additive?.calPerUnit ?? 0}" /></div>
      <div class="form-group"><label>Lemak (g)</label><input id="aFat" type="number" step="0.1" value="${additive?.fatPerUnit ?? 0}" /></div>
    </div>
    <div class="form-row">
      <div class="form-group"><label>Karbohidrat (g)</label><input id="aKarbo" type="number" step="0.1" value="${additive?.karboPerUnit ?? 0}" /></div>
      <div class="form-group"><label>Protein (g)</label><input id="aProt" type="number" step="0.1" value="${additive?.proteinPerUnit ?? 0}" /></div>
    </div>
    <div class="form-row">
      <div class="form-group"><label>Natrium (mg)</label><input id="aNat" type="number" step="0.1" value="${additive?.natriumPerUnit ?? 0}" /></div>
      <div class="form-group"><label>Kalium (mg)</label><input id="aKal" type="number" step="0.1" value="${additive?.kaliumPerUnit ?? 0}" /></div>
    </div>
    <div class="form-row">
      <div class="form-group"><label>Fosfor (mg)</label><input id="aFos" type="number" step="0.1" value="${additive?.fosforPerUnit ?? 0}" /></div>
      <div class="form-group"><label>Serat (g)</label><input id="aSer" type="number" step="0.1" value="${additive?.seratPerUnit ?? 0}" /></div>
    </div>

    <div class="form-group">
      <label>Keterangan</label>
      <textarea id="aDesc" rows="2" placeholder="cth: Minyak sawit, digunakan untuk menggoreng dan menumis">${additive?.description ?? ''}</textarea>
    </div>`;

  openModal(
    isEdit ? `Edit: ${additive.name}` : 'Tambah Bahan Tambahan',
    body,
    `<button class="btn btn-outline" id="aCancel">Batal</button>
     <button class="btn btn-primary" id="aSave">${isEdit ? 'Simpan' : 'Tambah'}</button>`,
    true,
  );
  document.getElementById('aCancel').addEventListener('click', closeModal);
  document.getElementById('aSave').addEventListener('click', () => saveAdditive(additive));
}

async function saveAdditive(existing) {
  const name = document.getElementById('aName').value.trim();
  const unit = document.getElementById('aUnit').value.trim();
  if (!name || !unit) { showToast('Nama dan satuan wajib diisi.', 'warning'); return; }
  const num = id => { const v = document.getElementById(id).value; return v !== '' ? Number(v) : 0; };

  const data = {
    name, unitLabel: unit,
    category:       document.getElementById('aCat').value,
    gramPerUnit:    num('aGram'),
    calPerUnit:     num('aCal'),
    fatPerUnit:     num('aFat'),
    karboPerUnit:   num('aKarbo'),
    proteinPerUnit: num('aProt'),
    natriumPerUnit: num('aNat'),
    kaliumPerUnit:  num('aKal'),
    fosforPerUnit:  num('aFos'),
    seratPerUnit:   num('aSer'),
    description:    document.getElementById('aDesc').value.trim(),
    updatedAt:      serverTimestamp(),
  };

  try {
    if (existing) {
      await setDoc(doc(db, COL, existing.id), data, { merge: true });
      showToast('Bahan diperbarui!', 'success');
    } else {
      data.createdAt = serverTimestamp();
      await addDoc(collection(db, COL), data);
      showToast('Bahan ditambahkan!', 'success');
    }
    closeModal();
    await loadAdditives();
  } catch (err) {
    showToast('Gagal: ' + err.message, 'error');
  }
}

async function deleteAdditive(id) {
  try {
    await deleteDoc(doc(db, COL, id));
    allAdditives = allAdditives.filter(a => a.id !== id);
    applyFilter();
    showToast('Bahan dihapus.', 'success');
  } catch (err) {
    showToast('Gagal: ' + err.message, 'error');
  }
}

// ── Seed Data Awal ──────────────────────────────────────────────────────────
async function seedDefaultAdditives() {
  // Sumber: TKPI 2017 / referensi gizi umum Indonesia
  const defaults = [
    // ── Lemak & Minyak ──────────────────────────────────────────────────
    { name: 'Minyak Goreng (Sawit)', category: 'Lemak & Minyak',
      unitLabel: '1 Sendok Makan', gramPerUnit: 13,
      calPerUnit: 115, fatPerUnit: 13, karboPerUnit: 0, proteinPerUnit: 0,
      natriumPerUnit: 0, kaliumPerUnit: 0, fosforPerUnit: 0, seratPerUnit: 0,
      description: 'Minyak kelapa sawit. 1 SDM = ±13g, 115 kkal, 13g lemak.' },
    { name: 'Minyak Goreng (Kelapa)', category: 'Lemak & Minyak',
      unitLabel: '1 Sendok Makan', gramPerUnit: 13,
      calPerUnit: 115, fatPerUnit: 13, karboPerUnit: 0, proteinPerUnit: 0,
      natriumPerUnit: 0, kaliumPerUnit: 0, fosforPerUnit: 0, seratPerUnit: 0,
      description: 'Minyak kelapa.' },
    { name: 'Margarin', category: 'Lemak & Minyak',
      unitLabel: '1 Sendok Makan', gramPerUnit: 14,
      calPerUnit: 100, fatPerUnit: 11, karboPerUnit: 0.1, proteinPerUnit: 0.1,
      natriumPerUnit: 90, kaliumPerUnit: 5, fosforPerUnit: 2, seratPerUnit: 0,
      description: 'Margarin serbaguna.' },
    { name: 'Mentega', category: 'Lemak & Minyak',
      unitLabel: '1 Sendok Makan', gramPerUnit: 14,
      calPerUnit: 100, fatPerUnit: 11.5, karboPerUnit: 0, proteinPerUnit: 0.1,
      natriumPerUnit: 82, kaliumPerUnit: 3, fosforPerUnit: 3, seratPerUnit: 0,
      description: 'Butter / mentega sapi.' },
    { name: 'Santan Kental', category: 'Susu & Santan',
      unitLabel: '1 Sendok Makan', gramPerUnit: 15,
      calPerUnit: 52, fatPerUnit: 5.4, karboPerUnit: 0.8, proteinPerUnit: 0.5,
      natriumPerUnit: 4, kaliumPerUnit: 35, fosforPerUnit: 10, seratPerUnit: 0,
      description: 'Santan kental dari kelapa parut. Tinggi lemak jenuh.' },
    { name: 'Santan Encer', category: 'Susu & Santan',
      unitLabel: '1 Sendok Makan', gramPerUnit: 15,
      calPerUnit: 15, fatPerUnit: 1.4, karboPerUnit: 0.6, proteinPerUnit: 0.2,
      natriumPerUnit: 2, kaliumPerUnit: 12, fosforPerUnit: 4, seratPerUnit: 0,
      description: 'Santan encer (diencerkan air).' },

    // ── Pemanis ─────────────────────────────────────────────────────────
    { name: 'Gula Pasir', category: 'Pemanis',
      unitLabel: '1 Sendok Makan', gramPerUnit: 12,
      calPerUnit: 46, fatPerUnit: 0, karboPerUnit: 12, proteinPerUnit: 0,
      natriumPerUnit: 0, kaliumPerUnit: 0, fosforPerUnit: 0, seratPerUnit: 0,
      description: 'Gula pasir putih. 1 SDM = 12g.' },
    { name: 'Gula Merah / Gula Jawa', category: 'Pemanis',
      unitLabel: '1 Sendok Makan', gramPerUnit: 15,
      calPerUnit: 54, fatPerUnit: 0, karboPerUnit: 14, proteinPerUnit: 0.2,
      natriumPerUnit: 5, kaliumPerUnit: 50, fosforPerUnit: 3, seratPerUnit: 0,
      description: 'Gula aren/merah/jawa.' },
    { name: 'Gula Aren (Cair)', category: 'Pemanis',
      unitLabel: '1 Sendok Makan', gramPerUnit: 20,
      calPerUnit: 62, fatPerUnit: 0, karboPerUnit: 16, proteinPerUnit: 0,
      natriumPerUnit: 3, kaliumPerUnit: 40, fosforPerUnit: 2, seratPerUnit: 0,
      description: 'Gula aren cair.' },
    { name: 'Madu', category: 'Pemanis',
      unitLabel: '1 Sendok Makan', gramPerUnit: 21,
      calPerUnit: 64, fatPerUnit: 0, karboPerUnit: 17.3, proteinPerUnit: 0.1,
      natriumPerUnit: 1, kaliumPerUnit: 11, fosforPerUnit: 1, seratPerUnit: 0,
      description: 'Madu lebah asli. GI tinggi ±55.' },

    // ── Tepung & Pati ───────────────────────────────────────────────────
    { name: 'Tepung Terigu', category: 'Tepung & Pati',
      unitLabel: '1 Sendok Makan', gramPerUnit: 10,
      calPerUnit: 36, fatPerUnit: 0.1, karboPerUnit: 7.5, proteinPerUnit: 1,
      natriumPerUnit: 0, kaliumPerUnit: 20, fosforPerUnit: 25, seratPerUnit: 0.2,
      description: 'Tepung terigu serbaguna. BDD 100%.' },
    { name: 'Tepung Beras', category: 'Tepung & Pati',
      unitLabel: '1 Sendok Makan', gramPerUnit: 10,
      calPerUnit: 36, fatPerUnit: 0.1, karboPerUnit: 7.9, proteinPerUnit: 0.7,
      natriumPerUnit: 0, kaliumPerUnit: 10, fosforPerUnit: 15, seratPerUnit: 0.1,
      description: 'Tepung beras putih.' },
    { name: 'Tepung Maizena', category: 'Tepung & Pati',
      unitLabel: '1 Sendok Makan', gramPerUnit: 10,
      calPerUnit: 34, fatPerUnit: 0, karboPerUnit: 8.3, proteinPerUnit: 0,
      natriumPerUnit: 0, kaliumPerUnit: 3, fosforPerUnit: 5, seratPerUnit: 0.1,
      description: 'Pati jagung. Digunakan sebagai pengental.' },
    { name: 'Tepung Sagu', category: 'Tepung & Pati',
      unitLabel: '1 Sendok Makan', gramPerUnit: 10,
      calPerUnit: 35, fatPerUnit: 0, karboPerUnit: 8.6, proteinPerUnit: 0,
      natriumPerUnit: 0, kaliumPerUnit: 5, fosforPerUnit: 3, seratPerUnit: 0,
      description: 'Tepung sagu / tapioka.' },

    // ── Saus & Kecap ────────────────────────────────────────────────────
    { name: 'Kecap Manis', category: 'Saus & Kecap',
      unitLabel: '1 Sendok Makan', gramPerUnit: 18,
      calPerUnit: 43, fatPerUnit: 0, karboPerUnit: 10.5, proteinPerUnit: 0.9,
      natriumPerUnit: 490, kaliumPerUnit: 35, fosforPerUnit: 20, seratPerUnit: 0,
      description: 'Kecap manis. SANGAT TINGGI NATRIUM — perhatian pasien HT & Ginjal.' },
    { name: 'Kecap Asin', category: 'Saus & Kecap',
      unitLabel: '1 Sendok Makan', gramPerUnit: 15,
      calPerUnit: 9, fatPerUnit: 0.1, karboPerUnit: 0.9, proteinPerUnit: 1.3,
      natriumPerUnit: 920, kaliumPerUnit: 32, fosforPerUnit: 20, seratPerUnit: 0,
      description: 'Kecap asin. SANGAT TINGGI NATRIUM.' },
    { name: 'Saus Tomat', category: 'Saus & Kecap',
      unitLabel: '1 Sendok Makan', gramPerUnit: 15,
      calPerUnit: 15, fatPerUnit: 0, karboPerUnit: 3.6, proteinPerUnit: 0.2,
      natriumPerUnit: 160, kaliumPerUnit: 60, fosforPerUnit: 8, seratPerUnit: 0.2,
      description: 'Saus tomat kemasan.' },
    { name: 'Saus Sambal', category: 'Saus & Kecap',
      unitLabel: '1 Sendok Makan', gramPerUnit: 15,
      calPerUnit: 20, fatPerUnit: 0.1, karboPerUnit: 4.5, proteinPerUnit: 0.3,
      natriumPerUnit: 250, kaliumPerUnit: 40, fosforPerUnit: 6, seratPerUnit: 0.1,
      description: 'Saus sambal kemasan.' },

    // ── Garam ───────────────────────────────────────────────────────────
    { name: 'Garam Dapur', category: 'Garam',
      unitLabel: '1 Sendok Teh', gramPerUnit: 5,
      calPerUnit: 0, fatPerUnit: 0, karboPerUnit: 0, proteinPerUnit: 0,
      natriumPerUnit: 1960, kaliumPerUnit: 0, fosforPerUnit: 0, seratPerUnit: 0,
      description: 'Garam dapur NaCl. 1 sendok teh = ±1.960 mg Natrium. SANGAT TINGGI — wajib dicatat pasien HT/Ginjal/Jantung.' },

    // ── Bumbu & Rempah ──────────────────────────────────────────────────
    { name: 'Bawang Merah (cincang)', category: 'Bumbu & Rempah',
      unitLabel: '1 Sendok Makan', gramPerUnit: 10,
      calPerUnit: 4, fatPerUnit: 0, karboPerUnit: 0.9, proteinPerUnit: 0.1,
      natriumPerUnit: 2, kaliumPerUnit: 35, fosforPerUnit: 5, seratPerUnit: 0.2,
      description: 'Bawang merah cincang mentah.' },
    { name: 'Bawang Putih (cincang)', category: 'Bumbu & Rempah',
      unitLabel: '1 Siung', gramPerUnit: 5,
      calPerUnit: 7, fatPerUnit: 0, karboPerUnit: 1.5, proteinPerUnit: 0.3,
      natriumPerUnit: 1, kaliumPerUnit: 12, fosforPerUnit: 5, seratPerUnit: 0.1,
      description: 'Bawang putih 1 siung ±5g.' },
    { name: 'Terasi', category: 'Bumbu & Rempah',
      unitLabel: '1 Sendok Teh', gramPerUnit: 5,
      calPerUnit: 14, fatPerUnit: 0.4, karboPerUnit: 0.6, proteinPerUnit: 2.1,
      natriumPerUnit: 500, kaliumPerUnit: 30, fosforPerUnit: 40, seratPerUnit: 0,
      description: 'Terasi udang. Tinggi natrium.' },

    // ── Susu & Santan ────────────────────────────────────────────────────
    { name: 'Susu Kental Manis', category: 'Susu & Santan',
      unitLabel: '1 Sendok Makan', gramPerUnit: 20,
      calPerUnit: 66, fatPerUnit: 1.8, karboPerUnit: 11.5, proteinPerUnit: 1.5,
      natriumPerUnit: 30, kaliumPerUnit: 60, fosforPerUnit: 45, seratPerUnit: 0,
      description: 'Susu kental manis. Tinggi gula & kalori.' },
    { name: 'Susu Bubuk Full Cream', category: 'Susu & Santan',
      unitLabel: '1 Sendok Makan', gramPerUnit: 10,
      calPerUnit: 49, fatPerUnit: 2.5, karboPerUnit: 4.8, proteinPerUnit: 2.5,
      natriumPerUnit: 40, kaliumPerUnit: 115, fosforPerUnit: 75, seratPerUnit: 0,
      description: 'Susu bubuk full cream.' },
  ];

  try {
    let added = 0;
    for (const d of defaults) {
      const exists = allAdditives.find(a => a.name.toLowerCase() === d.name.toLowerCase());
      if (exists) continue;
      await addDoc(collection(db, COL), { ...d, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
      added++;
    }
    showToast(`${added} bahan tambahan berhasil di-seed!`, 'success');
    await loadAdditives();
  } catch (err) {
    showToast('Seed gagal: ' + err.message, 'error');
  }
}
