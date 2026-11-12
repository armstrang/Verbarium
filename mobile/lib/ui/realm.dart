/// Where the score ranges of the titles come from (Pengaturan, and the ladder of titles in Negeri).
library;

import 'package:flutter/material.dart';

import '../app/lang.dart';
import 'theme.dart';
import 'widgets.dart';

/// Where the score ranges come from (docs/riset-skor.md has the same, with links).
class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = Look.of(context).pal;
    Widget p(String s) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(s, style: T.body(16.5, pal.ink, height: 1.5)),
    );
    Widget h(String s) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(s, style: T.display(23, pal.ink)),
    );
    return Leaf(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Press(
                onTap: () => Navigator.of(context).pop(),
                label: tr('Kembali', 'Back', 'Volver', 'Retour', 'Zurück', 'Voltar'),
                child: SizedBox(width: 48, height: 48, child: Icon(Icons.arrow_back, color: pal.ink)),
              ),
              Expanded(
                child: Text(
                  tr(
                    'Dari mana angka ini?',
                    'Where do these numbers come from?',
                    '¿De dónde salen estos números?',
                    'D’où viennent ces chiffres ?',
                    'Woher kommen diese Zahlen?',
                    'De onde vêm esses números?',
                  ),
                  style: T.display(25, pal.ink),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
              children: [
                p(
                  tr(
                    'Tiap gelar dipasangkan dengan satu tingkat CEFR, kerangka Eropa yang dipakai kedua ujian untuk menjelaskan skornya. Rentang skor di tangga gelar diambil dari penyelarasan CEFR milik penyelenggara ujian sendiri.',
                    'Each title is paired with one CEFR level, the European framework both tests use to explain their scores. The score ranges on the ladder of titles are taken from the test owners\' own CEFR alignments.',
                    'Cada título se empareja con un nivel del MCER, el marco europeo que ambos exámenes usan para explicar sus notas. Los rangos de la escala de títulos salen de las equivalencias MCER publicadas por los propios dueños de los exámenes.',
                    'Chaque titre correspond à un niveau du CECRL, le cadre européen que les deux tests utilisent pour expliquer leurs scores. Les fourchettes de l’échelle des titres viennent des correspondances CECRL publiées par les organismes des tests eux-mêmes.',
                    'Jeder Titel ist einer GER-Stufe zugeordnet, dem europäischen Rahmen, mit dem beide Prüfungen ihre Ergebnisse erklären. Die Spannen auf der Titelleiter stammen aus den GER-Zuordnungen der Prüfungsanbieter selbst.',
                    'Cada título corresponde a um nível do QECR, o quadro europeu que as duas provas usam para explicar suas notas. As faixas na escada de títulos vêm dos próprios alinhamentos ao QECR feitos pelos donos das provas.',
                  ),
                ),
                h('IELTS'),
                p(
                  tr(
                    'B1 = band 4.0–5.0, B2 = 5.5–6.5, C1 = 7.0–8.0, C2 = 8.5–9.0. Band 8.0 berada di perbatasan C1 dan C2. Sumber: halaman "IELTS and the CEFR" di ielts.org, berdasarkan kajian Cambridge English.',
                    'B1 = band 4.0–5.0, B2 = 5.5–6.5, C1 = 7.0–8.0, C2 = 8.5–9.0. Band 8.0 sits on the border of C1 and C2. Source: the page "IELTS and the CEFR" on ielts.org, based on studies by Cambridge English.',
                    'B1 = banda 4.0–5.0, B2 = 5.5–6.5, C1 = 7.0–8.0, C2 = 8.5–9.0. La banda 8.0 está en el límite entre C1 y C2. Fuente: la página «IELTS and the CEFR» de ielts.org, basada en estudios de Cambridge English.',
                    'B1 = bande 4.0–5.0, B2 = 5.5–6.5, C1 = 7.0–8.0, C2 = 8.5–9.0. La bande 8.0 se situe à la limite entre C1 et C2. Source : la page « IELTS and the CEFR » sur ielts.org, fondée sur des études de Cambridge English.',
                    'B1 = Band 4.0–5.0, B2 = 5.5–6.5, C1 = 7.0–8.0, C2 = 8.5–9.0. Band 8.0 liegt an der Grenze von C1 und C2. Quelle: die Seite „IELTS and the CEFR“ auf ielts.org, gestützt auf Studien von Cambridge English.',
                    'B1 = banda 4.0–5.0, B2 = 5.5–6.5, C1 = 7.0–8.0, C2 = 8.5–9.0. A banda 8.0 fica na fronteira entre C1 e C2. Fonte: a página “IELTS and the CEFR” em ielts.org, com base em estudos da Cambridge English.',
                  ),
                ),
                h('TOEFL iBT'),
                p(
                  tr(
                    'Sejak 21 Januari 2026 skor dilaporkan pada skala 1–6. Menurut ETS: 6 = 114 ke atas pada skala lama, 5.5 = 107 ke atas, 5 = 95 ke atas, 4.5 = 86 ke atas, 4 = 72 ke atas, 3.5 = 58 ke atas, 3 = 44 ke atas.',
                    'Since 21 January 2026 scores are reported on a scale of 1–6. According to ETS: 6 = 114 and above on the old scale, 5.5 = 107 and above, 5 = 95 and above, 4.5 = 86 and above, 4 = 72 and above, 3.5 = 58 and above, 3 = 44 and above.',
                    'Desde el 21 de enero de 2026 las notas se dan en una escala de 1 a 6. Según ETS: 6 = 114 o más en la escala antigua, 5.5 = 107 o más, 5 = 95 o más, 4.5 = 86 o más, 4 = 72 o más, 3.5 = 58 o más, 3 = 44 o más.',
                    'Depuis le 21 janvier 2026, les scores sont donnés sur une échelle de 1 à 6. Selon ETS : 6 = 114 et plus sur l’ancienne échelle, 5.5 = 107 et plus, 5 = 95 et plus, 4.5 = 86 et plus, 4 = 72 et plus, 3.5 = 58 et plus, 3 = 44 et plus.',
                    'Seit dem 21. Januar 2026 werden Ergebnisse auf einer Skala von 1–6 angegeben. Laut ETS: 6 = 114 und mehr auf der alten Skala, 5.5 = 107 und mehr, 5 = 95 und mehr, 4.5 = 86 und mehr, 4 = 72 und mehr, 3.5 = 58 und mehr, 3 = 44 und mehr.',
                    'Desde 21 de janeiro de 2026 as notas são dadas numa escala de 1–6. Segundo a ETS: 6 = 114 ou mais na escala antiga, 5.5 = 107 ou mais, 5 = 95 ou mais, 4.5 = 86 ou mais, 4 = 72 ou mais, 3.5 = 58 ou mais, 3 = 44 ou mais.',
                  ),
                ),
                p(
                  tr(
                    'Padanan CEFR pada skala lama, juga dari ETS: B1 = 42–71, B2 = 72–94, C1 = 95–113, C2 = 114–120.',
                    'The CEFR levels on the old scale, also from ETS: B1 = 42–71, B2 = 72–94, C1 = 95–113, C2 = 114–120.',
                    'Los niveles MCER en la escala antigua, también de ETS: B1 = 42–71, B2 = 72–94, C1 = 95–113, C2 = 114–120.',
                    'Les niveaux CECRL sur l’ancienne échelle, également selon ETS : B1 = 42–71, B2 = 72–94, C1 = 95–113, C2 = 114–120.',
                    'Die GER-Stufen auf der alten Skala, ebenfalls von ETS: B1 = 42–71, B2 = 72–94, C1 = 95–113, C2 = 114–120.',
                    'Os níveis do QECR na escala antiga, também da ETS: B1 = 42–71, B2 = 72–94, C1 = 95–113, C2 = 114–120.',
                  ),
                ),
                h(
                  tr(
                    'Yang kami putuskan sendiri',
                    'What we decided ourselves',
                    'Lo que decidimos nosotros',
                    'Ce que nous avons décidé nous-mêmes',
                    'Was wir selbst entschieden haben',
                    'O que decidimos nós mesmos',
                  ),
                ),
                p(
                  tr(
                    'C1 dibagi menjadi dua gelar, Count dan Duke, supaya jarak antargelar tidak terlalu jauh. Pada TOEFL pembagian itu mengikuti setengah band (5 dan 5.5). Pada IELTS pembagian 7.0 lalu 7.5–8.0 adalah keputusan Verbarium, bukan ketetapan resmi.',
                    'C1 is split into two titles, Count and Duke, so that the step between titles is not too large. On TOEFL the split follows the half bands (5 and 5.5). On IELTS the split into 7.0 and then 7.5–8.0 is Verbarium\'s decision, not an official one.',
                    'El C1 se divide en dos títulos, Count y Duke, para que el salto entre títulos no sea demasiado grande. En TOEFL la división sigue las medias bandas (5 y 5.5). En IELTS, la división en 7.0 y luego 7.5–8.0 es decisión de Verbarium, no oficial.',
                    'Le C1 est partagé en deux titres, Count et Duke, pour que le pas entre titres ne soit pas trop grand. Au TOEFL, le partage suit les demi-bandes (5 et 5.5). À l’IELTS, le partage en 7.0 puis 7.5–8.0 est un choix de Verbarium, non officiel.',
                    'C1 ist in zwei Titel geteilt, Count und Duke, damit der Schritt zwischen den Titeln nicht zu groß wird. Beim TOEFL folgt die Teilung den halben Bändern (5 und 5.5). Beim IELTS ist die Teilung in 7.0 und dann 7.5–8.0 eine Entscheidung von Verbarium, keine offizielle.',
                    'O C1 é dividido em dois títulos, Count e Duke, para que o passo entre títulos não seja grande demais. No TOEFL a divisão segue as meias bandas (5 e 5.5). No IELTS a divisão em 7.0 e depois 7.5–8.0 é uma decisão do Verbarium, não oficial.',
                  ),
                ),
                p(
                  tr(
                    'Peasant adalah titik awal (A1) dan Squire setara A2. Kedua ujian tidak memberi rentang skor tersendiri di bawah B1, jadi di tangga gelar keduanya tertulis di bawah 4.0 dan di bawah 3.',
                    'The Peasant is where everyone starts (A1) and the Squire stands for A2. Neither test gives its own score range below B1, so on the ladder both read as under 4.0 and under 3.',
                    'Peasant es el punto de partida (A1) y Squire equivale a A2. Ninguno de los dos exámenes da un rango propio por debajo de B1, así que en la escala ambos figuran como menos de 4.0 y menos de 3.',
                    'Peasant est le point de départ (A1) et Squire correspond à A2. Aucun des deux tests ne donne de fourchette propre sous B1, donc sur l’échelle les deux figurent comme moins de 4.0 et moins de 3.',
                    'Der Peasant ist der Anfang für alle (A1), der Squire steht für A2. Keine der Prüfungen nennt unter B1 eine eigene Spanne, darum steht auf der Leiter für beide unter 4.0 und unter 3.',
                    'O Peasant é onde todos começam (A1), e o Squire representa o A2. Nenhuma das provas dá faixa própria abaixo do B1, por isso na escada os dois aparecem como abaixo de 4.0 e abaixo de 3.',
                  ),
                ),
                p(
                  tr(
                    'Tiap kata ditaruh di gelar menurut tingkat CEFR-nya dalam Oxford 3000 dan Oxford 5000 (Oxford University Press). Kata di luar daftar itu ditaruh menurut seberapa sering dipakai dalam korpus BNC/COCA; yang paling jarang menjadi C2. Kalimat dan artinya kami tulis sendiri; daftar Oxford hanya dipakai untuk menentukan tingkat.',
                    'Each word sits at the title of its CEFR level in the Oxford 3000 and Oxford 5000 (Oxford University Press). Words outside those lists are placed by how often they are used in the BNC/COCA corpora; the rarest become C2. The sentences and meanings are our own; the Oxford lists only decide the level.',
                    'Cada palabra está en el título de su nivel MCER según el Oxford 3000 y el Oxford 5000 (Oxford University Press). Las que no figuran en esas listas se colocan según su frecuencia en los corpus BNC/COCA; las más raras pasan a C2. Las frases y los significados son nuestros; las listas de Oxford solo deciden el nivel.',
                    'Chaque mot est placé au titre de son niveau CECRL dans l’Oxford 3000 et l’Oxford 5000 (Oxford University Press). Les mots absents de ces listes sont placés selon leur fréquence dans les corpus BNC/COCA ; les plus rares deviennent C2. Les phrases et les sens sont les nôtres ; les listes d’Oxford ne décident que du niveau.',
                    'Jedes Wort steht beim Titel seiner GER-Stufe in den Oxford 3000 und Oxford 5000 (Oxford University Press). Wörter außerhalb dieser Listen werden nach ihrer Häufigkeit in den Korpora BNC/COCA eingeordnet; die seltensten werden C2. Sätze und Bedeutungen sind unsere eigenen; die Oxford-Listen bestimmen nur die Stufe.',
                    'Cada palavra fica no título do seu nível do QECR no Oxford 3000 e no Oxford 5000 (Oxford University Press). Palavras fora dessas listas são posicionadas pela frequência de uso nos corpora BNC/COCA; as mais raras viram C2. As frases e os sentidos são nossos; as listas de Oxford só decidem o nível.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
