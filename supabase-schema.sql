
-- =====================================================
-- ERP SAYURAN ENTERPRISE v1.0 - SUPABASE DEPLOYMENT
-- Paste ini di Supabase Dashboard > SQL Editor > Run
-- =====================================================

-- Enable extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- 1. MASTER DATA
create table if not exists products (
  id serial primary key,
  sku varchar(50) unique not null,
  name varchar(100) not null,
  type varchar(20) not null check (type in ('RAW','FINISHED_GOOD','CURAH','REJECT')),
  pack_weight decimal(10,3),
  shrinkage_pct decimal(5,2) default 3.00,
  yield_pct decimal(5,2) default 97.00,
  created_at timestamptz default now()
);

create table if not exists suppliers (
  id serial primary key,
  name varchar(100) not null,
  deduction_pct decimal(5,2) default 0,
  deduction_type varchar(20) default 'PERCENTAGE',
  score decimal(5,2),
  is_active boolean default true,
  created_at timestamptz default now()
);

create table if not exists customers (
  id serial primary key,
  name varchar(100) not null,
  type varchar(20) not null check (type in ('GROSIR','ECERAN','RESELLER')),
  credit_limit decimal(15,2) default 0,
  balance decimal(15,2) default 0,
  created_at timestamptz default now()
);

create table if not exists employees (
  id serial primary key,
  name varchar(100) not null,
  role varchar(30) not null,
  base_salary decimal(15,2),
  is_active boolean default true,
  created_at timestamptz default now()
);

