// Generic IndexedDB persistence layer.
// Exposes a minimal get/set/list/delete interface so the storage backend
// (IndexedDB today) can be swapped later without touching business logic or UI.

const DB_NAME = 'stock-db';
const DB_VERSION = 1;

const STORE_CONFIG = {
  users: { keyPath: 'username' },
  brands: { keyPath: 'id', autoIncrement: true },
  purchases: { keyPath: 'id', autoIncrement: true },
  sales: { keyPath: 'id', autoIncrement: true },
};

let dbPromise = null;

function openDB() {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);

    request.onupgradeneeded = () => {
      const db = request.result;
      for (const [name, config] of Object.entries(STORE_CONFIG)) {
        if (!db.objectStoreNames.contains(name)) {
          db.createObjectStore(name, config);
        }
      }
    };

    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  return dbPromise;
}

function tx(storeName, mode) {
  return openDB().then(
    (db) =>
      new Promise((resolve, reject) => {
        const transaction = db.transaction(storeName, mode);
        const store = transaction.objectStore(storeName);
        resolve(store);
        transaction.onerror = () => reject(transaction.error);
      })
  );
}

function wrapRequest(request) {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

// Storage interface: list / get / set / remove.
// `set` inserts when the record has no key, updates when it does.
export const store = {
  async list(storeName) {
    const s = await tx(storeName, 'readonly');
    return wrapRequest(s.getAll());
  },

  async get(storeName, key) {
    const s = await tx(storeName, 'readonly');
    return wrapRequest(s.get(key));
  },

  async set(storeName, record) {
    const s = await tx(storeName, 'readwrite');
    const key = await wrapRequest(s.put(record));
    const { keyPath } = STORE_CONFIG[storeName];
    return record[keyPath] !== undefined ? record[keyPath] : key;
  },

  async remove(storeName, key) {
    const s = await tx(storeName, 'readwrite');
    await wrapRequest(s.delete(key));
  },
};

// Seeds default brands on first run only (does not overwrite edits made later).
const DEFAULT_BRANDS = [
  { name: 'Crush 16mm', ratePerCft: 52 },
  { name: 'Crush 10mm', ratePerCft: 52 },
  { name: 'Crush 50mm', ratePerCft: 52 },
  { name: 'Crush 0mm', ratePerCft: 52 },
  { name: 'Ghera', ratePerCft: 39 },
  { name: 'Khaka', ratePerCft: 27 },
  { name: 'Mitti', ratePerCft: 16 },
  { name: 'Retti (Silica)', ratePerCft: 39 },
  { name: 'Danedar', ratePerCft: 39 },
];

export async function seedBrandsIfEmpty() {
  const existing = await store.list('brands');
  if (existing.length > 0) return;
  for (const brand of DEFAULT_BRANDS) {
    await store.set('brands', brand);
  }
}
