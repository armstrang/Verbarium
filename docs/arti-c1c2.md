# Arti C1–C2 dirapikan (v0.7)

Untuk gelar Count, Duke dan King (C1–C2), banyak kata punya arti Indonesia yang sama persis dengan kata lain, misalnya
`alleviate`, `ease` dan `relieve` sama-sama "meringankan". Di level ini petunjuknya hanya garis, jadi pelajar yang
mengetik sinonim yang benar tidak tahu kenapa dianggap salah.

Yang dilakukan:

- `content/tools/c1c2_meanings.txt` memuat 736 kata C1–C2 yang artinya hanya satu makna dan dipakai bersama kata lain.
  Makna utama tetap di depan. Di dalam kurung ditambahkan pemakaian yang membedakannya, seperti label di kamus (KBBI,
  Oxford). Contoh: `alleviate` → "meringankan (penderitaan, masalah)", `ease` → "meringankan (rasa sakit,
  kecemasan)".
- `content/tools/apply_meanings.py` menerapkannya ke deck. 709 baris berubah, `check_deck.py` lulus.
- Makna yang memang sama tetap sama. Dengan begitu kesempatan kedua C1–C2 (`nearMeaning` di `run.dart`) tetap
  mengenali kata yang berdekatan: kata lain di deck, jenis kata sama, dan satu makna sama (tanpa isi kurung). Pelajar
  mendapat pesan "Bukan kata yang dicari", lalu huruf pertama kata yang dicari muncul.

Yang belum: arti dalam bahasa Spanyol, Prancis, Jerman dan Portugis (`es/`, `fr/`, `de/`, `pt/`) belum diberi
penanda yang sama, dan sebaiknya diperiksa penutur asli.
