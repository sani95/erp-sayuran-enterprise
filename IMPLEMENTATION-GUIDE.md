
# ERP SAYURAN ENTERPRISE - IMPLEMENTATION GUIDE

## 1. Cara Hitung HPP (Actual Cost Per Batch) - Paling Penting

```typescript
// services/hpp.service.ts
export async function calculateHPP(batchNumber: string) {
  const costs = await prisma.batchCost.findMany({ where: { batchNumber } });
  const production = await prisma.productionBatch.findUnique({ where: { batchNumber } });
  
  const totalHPP = costs.reduce((sum, c) => sum + c.amount, 0);
  const hppPerKg = totalHPP / production.beratOutput;
  const hppPerPack = totalHPP / production.jumlahPack;
  
  return { totalHPP, hppPerKg, hppPerPack };
}
```

JANGAN pakai average cost. Setiap batch punya HPP sendiri.

## 2. Cara Implementasi FIFO

```typescript
// services/stock.service.ts
export async function getFIFOStock(productId: number, location: string, qtyNeeded: number) {
  const batches = await prisma.stockMovement.findMany({
    where: { productId, location, qtyBalance: { gt: 0 } },
    orderBy: { createdAt: 'asc' } // FIFO = tertua dulu
  });
  
  let remaining = qtyNeeded;
  const picked = [];
  for (const batch of batches) {
    if (remaining <= 0) break;
    const take = Math.min(batch.qtyBalance, remaining);
    picked.push({ batchNumber: batch.batchNumber, qty: take, hpp: batch.hppPerUnit });
    remaining -= take;
  }
  return picked;
}
```

## 3. Flow End-to-End Code

```typescript
// 1. PO
const po = await prisma.purchaseOrder.create({ data: { supplierId: 1, status: 'APPROVED' } });

// 2. Penerimaan - Rumus PRD
const beratDiterima = beratBeli * (1 - potonganPct/100);
await prisma.goodsReceipt.create({
  data: { poId: po.id, batchNumber: generateBatch(), beratBeli, potonganSupplierPct, beratDiterima }
});
await prisma.stockMovement.create({
  data: { batchNumber, productId, location: 'GUDANG_MOJOKERTO', movementType: 'IN', qtyIn: beratDiterima, qtyBalance: beratDiterima }
});

// 3. QC
await prisma.qcInspection.create({ data: { receiptId, gradeA, gradeB, reject } });

// 4. Produksi - Yield 97%
const beratOutput = gradeA * 0.97;
const jumlahPack = Math.floor(beratOutput / packWeight);
const sisaCurah = beratOutput % packWeight;

// 5. HPP - Tambah semua biaya ke batch_costs
await prisma.batchCost.createMany({ data: [
  { batchNumber, costType: 'BAHAN_BAKU', amount: beratBeli * hargaPerKg },
  { batchNumber, costType: 'PAYROLL_GUDANG', amount: 150000 },
  // ... semua komponen
]});

// 6. Distribusi Gudang -> Lapak
await prisma.stockMovement.create({ data: { batchNumber, location: 'GUDANG_MOJOKERTO', movementType: 'DISTRIBUTION_OUT', qtyOut: qty } });
await prisma.stockMovement.create({ data: { batchNumber, location: 'LAPAK_PORONG', movementType: 'DISTRIBUTION_IN', qtyIn: qty, qtyBalance: qty } });

// 7. Penjualan - Pakai FIFO
const fifoBatches = await getFIFOStock(productId, 'LAPAK_PORONG', qtyJual);
for (const b of fifoBatches) {
  await prisma.salesItem.create({
    data: { salesId, batchNumber: b.batchNumber, qty: b.qty, hppPerUnit: b.hpp, hargaJualPerUnit, margin: hargaJualPerUnit - b.hpp }
  });
}
```

## 4. Dashboard Owner Query

```sql
-- KPI Realtime
SELECT 
  SUM(CASE WHEN DATE(created_at) = CURRENT_DATE THEN total_omzet ELSE 0 END) as omzet_hari_ini,
  SUM(total_omzet - total_hpp) as laba,
  SUM(total_hpp) / NULLIF(SUM(total_omzet),0) as hpp_avg
FROM sales;

-- Margin per Batch
SELECT batch_number, product_name, total_hpp_batch, hpp_per_pack, harga_jual, margin_pct 
FROM v_hpp_batch 
JOIN sales_items USING(batch_number);
```

## 5. Setup

1. npm install
2. npx prisma migrate dev
3. npm run dev

.env:
DATABASE_URL=postgresql://...
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
