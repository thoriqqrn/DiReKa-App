// modules/education.js — CRUD education_posts
import { db } from '../firebase.js';
import {
  collection, getDocs, doc, addDoc, setDoc, deleteDoc,
  query, orderBy, serverTimestamp,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';
import {
  showToast, openModal, closeModal, showConfirm,
  fmtDate, paginate, renderPagination,
} from '../dashboard.js';

const COL = 'education_posts';
const PER_PAGE = 10;

let allPosts = [];
let filtered = [];
let curPage  = 1;
let searchQ  = '';
let filterType = 'all';

export async function initEducation() {
  const main = document.getElementById('mainContent');
  main.innerHTML = `
    <div class="section-header">
      <div><h2>Edukasi Kesehatan</h2><p>Kelola artikel dan booklet edukasi.</p></div>
      <button class="btn btn-primary" id="btnAddEdu">
        <i class="fa fa-plus"></i> Tambah Konten
      </button>
    </div>

    <div class="card" style="margin-bottom:1rem">
      <div class="card-body" style="padding:.75rem 1rem">
        <div class="toolbar">
          <div class="search-box">
            <i class="icon fa fa-search"></i>
            <input type="text" id="eduSearch" placeholder="Cari judul..." />
          </div>
          <div class="filter-chips" id="typeChips">
            <span class="chip active" data-t="all">Semua</span>
            <span class="chip" data-t="artikel">Artikel</span>
            <span class="chip" data-t="booklet">Booklet</span>
          </div>
        </div>
      </div>
    </div>

    <div class="card">
      <div class="card-header"><h3 id="eduCount">Konten</h3></div>
      <div class="card-body no-pad">
        <div class="table-wrap">
          <table>
            <thead>
              <tr><th>#</th><th>Judul</th><th>Tipe</th><th>Dibuat Oleh</th><th>Tanggal</th><th>Aksi</th></tr>
            </thead>
            <tbody id="eduTbody">
              <tr><td colspan="6" class="table-empty"><div class="table-loading"><div class="spinner"></div>Memuat...</div></td></tr>
            </tbody>
          </table>
        </div>
        <div class="pagination" id="eduPagination"></div>
      </div>
    </div>`;

  document.getElementById('eduSearch').addEventListener('input', (e) => {
    searchQ = e.target.value.toLowerCase(); curPage = 1; applyFilter();
  });
  document.getElementById('typeChips').addEventListener('click', (e) => {
    const chip = e.target.closest('.chip');
    if (!chip) return;
    filterType = chip.dataset.t;
    document.querySelectorAll('#typeChips .chip').forEach(c => c.classList.remove('active'));
    chip.classList.add('active');
    curPage = 1; applyFilter();
  });
  document.getElementById('btnAddEdu').addEventListener('click', () => openEduForm());

  await loadPosts();
}

async function loadPosts() {
  try {
    const snap = await getDocs(query(collection(db, COL), orderBy('createdAt', 'desc')));
    allPosts = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    applyFilter();
  } catch (err) {
    document.getElementById('eduTbody').innerHTML =
      `<tr><td colspan="6" class="table-empty">Gagal memuat: ${err.message}</td></tr>`;
  }
}

function applyFilter() {
  filtered = allPosts.filter(p => {
    const matchT = filterType === 'all' || p.contentType === filterType;
    const matchQ = !searchQ || (p.title ?? '').toLowerCase().includes(searchQ);
    return matchT && matchQ;
  });
  document.getElementById('eduCount').textContent = `${filtered.length} Konten`;
  renderTable();
}

function renderTable() {
  const { items } = paginate(filtered, curPage, PER_PAGE);
  const tbody = document.getElementById('eduTbody');

  if (items.length === 0) {
    tbody.innerHTML = `<tr><td colspan="6" class="table-empty">Tidak ada data.</td></tr>`;
    document.getElementById('eduPagination').innerHTML = '';
    return;
  }

  const start = (curPage - 1) * PER_PAGE;
  tbody.innerHTML = items.map((p, i) => `
    <tr>
      <td class="muted">${start + i + 1}</td>
      <td>
        <div class="fw-600">${p.title ?? '-'}</div>
        <div class="text-xs text-muted" style="max-width:300px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">
          ${(p.content ?? '').slice(0, 80)}${(p.content ?? '').length > 80 ? '…' : ''}
        </div>
      </td>
      <td>${typeBadge(p.contentType)}</td>
      <td class="muted text-sm">${p.createdBy ?? '-'}</td>
      <td class="muted text-sm">${fmtDate(p.createdAt)}</td>
      <td>
        <div class="actions">
          <button class="btn btn-ghost btn-sm btn-view" title="Pratinjau" data-id="${p.id}">
            <i class="fa fa-eye"></i>
          </button>
          <button class="btn btn-ghost btn-sm btn-edit" title="Edit" data-id="${p.id}">
            <i class="fa fa-pen"></i>
          </button>
          <button class="btn btn-ghost btn-sm btn-del" title="Hapus" data-id="${p.id}" data-title="${p.title}">
            <i class="fa fa-trash"></i>
          </button>
        </div>
      </td>
    </tr>`).join('');

  tbody.querySelectorAll('.btn-view').forEach(b =>
    b.addEventListener('click', () => viewPost(b.dataset.id)));
  tbody.querySelectorAll('.btn-edit').forEach(b =>
    b.addEventListener('click', () => openEduForm(allPosts.find(p => p.id === b.dataset.id))));
  tbody.querySelectorAll('.btn-del').forEach(b =>
    b.addEventListener('click', () =>
      showConfirm('Hapus Konten?',
        `Hapus artikel <strong>${b.dataset.title}</strong>?`,
        () => deletePost(b.dataset.id))));

  renderPagination('eduPagination', curPage, filtered.length, PER_PAGE, (pg) => {
    curPage = pg; renderTable();
  });
}

function viewPost(id) {
  const p = allPosts.find(x => x.id === id);
  if (!p) return;
  openModal(
    p.title ?? 'Pratinjau Konten',
    `<div style="white-space:pre-wrap;line-height:1.6;font-size:.88rem">${p.content ?? '-'}</div>
     ${p.sourceUrl ? `<div class="mt-3"><a href="${p.sourceUrl}" target="_blank" class="btn btn-outline btn-sm"><i class="fa fa-link"></i> Buka Sumber</a></div>` : ''}`,
    `<span class="badge ${p.contentType === 'artikel' ? 'badge-info' : 'badge-success'}">${p.contentType}</span>
     <span class="text-xs text-muted">Dibuat: ${fmtDate(p.createdAt)}</span>
     <button class="btn btn-outline" onclick="document.getElementById('modalOverlay').classList.remove('show')">Tutup</button>`,
    true,
  );
}

function openEduForm(post = null) {
  const isEdit = !!post;
  openModal(
    isEdit ? `Edit: ${post.title}` : 'Tambah Konten Edukasi',
    `<div class="form-group">
       <label>Judul *</label>
       <input id="eTitle" value="${post?.title ?? ''}" placeholder="Judul artikel..." />
     </div>
     <div class="form-group">
       <label>Tipe Konten</label>
       <select id="eType">
         <option value="artikel" ${!post || post.contentType === 'artikel' ? 'selected' : ''}>Artikel</option>
         <option value="booklet" ${post?.contentType === 'booklet' ? 'selected' : ''}>Booklet</option>
       </select>
     </div>
     <div class="form-group">
       <label>Isi Konten *</label>
       <textarea id="eContent" rows="8" placeholder="Tulis isi konten di sini...">${post?.content ?? ''}</textarea>
     </div>
     <div class="form-group">
       <label>URL Sumber (opsional)</label>
       <input id="eUrl" type="url" value="${post?.sourceUrl ?? ''}" placeholder="https://..." />
     </div>`,
    `<button class="btn btn-outline" id="eCancel">Batal</button>
     <button class="btn btn-primary" id="eSave">${isEdit ? 'Simpan Perubahan' : 'Publikasikan'}</button>`,
    true,
  );
  document.getElementById('eCancel').addEventListener('click', closeModal);
  document.getElementById('eSave').addEventListener('click', () => savePost(post));
}

async function savePost(existing) {
  const title   = document.getElementById('eTitle').value.trim();
  const content = document.getElementById('eContent').value.trim();
  if (!title || !content) {
    showToast('Judul dan isi wajib diisi.', 'warning'); return;
  }
  const data = {
    title,
    content,
    contentType: document.getElementById('eType').value,
    sourceUrl:   document.getElementById('eUrl').value.trim() || null,
    updatedAt:   serverTimestamp(),
    updatedBy:   'admin@direka.app',
  };
  try {
    if (existing) {
      await setDoc(doc(db, COL, existing.id), data, { merge: true });
      showToast('Konten diperbarui!', 'success');
    } else {
      data.createdAt = serverTimestamp();
      data.createdBy = 'admin@direka.app';
      await addDoc(collection(db, COL), data);
      showToast('Konten dipublikasikan!', 'success');
    }
    closeModal();
    await loadPosts();
  } catch (err) {
    showToast('Gagal simpan: ' + err.message, 'error');
  }
}

async function deletePost(id) {
  try {
    await deleteDoc(doc(db, COL, id));
    allPosts = allPosts.filter(p => p.id !== id);
    applyFilter();
    showToast('Konten dihapus.', 'success');
  } catch (err) {
    showToast('Gagal hapus: ' + err.message, 'error');
  }
}

function typeBadge(type) {
  if (type === 'artikel') return '<span class="badge badge-info">Artikel</span>';
  if (type === 'booklet') return '<span class="badge badge-success">Booklet</span>';
  return '<span class="badge badge-neutral">-</span>';
}
