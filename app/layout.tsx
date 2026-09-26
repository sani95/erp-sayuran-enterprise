
import './globals.css'
export const metadata = { title: 'ERP Sayuran Enterprise', description: 'Gudang Mojokerto & Lapak Porong - FIFO + Actual Cost HPP' }
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="id"><body className="bg-gray-50">{children}</body></html>
}
