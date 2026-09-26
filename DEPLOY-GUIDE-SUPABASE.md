
# DEPLOY ERP SAYURAN KE SUPABASE - PANDUAN LENGKAP

## LANGKAH 1: BUAT PROJECT SUPABASE (5 menit)
1. Buka https://supabase.com > New Project
2. Nama: erp-sayuran-enterprise
3. Password DB: buat yang kuat, simpan
4. Region: Singapore (paling dekat Surabaya)
5. Tunggu 2 menit sampai project ready

## LANGKAH 2: JALANKAN SQL SCHEMA (2 menit)
1. Di Supabase Dashboard > SQL Editor > New Query
2. Copy paste isi file `supabase-schema.sql` > Run
   -> Akan buat 17 tabel + seed data produk, supplier, COA
3. Copy paste isi file `supabase-realtime-rls.sql` > Run
   -> Akan aktifkan realtime + trigger berat_diterima

## LANGKAH 3: SETUP AUTH & ROLES (3 menit)
1. Authentication > Users > Create User
   - superadmin@erp-sayuran.id / password123
   - owner@erp-sayuran.id
   - gudang@erp-sayuran.id
2. SQL Editor > Jalankan:
```sql
-- Buat tabel roles
create table public.user_roles (
  user_id uuid references auth.users(id) primary key,
  role varchar(30) not null check (role in ('SUPER_ADMIN','OWNER','PURCHASING','KEPALA_GUDANG','STAFF_GUDANG','SOPIR','KEPALA_LAPAK','KASIR','ACCOUNTING')),
  created_at timestamptz default now()
);
-- Insert role (ganti user_id dari Auth > Users)
insert into user_roles (user_id, role) values ('uuid-superadmin','SUPER_ADMIN');
```

## LANGKAH 4: SETUP STORAGE UNTUK SELFIE GPS (2 menit)
1. Storage > New Bucket > attendance-selfie (public)
2. Storage > New Bucket > product-photos (public)
3. Policies > Allow authenticated upload

## LANGKAH 5: DEPLOY FRONTEND KE VERCEL (5 menit)
1. Download artifact full system yang sudah jadi
2. Buat repo GitHub baru, push
3. Vercel.com > New Project > Import GitHub repo
4. Environment Variables: paste dari .env.example (isi URL & ANON KEY dari Supabase Settings > API)
5. Deploy > Selesai, dapat URL https://erp-sayuran.vercel.app

## LANGKAH 6: TEST FLOW END-TO-END
1. Login sebagai Purchasing > Buat PO: Supplier Pare, 100kg
2. Login sebagai Kepala Gudang > Penerimaan: Input berat beli 100, potongan 7% -> auto 93kg, batch BATCH-20260926-PARE-001
3. QC: Grade A 83.7kg, B 6.51kg, Reject 2.79kg
4. Produksi: Pilih batch, product Daun Bawang Kecil 0.85kg -> auto jadi 95 pack + curah 0.439kg
5. HPP: Tambah biaya bahan baku Rp 1.2jt + payroll + kemasan -> Total HPP Rp 1.702.500, HPP/pack Rp 17.921
6. Distribusi: Gudang Mojokerto -> Lapak Porong, status In Transit (driver GPS)
7. Penjualan: Kasir Lapak Porong jual 10 pack FIFO -> Omzet Rp 250rb, Laba Rp 70.790
8. Dashboard Owner: Cek KPI realtime langsung update via Supabase Realtime (tanpa refresh)

## FITUR REALTIME YANG SUDAH AKTIF
- Dashboard Owner pakai Supabase Realtime Channel:
```typescript
const channel = supabase.channel('dashboard')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'sales' }, () => refreshKPI())
  .on('postgres_changes', { event: '*', schema: 'public', table: 'stock_movements' }, () => refreshStok())
  .subscribe()
```

## NEXT: EDGE FUNCTION UNTUK HPP AUTO
Buat di Supabase Dashboard > Edge Functions > New Function `calculate-hpp`:
```typescript
// supabase/functions/calculate-hpp/index.ts
// Auto hitung HPP setiap ada batch_costs baru
```

## BIAYA SUPABASE
- Free tier: 500MB DB, 1GB storage, 50k MAU - cukup untuk MVP 1 bulan
- Pro $25/bulan: 8GB DB, 100GB storage - cukup untuk produksi Gudang Mojokerto + Lapak Porong

Butuh bantuan deploy? Kirim project URL Supabase kamu, aku bantu cek SQL & koneksi Vercel.
