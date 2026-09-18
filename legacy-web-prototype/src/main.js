// Phase 1 scaffold: initialize the DB, seed default brands, and confirm on screen.
// Auth/routing/screens are added in later phases.
import { seedBrandsIfEmpty, store } from './db/db.js';

const app = document.getElementById('app');

async function init() {
  await seedBrandsIfEmpty();
  const brands = await store.list('brands');

  app.innerHTML = `
    <div class="auth-wrap">
      <div class="brand">
        <div class="logo">Stock</div>
        <p>Phase 1 check — IndexedDB is live</p>
      </div>
      <div class="card">
        <div class="card-title">Seeded brands (${brands.length})</div>
        <div class="card-sub">
          ${brands.map((b) => `${b.name}: ₹${b.ratePerCft}/cft`).join('<br>')}
        </div>
      </div>
    </div>
  `;
}

init();
