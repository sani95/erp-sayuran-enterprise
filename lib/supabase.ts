
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// FIFO Service - sesuai PRD
export async function getFIFOStock(productId: number, location: string, qtyNeeded: number) {
  const { data } = await supabase
    .from('stock_movements')
    .select('*')
    .eq('product_id', productId)
    .eq('location', location)
    .gt('qty_balance', 0)
    .order('created_at', { ascending: true })
  
  let remaining = qtyNeeded
  const picked: any[] = []
  for (const batch of data || []) {
    if (remaining <= 0) break
    const take = Math.min(Number(batch.qty_balance), remaining)
    picked.push({ ...batch, qty_take: take })
    remaining -= take
  }
  return picked
}
