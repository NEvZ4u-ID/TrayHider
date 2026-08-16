# TrayHider

Lightweight Windows utility to hide any active window to the System Tray using a keyboard shortcut — similar to "MinimizeToTray" tools.

**Free & open source (MIT License)** · Created by [**NEvZ4u-ID**](https://github.com/NEvZ4u-ID)

> 🇮🇩 Baca dalam Bahasa Indonesia di bawah / Scroll down for Indonesian.

---

## ⚠️ About Antivirus / VirusTotal Detections

**This project is 100% clean. There is no malicious code anywhere in this repository.**

If you scan the compiled `.exe` on VirusTotal, some engines *will* flag it (usually as `Generic.Trojan` or similar). This is a well-known **false positive** affecting scripts compiled with [AutoHotkey](https://www.autohotkey.com/). It happens because:

- The compiler bundles the AHK interpreter + your script into a single self-extracting binary — a packaging pattern real malware also uses to hide payloads.
- The script legitimately calls low-level Windows APIs (`WinHide`, `RegWrite` for the autostart toggle, global keyboard hooks) — the exact same APIs many AV heuristics associate with spyware/keyloggers, even though here they're used for a visible, user-triggered tray utility.

**How to verify it yourself instead of trusting this claim:**
1. Read the full source — it's one `.ahk` file, plain text, nothing hidden. See [`TrayHider.ahk`](./TrayHider.ahk).
2. Compile it yourself (steps below) instead of downloading the prebuilt `.exe`.
3. Compare the SHA256 checksum of any release binary against the one published in that release's notes.
4. Every release `.exe` in this repo is built automatically by **GitHub Actions** directly from the source in this repo — you can inspect the exact build log for each release under the **Actions** tab. Nothing is compiled on a private machine and uploaded blind.

---

## Description

TrayHider lets you hide the currently focused window from the taskbar and Alt+Tab, tucking it away in the system tray, and bring it back with a hotkey or from the tray menu — without closing the app or losing its state.

### Features
- **Hide active window** to tray with a global hotkey (default `Alt+F1`)
- **Restore last hidden window** (default `Alt+F2`)
- **Restore all hidden windows** (default `Alt+F10`)
- Tray menu lists every hidden window by title — click one to restore just that window
- **Fully customizable shortcuts** via a built-in Settings GUI (no config file editing needed)
- **Start with Windows** toggle (checkbox in the tray menu, no admin rights required)
- **Bilingual UI**: English / Bahasa Indonesia, switchable anytime
- Guards against hiding the Taskbar/Desktop by accident
- Crash-safe: if the app is force-killed, hidden windows are recovered automatically on next launch
- Works with stubborn apps: games and frameworks (SDL2/FNA, Electron, Unity) that re-show their own window are kept hidden by a lightweight watchdog

### Known limitations
- **Exclusive-fullscreen games** may not hide reliably — switch the game to *windowed* or *borderless windowed* mode first. This is a limitation of how exclusive fullscreen takes over the display, not something an external tool can override.
- Windows running **as administrator** can only be hidden if TrayHider is elevated too (see the tray menu's "Run as Administrator").
- Small footprint: ~1MB compiled, a few MB RAM idle

### Requirements
- Windows 10/11
- [AutoHotkey v2.0+](https://www.autohotkey.com/) (only needed if running/compiling from source — the prebuilt `.exe` is standalone)

---

## 🚀 Option A — Installer (recommended, no admin/UAC prompt)

1. Go to the [**Releases**](../../releases) page and download **`TrayHider-Setup.exe`**.
2. Run it — it installs to your own user profile (`%LocalAppData%\TrayHider`), **not** Program Files, so Windows never asks for admin rights during setup.
3. Optionally tick "Start TrayHider automatically when you log on" during install (uses the same non-admin Task Scheduler mechanism as the in-app toggle).
4. Done — TrayHider launches and a Start Menu shortcut is created.

To uninstall later: **Settings → Apps → TrayHider → Uninstall** (also removes the scheduled task if it was created).

## 📦 Option B — Portable (no install)

1. Download **`TrayHider.exe`** from [**Releases**](../../releases).
2. (Recommended) Verify the SHA256 checksum listed on the release page:
   ```powershell
   certutil -hashfile TrayHider.exe SHA256
   ```
3. Run it directly. On first launch it creates `config.ini` next to itself — keep it in a writable folder.
4. If Windows SmartScreen shows a warning, click **More info → Run anyway** (see the false-positive explanation above).

## 🛠️ Option C — Build It Yourself (recommended if you distrust prebuilt binaries)

1. Install [AutoHotkey v2](https://www.autohotkey.com/download/) (choose the 64-bit version).
2. Clone or download this repository:
   ```powershell
   git clone https://github.com/NEvZ4u-ID/TrayHider.git
   cd TrayHider
   ```
3. **To just run it** (no compiling needed): double-click `TrayHider.ahk`. Requires AHK v2 installed.
4. **To compile your own `.exe`:**
   - Install **Ahk2Exe** (bundled with the AutoHotkey installer, or via the [AutoHotkey Dash](https://www.autohotkey.com/docs/v2/Program.htm#ahk2exe)).
   - Open Ahk2Exe, set:
     - **Source**: `TrayHider.ahk`
     - **Base File**: `AutoHotkey64.exe` (v2, Unicode 64-bit)
     - **Destination**: `TrayHider.exe`
   - Click **Convert**.
   - Or via command line:
     ```powershell
     Ahk2Exe.exe /in TrayHider.ahk /base "AutoHotkey64.exe" /out TrayHider.exe
     ```
5. You now have a binary you compiled yourself from source you read — nothing to trust but your own toolchain.

---

## Usage

| Shortcut (default) | Action |
|---|---|
| `Alt+F1` | Hide the active window |
| `Alt+F2` | Restore the last hidden window |
| `Alt+F10` | Restore all hidden windows |

Right-click the tray icon for:
- List of hidden windows (click to restore one)
- Restore All
- Shortcut Settings (change hotkeys from a GUI, applies instantly)
- Start with Windows (checkbox)
- Run as Administrator (only if needed, never automatic)
- Language switch (EN/ID)
- About TrayHider
- Exit (auto-restores everything first)

All settings are stored in `config.ini`, created next to the executable on first run.

---

## Why does it need these permissions?

| Behavior | Why |
|---|---|
| Global hotkeys | Required to trigger hide/restore from any application |
| `WinHide` / `WinShow` (Windows API) | Core mechanism — no alternative API for this |
| Task Scheduler entry (user scope) | Only when you enable "Start with Windows"; created via `schtasks /RL LIMITED` — runs with your own user privileges (never SYSTEM), no admin needed, fully reversible from the same checkbox. On some managed/policy-restricted systems this step itself may require elevation — if so, TrayHider asks before restarting as Administrator, purely to complete that one action |
| Manual "Run as Administrator" | Only triggered if you click it yourself from the tray menu — never automatic, never on startup. Needed only if you want to hide windows that are themselves running elevated (e.g. Task Manager) |

No network access, no file access outside its own folder, no telemetry.

---

## Credits

Created and maintained by [**NEvZ4u-ID**](https://github.com/NEvZ4u-ID).

## License

MIT — see [LICENSE](./LICENSE).

## Contributing

Issues and PRs welcome. Since this is a single-file AHK script, please keep contributions in plain, readable AutoHotkey v2 — no obfuscation, no external binary dependencies, to keep the "read the source yourself" trust model intact.

---

<br>

# 🇮🇩 Versi Bahasa Indonesia

## ⚠️ Tentang Deteksi Antivirus / VirusTotal

**Proyek ini 100% bersih. Tidak ada kode berbahaya di repository ini.**

Jika Anda scan file `.exe` hasil kompilasi di VirusTotal, beberapa engine **akan** mendeteksinya sebagai virus (biasanya `Generic.Trojan` atau sejenis). Ini adalah **false positive** yang sudah dikenal luas pada script yang dikompilasi dengan [AutoHotkey](https://www.autohotkey.com/), karena:

- Compiler AHK menggabungkan interpreter + script Anda menjadi satu file self-extracting — pola packaging yang juga dipakai malware sungguhan untuk menyembunyikan payload.
- Script ini memang memanggil API Windows level-rendah (`WinHide`, `RegWrite` untuk fitur autostart, global keyboard hook) — API yang sama yang sering dikaitkan heuristik antivirus dengan spyware/keylogger, walau di sini dipakai untuk utility tray yang terlihat dan dipicu user sendiri.

**Cara memverifikasi sendiri, bukan sekadar percaya klaim ini:**
1. Baca source code lengkapnya — satu file `.ahk`, teks polos, tidak ada yang disembunyikan. Lihat [`TrayHider.ahk`](./TrayHider.ahk).
2. Compile sendiri (langkah di bawah) daripada mengunduh `.exe` yang sudah jadi.
3. Bandingkan checksum SHA256 file rilis dengan yang tercantum di catatan rilis tersebut.
4. Setiap `.exe` rilis di repo ini dibuat otomatis oleh **GitHub Actions** langsung dari source di repo ini — Anda bisa memeriksa log build persis untuk tiap rilis di tab **Actions**. Tidak ada yang dikompilasi di mesin pribadi lalu diunggah tanpa jejak.

## Deskripsi

TrayHider menyembunyikan jendela yang sedang aktif dari taskbar dan Alt+Tab, menyimpannya di system tray, dan mengembalikannya lewat hotkey atau menu tray — tanpa menutup aplikasi atau kehilangan statenya.

### Fitur
- **Sembunyikan jendela aktif** ke tray dengan hotkey global (default `Alt+F1`)
- **Pulihkan jendela terakhir** yang disembunyikan (default `Alt+F2`)
- **Pulihkan semua jendela** tersembunyi (default `Alt+F10`)
- Menu tray menampilkan daftar jendela tersembunyi berdasarkan judul — klik untuk memulihkan satu jendela
- **Shortcut dapat dikustomisasi penuh** lewat GUI Pengaturan bawaan (tanpa edit file config)
- Toggle **Mulai saat Windows boot** (checkbox di menu tray, tanpa hak admin)
- **UI dwi-bahasa**: Inggris / Indonesia, bisa diganti kapan saja
- Melindungi dari menyembunyikan Taskbar/Desktop secara tidak sengaja
- Aman dari crash: jika aplikasi dipaksa berhenti, jendela tersembunyi otomatis dipulihkan saat dijalankan ulang
- Mendukung aplikasi "bandel": game dan framework (SDL2/FNA, Electron, Unity) yang menampilkan ulang jendelanya sendiri tetap tersembunyi berkat watchdog ringan

### Batasan yang diketahui
- **Game mode exclusive-fullscreen** mungkin tidak bisa disembunyikan dengan andal — ubah dulu game ke mode *windowed* atau *borderless windowed*. Ini batasan cara kerja exclusive fullscreen menguasai tampilan, bukan sesuatu yang bisa ditimpa dari aplikasi luar.
- Jendela yang berjalan **sebagai administrator** hanya bisa disembunyikan bila TrayHider juga elevated (lihat menu tray "Jalankan sebagai Administrator").
- Ringan: ~1MB hasil kompilasi, RAM idle beberapa MB saja

## 🚀 Opsi A — Installer (disarankan, tanpa prompt admin/UAC)

1. Buka [**Releases**](../../releases) dan unduh **`TrayHider-Setup.exe`**.
2. Jalankan — akan terpasang ke folder profil Anda sendiri (`%LocalAppData%\TrayHider`), **bukan** Program Files, jadi Windows tidak pernah meminta hak admin saat instalasi.
3. Opsional: centang "Start TrayHider automatically when you log on" saat instalasi (memakai mekanisme Task Scheduler non-admin yang sama dengan toggle di dalam aplikasi).
4. Selesai — TrayHider langsung jalan dan shortcut Start Menu dibuat.

Untuk uninstall nanti: **Settings → Apps → TrayHider → Uninstall** (otomatis menghapus scheduled task juga bila pernah dibuat).

## 📦 Opsi B — Portable (tanpa instalasi)

1. Unduh **`TrayHider.exe`** dari [**Releases**](../../releases).
2. (Disarankan) Verifikasi checksum SHA256:
   ```powershell
   certutil -hashfile TrayHider.exe SHA256
   ```
3. Jalankan langsung. Saat pertama kali dijalankan, `config.ini` dibuat di folder yang sama — pastikan folder tersebut bisa ditulis.
4. Jika SmartScreen menampilkan peringatan, klik **More info → Run anyway** (lihat penjelasan false-positive di atas).

## 🛠️ Opsi C — Compile Sendiri (disarankan jika ragu dengan binary jadi)

1. Install [AutoHotkey v2](https://www.autohotkey.com/download/) (pilih versi 64-bit).
2. Clone atau unduh repository ini:
   ```powershell
   git clone https://github.com/NEvZ4u-ID/TrayHider.git
   cd TrayHider
   ```
3. **Untuk sekadar menjalankan** (tanpa compile): double-click `TrayHider.ahk`. Butuh AHK v2 terinstall.
4. **Untuk compile jadi `.exe` sendiri:**
   - Install **Ahk2Exe** (sudah termasuk dalam installer AutoHotkey).
   - Buka Ahk2Exe, atur:
     - **Source**: `TrayHider.ahk`
     - **Base File**: `AutoHotkey64.exe` (v2, Unicode 64-bit)
     - **Destination**: `TrayHider.exe`
   - Klik **Convert**.

## Penggunaan

| Shortcut (default) | Fungsi |
|---|---|
| `Alt+F1` | Sembunyikan jendela aktif |
| `Alt+F2` | Pulihkan jendela terakhir |
| `Alt+F10` | Pulihkan semua jendela |

Klik kanan ikon tray untuk: daftar jendela tersembunyi, Restore All, Pengaturan Shortcut, toggle Mulai saat boot, Jalankan sebagai Administrator (bila diperlukan, tidak pernah otomatis), ganti bahasa, About, dan Exit (otomatis memulihkan semua jendela terlebih dahulu).

## Kredit

Dibuat dan dirawat oleh [**NEvZ4u-ID**](https://github.com/NEvZ4u-ID).

## Lisensi

MIT — lihat [LICENSE](./LICENSE).
