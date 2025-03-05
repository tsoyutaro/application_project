import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

// グローバル変数（ホームで選択した気分と日記の情報を保持するため）
Map<String, int> globalMoodMap = {};
Map<String, String> globalDiaryMap = {};

// 気分アイコンのグローバル定数
const List<IconData> kMoodIcons = [
  Icons.sentiment_very_dissatisfied,
  Icons.sentiment_dissatisfied,
  Icons.sentiment_neutral,
  Icons.sentiment_satisfied,
  Icons.sentiment_very_satisfied,
];

// ValueNotifier を利用してグローバル気分情報の更新を監視
ValueNotifier<Map<String, int>> globalMoodNotifier = ValueNotifier(
  globalMoodMap,
);

ValueNotifier<Map<String, String>> globalDiaryNotifier = ValueNotifier(
  globalDiaryMap,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  var diaryBox = await Hive.openBox('diary');

  // Hiveに保存されている各エントリをグローバル変数に読み込み
  for (var key in diaryBox.keys) {
    var entry = diaryBox.get(key);
    if (entry is Map) {
      if (entry['mood'] != null &&
          entry['mood'] is int &&
          entry['mood'] != -1) {
        globalMoodMap[key] = entry['mood'];
      }
      if (entry['diary'] != null && entry['diary'] is String) {
        globalDiaryMap[key] = entry['diary'];
      }
    }
  }
  // ValueNotifierに反映させる
  globalMoodNotifier.value = Map.from(globalMoodMap);
  globalDiaryNotifier.value = Map.from(globalDiaryMap);

  runApp(MyApp());
}

/// アプリ全体のルートウィジェット
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emonator',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainScreen(),
    );
  }
}

/// BottomNavigationBarで各ページに遷移するためのメイン画面
class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 各ページのリスト
  final List<Widget> _pages = <Widget>[HomePage(), DatabasePage(), MyPage()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 各ページごとにヘッダーのタイトルを切り替え
    String appBarTitle;
    if (_selectedIndex == 0) {
      appBarTitle = 'Emonator';
    } else if (_selectedIndex == 1) {
      appBarTitle = 'Database';
    } else {
      appBarTitle = 'My Page';
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.lightBlue.shade100,
        title: Text(
          appBarTitle,
          style: TextStyle(
            color: Colors.black, // 濃い文字色（例：黒）
            fontWeight: FontWeight.bold, // 太字
            fontSize: 20, // 必要に応じてフォントサイズも調整
          ),
        ),
      ),
      // Homeタブの場合のみ floatingActionButton を表示
      floatingActionButton:
          _selectedIndex == 0
              ? FloatingActionButton(
                onPressed: () async {
                  // 現在の日付を取得
                  DateTime now = DateTime.now();
                  DateTime today = DateTime(now.year, now.month, now.day);
                  try {
                    int? selectedMood = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DiaryPage(date: today),
                      ),
                    );
                    String key = '${today.year}-${today.month}-${today.day}';
                    if (selectedMood != null) {
                      globalMoodMap[key] = selectedMood;
                    } else {
                      globalMoodMap.remove(key); // 未選択の場合はキーを削除
                    }
                    globalMoodNotifier.value = Map.from(globalMoodMap);
                    if (mounted) {
                      setState(() {});
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('DiaryPage への遷移中にエラーが発生しました: $e')),
                    );
                  }
                },
                child: Icon(Icons.today),
              )
              : null,

      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home, color: Colors.grey),
            activeIcon: Icon(Icons.home, color: Colors.blue),
            label: 'ホーム',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storage, color: Colors.grey),
            activeIcon: Icon(Icons.storage, color: Colors.green),
            label: 'データベース',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, color: Colors.grey),
            activeIcon: Icon(Icons.person, color: Colors.red),
            label: 'マイページ',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