-- 2. PURCHASING & BATCH CORE (TRACEABILITY 100%)
create table if not exists purchase_orders (
  id serial primary key,
  po_number varchar(50) unique not null,
  supplier_id int references suppliers(id),
  status varchar(20) not null default 'DRAFT' check (status in ('DRAFT','WAITING_APPROVAL','APPROVED','PARTIALLY_RECEIVED','COMPLETED','CANCELLED')),
  total_weight_beli decimal(10,2),
  total_hutang decimal(15,2),
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

create table if not exists goods_receipts (
  id serial primary key,
  po_id int references purchase_orders(id),
  batch_number varchar(100) unique not null,
  berat_beli decimal(10,2) not null,
  potongan_supplier_pct decimal(5,2) not null,
  berat_diterima decimal(10,2) not null, -- dihitung aplikasi: berat_beli * (1 - potongan/100)
  received_at timestamptz default now(),
  received_by uuid references auth.users(id)
);

create table if not exists qc_inspections (
  id serial primary key,
  receipt_id int references goods_receipts(id) on delete cascade,
  batch_number varchar(100) not null,
  grade_a_kg decimal(10,2) default 0,
  grade_b_kg decimal(10,2) default 0,
  grade_c_kg decimal(10,2) default 0,
  reject_kg decimal(10,2) default 0,
  quality_pct decimal(5,2),
  reject_pct decimal(5,2),
  created_at timestamptz default now()
);

create table if not exists production_batches (
  id serial primary key,
  batch_number varchar(100) unique not null references goods_receipts(batch_number),
  product_id int references products(id),
  berat_input decimal(10,2) not null,
  berat_output decimal(10,2) not null,
  penyusutan_kg decimal(10,2),
  jumlah_pack int not null,
  sisa_curah_kg decimal(10,2) default 0,
  status varchar(20) default 'SELESAI',
  created_at timestamptz default now()
);

-- 3. HPP ACTUAL COST PER BATCH (TIDAK BOLEH AVERAGE)
create table if not exists batch_costs (
  id serial primary key,
  batch_number varchar(100) not null references production_batches(batch_number) on delete cascade,
  cost_type varchar(30) not null check (cost_type in ('BAHAN_BAKU','PAYROLL_GUDANG','PAYROLL_LAPAK','UANG_MAKAN','TRANSPORT','DISTRIBUSI','OVERHEAD','KEMASAN')),
  amount decimal(15,2) not null,
  description text,
  created_at timestamptz default now()
);

-- VIEW HPP REALTIME
create or replace view v_hpp_batch as
select 
  pb.batch_number,
  pb.product_id,
  p.name as product_name,
  p.sku,
  pb.jumlah_pack,
  pb.berat_output,
  coalesce(sum(bc.amount),0) as total_hpp_batch,
  case when pb.berat_output > 0 then coalesce(sum(bc.amount),0) / pb.berat_output else 0 end as hpp_per_kg,
  case when pb.jumlah_pack > 0 then coalesce(sum(bc.amount),0) / pb.jumlah_pack else 0 end as hpp_per_pack
from production_batches pb
join products p on p.id = pb.product_id
left join batch_costs bc on bc.batch_number = pb.batch_number
group by pb.batch_number, pb.product_id, p.name, p.sku, pb.jumlah_pack, pb.berat_output;

-- 4. STOK FIFO - Semua pergerakan wajib movement
create table if not exists stock_movements (
  id serial primary key,
  batch_number varchar(100) not null,
  product_id int references products(id),
  location varchar(30) not null check (location in ('GUDANG_MOJOKERTO','LAPAK_PORONG','WIP','REJECT')),
  movement_type varchar(30) not null check (movement_type in ('IN','OUT','ADJUSTMENT','PRODUCTION_IN','PRODUCTION_OUT','DISTRIBUTION_OUT','DISTRIBUTION_IN','SALES_OUT')),
  qty_in decimal(10,2) default 0,
  qty_out decimal(10,2) default 0,
  qty_balance decimal(10,2) default 0,
  hpp_per_unit decimal(15,2),
  reference_id varchar(100),
  created_at timestamptz default now(),
  created_by uuid references auth.users(id)
);
create index if not exists idx_fifo on stock_movements (product_id, location, created_at asc, batch_number);
create index if not exists idx_batch on stock_movements (batch_number);

-- 5. DISTRIBUSI GUDANG -> LAPAK
create table if not exists distributions (
  id serial primary key,
  do_number varchar(50) unique not null,
  from_location varchar(30) default 'GUDANG_MOJOKERTO',
  to_location varchar(30) default 'LAPAK_PORONG',
  status varchar(20) not null default 'DRAFT' check (status in ('DRAFT','PICKING','LOADING','IN_TRANSIT','RECEIVED','COMPLETED')),
  driver_id int references employees(id),
  shipped_at timestamptz,
  received_at timestamptz,
  created_at timestamptz default now()
);

create table if not exists distribution_items (
  id serial primary key,
  distribution_id int references distributions(id) on delete cascade,
  batch_number varchar(100) not null,
  product_id int references products(id),
  qty decimal(10,2) not null
);

-- 6. PENJUALAN LAPAK PORONG
create table if not exists sales (
  id serial primary key,
  invoice_number varchar(50) unique not null,
  customer_id int references customers(id),
  location varchar(30) default 'LAPAK_PORONG',
  type varchar(20) not null check (type in ('TUNAI','TRANSFER','KREDIT')),
  total_omzet decimal(15,2) default 0,
  total_hpp decimal(15,2) default 0,
  total_margin decimal(15,2) default 0,
  status varchar(20) default 'SELESAI',
  created_at timestamptz default now(),
  created_by uuid references auth.users(id)
);

create table if not exists sales_items (
  id serial primary key,
  sales_id int references sales(id) on delete cascade,
  batch_number varchar(100) not null,
  product_id int references products(id),
  qty decimal(10,2) not null,
  hpp_per_unit decimal(15,2),
  harga_jual_per_unit decimal(15,2),
  margin_per_unit decimal(15,2)
);

-- 7. HUTANG PIUTANG
create table if not exists payables (
  id serial primary key,
  supplier_id int references suppliers(id),
  po_id int references purchase_orders(id),
  amount decimal(15,2) not null,
  paid_amount decimal(15,2) default 0,
  status varchar(20) not null default 'BELUM_JATUH_TEMPO' check (status in ('BELUM_JATUH_TEMPO','JATUH_TEMPO','SEBAGIAN_DIBAYAR','LUNAS')),
  due_date date,
  created_at timestamptz default now()
);

create table if not exists receivables (
  id serial primary key,
  customer_id int references customers(id),
  sales_id int references sales(id),
  amount decimal(15,2) not null,
  paid_amount decimal(15,2) default 0,
  status varchar(20) not null default 'BELUM_JATUH_TEMPO' check (status in ('BELUM_JATUH_TEMPO','JATUH_TEMPO','SEBAGIAN_DIBAYAR','LUNAS')),
  due_date date,
  created_at timestamptz default now()
);

-- 8. PAYROLL GPS + SELFIE
create table if not exists attendance (
  id serial primary key,
  employee_id int references employees(id),
  check_in timestamptz,
  check_out timestamptz,
  gps_lat decimal(10,6),
  gps_lng decimal(10,6),
  selfie_url text,
  location_verified boolean default false,
  created_at timestamptz default now()
);

create table if not exists payrolls (
  id serial primary key,
  employee_id int references employees(id),
  period date not null,
  base_salary decimal(15,2),
  bonus decimal(15,2) default 0,
  kasbon decimal(15,2) default 0,
  uang_makan decimal(15,2) default 0,
  total_pay decimal(15,2),
  created_at timestamptz default now()
);

-- 9. AKUNTANSI DOUBLE ENTRY
create table if not exists chart_of_accounts (
  id serial primary key,
  code varchar(20) unique not null,
  name varchar(100) not null,
  type varchar(20) not null check (type in ('ASSET','LIABILITY','EQUITY','REVENUE','EXPENSE'))
);

create table if not exists journal_entries (
  id serial primary key,
  journal_number varchar(50) unique not null,
  transaction_type varchar(30) not null,
  reference_id varchar(100),
  batch_number varchar(100),
  description text,
  created_at timestamptz default now(),
  created_by uuid references auth.users(id)
);

create table if not exists journal_lines (
  id serial primary key,
  journal_id int references journal_entries(id) on delete cascade,
  coa_id int references chart_of_accounts(id),
  debit decimal(15,2) default 0,
  credit decimal(15,2) default 0
);

-- 10. AUDIT LOG
create table if not exists audit_logs (
  id serial primary key,
  user_id uuid references auth.users(id),
  action varchar(50) not null,
  table_name varchar(50),
  record_id varchar(100),
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz default now()
);

-- SEED DATA AWAL
insert into products (sku, name, type, pack_weight, shrinkage_pct, yield_pct) values
('DBW-KECIL-085','Daun Bawang Kecil','FINISHED_GOOD',0.85,3.00,97.00),
('DBW-BESAR-090','Daun Bawang Besar','FINISHED_GOOD',0.90,3.00,97.00),
('JAGUNG-WRAP','Jagung Wrapping','FINISHED_GOOD',1.00,3.00,97.00),
('DBW-RAW','Daun Bawang Raw Material','RAW',null,0,100),
('CURAH','Curah Sisa Packing','CURAH',null,0,100)
on conflict (sku) do nothing;

insert into suppliers (name, deduction_pct, deduction_type) values
('Pare',7,'PERCENTAGE'),
('Pacet',0,'PERCENTAGE'),
('Supplier Khusus',5,'CONTRACT')
on conflict do nothing;

insert into chart_of_accounts (code, name, type) values
('101','Kas','ASSET'),
('102','Piutang Usaha','ASSET'),
('103','Persediaan Gudang Mojokerto','ASSET'),
('104','Persediaan Lapak Porong','ASSET'),
('105','Persediaan WIP','ASSET'),
('201','Hutang Supplier','LIABILITY'),
('401','Omzet Penjualan','REVENUE'),
('501','HPP','EXPENSE'),
('502','Biaya Gaji Gudang','EXPENSE'),
('503','Biaya Gaji Lapak','EXPENSE'),
('504','Biaya Transport','EXPENSE'),
('505','Biaya Distribusi','EXPENSE'),
('506','Biaya Overhead','EXPENSE')
on conflict (code) do nothing;
