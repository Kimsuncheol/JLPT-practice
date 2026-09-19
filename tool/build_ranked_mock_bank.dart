import 'dart:io';

import 'package:jlpt_practice/data/models/jlpt_exam_blueprint.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/data/repositories/csv_utils.dart';

const _legacyPath = 'assets/data/jlpt_test_problems_2021_2025.csv';
const _outputPath = 'assets/data/jlpt_ranked_mock_questions.csv';

void main() {
  final rows = parseCsvRows(File(_legacyPath).readAsStringSync());
  if (rows.isEmpty) throw StateError('Legacy question bank is empty.');
  final header = rows.first;
  final cell = csvCellReader(header);
  final outputHeader = [...header, 'part', 'rank', 'item_type', 'source'];
  final counters = <String, int>{};
  final partCursor = <String, int>{};
  final output = <List<String>>[];

  for (final row in rows.skip(1)) {
    final level = cell(row, 'level');
    final section = _section(cell(row, 'section'));
    final parts = blueprintParts(level, section);
    if (parts.isEmpty) continue;
    final id = cell(row, 'id');
    // Official practice rows stay only in the untouched legacy reference
    // bank. The live ranked bank contains app-authored mock questions.
    if (id.startsWith('off-')) continue;
    final idMatch = RegExp(
      r'^off-n[1-5]-(?:vocabulary|grammar|reading|listening)-(\d+)-',
    ).firstMatch(id);
    final partNumber = idMatch == null
        ? _nextPart(level, section, parts, partCursor)
        : int.parse(idMatch.group(1)!);
    final blueprintPart = parts.where((part) => part.number == partNumber);
    if (blueprintPart.isEmpty) continue;
    final key = '$level:${section.name}:$partNumber';
    final rank = (counters[key] ?? 0) + 1;
    counters[key] = rank;
    output.add([
      ..._padded(row, header.length),
      '$partNumber',
      '$rank',
      blueprintPart.first.itemType,
      'legacy_app_authored',
    ]);
  }

  for (final item in _newListeningRows) {
    final level = item['level']!;
    final section = ProblemSection.listening;
    final partNumber = int.parse(item['part']!);
    final part = blueprintParts(
      level,
      section,
    ).firstWhere((candidate) => candidate.number == partNumber);
    final key = '$level:${section.name}:$partNumber';
    final rank = (counters[key] ?? 0) + 1;
    counters[key] = rank;
    output.add([
      for (final column in header) item[column] ?? '',
      '$partNumber',
      '$rank',
      part.itemType,
      'new_app_authored',
    ]);
  }

  final sink = File(_outputPath).openWrite();
  sink.writeln(outputHeader.map(_csv).join(','));
  for (final row in output) {
    sink.writeln(row.map(_csv).join(','));
  }
  sink.close();
  stdout.writeln('Wrote ${output.length} ranked questions to $_outputPath');
}

int _nextPart(
  String level,
  ProblemSection section,
  List<JlptExamPart> parts,
  Map<String, int> cursor,
) {
  final key = '$level:${section.name}';
  final index = cursor[key] ?? 0;
  cursor[key] = index + 1;
  return parts[index % parts.length].number;
}

ProblemSection _section(String value) => switch (value) {
  'grammar' => ProblemSection.grammar,
  'reading' => ProblemSection.reading,
  'listening' => ProblemSection.listening,
  _ => ProblemSection.vocabulary,
};

List<String> _padded(List<String> row, int length) => [
  for (var index = 0; index < length; index++)
    index < row.length ? row[index] : '',
];

