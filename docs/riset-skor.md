# Rentang skor per gelar

Tiap gelar Verbarium dipasangkan dengan satu tingkat CEFR. Rentang skor diambil dari penyelarasan CEFR yang
diterbitkan penyelenggara ujian sendiri, dicek pada 10 November 2026.

| Gelar | CEFR | IELTS (band) | TOEFL iBT (skala 1–6) | TOEFL iBT (skala lama 0–120) |
|---|---|---|---|---|
| Peasant | A2 | di bawah 4.0 | di bawah 3 | di bawah 42 |
| Squire | B1 | 4.0–5.0 | 3–3.5 | 42–71 |
| Knight | B2 | 5.5–6.5 | 4–4.5 | 72–94 |
| Baron | C1 (awal) | 7.0 | 5 | 95–106 |
| Duke | C1 (lanjut) | 7.5–8.0 | 5.5 | 107–113 |
| King | C2 | 8.5–9.0 | 6 | 114–120 |

Angka ini ada di `Engine.ranks` (`mobile/lib/engine/engine.dart`) dan di layar "Dari mana angka ini?".

## Sumber

**IELTS.** Halaman "IELTS and the CEFR" di ielts.org (kajian Cambridge English): B1 = 4.0–5.0, B2 = 5.5–6.5,
C1 = 7.0–8.0, C2 = 8.5–9.0. Band 8.5 ke atas diakui sebagai C2; band 8.0 berada di perbatasan. Yang dipetakan
adalah skor keseluruhan, bukan skor tiap keterampilan.
<https://www.ielts.org/about-ielts/ielts-in-cefr-scale>

**TOEFL iBT, skala 1–6.** Sejak 21 Januari 2026 ETS melaporkan skor pada skala 1–6 dengan kelipatan setengah,
yang diselaraskan dengan CEFR. Tabel perbandingan ETS dengan skala lama: 6 = 114+, 5.5 = 107+, 5 = 95+,
4.5 = 86+, 4 = 72+, 3.5 = 58+, 3 = 44+, 2.5 = 34+, 2 = 24+. Dicek ulang pada 11 November 2026: tabel ETS
masih sama, dan laporan skor menampilkan kedua skala sampai Januari 2028.
<https://www.ets.org/toefl/test-takers/ibt/scores/understand-scores.html>

**TOEFL iBT, skala lama dan CEFR.** ETS: C2 = 114–120, C1 = 95–113, B2 = 72–94, B1 = 42–71, di bawah 42 = A2.
<https://www.ets.org/toefl/score-users/ibt/compare-scores.html>

## Keputusan Verbarium sendiri (bukan ketetapan resmi)

- **C1 dibagi dua** menjadi Baron dan Duke supaya jarak antargelar tidak terlalu jauh. Pada TOEFL pembagian itu
  mengikuti setengah band (5 dan 5.5, yaitu 95–106 dan 107–113 pada skala lama). Pada IELTS pembagian 7.0 lalu
  7.5–8.0 adalah keputusan kami.
- **Peasant** adalah titik awal sebelum ada bukti apa pun, dipasangkan dengan A2 dan di bawahnya.
- **Skala TOEFL 3–3.5 = B1** sedikit lebih ketat daripada skala lama: band 3 mulai dari 44, sedangkan B1 lama
  mulai dari 42.
- **Gelar mengukur kosakata, bukan menjamin skor.** Skor ujian juga ditentukan oleh membaca, menyimak, menulis
  dan berbicara. Aplikasi menulis "kosakata setara", bukan "skormu".
- **Pemilihan kata per ranah** disusun sendiri menurut tingkat kesulitan (lihat `mobile/assets/deck/`), bukan
  salinan daftar resmi mana pun. Belum ada kajian yang mengukur apakah menguasai ranah tertentu benar-benar
  berkorelasi dengan rentang skor tersebut; itu baru bisa diuji dengan data pengguna.