/// ホーム画面（カレンダー表示）
/// 1. 上部に◀▶付きの年月表示（タップで年月変更）
/* 2. 曜日の表示（「日　月　火　水　木　金　土」）
/// 3. 現在の年月と曜日に合わせたカレンダーグリッド  
///    各セルの下にある丸ボタンをタップすると DiaryPage へ遷移し、
///    選択した気分はグローバル変数に保存される（ValueNotifier 経由で更新）。
*/
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 初期状態は当月の1日を基準とする
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  // 指定された年月の日数を計算
  int daysInMonth(DateTime date) {
    var beginningNextMonth =
        (date.month < 12)
            ? DateTime(date.year, date.month + 1, 1)
            : DateTime(date.year + 1, 1, 1);
    return beginningNextMonth.subtract(Duration(days: 1)).day;
  }

  @override
  Widget build(BuildContext context) {
    int daysCount = daysInMonth(_selectedMonth);
    // 月初日の曜日を取得（Dartでは月曜日が1、日曜日が7）→ 表示順を「日～土」にするため、日曜日を0に
    DateTime firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    int weekdayOffset = firstDay.weekday % 7;
    int totalCells = weekdayOffset + daysCount;

    return Container(
      color: Colors.grey.shade200, // 薄いグレーの背景
      child: Column(
        children: [
          // 上部：◀▶付きの年月表示
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_left),
                onPressed: () {
                  setState(() {
                    // 1か月前へ移動（DateTime は自動で年跨ぎも対応）
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month - 1,
                      1,
                    );
                  });
                },
              ),
              GestureDetector(
                onTap: () async {
                  try {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedMonth,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedMonth = DateTime(picked.year, picked.month, 1);
                      });
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('日付選択中にエラーが発生しました: $e')),
                    );
                  }
                },
                child: Text(
                  '${_selectedMonth.year}年${_selectedMonth.month}月',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),

              IconButton(
                icon: Icon(Icons.arrow_right),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                      1,
                    );
                  });
                },
              ),
            ],
          ),
          // 2. 曜日の表示
          Row(
            children:
                ['日', '月', '火', '水', '木', '金', '土'].map((day) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }).toList(),
          ),
          // 3. カレンダーグリッド
          Expanded(
            child: GridView.builder(
              // ここを追加
              //shrinkWrap: true,
              physics:
                  const BouncingScrollPhysics(), // または AlwaysScrollableScrollPhysics()
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 1.0, // <-- 高さ方向にゆとりをもたせる
              ),

              itemCount: totalCells,
              itemBuilder: (context, index) {
                if (index < weekdayOffset) {
                  return Container(); // 前月分の空セル
                } else {
                  int day = index - weekdayOffset + 1;
                  DateTime cellDate = DateTime(
                    _selectedMonth.year,
                    _selectedMonth.month,
                    day,
                  );
                  String key =
                      '${cellDate.year}-${cellDate.month}-${cellDate.day}';
                  DateTime now = DateTime.now();
                  // 当日と比較（時刻は無視）
                  bool isToday =
                      (now.year == cellDate.year &&
                          now.month == cellDate.month &&
                          now.day == cellDate.day);
                  // 日付表示用のウィジェットを共通化
                  Widget dayCircle = Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isToday ? Colors.blue.shade900 : Colors.transparent,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: isToday ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  );
                  // カレンダーグリッド内の日付セル（itemBuilder 内）
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 日付の部分：当日は背景付き（例：濃い青）で日付を白文字表示
                      dayCircle,
                      const SizedBox(height: 4),
                      // 気分ボタン：全日共通のサイズに統一
                      GestureDetector(
                        onTap: () async {
                          int? selectedMood = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DiaryPage(date: cellDate),
                            ),
                          );
                          if (selectedMood != null) {
                            globalMoodMap[key] = selectedMood;
                            globalMoodNotifier.value = Map.from(globalMoodMap);
                            setState(() {});
                          }
                        },
                        child: ValueListenableBuilder<Map<String, int>>(
                          valueListenable: globalMoodNotifier,
                          builder: (context, moodMap, child) {
                            const double buttonSize = 20;
                            final bool hasMood = moodMap.containsKey(key);
                            return Container(
                              width: buttonSize,
                              height: buttonSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    hasMood
                                        ? Colors.transparent
                                        : Colors.lightBlue.shade100,
                              ),
                              child: Center(
                                child:
                                    hasMood
                                        ? Icon(
                                          kMoodIcons[moodMap[key]!],
                                          size: buttonSize,
                                          color: Colors.blue.shade900,
                                        )
                                        : Container(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 日記入力画面（DiaryPage）
/// ヘッダーには左上の戻るボタンと、タップで変更可能な日付（年月日）を表示。
/// センターには気分選択用のアイコン群とテキストフィールド、
/// ボトムには完了ボタンでホームへ戻り、選択した気分を返す。
class DiaryPage extends StatefulWidget {
  final DateTime date;
  DiaryPage({required this.date});

  @override
  _DiaryPageState createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  late DateTime _currentDate;
  int _selectedMoodIndex = -1;
  final TextEditingController _diaryController = TextEditingController();

  final List<IconData> _moodIcons = [
    Icons.sentiment_very_dissatisfied,
    Icons.sentiment_dissatisfied,
    Icons.sentiment_neutral,
    Icons.sentiment_satisfied,
    Icons.sentiment_very_satisfied,
  ];

  @override
  void initState() {
    super.initState();
    _currentDate = widget.date;
    var diaryBox = Hive.box('diary');
    String key =
        '${_currentDate.year}-${_currentDate.month}-${_currentDate.day}';
    var entry = diaryBox.get(key);
    if (entry != null) {
      _selectedMoodIndex = entry['mood'] ?? -1;
      _diaryController.text = entry['diary'] ?? '';
    }

    // 既存の気分を反映
    if (globalMoodMap.containsKey(key)) {
      _selectedMoodIndex = globalMoodMap[key]!;
    }
    // 既存の日記内容を反映
    if (globalDiaryMap.containsKey(key)) {
      _diaryController.text = globalDiaryMap[key]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(),
        // タップで日付変更可能なタイトル
        title: GestureDetector(
          onTap: () async {
            try {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _currentDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() {
                  _currentDate = picked;
                });
              }
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('日付選択中にエラーが発生しました: $e')));
            }
          },
          child: Text(
            '${_currentDate.year}/${_currentDate.month}/${_currentDate.day}',
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 気分選択のアイコン群
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_moodIcons.length, (index) {
                return IconButton(
                  icon: Icon(
                    _moodIcons[index],
                    color:
                        _selectedMoodIndex == index ? Colors.blue : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      // 同じボタンが再タップされた場合はリセットする
                      if (_selectedMoodIndex == index) {
                        _selectedMoodIndex = -1;
                      } else {
                        _selectedMoodIndex = index;
                      }
                    });
                  },
                );
              }),
            ),

            const SizedBox(height: 16),
            // 日記記入用テキストフィールド
            Expanded(
              child: TextField(
                controller: _diaryController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: '日記を記入してください...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
      // 完了ボタンでホームへ戻り、選択した気分を返す
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          child: const Text('完了'),
          onPressed: () {
            if (_diaryController.text.length > 100) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('日記は100文字以内で入力してください')));
              return;
            }
            try {
              ScaffoldMessenger.of(context).clearSnackBars();
              var diaryBox = Hive.box('diary');
              String key =
                  '${_currentDate.year}-${_currentDate.month}-${_currentDate.day}';
              // グローバル変数の更新と同時に Hive に書き込む
              if (_selectedMoodIndex == -1) {
                // 未選択の場合はキー削除
                globalMoodMap.remove(key);
                diaryBox.delete(key); // 必要に応じて削除も行う
              } else {
                globalMoodMap[key] = _selectedMoodIndex;
                diaryBox.put(key, {
                  'mood': _selectedMoodIndex,
                  'diary': _diaryController.text,
                });
              }
              globalDiaryMap[key] = _diaryController.text;
              globalMoodNotifier.value = Map.from(globalMoodMap);
              globalDiaryNotifier.value = Map.from(globalDiaryMap);
              // 完了時に、未選択なら null を返す
              int? moodToReturn =
                  (_selectedMoodIndex == -1) ? null : _selectedMoodIndex;
              Navigator.pop(context, moodToReturn);
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('保存中にエラーが発生しました: $e')));
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _diaryController.dispose();
    super.dispose();
  }
}

