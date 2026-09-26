
'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

export default function Page() {
  const [stats, setStats] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    async function load() {
      try {
        const url = process.env.NEXT_PUBLIC_SUPABASE_URL
        if (!url || url.includes('your-project')) {
          setError('ENV belum di-set di Vercel. Set NEXT_PUBLIC_SUPABASE_URL & ANON_KEY di Vercel > Settings > Environment Variables')
          setLoading(false)
          return
        }
        // Test koneksi
        const { data: products } = await supabase.from('products').select('*').limit(5)
        const { data: stocks } = await supabase.from('stock_movements').select('qty_balance').limit(100)
        const { data: hpp } = await supabase.from('v_hpp_batch').select('*').limit(5)
        
        const totalStok = stocks?.reduce((s, r: any) => s + Number(r.qty_balance), 0) || 0
        
        setStats({ products, totalStok, hpp, countProducts: products?.length || 0 })
        
        // Realtime
        const channel = supabase.channel('dashboard')
          .on('postgres_changes', { event: '*', schema: 'public', table: 'sales' }, () => load())
          .on('postgres_changes', { event: '*', schema: 'public', table: 'stock_movements' }, () => load())
          .subscribe()
        
        return () => { supabase.removeChannel(channel) }
      } catch (e: any) {
        setError(e.message)
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  if (loading) return <div className="p-10 text-center">Loading ERP Sayuran...</div>
  
  if (error) return (
    <div className="p-6 max-w-3xl mx-auto">
      <div className="bg-red-50 border border-red-200 p-6 rounded-xl">
        <h2 className="font-bold text-red-800 mb-2">Vercel Belum Connect ke Supabase</h2>
        <p className="text-sm text-red-700 mb-4">{error}</p>
        <div className="bg-white p-4 rounded text-xs font-mono">
          <div>1. Buka Vercel Dashboard → Project kamu → Settings → Environment Variables</div>
          <div>2. Add:</div>
          <div className="ml-4">NEXT_PUBLIC_SUPABASE_URL = https://xxxx.supabase.co</div>
          <div className="ml-4">NEXT_PUBLIC_SUPABASE_ANON_KEY = eyJ...</div>
          <div>3. Redeploy: Deployments → ... → Redeploy</div>
        </div>
        <div className="mt-4 text-sm">Repo: https://github.com/sani95/erp-sayuran-enterprise</div>
      </div>
    </div>
  )

  return (
    <div className="p-6 max-w-6xl mx-auto">
      <h1 className="text-3xl font-bold text-green-800">ERP Sayuran Enterprise v1.0</h1>
      <p className="text-gray-600 mb-6">Gudang Mojokerto & Lapak Porong - Terhubung ke Supabase ✅</p>
      
      <div className="grid grid-cols-3 gap-4 mb-6">
        <div className="bg-white p-5 rounded-xl shadow border">
          <div className="text-sm text-gray-500">Total Produk</div>
          <div className="text-2xl font-bold">{stats?.countProducts || 0}</div>
          <div className="text-xs text-green-600">Daun Bawang Kecil 0.85kg, Besar 0.90kg, Jagung</div>
        </div>
        <div className="bg-white p-5 rounded-xl shadow border">
          <div className="text-sm text-gray-500">Total Stok</div>
          <div className="text-2xl font-bold">{stats?.totalStok?.toFixed(2)} kg</div>
          <div className="text-xs text-gray-500">FIFO - Batch tertua keluar dulu</div>
        </div>
        <div className="bg-white p-5 rounded-xl shadow border">
          <div className="text-sm text-gray-500">Koneksi</div>
          <div className="text-lg font-bold text-green-700">Supabase Realtime ON</div>
          <div className="text-xs">Dashboard update tanpa refresh</div>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow border p-5">
        <h2 className="font-bold mb-3">HPP Actual Cost Per Batch (v_hpp_batch)</h2>
        <div className="overflow-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50"><tr><th className="p-2 text-left">Batch</th><th className="p-2">Produk</th><th className="p-2">Pack</th><th className="p-2">HPP/Pack</th><th className="p-2">HPP/Kg</th></tr></thead>
            <tbody>
              {(stats?.hpp || []).map((r: any) => (
                <tr key={r.batch_number} className="border-t"><td className="p-2 font-mono text-xs">{r.batch_number}</td><td className="p-2">{r.product_name}</td><td className="p-2 text-center">{r.jumlah_pack}</td><td className="p-2 text-right">Rp {Number(r.hpp_per_pack).toLocaleString('id-ID')}</td><td className="p-2 text-right">Rp {Number(r.hpp_per_kg).toLocaleString('id-ID')}</td></tr>
              ))}
            </tbody>
          </table>
          {(!stats?.hpp || stats.hpp.length===0) && <div className="p-4 text-center text-gray-500 text-sm">Belum ada batch. Input penerimaan 100kg Pare di Supabase → auto 93kg → produksi → HPP muncul di sini</div>}
        </div>
      </div>

      <div className="mt-6 p-4 bg-green-50 border border-green-200 rounded-xl text-sm">
        <b>Next:</b> Deploy berhasil! Sekarang test: Supabase Dashboard → Table goods_receipts → Insert berat_beli 100, potongan 7% → berat_diterima auto 93kg → Cek di sini realtime update.
      </div>
    </div>
  )
}
