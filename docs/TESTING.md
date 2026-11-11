# ECHO//VOID — Panduan Tes P0 + P1

Versi: `0.1.0-p1` · Tanggal: 2026-11-11 · Place: `void` (placeId 98231709266697)

## 1. Struktur & sumber kebenaran

File `.luau` di `src/` adalah **sumber kebenaran**. Isi Studio harus identik dengan file ini.

| Folder disk | Lokasi di Studio | Isi |
|---|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` | `Config`, `SoundEventSchema`, `EdgeBuilder`, `Net` |
| `src/server/` | `ServerScriptService.Echo` | `Main` (Script) + modul sistem server |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Echo` | `Main` (LocalScript) + controller client |
| `src/overrides/` | `StarterPlayer.StarterPlayerScripts` | `RbxCharacterSounds` kosong (mematikan suara langkah bawaan) |
| `tools/BuildPlace.luau` | dijalankan sekali di mode Edit | arena tes, HUD, folder `Remotes`, setting pemain |

`default.project.json` sudah berformat Rojo. Kalau nanti Rojo dipasang, cukup `rojo serve` + Connect.
Untuk sementara, perubahan di `src/` di-sync ke Studio lewat Studio MCP (minta Claude: "sync src ke Studio").

**Simpan place-nya** (Ctrl+S / File → Save to Roblox) supaya arena, HUD, dan script tersimpan.

## 2. Cara menjalankan

1. Buka place `void` di Roblox Studio.
2. **Solo:** tab Tes → **Mainkan** (F5).
3. **Multiplayer (wajib untuk kriteria P1):** tab Tes → bagian *Klien dan Server* → pilih **2 pemain** → **Mulai**.
   Studio membuka 1 jendela server + 2 jendela client.
4. **Log:** Jendela → **Output**. Di mode Klien & Server, setiap jendela punya Output sendiri; cek server **dan** kedua client.
   Baris normal saat start:
   - `[ECHO//VOID] server siap, versi 0.1.0-p1`
   - `[ECHO//VOID] client siap, versi 0.1.0-p1`
5. Log tiap sound event di server: ubah `Config.Debug.LogEvents = true`.
6. Debug in-game: **F3** (FPS, total segmen, garis menyala, gelombang aktif, raycast/frame). **H** = bantuan.

> Catatan: pesan `ContentId ... Requester does not have permission` / `Asset type does not match` di Output
> **bukan** dari ECHO//VOID (semua audio kita sudah dicek bisa dimuat). Kemungkinan dari plugin/UI bawaan.

## 3. Kontrol

| Tombol | Aksi |
|---|---|
| WASD | jalan (langkah = echo kecil, r 10) |
| Shift (tahan) | lari (r 15, lebih keras) |
| C / Ctrl | jongkok toggle (r 4, pelan) |
| Q | sonar (r 38, cooldown 3 s) |
| E | interaksi (ambil batu, buka/tutup pintu) |
| F | lempar batu yang dipegang |
| G | jatuhkan batu |
| H / F3 | bantuan / debug |
| V | **dev view** (hanya di Studio): OFF → WIREFRAME (semua garis) → LIT (dunia terang, warna asli) → OFF |

Dev view hanya visual lokal; server, sound event, dan oklusi echo tidak berubah.
Kode-nya mengecek `RunService:IsStudio()`, jadi tidak bisa aktif di game live.
**Sebelum rilis:** set `Config.Debug.DevView = false` (supaya warna asli map tidak ikut dikirim sebagai atribut `DevColor`).

Mobile: tombol sentuh PING / RUN / CROUCH / THROW dibuat otomatis oleh ContextActionService (belum dites di perangkat).

## 4. Peta arena tes

```
 z=+60  ┌───────────── RUANG B ───────────────┐
        │ [Peti x3]          [GENERATOR]  [Platform]│  Generator: berbunyi tiap 5–8 s (r 30)
        │ [LowCover]   ▯Pilar      ▯Pilar  /Ramp   │
        │              ▯Pilar      ▯Pilar          │
 z=0    ├──[lorong terbuka x=-40]──[PINTU x=0]─────┤  Pintu geser = putih, menghalangi echo saat tertutup
        │ [Plat logam]   [Peti]          ║Dinding  │  Plat logam: langkah lebih keras (r 12.5)
        │                     [Peti]     ║lorong   │  Genangan: profil Water (r 11)
        │                [Meja+3 batu]   ║ [Air]   │
 z=-60  └──────────── RUANG A (spawn z=-48) ───────┘
       x=-60                                     x=+60
```

## 5. Checklist penerimaan manual

Tandai ✅ / ❌ dan catat Output kalau gagal.

### P0
- [ ] Start tanpa error merah di Output server & client.
- [ ] Dunia hitam total; crosshair, bar SONAR, label WALK tetap terlihat.
- [ ] Tidak bisa menembus dinding/lantai (collision tetap aktif walau tak terlihat).

