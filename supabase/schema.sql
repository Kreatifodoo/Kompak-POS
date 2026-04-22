-- ============================================================
-- KOMPAK POS — License System Schema
-- Jalankan di Supabase SQL Editor
-- ============================================================

-- 1. TABEL LISENSI (satu baris per pelanggan)
create table if not exists licenses (
  id              uuid primary key default gen_random_uuid(),
  license_key     text unique not null,          -- format: KOMP-XXXX-XXXX-XXXX
  customer_name   text not null,
  store_name      text,
  max_devices     int not null default 1,
  status          text not null default 'unactivated'
                  check (status in ('unactivated','active','revoked','expired')),
  expires_at      timestamptz,                   -- null = lisensi seumur hidup
  notes           text,
  created_at      timestamptz not null default now()
);

-- 2. TABEL DOWNLOAD TOKEN (link APK sekali pakai)
create table if not exists download_tokens (
  id              uuid primary key default gen_random_uuid(),
  token           text unique not null,          -- random 32 char, masuk di URL
  license_id      uuid references licenses(id) on delete cascade,
  apk_download_url text not null,               -- URL langsung ke file APK (Google Drive / S3 / dll)
  apk_version     text not null default '1.0.0',
  is_used         boolean not null default false,
  used_at         timestamptz,
  used_ip         text,
  expires_at      timestamptz not null,          -- link kedaluwarsa (misal 7 hari)
  created_at      timestamptz not null default now()
);

-- 3. TABEL AKTIVASI PERANGKAT
create table if not exists device_activations (
  id                  uuid primary key default gen_random_uuid(),
  license_id          uuid not null references licenses(id) on delete cascade,
  activation_token    text unique not null default gen_random_uuid()::text,  -- disimpan di HP
  device_fingerprint  text not null,             -- SHA-256 dari ANDROID_ID + model + brand
  device_model        text,
  device_brand        text,
  android_version     text,
  activated_at        timestamptz not null default now(),
  last_verified_at    timestamptz not null default now(),
  is_active           boolean not null default true,
  unique (license_id, device_fingerprint)
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table licenses         enable row level security;
alter table download_tokens  enable row level security;
alter table device_activations enable row level security;

-- Hanya service_role (Edge Functions) yang bisa akses tabel ini
-- Tidak ada akses publik langsung via Supabase client
create policy "service_role only - licenses"
  on licenses for all
  using (auth.role() = 'service_role');

create policy "service_role only - download_tokens"
  on download_tokens for all
  using (auth.role() = 'service_role');

create policy "service_role only - device_activations"
  on device_activations for all
  using (auth.role() = 'service_role');

-- ============================================================
-- CONTOH DATA — Hapus sebelum production!
-- ============================================================

-- Contoh insert lisensi manual:
-- insert into licenses (license_key, customer_name, store_name)
-- values ('KOMP-A3F7-C891-X2QR', 'Toko Maju Jaya', 'Toko Maju');

-- ============================================================
-- CARA GENERATE LICENSE KEY FORMAT KOMP-XXXX-XXXX-XXXX
-- Jalankan ini di SQL Editor untuk generate key baru:
-- ============================================================
-- select 'KOMP-'
--   || upper(substring(md5(random()::text) for 4))
--   || '-'
--   || upper(substring(md5(random()::text) for 4))
--   || '-'
--   || upper(substring(md5(random()::text) for 4)) as license_key;