String _csv(String value) {
  if (!value.contains(RegExp('[,"\n\r]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

const _newN5ListeningRows = <Map<String, String>>[
  {
    'id': 'ranked-n5-listening-1-1',
    'level': 'N5',
    'section': 'listening',
    'part': '1',
    'passage':
        'F：スーパーへ行きます。牛乳を買ってきてください。\nM：はい。パンも買いますか。\nF：パンはあります。牛乳だけお願いします。',
    'question': '男の人は何を買いますか。',
    'choice_a': 'パン',
    'choice_b': '牛乳',
    'choice_c': 'パンと牛乳',
    'choice_d': '何も買いません',
    'correct_answer': 'B',
    'explanation_en': 'The woman asks him to buy only milk.',
    'explanation_ko': '여자는 남자에게 우유만 사 달라고 합니다.',
  },
  {
    'id': 'ranked-n5-listening-1-2',
    'level': 'N5',
    'section': 'listening',
    'part': '1',
    'passage': 'M：この紙に名前を書いてください。それから、あの箱に入れてください。\nF：はい、わかりました。',
    'question': '女の人は名前を書いたあと、何をしますか。',
    'choice_a': '紙を先生に見せます',
    'choice_b': '紙を箱に入れます',
    'choice_c': '箱に名前を書きます',
    'choice_d': '家へ帰ります',
    'correct_answer': 'B',
    'explanation_en': 'After writing her name, she puts the paper in the box.',
    'explanation_ko': '이름을 쓴 뒤 종이를 상자에 넣습니다.',
  },
  {
    'id': 'ranked-n5-listening-2-1',
    'level': 'N5',
    'section': 'listening',
    'part': '2',
    'passage': 'F：あしたの映画は何時からですか。\nM：三時からです。でも、二時半に駅で会いましょう。',
    'question': '二人は何時に会いますか。',
    'choice_a': '二時',
    'choice_b': '二時半',
    'choice_c': '三時',
    'choice_d': '三時半',
    'correct_answer': 'B',
    'explanation_en': 'They agree to meet at 2:30.',
    'explanation_ko': '두 사람은 2시 30분에 만나기로 합니다.',
  },
  {
    'id': 'ranked-n5-listening-2-2',
    'level': 'N5',
    'section': 'listening',
    'part': '2',
    'passage': 'M：誕生日に何がほしいですか。時計ですか、かばんですか。\nF：時計はあります。新しいかばんがほしいです。',
    'question': '女の人は何がほしいですか。',
    'choice_a': '時計',
    'choice_b': 'かばん',
    'choice_c': 'くつ',
    'choice_d': '本',
    'correct_answer': 'B',
    'explanation_en': 'She says she wants a new bag.',
    'explanation_ko': '여자는 새 가방을 원한다고 말합니다.',
  },
  {
    'id': 'ranked-n5-listening-3-1',
    'level': 'N5',
    'section': 'listening',
    'part': '3',
    'passage': '友だちの家で水を飲みたいです。何と言いますか。',
    'question': '何と言いますか。',
    'choice_a': '水を飲んでもいいですか',
    'choice_b': '水を飲みませんでした',
    'choice_c': '水を飲んでいます',
    'choice_d': '水が飲みたくなかったです',
    'correct_answer': 'A',
    'explanation_en': 'This politely asks permission to drink water.',
    'explanation_ko': '물을 마셔도 되는지 정중하게 허락을 구하는 표현입니다.',
  },
  {
    'id': 'ranked-n5-listening-3-2',
    'level': 'N5',
    'section': 'listening',
    'part': '3',
    'passage': '教室で先生の声が聞こえません。何と言いますか。',
    'question': '何と言いますか。',
    'choice_a': 'もう一度お願いします',
    'choice_b': 'どうぞよろしく',
    'choice_c': 'いただきます',
    'choice_d': 'お先にどうぞ',
    'correct_answer': 'A',
    'explanation_en': 'You ask the teacher to say it once more.',
    'explanation_ko': '선생님께 한 번 더 말해 달라고 부탁하는 표현입니다.',
  },
  {
    'id': 'ranked-n5-listening-4-1',
    'level': 'N5',
    'section': 'listening',
    'part': '4',
    'passage': 'M：今日は寒いですね。',
    'question': 'いちばんいい答えはどれですか。',
    'choice_a': 'そうですね',
    'choice_b': 'きのうです',
    'choice_c': '三人です',
    'choice_d': '駅にあります',
    'correct_answer': 'A',
    'explanation_en': 'そうですね naturally agrees that it is cold.',
    'explanation_ko': '「そうですね」는 춥다는 말에 자연스럽게 동의하는 답입니다.',
  },
  {
    'id': 'ranked-n5-listening-4-2',
    'level': 'N5',
    'section': 'listening',
    'part': '4',
    'passage': 'F：いっしょに昼ごはんを食べませんか。',
    'question': 'いちばんいい答えはどれですか。',
    'choice_a': 'はい、食べましょう',
    'choice_b': 'いいえ、昼です',
    'choice_c': 'ごはんでした',
    'choice_d': '一時からです',
    'correct_answer': 'A',
    'explanation_en': 'はい、食べましょう naturally accepts the invitation.',
    'explanation_ko': '「はい、食べましょう」는 점심 제안을 자연스럽게 받아들이는 답입니다.',
  },
];

final _newListeningRows = <Map<String, String>>[
  ..._newN5ListeningRows,
  ..._newAdvancedListeningRows,
];

final _newAdvancedListeningRows = <Map<String, String>>[
  _l(
    'N1',
    1,
    1,
    'M：会議資料は印刷できましたか。\nF：はい。ただ、部長の確認がまだです。確認後、参加者にメールで送ります。',
    '女の人はこのあと、まず何をしますか。',
    ['資料を印刷する', '部長に確認してもらう', '参加者に電話する', '会議を始める'],
    1,
  ),
  _l(
    'N1',
    1,
    2,
    'F：先に利用者への聞き取りをして、その結果を基に質問票を直してください。集計は来週で構いません。',
    '最初に何をしなければなりませんか。',
    ['質問票を集計する', '利用者に聞き取りをする', '結果を発表する', '会議を予約する'],
    1,
  ),
  _l(
    'N1',
    2,
    1,
    'M：候補地は駅前と郊外ですが、採用を強化するなら費用より通勤のしやすさを優先すべきでしょう。',
    '男の人は何を優先すべきだと考えていますか。',
    ['土地の広さ', '通勤のしやすさ', '建物の新しさ', '周辺の店'],
    1,
  ),
  _l(
    'N1',
    2,
    2,
    'F：売上は伸びていますが返品も増えています。広告より、まず品質管理の工程を見直す必要があります。',
    '女の人が最も重視していることは何ですか。',
    ['広告の増加', '品質管理の見直し', '値下げ', '販売地域の拡大'],
    1,
  ),
  _l(
    'N1',
    3,
    1,
    'M：便利な道具は作業時間を短縮します。しかし、その時間を新しい仕事で埋めてしまう社会の仕組みも考える必要があります。',
    '話の中心は何ですか。',
    ['道具の製造', '時間短縮と働き方', '余暇の旅行', '新しい商品の価格'],
    1,
  ),
  _l(
    'N1',
    3,
    2,
    'F：失敗を記録する目的は責任者を探すことではなく、同じ条件が重なったときに組織としてどう防ぐかを学ぶことです。',
    '女の人が最も言いたいことは何ですか。',
    ['責任者を処罰する', '記録から再発防止を学ぶ', '記録を削除する', '担当者を増やす'],
    1,
  ),
  _l('N1', 4, 1, 'F：念のため、先方にも日程を確認しておいてもらえますか。', 'いちばん自然な答えはどれですか。', [
    '承知しました。確認しておきます',
    '日程が確認しました',
    '先方を確認されます',
    '確認していただきました',
  ], 0),
  _l('N1', 4, 2, 'M：この案、見送らざるを得ないかもしれませんね。', 'いちばん自然な答えはどれですか。', [
    'ええ、条件が整っていませんから',
    '案を見送ってきますか',
    '条件が見送りました',
    '案に違いありません',
  ], 0),
  _l(
    'N1',
    5,
    1,
    'M：A案は安いですが一年かかります。\nF：B案は高くても半年です。納期を守るならB案でしょう。',
    '二人はどの案を選ぶと考えられますか。',
    ['A案', 'B案', '両方', 'どちらも選ばない'],
    1,
  ),
  _l(
    'N1',
    5,
    2,
    'F：研修は対面のほうが議論しやすいですね。\nM：地方の社員もいるので、講義はオンライン、討論だけ対面にしましょう。',
    '男の人はどの方法を提案していますか。',
    ['すべて対面', 'すべてオンライン', '講義はオンラインで討論は対面', '研修を中止する'],
    2,
  ),
  _l(
    'N2',
    1,
    1,
    'F：申込書を書いたら、受付で身分証を見せてください。そのあと二階で写真を撮ります。',
    '申込書を書いたあと、まず何をしますか。',
    ['写真を撮る', '身分証を見せる', '二階で待つ', '料金を振り込む'],
    1,
  ),
  _l(
    'N2',
    1,
    2,
    'M：報告書の数字を確認してから課長に送ってください。表紙は私が後で付けます。',
    '女の人は何をしなければなりませんか。',
    ['表紙を作る', '数字を確認して課長に送る', '印刷する', '課長に電話する'],
    1,
  ),
  _l(
    'N2',
    2,
    1,
    'F：ホテルは駅から遠いですが会議場の隣です。朝早い会議なので、私はそこがいいと思います。',
    '女の人がそのホテルを選ぶ理由は何ですか。',
    ['駅に近い', '会議場に近い', '料金が安い', '部屋が広い'],
    1,
  ),
  _l(
    'N2',
    2,
    2,
    'M：この講座は内容はいいんですが平日の昼だけです。仕事をしながら通える夜の講座を探します。',
    '男の人が申し込まない理由は何ですか。',
    ['内容が難しい', '時間が合わない', '料金が高い', '場所が遠い'],
    1,
  ),
  _l(
    'N2',
    3,
    1,
    'F：地域の店を守るには、店同士が情報を共有し、一緒に地域の魅力を発信することが大切です。',
    '話のテーマは何ですか。',
    ['地域商店の協力', '商品の値下げ', '観光客の減少', '店員の採用'],
    0,
  ),
  _l(
    'N2',
    3,
    2,
    'M：運動は長時間まとめてする必要はありません。短い時間でも毎日続けることで効果が期待できます。',
    '男の人が伝えたいことは何ですか。',
    ['毎日長時間運動する', '短時間でも継続する', '週末だけ運動する', '運動前に休む'],
    1,
  ),
  _l('N2', 4, 1, 'F：資料の修正、今日中には難しそうです。', 'いちばん自然な答えはどれですか。', [
    'では、明日の朝までで構いません',
    '今日は資料でした',
    '修正が難しかったですか',
    '資料を直させました',
  ], 0),
  _l('N2', 4, 2, 'M：駅まで車でお送りしましょうか。', 'いちばん自然な答えはどれですか。', [
    'ありがとうございます。お願いします',
    '駅で送っています',
    '車に送りました',
    'どういたしまして',
  ], 0),
  _l(
    'N2',
    5,
    1,
    'F：会場Aは広いですが駅から遠いです。\nM：会場Bは少し狭くても駅前です。参加者は百人以下なのでBで十分でしょう。',
    '二人はどの会場を選びますか。',
    ['会場A', '会場B', '両方', 'まだ決めない'],
    1,
  ),
  _l(
    'N2',
    5,
    2,
    'M：紙の案内は高齢者に必要です。\nF：若い人にはアプリが便利です。紙を減らして両方残しましょう。',
    '二人はどうすることにしましたか。',
    ['紙だけにする', 'アプリだけにする', '紙を減らして両方使う', '案内をやめる'],
    2,
  ),
  _l('N3', 1, 1, 'M：図書館の本を返してから、郵便局でこの手紙を出してください。買い物はそのあとでいいです。', 'まず何をしますか。', [
    '買い物をする',
    '本を返す',
    '手紙を出す',
    '家に帰る',
  ], 1),
  _l('N3', 1, 2, 'F：会議室にいすを並べたら、机の上に資料を置いてください。飲み物は私が用意します。', '男の人は何をしますか。', [
    'いすと資料を準備する',
    '飲み物だけ用意する',
    '机を買う',
    '会議を中止する',
  ], 0),
  _l('N3', 2, 1, 'F：赤いシャツもいいですが、仕事でも着られる白いほうにします。', '女の人はなぜ白いシャツを選びますか。', [
    '安いから',
    '仕事でも着られるから',
    '赤がないから',
    '大きいから',
  ], 1),
  _l('N3', 2, 2, 'M：電車は速いけど、今日は荷物が多いから乗り換えのないバスで行きます。', '男の人がバスで行く理由は何ですか。', [
    '電車が止まった',
    '荷物が多く乗り換えがない',
    'バスが無料',
    '駅が遠い',
  ], 1),
  _l('N3', 3, 1, 'F：家で働くと通勤時間がなくなる一方、同僚と話す機会を作る工夫も必要です。', '何について話していますか。', [
    '在宅勤務の長所と課題',
    '電車の混雑',
    '家の値段',
    '会社の引っ越し',
  ], 0),
  _l('N3', 3, 2, 'M：この町では古い建物を壊さず、店やホテルとして使う活動が進んでいます。', '話のテーマは何ですか。', [
    '新しい住宅',
    '古い建物の活用',
    'ホテルの料金',
    '町の交通',
  ], 1),
  _l('N3', 4, 1, '友だちの家に入るとき、何と言いますか。', 'いちばん自然な表現はどれですか。', [
    'おじゃまします',
    'いってきます',
    'おかえりなさい',
    'ごちそうさま',
  ], 0),
  _l('N3', 4, 2, '会社で先に帰るとき、何と言いますか。', 'いちばん自然な表現はどれですか。', [
    'お先に失礼します',
    'ただいま',
    'いただきます',
    'お大事に',
  ], 0),
  _l('N3', 5, 1, 'F：来週の試験、難しそうですね。', 'いちばん自然な答えはどれですか。', [
    'ええ、しっかり勉強しないと',
    'いいえ、来週でした',
    '試験を難しくします',
    '勉強が来ました',
  ], 0),
  _l('N3', 5, 2, 'M：この荷物、持ちましょうか。', 'いちばん自然な答えはどれですか。', [
    'すみません、お願いします',
    '荷物を持ちませんか',
    '持っていました',
    'こちらこそ',
  ], 0),
  _l('N4', 1, 1, 'F：駅へ行く前に、銀行でお金をおろしてください。', 'まずどこへ行きますか。', [
    '駅',
    '銀行',
    '学校',
    '病院',
  ], 1),
  _l('N4', 1, 2, 'M：この本を先生に返して、それから教室へ来てください。', 'まず何をしますか。', [
    '教室へ行く',
    '本を先生に返す',
    '本を買う',
    '先生を呼ぶ',
  ], 1),
  _l('N4', 2, 1, 'M：青いかさは千円で、黒いかさは八百円です。\nF：では、安いほうをください。', '女の人はどのかさを買いますか。', [
    '青いかさ',
    '黒いかさ',
    '両方',
    '買いません',
  ], 1),
  _l(
    'N4',
    2,
    2,
    'F：土曜日と日曜日、どちらがいいですか。\nM：土曜日は仕事ですから、日曜日にしましょう。',
    '二人はいつ会いますか。',
    ['金曜日', '土曜日', '日曜日', '月曜日'],
    2,
  ),
  _l('N4', 3, 1, '店でシャツを見たいです。何と言いますか。', 'いちばん自然な表現はどれですか。', [
    'このシャツを見せてください',
    'シャツを見ました',
    'シャツが見ません',
    '見せていますか',
  ], 0),
  _l('N4', 3, 2, '電車で席をゆずります。何と言いますか。', 'いちばん自然な表現はどれですか。', [
    'どうぞ、座ってください',
    '座ってもらいました',
    'ここに座りますか',
    '席が立ちます',
  ], 0),
  _l('N4', 4, 1, 'F：今日は雨が降りそうですね。', 'いちばん自然な答えはどれですか。', [
    'かさを持って行きましょう',
    '雨は昨日です',
    '今日は三時です',
    '降ってください',
  ], 0),
  _l('N4', 4, 2, 'M：窓を開けてもいいですか。', 'いちばん自然な答えはどれですか。', [
    'ええ、どうぞ',
    '窓があります',
    '開けませんでした',
    'いい天気です',
  ], 0),
];

Map<String, String> _l(
  String level,
  int part,
  int variant,
  String passage,
  String question,
  List<String> choices,
  int correctIndex,
) => {
  'id': 'ranked-${level.toLowerCase()}-listening-$part-$variant',
  'level': level,
  'section': 'listening',
  'part': '$part',
  'passage': passage,
  'question': question,
  'choice_a': choices[0],
  'choice_b': choices[1],
  'choice_c': choices[2],
  'choice_d': choices[3],
  'correct_answer': const ['A', 'B', 'C', 'D'][correctIndex],
  'explanation_en': 'The correct response is ${choices[correctIndex]}.',
  'explanation_ko': '정답은 ${choices[correctIndex]}입니다.',
};