### P1 — solo
- [ ] Berjalan: tiap langkah memunculkan grid lantai kecil di sekitar kaki, lalu memudar.
- [ ] Shift: radius langkah lebih besar. C: radius sangat kecil. Label kiri bawah berubah RUN/CROUCH.
- [ ] Jalan di plat logam / genangan: suara berbeda, radius sedikit lebih besar.
- [ ] Q: gelombang besar merambat keluar (~1 detik sampai r 38), bar SONAR mengisi ulang 3 s.
- [ ] Tekan Q lagi saat cooldown: tulisan SONAR berkedip merah, tidak ada gelombang.
- [ ] Berdiri dekat pintu tertutup, Q: tidak ada garis di ruang B. Buka pintu (E), Q: lantai/pilar ruang B terlihat lewat celah pintu.
- [ ] Di balik dinding lorong timur (x=45), Q dari sisi lain: tidak ada garis yang menembus dinding.
- [ ] Ambil batu di meja (E), lempar (F) ke dinding/lantai: echo putih/cyan muncul di titik benturan + suara batu.
- [ ] Dekati Generator di ruang B: tiap 5–8 s ada denyut echo + suara dentang; dengung terus-menerus terdengar.
- [ ] Diam ±8 detik: semua garis hilang (fase terang + afterglow 5 s).
- [ ] Ping berulang di tempat yang sama tidak menumpuk garis (F3: angka "lit" tidak terus naik).

### P1 — 2 client (Klien & Server, 2 pemain)
- [ ] Client 1 ping dekat Client 2 → kedua layar melihat echo yang sama di lokasi yang sama.
- [ ] Client 2 berada di ruang lain dengan pintu tertutup → **tidak** melihat struktur ruang Client 1 (oklusi dari sumber suara).
- [ ] Pemain lain tampil sebagai siluet hijau saat dalam pandangan; hilang saat terhalang dinding.
- [ ] Langkah pemain lain memunculkan titik hijau kecil di sumber suara.
- [ ] Nama pemain di atas kepala tidak terlihat menembus dinding.
- [ ] FPS (F3) tetap playable saat keduanya spam ping (target PC 60 FPS).

## 6. Hasil tes otomatis (dijalankan Claude via Studio MCP, 2026-11-11, solo playtest)

| Tes | Hasil |
|---|---|
| Server & client start, tanpa error dari kode ECHO//VOID | ✅ |
| Dunia hitam, HUD terlihat (screenshot) | ✅ |
| Ping Q → ~540–800 segmen menyala (lantai, dinding, peti, meja, batu) | ✅ |
| Oklusi: pintu tertutup → 0 segmen terang di balik pintu; pintu dibuka → 14 segmen | ✅ |
| Fade berjalan (transparansi naik seiring waktu, lalu adornment kembali ke pool) | ✅ |
| Langkah: Walk r=10, Run r=15, Crouch r=4; logam r=12.5, air r=11 | ✅ |
| Benturan batu (dijatuhkan dari server) → ItemImpact r=25 lalu pantulan r=23 | ✅ |
| Validasi: ping + payload palsu → 0 event; spam 15x → 1 event; ping saat cooldown → ditolak | ✅ |
| Validasi: MoveMode "Fly"/tabel → diabaikan; throw NaN / tanpa batu → diabaikan | ✅ |
| Biaya script saat ping ±800 garis: Heartbeat tetap 60/s, frame terburuk 20 ms | ✅ |
| Suara ping & langkah ter-load dan diputar | ✅ |
| Isi 21 script di Studio identik (hash) dengan `src/` | ✅ |
| **Belum dites:** 2 client, prompt E (pintu/ambil batu) & lempar F lewat input asli, FPS render asli (Studio di-throttle saat dikendalikan MCP: 15 FPS render sementara Heartbeat 60), mobile | ⏳ manual |

## 7. P2 — Generator peta prosedural (versi 0.2.0-p2)

### Cara kerja singkat
- `Config.MapGen.Enabled = true` → saat server start, arena tes dipindah ke ServerStorage dan peta baru dibuat di `Workspace.RuntimeMap`.
- Grid sel 32 stud, 10 template industrial (`src/server/MapGen/RoomCatalog.luau`):
  Spawn, Exit, CorridorStraight, CorridorCorner, JunctionT, JunctionX, MachineRoom (Machine), Storage (Loot), PillarHall (Danger), DeadEnd.
