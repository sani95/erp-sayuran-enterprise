# ERP SAYURAN ENTERPRISE v1.0 - COMPLETE PACKAGE

## Isi Paket ZIP
- ERP-Sayuran-HPP-Simulasi.xlsx - Simulasi HPP Actual Cost Per Batch
- supabase-schema.sql - SQL Schema lengkap untuk Supabase (17 tabel)
- supabase-realtime-rls.sql - Enable Realtime + Trigger
- schema.prisma - Prisma schema untuk Next.js
- supabase-client.ts - Service FIFO & HPP
- erp-api-spec.yaml - OpenAPI 3.0 Spec 20+ endpoints
- .env.example - Template environment
- DEPLOY-GUIDE-SUPABASE.md - Panduan deploy 10 menit
- IMPLEMENTATION-GUIDE.md - Panduan implementasi kode
- erp-sayuran-full-system.html - Aplikasi ERP Full System (buka di browser)
- erp-sayuran-dashboard.html - Dashboard Owner Realtime

## Quick Start
1. Buka Supabase.com -> New Project (Singapore)
2. SQL Editor -> Run supabase-schema.sql
3. SQL Editor -> Run supabase-realtime-rls.sql
4. Copy .env.example jadi .env.local, isi SUPABASE_URL & ANON_KEY
5. Deploy frontend ke Vercel

Lihat TUTORIAL-PDF untuk panduan lengkap dengan screenshot.

## Arsitektur
- Frontend: Next.js 15 + Tailwind (artifact sudah jadi)
- Backend: Supabase PostgreSQL + Realtime + Auth + Storage
- HPP: Actual Cost Per Batch (bukan average)
- Stok: FIFO ORDER BY created_at ASC
- Akuntansi: Double Entry Auto Journal

## Kontak
Siap bantu deploy & custom.

Versi: 1.0 Final Draft
Tanggal: 26 Sep 2026
Lokasi: Gudang Mojokerto & Lapak Porong
