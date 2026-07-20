// modules/food-catalog.js — CRUD Katalog Makanan (food_catalog)
import { db } from '../firebase.js';
import {
  collection, getDocs, doc, setDoc, deleteDoc,
  query, orderBy, serverTimestamp,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';
import {
  showToast, openModal, closeModal, showConfirm,
  paginate, renderPagination,
} from '../dashboard.js';

const COL = 'food_catalog';
const PER_PAGE = 12;

let allFoods = [];
let filtered = [];
let curPage  = 1;
let searchQ  = '';
let filterCat = 'all';

const PRESET_CATEGORIES = [
  'Makanan Pokok', 'Lauk Pauk', 'Sayuran', 'Buah-buahan',
  'Minuman', 'Snack/Jajanan', 'Bumbu & Rempah', 'Produk Susu',
  'Kacang-kacangan', 'Olahan', 'Lainnya',
];

export async function initFoodCatalog() {
  const main = document.getElementById('mainContent');
  main.innerHTML = `
    <div class="section-header">
      <div><h2>Katalog Makanan</h2><p>Database makanan untuk Food Tracker.</p></div>
      <button class="btn btn-primary" id="btnAddFood">
        <i class="fa fa-plus"></i> Tambah Makanan
      </button>
    </div>

    <div class="card" style="margin-bottom:1rem">
      <div class="card-body" style="padding:.75rem 1rem">
        <div class="toolbar">
          <div class="search-box">
            <i class="icon fa fa-search"></i>
            <input type="text" id="foodSearch" placeholder="Cari nama / kategori..." />
          </div>
          <select id="foodCatFilter" style="padding:.4rem .75rem;border:1.5px solid var(--color-border);border-radius:var(--radius-sm);font-size:.83rem">
            <option value="all">Semua Kategori</option>
            ${PRESET_CATEGORIES.map(c => `<option value="${c}">${c}</option>`).join('')}
          </select>
        </div>
      </div>
    </div>

    <div class="card">
      <div class="card-header">
        <h3 id="foodCount">Makanan</h3>
      </div>
      <div class="card-body no-pad">
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>#</th><th>Nama</th><th>Kategori</th>
                <th>Energi</th><th>Protein</th><th>Lemak</th><th>Karbo</th>
                <th>GI</th><th>Aksi</th>
              </tr>
            </thead>
            <tbody id="foodTbody">
              <tr><td colspan="9" class="table-empty"><div class="table-loading"><div class="spinner"></div>Memuat...</div></td></tr>
            </tbody>
          </table>
        </div>
        <div class="pagination" id="foodPagination"></div>
      </div>
    </div>`;

  document.getElementById('foodSearch').addEventListener('input', (e) => {
    searchQ = e.target.value.toLowerCase(); curPage = 1; applyFilter();
  });
  document.getElementById('foodCatFilter').addEventListener('change', (e) => {
    filterCat = e.target.value; curPage = 1; applyFilter();
  });
  document.getElementById('btnAddFood').addEventListener('click', () => openFoodForm());

  await loadFoods();
}

async function loadFoods() {
  try {
    const snap = await getDocs(query(collection(db, COL), orderBy('nama')));
    allFoods = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    applyFilter();
  } catch (err) {
    document.getElementById('foodTbody').innerHTML =
      `<tr><td colspan="9" class="table-empty">Gagal memuat: ${err.message}</td></tr>`;
  }
}

function applyFilter() {
  filtered = allFoods.filter(f => {
    const matchCat = filterCat === 'all' || f.kategori === filterCat;
    const matchQ = !searchQ ||
      (f.nama ?? '').toLowerCase().includes(searchQ) ||
      (f.kategori ?? '').toLowerCase().includes(searchQ);
    return matchCat && matchQ;
  });
  document.getElementById('foodCount').textContent = `${filtered.length} Makanan`;
  renderTable();
}

function renderTable() {
  const { items } = paginate(filtered, curPage, PER_PAGE);
  const tbody = document.getElementById('foodTbody');

  if (items.length === 0) {
    tbody.innerHTML = `<tr><td colspan="9" class="table-empty">Tidak ada data.</td></tr>`;
    document.getElementById('foodPagination').innerHTML = '';
    return;
  }

  const start = (curPage - 1) * PER_PAGE;
  tbody.innerHTML = items.map((f, i) => `
    <tr>
      <td class="muted">${start + i + 1}</td>
      <td>
        <span style="margin-right:.35rem">${f.emoji ?? '🍽️'}</span>
        <strong>${f.nama ?? '-'}</strong>
      </td>
      <td><span class="badge badge-neutral">${f.kategori ?? '-'}</span></td>
      <td class="muted">${f.energi ?? '-'} kkal</td>
      <td class="muted">${f.protein ?? '-'} g</td>
      <td class="muted">${f.lemak ?? '-'} g</td>
      <td class="muted">${f.karbohidrat ?? '-'} g</td>
      <td><span class="badge ${giColor(f.indeksGlikemik)}">${f.indeksGlikemik ?? '-'}</span></td>
      <td>
        <div class="actions">
          <button class="btn btn-ghost btn-sm btn-edit" title="Edit" data-id="${f.id}">
            <i class="fa fa-pen"></i>
          </button>
          <button class="btn btn-ghost btn-sm btn-del" title="Hapus" data-id="${f.id}" data-name="${f.nama}">
            <i class="fa fa-trash"></i>
          </button>
        </div>
      </td>
    </tr>`).join('');

  tbody.querySelectorAll('.btn-edit').forEach(b =>
    b.addEventListener('click', () => openFoodForm(allFoods.find(f => f.id === b.dataset.id))));
  tbody.querySelectorAll('.btn-del').forEach(b =>
    b.addEventListener('click', () =>
      showConfirm('Hapus Makanan?',
        `Hapus <strong>${b.dataset.name}</strong> dari katalog?`,
        () => deleteFood(b.dataset.id))));

  renderPagination('foodPagination', curPage, filtered.length, PER_PAGE, (p) => {
    curPage = p; renderTable();
  });
}

function openFoodForm(food = null) {
  const isEdit = !!food;
  const body = `
    <div class="form-row">
      <div class="form-group">
        <label>Nama Makanan *</label>
        <input id="fNama" value="${food?.nama ?? ''}" placeholder="Contoh: Nasi Putih" />
      </div>
      <div class="form-group">
        <label>Emoji</label>
        <input id="fEmoji" value="${food?.emoji ?? ''}" placeholder="🍚" maxlength="4" />
      </div>
    </div>
    <div class="form-row">
      <div class="form-group">
        <label>Kategori *</label>
        <select id="fKat">
          ${PRESET_CATEGORIES.map(c =>
            `<option ${food?.kategori === c ? 'selected' : ''} value="${c}">${c}</option>`
          ).join('')}
        </select>
      </div>
      <div class="form-group">
        <label>Nama Satuan Dasar</label>
        <input id="fSatuan" value="${food?.satuanNama ?? 'Porsi'}" placeholder="cth: Porsi, Centong, Buah" />
      </div>
    </div>
    
    <div class="form-group">
      <label>Keterangan URT (Opsional)</label>
      <input id="fUrt" value="${food?.urt ?? ''}" placeholder="cth: 1 porsi sedang = 100g" />
    </div>

    <div class="detail-section-title flex justify-between items-center" style="margin-top:1.5rem">
      <span>Takaran Saji</span>
      <button class="btn btn-outline btn-sm" id="btnAddTakaran"><i class="fa fa-plus"></i> Tambah</button>
    </div>
    <div id="takaranContainer" style="display:flex;flex-direction:column;gap:8px;margin-bottom:1rem">
      <!-- Injected via JS -->
    </div>

    <div class="detail-section-title">Nilai Gizi (per 100g)</div>
    <div class="form-row">
      <div class="form-group"><label>Energi (kkal)</label><input id="fEnergi" type="number" step="0.1" value="${food?.energi ?? ''}" /></div>
      <div class="form-group"><label>Protein (g)</label><input id="fProtein" type="number" step="0.1" value="${food?.protein ?? ''}" /></div>
    </div>
    <div class="form-row">
      <div class="form-group"><label>Lemak (g)</label><input id="fLemak" type="number" step="0.1" value="${food?.lemak ?? ''}" /></div>
      <div class="form-group"><label>Karbohidrat (g)</label><input id="fKarbo" type="number" step="0.1" value="${food?.karbohidrat ?? ''}" /></div>
    </div>
    <div class="form-row">
      <div class="form-group"><label>Serat (g)</label><input id="fSerat" type="number" step="0.1" value="${food?.serat ?? ''}" /></div>
      <div class="form-group"><label>Indeks Glikemik</label><input id="fGI" type="number" value="${food?.indeksGlikemik ?? ''}" /></div>
    </div>
    <div class="form-row">
      <div class="form-group"><label>Natrium (mg)</label><input id="fNatrium" type="number" step="0.1" value="${food?.natrium ?? ''}" /></div>
      <div class="form-group"><label>Kalium (mg)</label><input id="fKalium" type="number" step="0.1" value="${food?.kalium ?? ''}" /></div>
    </div>
    <div class="form-row">
      <div class="form-group"><label>Fosfor (mg)</label><input id="fFosfor" type="number" step="0.1" value="${food?.fosfor ?? ''}" /></div>
      <div class="form-group"><label>Air (g)</label><input id="fAir" type="number" step="0.1" value="${food?.air ?? ''}" /></div>
    </div>
    <div class="form-row">
      <div class="form-group"><label>Kalsium (mg)</label><input id="fKalsium" type="number" step="0.1" value="${food?.kalsium ?? ''}" /></div>
      <div class="form-group"><label>Magnesium (mg)</label><input id="fMagnesium" type="number" step="0.1" value="${food?.magnesium ?? ''}" /></div>
    </div>`;

  openModal(
    isEdit ? `Edit: ${food.nama}` : 'Tambah Makanan Baru',
    body,
    `<button class="btn btn-outline" id="fCancel">Batal</button>
     <button class="btn btn-primary" id="fSave">${isEdit ? 'Simpan Perubahan' : 'Tambah'}</button>`,
    true,
  );

  let currentTakaran = food?.takaranSaji ? [...food.takaranSaji] : [];
  
  function renderTakaran() {
    const cont = document.getElementById('takaranContainer');
    if (currentTakaran.length === 0) {
      cont.innerHTML = '<div style="font-size:.8rem;color:var(--text-secondary);text-align:center;padding:.5rem">Belum ada takaran saji terstruktur. User akan dipaksa input Gram manual.</div>';
      return;
    }
    cont.innerHTML = currentTakaran.map((t, i) => `
      <div style="display:flex;gap:8px;align-items:center;background:var(--color-bg);padding:8px;border-radius:6px;border:1px solid var(--color-border)">
        <input type="text" class="tUkuran" data-idx="${i}" value="${t.ukuran ?? ''}" placeholder="Cth: Sedang" style="flex:1;padding:6px;border:1px solid var(--color-border);border-radius:4px;font-size:.8rem" />
        <input type="number" class="tGram" data-idx="${i}" value="${t.gram ?? ''}" placeholder="Gram" style="width:70px;padding:6px;border:1px solid var(--color-border);border-radius:4px;font-size:.8rem" />
        <button class="btn-ghost btn-del-takaran" data-idx="${i}" style="color:var(--color-error);padding:4px"><i class="fa fa-trash"></i></button>
      </div>
    `).join('');

    cont.querySelectorAll('.tUkuran').forEach(el => 
      el.addEventListener('input', e => currentTakaran[e.target.dataset.idx].ukuran = e.target.value)
    );
    cont.querySelectorAll('.tGram').forEach(el => 
      el.addEventListener('input', e => currentTakaran[e.target.dataset.idx].gram = Number(e.target.value))
    );
    cont.querySelectorAll('.btn-del-takaran').forEach(el => 
      el.addEventListener('click', e => {
        currentTakaran.splice(Number(e.currentTarget.dataset.idx), 1);
        renderTakaran();
      })
    );
  }

  renderTakaran();

  document.getElementById('btnAddTakaran').addEventListener('click', () => {
    currentTakaran.push({ ukuran: '', gram: 100, label: '' });
    renderTakaran();
  });

  document.getElementById('fCancel').addEventListener('click', closeModal);
  document.getElementById('fSave').addEventListener('click', () => saveFood(food, currentTakaran));
}

async function saveFood(existing, takaranArr) {
  const nama = document.getElementById('fNama').value.trim();
  if (!nama) { showToast('Nama makanan wajib diisi.', 'warning'); return; }

  const num = (id) => {
    const v = document.getElementById(id).value;
    return v !== '' ? Number(v) : null;
  };

  const cleanTakaran = takaranArr
    .filter(t => t.ukuran.trim() !== '' && t.gram > 0)
    .map(t => ({
      ukuran: t.ukuran.trim(),
      gram: t.gram,
      label: '1 ' + document.getElementById('fSatuan').value.trim() + ' ' + t.ukuran.trim()
    }));

  const data = {
    nama,
    emoji:         document.getElementById('fEmoji').value.trim() || '🍽️',
    kategori:      document.getElementById('fKat').value,
    satuanNama:    document.getElementById('fSatuan').value.trim() || 'Porsi',
    urt:           document.getElementById('fUrt').value.trim(),
    takaranSaji:   cleanTakaran,
    urt:           document.getElementById('fUrt').value.trim(),
    energi:        num('fEnergi'),
    protein:       num('fProtein'),
    lemak:         num('fLemak'),
    karbohidrat:   num('fKarbo'),
    serat:         num('fSerat'),
    indeksGlikemik:num('fGI'),
    natrium:       num('fNatrium'),
    kalium:        num('fKalium'),
    fosfor:        num('fFosfor'),
    air:           num('fAir'),
    kalsium:       num('fKalsium'),
    magnesium:     num('fMagnesium'),
    updatedAt:     serverTimestamp(),
  };

  if (!existing) {
    data.id = Date.now().toString();
    data.createdAt = serverTimestamp();
  }

  const docId = existing?.id ?? data.id;
  try {
    await setDoc(doc(db, COL, docId), data, { merge: true });
    closeModal();
    showToast(existing ? 'Makanan diperbarui!' : 'Makanan ditambahkan!', 'success');
    await loadFoods();
  } catch (err) {
    showToast('Gagal simpan: ' + err.message, 'error');
  }
}

async function deleteFood(id) {
  try {
    await deleteDoc(doc(db, COL, id));
    allFoods = allFoods.filter(f => f.id !== id);
    applyFilter();
    showToast('Makanan dihapus.', 'success');
  } catch (err) {
    showToast('Gagal hapus: ' + err.message, 'error');
  }
}

function giColor(gi) {
  if (!gi) return 'badge-neutral';
  const v = Number(gi);
  if (v < 55) return 'badge-success';
  if (v < 70) return 'badge-warning';
  return 'badge-error';
}