- Urutan: seed → `MapLayout` (graf + penempatan grid, Exit menempel ke Spawn, koridor loop) → `MapValidator` → `MapBuilder` (geometri, pintu, prop) → cek jalur Spawn→Exit dengan PathfindingService.
- Gagal validasi → seed turunan (maks 12) → `FallbackSeed`. Semua seed gagal dicatat di Output.
- Log tiap peta di Output server, contoh:
  `[MapGen] seed=783110097 used=783110097 attempt=1 fallback=false rooms=12 loops=1 doors=5 path=Success versi=industrial-1`
- Peta tertentu bisa direproduksi: isi `Config.MapGen.Seed` dengan angka `used=` dari log.

### Dev tools (Studio saja)
| Tombol | Aksi |
|---|---|
| N | peta baru dengan seed acak (semua pemain respawn) |
| V | WIREFRAME / LIT. Plafon disembunyikan lokal supaya bisa dilihat dari atas |
| F3 | debug, termasuk `map seed / rooms / loops` |

### Tes otomatis generator
Command bar Studio (mode Edit):
```lua
print(require(game.ServerScriptService.Tests.GeneratorSeeds:Clone()).run(100, 1))
```
Mengecek setiap seed: valid (jumlah ruangan, tanpa overlap, sambungan berhadapan, tanpa pintu mengambang, tag wajib Machine/Loot/Danger, Exit ≥ 2 sel, semua ruangan terhubung ke Spawn) dan deterministik (generate 2x → signature sama).

### Hasil (dijalankan Claude via Studio MCP, 2026-11-11)
| Tes | Hasil |
|---|---|
| 100 seed (1..100) | ✅ 100/100 lulus, deterministik, 8–12 ruangan (rata-rata 10,6), loop di 69 peta, 0 retry, 0 fallback |
| 1000 seed (1..1000) | ✅ 1000/1000 lulus, loop di 688 peta, 450 ms total |
| FallbackSeed 1 valid | ✅ |
| Playtest: peta dibuat, pemain spawn di ruang Spawn, arena lama tidak aktif | ✅ |
| Pathfinding Spawn → Exit | ✅ Success (4 peta berbeda) |
| Pathfinding Spawn → setiap ruangan (peta seed 783110097) | ✅ 11/11 |
| 5 pintu: tidak menabrak dinding, ada lantai di kedua sisi | ✅ |
| Regenerate N 3x: peta lama dibuang di client (jumlah part bertag ikut berubah), pemain respawn di Spawn | ✅ |
| Echo, ping, dev view tetap jalan di peta prosedural | ✅ |
| **Belum dites:** jalan kaki manual menyusuri seluruh peta, buka pintu peta prosedural dengan E, 2 client | ⏳ manual |

### Checklist manual P2
- [ ] Main beberapa kali (atau tekan N): tiap peta berbeda, selalu ada jalan dari Spawn ke Exit (pad ungu).
- [ ] Ping di tiap jenis ruangan: Storage (rak), PillarHall (pilar + genangan), MachineRoom (generator berdenyut + catwalk), DeadEnd (peti).
- [ ] Pintu di peta prosedural bisa dibuka/ditutup dan menghalangi echo saat tertutup.
- [ ] Tidak ada celah pintu yang menghadap dinding / ruang kosong; tidak bisa keluar dari peta.

## 8. Keterbatasan yang diketahui

- **Bukan anti-cheat visual.** Client punya geometri map (wajib untuk collision); exploiter bisa mewarnai ulang part di client-nya sendiri. Ini batas engine Roblox; yang dijamin server adalah *suara* (tidak bisa dipalsukan/disembunyikan).
- Oklusi per segmen = 1 raycast ke titik tengah segmen; segmen yang setengah terhalang dihitung terlihat/tidak secara utuh.
- Dinding yang dikenai gelombang menampilkan rusuknya sendiri juga di sisi belakang (rusuk part yang sama), tapi tertutup depth buffer kecuali penonton berada di sisi itu.
- `StreamingEnabled` dimatikan untuk P1. Renderer sudah menangani part yang muncul/hilang (tag added/removed), tapi belum dites dengan streaming.
- Pemain lain terlihat dalam 70 stud tanpa perlu suara (sesuai permintaan), terhalang dinding secara visual.
- Audio adalah placeholder dari library Pro Sound Effects / bawaan Roblox.
- Bentuk part selain blok & wedge (bola, silinder, mesh) memakai kotak pembatas; untuk bentuk khusus pakai Attachment `EchoEdgeTo`.
- Belum ada monster, loot bernilai, timer, ekstraksi (milestone P3+). Pad Exit baru penanda visual.
- Generator: satu lantai datar; loop sekitar 0,8 per peta (atur `LoopChance`/`MaxLoops`); template masih dari kode (belum dari model buatan tangan di ServerStorage).
- Sambungan ke ruang Exit tidak pernah diberi pintu (jalur pulang selalu terbuka).
- Cek jalur Spawn→Exit menganggap pintu bisa dilewati (PathfindingModifier PassThrough), karena pintu memang bisa dibuka.
