# Verbarium

Kosakata bahasa Inggris untuk TOEFL dan IELTS, dipelajari dengan mengetik kata yang hilang dalam kalimat.
Kemajuan dicatat sebagai gelar feodal, dari Peasant sampai King, dan sejak Squire karaktermu punya job yang ditentukan oleh cara belajarmu. Tiap gelar direbut dengan mengalahkan penjaga jalan
dan boss dalam pertarungan kata, dengan karakter pixel art, level, quest dan perlengkapan.

Aplikasi Android (Flutter), sepenuhnya offline. Masih versi uji coba: **belum dirilis di Google Play**.

## Mencoba

Unduh `Verbarium-alpha.apk` dari [Releases](../../releases) (pilih pre-release terbaru) dan buka di ponsel Android.

## Isi repositori

| Path | Isi |
|---|---|
| `mobile/` | aplikasi Flutter (`lib/engine` mesin belajar, `lib/ui` tampilan, `android/` sisi Android) |
| `mobile/assets/deck/` | 6.133 kata: lima ranah inti dan dua panji (TOEFL, IELTS); `en/` berisi definisi bahasa Inggris tiap kata |
| `content/tools/` | `check_deck.py`, `make_audio.py`, `make_icons.py` |
| `docs/riset-skor.md` | dari mana rentang skor tiap gelar berasal |
| `keystore/` | kunci untuk build uji (publik, bukan untuk Play) |

## Sumber dan lisensi

- Semua kata, arti dan kalimat contoh ditulis untuk Verbarium.
- Musik latar dan efek suara disintesis oleh `content/tools/make_audio.py`, tanpa sampel.
- Huruf: IM Fell English (Igino Marini) dan Alegreya Sans (Huerta Tipográfica), SIL Open Font License 1.1.

oleh Armstrang
