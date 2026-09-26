
# ERP Sayuran - Vercel Ready

Repo ini sudah fix untuk Vercel. 

## Deploy ke Vercel (2 menit)
1. Vercel -> New Project -> Import sani95/erp-sayuran-enterprise
2. Root Directory = vercel-ready (atau pindah semua file di vercel-ready ke root)
3. Env Vars:
   NEXT_PUBLIC_SUPABASE_URL
   NEXT_PUBLIC_SUPABASE_ANON_KEY
4. Deploy

Jika repo root masih berisi dokumen saja, copy isi folder vercel-ready ke root repo:
- app/
- lib/
- package.json (yang baru)
- next.config.js, tailwind.config.js, etc.

Lalu git push lagi.