/// Databaseページ
/// ヘッダーは MainScreen の AppBar により "Database" と表示され、
/// センターではタップで変更可能な日時（初期は現在日時）の下に、
/// その日時に対応する気分アイコン（ホームで選択したもの）と、
/// 書き込める状態の日記（四角で囲んだ TextField）を表示する。
/// ※初期状態は編集不可（readOnly）で、右側に配置した編集ボタンで編集ON/OFFを切替
class DatabasePage extends StatefulWidget {
  @override
  _DatabasePageState createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  late TextEditingController _diaryController;
  bool _isEditing = false; // 編集モード（初期はOFF）
  int _localMood = -1; // 編集モード中の気分状態。未選択は -1

  @override
  void initState() {
    super.initState();
    String key =
        '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
    _diaryController = TextEditingController(text: globalDiaryMap[key] ?? '');
    // globalMoodMap にあれば反映、なければ -1 をセット
    _localMood = globalMoodMap[key] ?? -1;
  }

  // 日付を1日進めたり戻したりするヘルパーメソッド
  void _changeDateByDays(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      String newKey =
          '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
      _diaryController.text = globalDiaryMap[newKey] ?? '';
      // globalMoodMap にあれば、その値、なければ -1 をセット
      _localMood = globalMoodMap[newKey] ?? -1;
    });
  }

  Widget _buildDateRow() {
    String dateText =
        '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}';
    return Column(
      children: [
        // 日付表示と左右矢印
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_left),
              onPressed: () {
                _changeDateByDays(-1);
              },
            ),
            GestureDetector(
              onTap: () async {
                try {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                      String newKey =
                          '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
                      _diaryController.text = globalDiaryMap[newKey] ?? '';
                      _localMood = globalMoodMap[newKey] ?? -1;
                    });
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('日付選択中にエラーが発生しました: $e')),
                  );
                }
              },
              child: Text(
                dateText,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: Icon(Icons.arrow_right),
              onPressed: () {
                _changeDateByDays(1);
              },
            ),
          ],
        ),
        // 編集切替ボタン
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              tooltip: _isEditing ? '編集OFF' : '編集ON',
              onPressed: () {
                String key =
                    '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
                if (_isEditing) {
                  if (_diaryController.text.length > 100) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('日記は100文字以内で入力してください')),
                    );
                    return; // エラー時は切替しない
                  }
                  String key =
                      '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
                  if (_localMood == -1) {
                    globalMoodMap.remove(key);
                    // 必要に応じて Hive からも削除
                    Hive.box('diary').delete(key);
                  } else {
                    globalMoodMap[key] = _localMood;
                  }
                  globalMoodNotifier.value = Map.from(globalMoodMap);
                  // ここで日記内容も Hive に書き込む
                  Hive.box('diary').put(key, {
                    'mood': _localMood,
                    'diary': _diaryController.text,
                  });
                } else {
                  // 編集ON時、最新の値を反映
                  _localMood = globalMoodMap[key] ?? -1;
                }
                setState(() {
                  _isEditing = !_isEditing;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  // 気分アイコン部分のウィジェット
  Widget _buildMoodButtons(String key) {
    if (!_isEditing) {
      // 編集OFFの場合は、globalMoodNotifier を監視してホームの気分状態を反映
      return ValueListenableBuilder<Map<String, int>>(
        valueListenable: globalMoodNotifier,
        builder: (context, moodMap, child) {
          int? currentMood = moodMap[key];
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(kMoodIcons.length, (index) {
              bool isSelected = (currentMood == index);
              return IconButton(
                icon: Icon(
                  kMoodIcons[index],
                  color: isSelected ? Colors.blue : Colors.grey,
                ),
                onPressed: null, // 編集OFFなのでタップ不可
              );
            }),
          );
        },
      );
    } else {
      // 編集ONの場合は、_localMood を表示・変更
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(kMoodIcons.length, (index) {
          bool isSelected = (_localMood == index);
          return IconButton(
            icon: Icon(
              kMoodIcons[index],
              color: isSelected ? Colors.blue : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                // 同じボタンが再タップされた場合はリセットする
                if (_localMood == index) {
                  _localMood = -1;
                } else {
                  _localMood = index;
                }
              });
            },
          );
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String key =
        '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
    return Container(
      color: Colors.grey.shade200, // センターの背景を薄いグレーに
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildDateRow(),
            const SizedBox(height: 16),
            _buildMoodButtons(key),
            const SizedBox(height: 16),
            Text(
              'Diary:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            ValueListenableBuilder<Map<String, String>>(
              valueListenable: globalDiaryNotifier,
              builder: (context, diaryMap, child) {
                String currentDiary = diaryMap[key] ?? '';
                if (_diaryController.text != currentDiary) {
                  _diaryController.text = currentDiary;
                }
                return Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade800),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: TextField(
                    controller: _diaryController,
                    maxLines: 5,
                    readOnly: !_isEditing,
                    decoration: const InputDecoration.collapsed(
                      hintText: '日記を記入してください...',
                    ),
                    onChanged:
                        _isEditing
                            ? (text) {
                              globalDiaryMap[key] = text;
                              globalDiaryNotifier.value = Map.from(
                                globalDiaryMap,
                              );
                            }
                            : null,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _diaryController.dispose();
    super.dispose();
  }
}

/// My Page（マイページ）
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200, // センターの背景を薄いグレーに
      child: ListView(
        children: [
          // アカウント情報セクション
          ExpansionTile(
            title: Text('アカウント情報'),
            subtitle: Text('認証方法: Email'),
            children: [
              ListTile(
                title: Text('UID: 12345678'),
                onTap: () {
                  // 詳細情報への遷移の準備
                },
              ),
            ],
          ),
          Divider(),
          // サービスセクション
          ExpansionTile(
            title: Text('サービス'),
            subtitle: Text('利用規約 / プライバシーポリシー / ログアウト'),
            children: [
              ListTile(
                title: Text('利用規約'),
                onTap: () {
                  // 利用規約の画面への遷移の準備
                },
              ),
              ListTile(
                title: Text('プライバシーポリシー'),
                onTap: () {
                  // プライバシーポリシーの画面への遷移の準備
                },
              ),
              ListTile(
                title: Text('ログアウト'),
                onTap: () {
                  // ログアウト処理の準備
                },
              ),
            ],
          ),
          Divider(),
          // アカウント削除セクション
          ListTile(
            title: Text('アカウント削除'),
            subtitle: Text('アカウント削除の準備中'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {
              // 今後、アカウント削除処理を実装するための準備
            },
          ),
        ],
      ),
    );
  }
}
