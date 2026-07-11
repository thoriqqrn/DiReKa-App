// auth.js — Admin auth guard + login/logout
import { auth } from './firebase.js';
import {
  signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js';

const ADMIN_EMAIL = 'admin@direka.app';

// Guard: jika belum login atau bukan admin → redirect ke login
export function requireAdmin(onReady) {
  onAuthStateChanged(auth, (user) => {
    if (!user || user.email !== ADMIN_EMAIL) {
      window.location.replace('index.html');
      return;
    }
    onReady(user);
  });
}

// Guard login page: jika sudah login → langsung ke dashboard
export function redirectIfLoggedIn() {
  onAuthStateChanged(auth, (user) => {
    if (user && user.email === ADMIN_EMAIL) {
      window.location.replace('dashboard.html');
    }
  });
}

export async function loginAdmin(email, password) {
  const cred = await signInWithEmailAndPassword(auth, email, password);
  if (cred.user.email !== ADMIN_EMAIL) {
    await signOut(auth);
    throw new Error('Akun ini bukan akun admin.');
  }
  return cred.user;
}

export async function logoutAdmin() {
  await signOut(auth);
  window.location.replace('index.html');
}
