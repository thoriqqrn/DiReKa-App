// firebase.js — Modul inisialisasi Firebase (modular SDK v10)
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js';
import { getAuth } from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js';
import { getFirestore } from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';

const firebaseConfig = {
  apiKey: 'AIzaSyAmx83myfs7KMbguedq2C72dLbu_DD5aA8',
  authDomain: 'direka-app.firebaseapp.com',
  projectId: 'direka-app',
  storageBucket: 'direka-app.firebasestorage.app',
  messagingSenderId: '742908514617',
  appId: '1:742908514617:android:b365397a3bc772f22818e8',
};

const app  = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db   = getFirestore(app);
