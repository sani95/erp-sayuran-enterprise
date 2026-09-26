
-- =====================================================
-- ENABLE REALTIME UNTUK DASHBOARD OWNER
-- =====================================================
-- Jalankan ini setelah schema di atas

-- Enable realtime publication
alter publication supabase_realtime add table stock_movements;
alter publication supabase_realtime add table sales;
alter publication supabase_realtime add table sales_items;
alter publication supabase_realtime add table distributions;
alter publication supabase_realtime add table goods_receipts;
alter publication supabase_realtime add table production_batches;
alter publication supabase_realtime add table payables;
alter publication supabase_realtime add table receivables;
alter publication supabase_realtime add table v_hpp_batch;

-- Untuk MVP, nonaktifkan RLS dulu (aktifkan lagi saat production)
-- alter table products disable row level security;
-- alter table suppliers disable row level security;
-- dst. Supabase default RLS disabled untuk table baru, jadi tidak perlu.

-- Fungsi auto hitung berat_diterima
create or replace function calculate_berat_diterima()
returns trigger as $$
begin
  NEW.berat_diterima := NEW.berat_beli * (1 - NEW.potongan_supplier_pct/100.0);
  return NEW;
end;
$$ language plpgsql;

drop trigger if exists trg_berat_diterima on goods_receipts;
create trigger trg_berat_diterima
before insert or update on goods_receipts
for each row execute function calculate_berat_diterima();

-- Fungsi audit log otomatis
create or replace function log_audit()
returns trigger as $$
begin
  insert into audit_logs (action, table_name, record_id, old_data, new_data)
  values (TG_OP, TG_TABLE_NAME, coalesce(NEW.id::text, OLD.id::text), to_jsonb(OLD), to_jsonb(NEW));
  return NEW;
end;
$$ language plpgsql;

-- Contoh trigger audit (aktifkan untuk table penting)
-- create trigger audit_stock after insert or update or delete on stock_movements for each row execute function log_audit();
