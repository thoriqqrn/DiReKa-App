import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import { getFirestore, collection, addDoc, serverTimestamp } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyAmx83myfs7KMbguedq2C72dLbu_DD5aA8',
  authDomain: 'direka-app.firebaseapp.com',
  projectId: 'direka-app',
  storageBucket: 'direka-app.firebasestorage.app',
  messagingSenderId: '742908514617',
  appId: '1:742908514617:android:b365397a3bc772f22818e8',
};

const cookingMethods = [
  {
    name: 'Digoreng (deep fry)',
    category: 'Goreng',
    description: 'Digoreng dalam banyak minyak. Menyerap ±10g lemak per 100g bahan baku.',
    affectsNutritionBy: 'addition',
    extraCalPer100g: 90, extraFatPer100g: 10, extraKarboPer100g: 0,
    extraProteinPer100g: 0, extraNatriumPer100g: 0, defaultFk: 1.0,
  },
  {
    name: 'Digoreng tepung',
    category: 'Goreng',
    description: 'Digoreng dengan balutan tepung. Menyerap ±15g lemak per 100g bahan.',
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
  {
    name: 'Direbus',
    category: 'Rebus',
    description: 'Direbus dalam air. FK = 1.0.',
    affectsNutritionBy: 'factor',
    extraCalPer100g: 0, extraFatPer100g: 0, extraKarboPer100g: 0,
    extraProteinPer100g: 0, extraNatriumPer100g: 0, defaultFk: 1.0,
  },
  {
    name: 'Dikukus',
    category: 'Kukus',
    description: 'Dikukus dengan uap air.',
    affectsNutritionBy: 'factor',
    extraCalPer100g: 0, extraFatPer100g: 0, extraKarboPer100g: 0,
    extraProteinPer100g: 0, extraNatriumPer100g: 0, defaultFk: 1.0,
  },
  {
    name: 'Dibakar / Dipanggang',
    category: 'Bakar/Panggang',
    description: 'Dibakar atau dipanggang tanpa minyak.',
    affectsNutritionBy: 'factor',
    extraCalPer100g: 0, extraFatPer100g: 0, extraKarboPer100g: 0,
    extraProteinPer100g: 0, extraNatriumPer100g: 0, defaultFk: 1.2,
  },
  {
    name: 'Mentah (Tidak Diolah)',
    category: 'Mentah',
    description: 'Tanpa pengolahan.',
    affectsNutritionBy: 'factor',
    extraCalPer100g: 0, extraFatPer100g: 0, extraKarboPer100g: 0,
    extraProteinPer100g: 0, extraNatriumPer100g: 0, defaultFk: 1.0,
  },
];

const additives = [
  { name: 'Minyak Goreng (Sawit)', category: 'Lemak & Minyak',
    unitLabel: '1 Sendok Makan', gramPerUnit: 13,
    calPerUnit: 115, fatPerUnit: 13, karboPerUnit: 0, proteinPerUnit: 0,
    natriumPerUnit: 0, kaliumPerUnit: 0, fosforPerUnit: 0, seratPerUnit: 0,
    description: 'Minyak kelapa sawit.' },
  { name: 'Gula Pasir', category: 'Pemanis',
    unitLabel: '1 Sendok Makan', gramPerUnit: 12,
    calPerUnit: 46, fatPerUnit: 0, karboPerUnit: 12, proteinPerUnit: 0,
    natriumPerUnit: 0, kaliumPerUnit: 0, fosforPerUnit: 0, seratPerUnit: 0,
    description: 'Gula pasir putih.' },
  { name: 'Tepung Terigu', category: 'Tepung & Pati',
    unitLabel: '1 Sendok Makan', gramPerUnit: 10,
    calPerUnit: 36, fatPerUnit: 0.1, karboPerUnit: 7.5, proteinPerUnit: 1,
    natriumPerUnit: 0, kaliumPerUnit: 20, fosforPerUnit: 25, seratPerUnit: 0.2,
    description: 'Tepung terigu serbaguna.' },
  { name: 'Kecap Manis', category: 'Saus & Kecap',
    unitLabel: '1 Sendok Makan', gramPerUnit: 18,
    calPerUnit: 43, fatPerUnit: 0, karboPerUnit: 10.5, proteinPerUnit: 0.9,
    natriumPerUnit: 490, kaliumPerUnit: 35, fosforPerUnit: 20, seratPerUnit: 0,
    description: 'Kecap manis. SANGAT TINGGI NATRIUM.' },
  { name: 'Garam Dapur', category: 'Garam',
    unitLabel: '1 Sendok Teh', gramPerUnit: 5,
    calPerUnit: 0, fatPerUnit: 0, karboPerUnit: 0, proteinPerUnit: 0,
    natriumPerUnit: 1960, kaliumPerUnit: 0, fosforPerUnit: 0, seratPerUnit: 0,
    description: 'Garam dapur NaCl.' },
];

async function run() {
  console.log('Menginisialisasi Firebase...');
  const app = initializeApp(firebaseConfig);
  const auth = getAuth(app);
  const db = getFirestore(app);

  console.log('Mencoba login admin...');
  await signInWithEmailAndPassword(auth, 'admin@direka.app', 'admin123');
  console.log('Login berhasil sebagai admin!');

  console.log('Memulai seed cooking_methods...');
  for (const m of cookingMethods) {
    await addDoc(collection(db, 'cooking_methods'), {
      ...m,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    });
    console.log(`- Seeded: ${m.name}`);
  }

  console.log('Memulai seed food_additives...');
  for (const a of additives) {
    await addDoc(collection(db, 'food_additives'), {
      ...a,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    });
    console.log(`- Seeded: ${a.name}`);
  }

  console.log('Seed selesai sukses!');
  process.exit(0);
}

run().catch(err => {
  console.error('Seed gagal:', err);
  process.exit(1);
});
