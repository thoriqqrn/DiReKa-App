// modules/broadcast.js — Kirim Broadcast Notifikasi ke admin_broadcasts
import { db } from '../firebase.js';
import {
  collection, addDoc, getDocs, deleteDoc, doc,
  query, orderBy, serverTimestamp,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';
import { showToast, showConfirm, fmtDate } from '../dashboard.js';

const COL = 'admin_broadcasts';

let broadcasts = [];

export async function initBroadcast() {
  const main = document.getElementById('mainContent');
  main.innerHTML = `
    <div class="section-header">
      <div><h2>Broadcast Notifikasi</h2><p>Kirim pengumuman ke seluruh pengguna.</p></div>
    </div>

    <!-- Form -->
    <div class="card" style="margin-bottom:1.5rem">
      <div class="card-header"><h3>Buat Broadcast Baru</h3></div>
      <div class="card-body">
        <div class="form-group">
          <label>Judul Notifikasi *</label>
          <input id="bTitle" placeholder="Contoh: Update Fitur Baru" style="width:100%;padding:.6rem .75rem;border:1.5px solid var(--color-border);border-radius:var(--radius-sm);font-size:.88rem" />
        </div>
        <div class="form-group">
          <label>Pesan *</label>
          <textarea id="bMessage" rows="4" placeholder="Tulis pesan broadcast..." style="width:100%;padding:.6rem .75rem;border:1.5px solid var(--color-border);border-radius:var(--radius-sm);font-size:.88rem;resize:vertical"></textarea>
        </div>
        <button class="btn btn-warning" id="btnSendBroadcast">
          <i class="fa fa-bullhorn"></i> Kirim Broadcast
        </button>
      </div>
    </div>

    <!-- Riwayat -->
    <div class="card">
      <div class="card-header"><h3 id="bCount">Riwayat Broadcast</h3></div>
      <div class="card-body no-pad">
        <div class="table-wrap">
          <table>
            <thead>
              <tr><th>#</th><th>Judul</th><th>Pesan</th><th>Dikirim Oleh</th><th>Waktu</th><th>Aksi</th></tr>
            </thead>
            <tbody id="bTbody">
              <tr><td colspan="6" class="table-empty"><div class="table-loading"><div class="spinner"></div>Memuat...</div></td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>`;

  document.getElementById('btnSendBroadcast').addEventListener('click', sendBroadcast);
  await loadBroadcasts();
}

async function loadBroadcasts() {
  try {
    const snap = await getDocs(query(collection(db, COL), orderBy('createdAt', 'desc')));
    broadcasts = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    renderBroadcasts();
  } catch (err) {
    document.getElementById('bTbody').innerHTML =
      `<tr><td colspan="6" class="table-empty">Gagal memuat: ${err.message}</td></tr>`;
  }
}

function renderBroadcasts() {
  document.getElementById('bCount').textContent = `${broadcasts.length} Riwayat Broadcast`;
  const tbody = document.getElementById('bTbody');
  if (broadcasts.length === 0) {
    tbody.innerHTML = `<tr><td colspan="6" class="table-empty">Belum ada broadcast.</td></tr>`;
    return;
  }
  tbody.innerHTML = broadcasts.map((b, i) => `
    <tr>
      <td class="muted">${i + 1}</td>
      <td><strong>${b.title ?? '-'}</strong></td>
      <td style="max-width:300px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis" class="muted text-sm">
        ${(b.message ?? '-').slice(0, 100)}${(b.message ?? '').length > 100 ? '…' : ''}
      </td>
      <td class="muted text-sm">${b.sentBy ?? '-'}</td>
      <td class="muted text-sm">${fmtDate(b.createdAt)}</td>
      <td>
        <button class="btn btn-ghost btn-sm btn-del" data-id="${b.id}" data-title="${b.title}">
          <i class="fa fa-trash"></i>
        </button>
      </td>
    </tr>`).join('');

  tbody.querySelectorAll('.btn-del').forEach(b =>
    b.addEventListener('click', () =>
      showConfirm('Hapus Broadcast?',
        `Hapus broadcast <strong>${b.dataset.title}</strong>?`,
        () => deleteBroadcast(b.dataset.id))));
}

async function sendBroadcast() {
  const title   = document.getElementById('bTitle').value.trim();
  const message = document.getElementById('bMessage').value.trim();
  if (!title || !message) {
    showToast('Judul dan pesan wajib diisi.', 'warning'); return;
  }
  const btn = document.getElementById('btnSendBroadcast');
  btn.disabled = true; btn.textContent = 'Mengirim...';
  try {
    await addDoc(collection(db, COL), {
      title,
      message,
      sentBy:    'admin@direka.app',
      createdAt: serverTimestamp(),
    });
    document.getElementById('bTitle').value   = '';
    document.getElementById('bMessage').value = '';
    showToast('Broadcast berhasil dikirim!', 'success');
    await loadBroadcasts();
  } catch (err) {
    showToast('Gagal kirim: ' + err.message, 'error');
  } finally {
    btn.disabled = false;
    btn.innerHTML = '<i class="fa fa-bullhorn"></i> Kirim Broadcast';
  }
}

async function deleteBroadcast(id) {
  try {
    await deleteDoc(doc(db, COL, id));
    broadcasts = broadcasts.filter(b => b.id !== id);
    renderBroadcasts();
    showToast('Broadcast dihapus.', 'success');
  } catch (err) {
    showToast('Gagal hapus: ' + err.message, 'error');
  }
}
