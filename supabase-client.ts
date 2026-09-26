
// lib/supabase.ts - Client untuk ERP Sayuran
import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

// lib/erp-service.ts - Service FIFO & HPP
export async function createGoodsReceipt(poId: number, beratBeli: number, potonganPct: number) {
  const beratDiterima = beratBeli * (1 - potonganPct/100)
  const batchNumber = `BATCH-${new Date().toISOString().slice(0,10).replace(/-/g,'')}-PARE-${String(Math.floor(Math.random()*1000)).padStart(3,'0')}`
  
  const { data, error } = await supabase
    .from('goods_receipts')
    .insert({ po_id: poId, batch_number: batchNumber, berat_beli: beratBeli, potongan_supplier_pct: potonganPct, berat_diterima: beratDiterima })
    .select()
  
  // Auto stock movement IN Gudang Mojokerto
  await supabase.from('stock_movements').insert({
    batch_number: batchNumber,
    product_id: 4, // RAW
    location: 'GUDANG_MOJOKERTO',
    movement_type: 'IN',
    qty_in: beratDiterima,
    qty_balance: beratDiterima
  })
  
  return data
}

export async function getFIFOStock(productId: number, location: string, qtyNeeded: number) {
  const { data } = await supabase
    .from('stock_movements')
    .select('*')
    .eq('product_id', productId)
    .eq('location', location)
    .gt('qty_balance', 0)
    .order('created_at', { ascending: true }) // FIFO
  
  let remaining = qtyNeeded
  const picked = []
  for (const batch of data || []) {
    if (remaining <= 0) break
    const take = Math.min(batch.qty_balance, remaining)
    picked.push({ ...batch, qty_take: take })
    remaining -= take
  }
  return picked
}

export async function calculateHPP(batchNumber: string) {
  const { data } = await supabase
    .from('v_hpp_batch')
    .select('*')
    .eq('batch_number', batchNumber)
    .single()
  return data // { total_hpp_batch, hpp_per_kg, hpp_per_pack }
}
