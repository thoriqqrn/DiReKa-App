// modules/cooking-methods.js — CRUD Metode Pengolahan Makanan
// Koleksi Firestore: cooking_methods
// Dokumen per metode: { id, name, category, description,
//   fatAbsorptionPer100g (g lemak minyak diserap per 100g bahan),
//   conversionFactors: [ { foodGroup, fk } ],   // FK dari buku konversi
//   extraCalPer100g, extraFatPer100g, extraKarboPer100g,
//   extraProteinPer100g, extraNatriumPer100g,
//   affectsNutritionBy: 'factor' | 'addition',
//   createdAt, updatedAt }
//
// affectsNutritionBy:
//   'factor' → gizi dasar × FK (konversi mentah-matang, nilai default FK dari buku)
//   'addition' → gizi dasar + nilai extra (misal penyerapan minyak goreng)
//
// Contoh:
//   Digoreng: affectsNutritionBy=addition, extraFatPer100g=10, extraCalPer100g=90
//   Direbus:  affectsNutritionBy=factor,  defaultFk=1.0 (berat sama, nutrisi relatif sama)

import { db } from '../firebase.js';
import {
  collection, getDocs, doc, setDoc, deleteDoc, addDoc,
  query, orderBy, serverTimestamp,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';
import {
  showToast, openModal, closeModal, showConfirm,
  paginate, renderPagination,
} from '../dashboard.js';

const COL = 'cooking_methods';
const PER_PAGE = 12;

let allMethods = [];
let filtered   = [];
let curPage    = 1;
let searchQ    = '';

const CATEGORIES = ['Goreng', 'Rebus', 'Kukus', 'Bakar/Panggang', 'Tumis', 'Tim/Pepes', 'Mentah', 'Lainnya'];

export async function initCookingMethods() {
  const main = document.getElementById('mainContent');
  main.innerHTML = `
    <div class="section-header">
      <div>
        <h2>Metode Pengolahan Makanan</h2>
        <p>Database cara masak + faktor konversi & tambahan gizi (berdasarkan Buku Konversi Mentah-Matang).</p>
      </div>
      <div class="flex gap-2">
        <button class="btn btn-primary" id="btnAddMethod">
          <i class="fa fa-plus"></i> Tambah Pengolahan
        </button>
      </div>
    </div>

    <!-- Info -->
    <div class="card mb-3" style="border-left:4px solid var(--color-info)">
      <div class="card-body" style="padding:.75rem 1rem;font-size:.83rem;color:var(--text-secondary)">
        <strong>Cara kerja:</strong>
        Mode <span class="badge badge-info">Faktor (FK)</span> — gizi dasar dikalikan faktor konversi buku mentah-matang.
        Mode <span class="badge badge-warning">Tambahan</span> — gizi tambahan dari penyerapan minyak/bumbu ditambahkan ke gizi dasar.
      </div>
    </div>

    <div class="card mb-3">
      <div class="card-body" style="padding:.75rem 1rem">
        <div class="search-box" style="max-width:360px">
          <i class="icon fa fa-search"></i>
          <input type="text" id="methodSearch" placeholder="Cari nama / kategori..." />
        </div>
      </div>
    </div>

    <div class="card">
      <div class="card-header"><h3 id="methodCount">Metode Pengolahan</h3></div>
      <div class="card-body no-pad">
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>#</th><th>Nama Metode</th><th>Kategori</th><th>Mode Hitung</th>
                <th>+Kalori/100g</th><th>+Lemak/100g</th><th>FK Default</th>
                <th>Keterangan</th><th>Aksi</th>
              </tr>
            </thead>
            <tbody id="methodTbody">
              <tr><td colspan="9" class="table-empty">
                <div class="table-loading"><div class="spinner"></div>Memuat...</div>
              </td></tr>
            </tbody>
          </table>
        </div>
        <div class="pagination" id="methodPagination"></div>
      </div>
    </div>`;

  document.getElementById('methodSearch').addEventListener('input', (e) => {
    searchQ = e.target.value.toLowerCase(); curPage = 1; applyFilter();
  });
  document.getElementById('btnAddMethod').addEventListener('click', () => openForm());

  await loadMethods();
}

async function loadMethods() {
  try {
    const snap = await getDocs(collection(db, COL));
    allMethods = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    
    // Sort in-memory to avoid index requirement
    allMethods.sort((a, b) => {
      const catComp = (a.category ?? '').localeCompare(b.category ?? '');
      if (catComp !== 0) return catComp;
      return (a.name ?? '').localeCompare(b.name ?? '');
    });
    
    applyFilter();
  } catch (err) {
    document.getElementById('methodTbody').innerHTML =
      `<tr><td colspan="9" class="table-empty">Gagal memuat: ${err.message}</td></tr>`;
  }
}

function applyFilter() {
  filtered = allMethods.filter(m => {
    if (!searchQ) return true;
    return (m.name ?? '').toLowerCase().includes(searchQ) ||
           (m.category ?? '').toLowerCase().includes(searchQ);
  });
  document.getElementById('methodCount').textContent = `${filtered.length} Metode`;
  renderTable();
}

function renderTable() {
  const { items } = paginate(filtered, curPage, PER_PAGE);
  const tbody = document.getElementById('methodTbody');
  if (items.length === 0) {
    tbody.innerHTML = `<tr><td colspan="9" class="table-empty">Tidak ada data.</td></tr>`;
    document.getElementById('methodPagination').innerHTML = '';
    return;
  }
  const start = (curPage - 1) * PER_PAGE;
  tbody.innerHTML = items.map((m, i) => {
    const mode = m.affectsNutritionBy === 'addition'
      ? '<span class="badge badge-warning">Tambahan</span>'
      : '<span class="badge badge-info">Faktor (FK)</span>';
    return `<tr>
      <td class="muted">${start + i + 1}</td>
      <td class="fw-600">${m.name ?? '-'}</td>
      <td><span class="badge badge-neutral">${m.category ?? '-'}</span></td>
      <td>${mode}</td>
      <td class="muted">${m.extraCalPer100g ?? 0} kkal</td>
      <td class="muted">${m.extraFatPer100g ?? 0} g</td>
      <td class="muted">${m.defaultFk ?? 1.0}</td>
      <td class="muted text-sm" style="max-width:180px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">
        ${m.description ?? '-'}
      </td>
      <td>
        <div class="actions">
          <button class="btn btn-ghost btn-sm btn-edit" data-id="${m.id}" title="Edit">
            <i class="fa fa-pen"></i>
          </button>
          <button class="btn btn-ghost btn-sm btn-del" data-id="${m.id}" data-name="${m.name}" title="Hapus">
            <i class="fa fa-trash"></i>
          </button>
        </div>
      </td>
    </tr>`;
  }).join('');

  tbody.querySelectorAll('.btn-edit').forEach(b =>
    b.addEventListener('click', () => openForm(allMethods.find(m => m.id === b.dataset.id))));
  tbody.querySelectorAll('.btn-del').forEach(b =>
    b.addEventListener('click', () =>
      showConfirm('Hapus Metode?', `Hapus metode <strong>${b.dataset.name}</strong>?`,
        () => deleteMethod(b.dataset.id))));

  renderPagination('methodPagination', curPage, filtered.length, PER_PAGE, (p) => {
    curPage = p; renderTable();
  });
}

function openForm(method = null) {
  const isEdit = !!method;
  const modeAddition = !isEdit || method.affectsNutritionBy === 'addition';

  const body = `
    <div class="form-row">
      <div class="form-group">
        <label>Nama Metode *</label>
        <input id="mName" value="${method?.name ?? ''}" placeholder="cth: Digoreng, Direbus..." />
      </div>
      <div class="form-group">
        <label>Kategori</label>
        <select id="mCat">
          ${CATEGORIES.map(c => `<option ${method?.category === c ? 'selected' : ''} value="${c}">${c}</option>`).join('')}
        </select>
      </div>
    </div>

    <div class="form-group">
      <label>Keterangan / Deskripsi</label>
      <textarea id="mDesc" rows="2" placeholder="cth: Digoreng menggunakan minyak, menyerap ±10g lemak per 100g bahan">${method?.description ?? ''}</textarea>
    </div>

    <div class="form-group">
      <label>Mode Perhitungan Gizi *</label>
      <select id="mMode">
        <option value="addition" ${modeAddition ? 'selected' : ''}>Tambahan (+ gizi dari minyak/bumbu)</option>
        <option value="factor"   ${!modeAddition ? 'selected' : ''}>Faktor / FK (× faktor konversi mentah-matang)</option>
      </select>
      <small style="color:var(--text-hint)">Pilih "Faktor" untuk metode rebus/kukus/bakar (FK dari buku konversi). Pilih "Tambahan" untuk goreng/tumis (penyerapan minyak).</small>
    </div>

    <div class="detail-section-title">Mode Tambahan (Goreng / Tumis)</div>
    <div class="form-row">
      <div class="form-group">
        <label>+ Kalori per 100g bahan (kkal)</label>
        <input id="mExCal" type="number" step="0.1" value="${method?.extraCalPer100g ?? 0}" placeholder="cth: 90" />
      </div>
      <div class="form-group">
        <label>+ Lemak per 100g bahan (g)</label>
        <input id="mExFat" type="number" step="0.1" value="${method?.extraFatPer100g ?? 0}" placeholder="cth: 10" />
      </div>
    </div>
    <div class="form-row">
      <div class="form-group">
        <label>+ Karbo per 100g bahan (g)</label>
        <input id="mExKarbo" type="number" step="0.1" value="${method?.extraKarboPer100g ?? 0}" />
      </div>
      <div class="form-group">
        <label>+ Protein per 100g bahan (g)</label>
        <input id="mExProt" type="number" step="0.1" value="${method?.extraProteinPer100g ?? 0}" />
      </div>
    </div>
    <div class="form-row">
      <div class="form-group">
        <label>+ Natrium per 100g bahan (mg)</label>
        <input id="mExNat" type="number" step="0.1" value="${method?.extraNatriumPer100g ?? 0}" />
      </div>
    </div>

    <div class="detail-section-title">Mode Faktor / FK (Rebus / Kukus / Bakar)</div>
    <div class="form-row">
      <div class="form-group">
        <label>Faktor Konversi (FK) Default</label>
        <input id="mFk" type="number" step="0.01" value="${method?.defaultFk ?? 1.0}" placeholder="cth: 1.1" />
        <small style="color:var(--text-hint)">Dari Buku Konversi. Berat matang = Berat mentah × FK. Gizi dihitung dari berat mentah.</small>
      </div>
    </div>`;

  openModal(
    isEdit ? `Edit: ${method.name}` : 'Tambah Metode Pengolahan',
    body,
    `<button class="btn btn-outline" id="mCancel">Batal</button>
     <button class="btn btn-primary" id="mSave">${isEdit ? 'Simpan' : 'Tambah'}</button>`,
    true,
  );
  document.getElementById('mCancel').addEventListener('click', closeModal);
  document.getElementById('mSave').addEventListener('click', () => saveMethod(method));
}

async function saveMethod(existing) {
  const name = document.getElementById('mName').value.trim();
  if (!name) { showToast('Nama wajib diisi.', 'warning'); return; }
  const num = id => { const v = document.getElementById(id).value; return v !== '' ? Number(v) : 0; };

  const data = {
    name,
    category:            document.getElementById('mCat').value,
    description:         document.getElementById('mDesc').value.trim(),
    affectsNutritionBy:  document.getElementById('mMode').value,
    extraCalPer100g:     num('mExCal'),
    extraFatPer100g:     num('mExFat'),
    extraKarboPer100g:   num('mExKarbo'),
    extraProteinPer100g: num('mExProt'),
    extraNatriumPer100g: num('mExNat'),
    defaultFk:           num('mFk') || 1.0,
    updatedAt:           serverTimestamp(),
  };

  try {
    if (existing) {
      await setDoc(doc(db, COL, existing.id), data, { merge: true });
      showToast('Metode diperbarui!', 'success');
    } else {
      data.createdAt = serverTimestamp();
      await addDoc(collection(db, COL), data);
      showToast('Metode ditambahkan!', 'success');
    }
    closeModal();
    await loadMethods();
  } catch (err) {
    showToast('Gagal: ' + err.message, 'error');
  }
}

async function deleteMethod(id) {
  try {
    await deleteDoc(doc(db, COL, id));
    allMethods = allMethods.filter(m => m.id !== id);
    applyFilter();
    showToast('Metode dihapus.', 'success');
  } catch (err) {
    showToast('Gagal hapus: ' + err.message, 'error');
  }
}

// ── Seed Data Awal dari Buku Konversi ──────────────────────────────────────
async function seedDefaultMethods() {
  const defaults = [
    // ── Mode TAMBAHAN (penyerapan minyak) ─────────────────────────────────
    {
      name: 'Digoreng (deep fry)',
      category: 'Goreng',
      description: 'Digoreng dalam banyak minyak. Menyerap ±10g lemak per 100g bahan baku (referensi: buku konversi mentah-matang, penyerapan minyak udang goreng ±24%).',
      affectsNutritionBy: 'addition',
      extraCalPer100g: 90, extraFatPer100g: 10, extraKarboPer100g: 0,
      extraProteinPer100g: 0, extraNatriumPer100g: 0, defaultFk: 1.0,
    },
    {
      name: 'Digoreng tepung',
      category: 'Goreng',
      description: 'Digoreng dengan balutan tepung. Menyerap ±15g lemak per 100g bahan. Tepung dicatat sebagai bahan tambahan terpisah.',
      affectsNutritionBy: 'addition',
      extraCalPer100g: 135, extraFatPer100g: 15, extraKarboPer100g: 0,
      extraProteinPer100g: 0, extraNatriumPer100g: 0, defaultFk: 1.0,
    },
    {
      name: 'Ditumis',
      category: 'Tumis',
      description: 'Ditumis dengan sedikit minyak. Menyerap ±5g lemak per 100g bahan.',
      affectsNutritionBy: 'addition',
      extraCalPer100g: 45, extraFatPer100g: 5, extraKarboPer100g: 0,
      extraProteinPer100g: 0, extraNatriumPer100g: 0, defaultFk: 1.0,
    },

    // ── Mode FAKTOR / FK (buku konversi mentah-matang) ────────────────────
    {
      name: 'Direbus',
      category: 'Rebus',
      description: 'Direbus dalam air. FK rata-rata 1.0 (berat relatif sama). Gizi dihitung dari berat mentah hasil konversi. Ref: Bayam rebus FK=1.1, Nasi liwet FK=0.4.',
      affectsNutritionBy: 'factor',
      extraCalPer100g: 0, extraFatPer100g: 0, extraKarboPer100g: 0,
      extraProteinPer100g: 0, extraNatriumPer100g: 0, defaultFk: 1.0,
    },
    {
      name: 'Dikukus',
      category: 'Kukus',
      description: 'Dikukus dengan uap air. Tidak ada tambahan lemak. Ref: Bayam kukus FK=0.9, Wortel kukus FK=1.1.',
      affectsNutritionBy: 'factor',
      extraCalPer100g: 0, extraFatPer100g: 0, extraKarboPer100g: 0,
      extraProteinPer100g: 0, extraNatriumPer100g: 0, defaultFk: 1.0,
    },
    {
      name: 'Dibakar / Dipanggang',
      category: 'Bakar/Panggang',
      description: 'Dibakar atau dipanggang tanpa minyak. Ref: Dada ayam panggang FK=1.7, Jagung bakar FK=1.2.',
      affectsNutritionBy: 'factor',
      extraCalPer100g: 0, extraFatPer100g: 0, extraKarboPer100g: 0,
      extraProteinPer100g: 0, extraNatriumPer100g: 0, defaultFk: 1.2,
    },
    {
      name: 'Dipepes / Ditim',
      category: 'Tim/Pepes',
      description: 'Dipepes (dibungkus daun + dikukus/bakar) atau ditim. Ref: Gurame pepes FK=1.1, Tongkol tim FK=1.1.',
      affectsNutritionBy: 'factor',
      extraCalPer100g: 0, extraFatPer100g: 0, extraKarboPer100g: 0,
      extraProteinPer100g: 0, extraNatriumPer100g: 0, defaultFk: 1.1,
    },
    {
      name: 'Diungkep',
      category: 'Rebus',
      description: 'Diungkep (dimasak dengan bumbu hingga cairan habis). Ref: Paha ayam ungkep FK=2.2.',
      affectsNutritionBy: 'factor',
      extraCalPer100g: 0, extraFatPer100g: 0, extraKarboPer100g: 0,
      extraProteinPer100g: 0, extraNatriumPer100g: 0, defaultFk: 1.5,
    },
    {
      name: 'Direbus + Digoreng',
      category: 'Goreng',
      description: 'Direbus dulu lalu digoreng. Ref: Paha ayam rebus-goreng FK=1.6, Daging sapi haas rebus-goreng FK=2.6.',
      affectsNutritionBy: 'addition',
      extraCalPer100g: 60, extraFatPer100g: 7, extraKarboPer100g: 0,
      extraProteinPer100g: 0, extraNatriumPer100g: 0, defaultFk: 1.6,
    },
    {
      name: 'Mentah (Tidak Diolah)',
      category: 'Mentah',
      description: 'Langsung dikonsumsi tanpa pengolahan. FK = 1.0, tidak ada tambahan gizi.',
      affectsNutritionBy: 'factor',
      extraCalPer100g: 0, extraFatPer100g: 0, extraKarboPer100g: 0,
      extraProteinPer100g: 0, extraNatriumPer100g: 0, defaultFk: 1.0,
    },
  ];

  try {
    let added = 0;
    for (const d of defaults) {
      // Cek duplikat by name
      const exists = allMethods.find(m => m.name.toLowerCase() === d.name.toLowerCase());
      if (exists) continue;
      await addDoc(collection(db, COL), { ...d, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
      added++;
    }
    showToast(`${added} metode pengolahan berhasil di-seed!`, 'success');
    await loadMethods();
  } catch (err) {
    showToast('Seed gagal: ' + err.message, 'error');
  }
}
