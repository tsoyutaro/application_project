import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
ValueNotifier<Map<String, int>> globalMoodNotifier = ValueNotifier(globalMoodMap);
ValueNotifier<Map<String, String>> globalDiaryNotifier = ValueNotifier(globalDiaryMap);

final FlutterSecureStorage secureStorage = FlutterSecureStorage();

/// 起動時の認証処理を実施するウィジェット（認証設定がOFFならスルー）
class StartupScreen extends StatefulWidget {
  @override
  _StartupScreenState createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // secureStorageから認証設定を読み込む（未設定ならデフォルトはOFF）
    String? biometricFlag = await secureStorage.read(key: 'enableBiometric');
    String? pinFlag = await secureStorage.read(key: 'enablePin');
    bool enableBiometric = biometricFlag == 'true';
    bool enablePin = pinFlag == 'true';

    // 認証設定がどちらもOFFの場合、すぐにメイン画面へ
    if (!enableBiometric && !enablePin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainScreen()),
      );
      return;
    }

    // 生体認証がONの場合、まず生体認証を試行
    if (enableBiometric) {
      bool authenticated = false;
      try {
        authenticated = await auth.authenticate(
          localizedReason: 'アプリ利用のため認証してください',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
      } catch (e) {
        print('生体認証エラー: $e');
      }
      if (authenticated) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainScreen()),
        );
        return;
      } else {
        // 生体認証失敗時、PIN認証がONならPIN認証へ
        if (enablePin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => PinAuthPage()),
          );
          return;
        }
      }
    } else if (enablePin) {
      // 生体認証がOFFでPIN認証のみONの場合はPIN認証画面へ
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PinAuthPage()),
      );
      return;
    }

    // いずれの認証も機能しなかった場合は、メイン画面へ遷移
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class PinAuthPage extends StatefulWidget {
  @override
  _PinAuthPageState createState() => _PinAuthPageState();
}

class _PinAuthPageState extends State<PinAuthPage> {
  final TextEditingController _pinController = TextEditingController();
  String? _storedPin;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadStoredPin();
  }

  Future<void> _loadStoredPin() async {
    _storedPin = await secureStorage.read(key: 'userPin');
    // PIN未設定の場合はPIN設定画面へ
    if (_storedPin == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SetPinPage()),
      );
    }
  }

  void _verifyPin() async {
    if (_pinController.text == _storedPin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainScreen()),
      );
    } else {
      setState(() {
        _errorText = "PINが正しくありません";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PIN認証')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _pinController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'PINコードを入力',
                errorText: _errorText,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _verifyPin, child: const Text('認証')),
          ],
        ),
      ),
    );
  }
}

class SetPinPage extends StatefulWidget {
  @override
  _SetPinPageState createState() => _SetPinPageState();
}

class _SetPinPageState extends State<SetPinPage> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  String? _errorText;

  void _savePin() async {
    if (_pinController.text != _confirmPinController.text) {
      setState(() {
        _errorText = "PINが一致しません";
      });
      return;
    }
    await secureStorage.write(key: 'userPin', value: _pinController.text);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PIN設定')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _pinController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '新しいPINコード'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _confirmPinController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'PINコード確認',
                errorText: _errorText,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _savePin, child: const Text('PINを保存')),
          ],
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  var diaryBox = await Hive.openBox('diary');

  // Hiveに保存されている各エントリをグローバル変数に読み込み
  for (var key in diaryBox.keys) {
    var entry = diaryBox.get(key);
    if (entry is Map) {
      if (entry['mood'] != null && entry['mood'] is int && entry['mood'] != -1) {
        globalMoodMap[key] = entry['mood'];
      }
      if (entry['diary'] != null && entry['diary'] is String) {
        globalDiaryMap[key] = entry['diary'];
      }
    }
  }
  globalMoodNotifier.value = Map.from(globalMoodMap);
  globalDiaryNotifier.value = Map.from(globalDiaryMap);

  runApp(
    MaterialApp(
      title: 'Emonator',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: StartupScreen(), // 最初に認証画面を表示
    ),
  );
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
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
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
                    globalMoodMap.remove(key);
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
              child: const Icon(Icons.today),
            )
          : null,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
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
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 初期状態は当月の1日を基準とする
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  // チュートリアル表示用フラグ
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    _checkTutorial();
  }

  Future<void> _checkTutorial() async {
    String? seen = await secureStorage.read(key: 'hasSeenTutorial');
    if (seen != 'true') {
      setState(() {
        _showTutorial = true;
      });
    }
  }

  Future<void> _dismissTutorial() async {
    setState(() {
      _showTutorial = false;
    });
    await secureStorage.write(key: 'hasSeenTutorial', value: 'true');
  }

  int daysInMonth(DateTime date) {
    var beginningNextMonth = (date.month < 12)
        ? DateTime(date.year, date.month + 1, 1)
        : DateTime(date.year + 1, 1, 1);
    return beginningNextMonth.subtract(const Duration(days: 1)).day;
  }

  @override
  Widget build(BuildContext context) {
    int daysCount = daysInMonth(_selectedMonth);
    DateTime firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    int weekdayOffset = firstDay.weekday % 7;
    int totalCells = weekdayOffset + daysCount;

    return Stack(
      children: [
        Container(
          color: Colors.grey.shade200,
          child: Column(
            children: [
              // 上部：◀▶付きの年月表示
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_left),
                    onPressed: () {
                      setState(() {
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
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_right),
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
              // 曜日の表示
              Row(
                children: const ['日', '月', '火', '水', '木', '金', '土'].map((day) {
                  return Expanded(
                    child: Center(
                      child: Text(day, style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  );
                }).toList(),
              ),
              // カレンダーグリッド
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: totalCells,
                  itemBuilder: (context, index) {
                    if (index < weekdayOffset) {
                      return const SizedBox.shrink();
                    } else {
                      int day = index - weekdayOffset + 1;
                      DateTime cellDate = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month,
                        day,
                      );
                      String key = '${cellDate.year}-${cellDate.month}-${cellDate.day}';
                      DateTime now = DateTime.now();
                      bool isToday = (now.year == cellDate.year &&
                          now.month == cellDate.month &&
                          now.day == cellDate.day);
                      Widget dayCircle = Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isToday ? Colors.blue.shade900 : Colors.transparent,
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
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          dayCircle,
                          const SizedBox(height: 4),
                          // 気分ボタン
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
                                    color: hasMood
                                        ? Colors.transparent
                                        : Colors.lightBlue.shade100,
                                  ),
                                  child: Center(
                                    child: hasMood
                                        ? Icon(
                                            kMoodIcons[moodMap[key]!],
                                            size: buttonSize,
                                            color: Colors.blue.shade900,
                                          )
                                        : const SizedBox.shrink(),
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
        ),
        // チュートリアルオーバーレイ（初回のみ表示）
        if (_showTutorial)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Emonatorへようこそ！\n\n'
                        '・上部の矢印で月を切り替えます。\n'
                        '・日付の下の丸ボタンをタップすると、その日の気分と日記を入力できます。\n'
                        '・下の丸ボタンに現在の気分が表示されます。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _dismissTutorial,
                        child: const Text('了解'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 日記入力画面（DiaryPage）
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
    String key = '${_currentDate.year}-${_currentDate.month}-${_currentDate.day}';
    var entry = diaryBox.get(key);
    if (entry != null) {
      _selectedMoodIndex = entry['mood'] ?? -1;
      _diaryController.text = entry['diary'] ?? '';
    }
    // 既存の気分・日記内容を反映
    if (globalMoodMap.containsKey(key)) {
      _selectedMoodIndex = globalMoodMap[key]!;
    }
    if (globalDiaryMap.containsKey(key)) {
      _diaryController.text = globalDiaryMap[key]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
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
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('日付選択中にエラーが発生しました: $e')));
            }
          },
          child: Text('${_currentDate.year}/${_currentDate.month}/${_currentDate.day}'),
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
                    color: _selectedMoodIndex == index ? Colors.blue : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedMoodIndex = _selectedMoodIndex == index ? -1 : index;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            // 日記記入用テキストフィールド（maxLength を設定して入力制限）
            Expanded(
              child: TextField(
                controller: _diaryController,
                maxLines: null,
                expands: true,
                maxLength: 100,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                decoration: const InputDecoration(
                  hintText: '日記を記入してください...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          child: const Text('完了'),
          onPressed: () {
            try {
              ScaffoldMessenger.of(context).clearSnackBars();
              var diaryBox = Hive.box('diary');
              String key = '${_currentDate.year}-${_currentDate.month}-${_currentDate.day}';
              if (_selectedMoodIndex == -1) {
                globalMoodMap.remove(key);
                diaryBox.delete(key);
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
              int? moodToReturn = (_selectedMoodIndex == -1) ? null : _selectedMoodIndex;
              Navigator.pop(context, moodToReturn);
            } catch (e) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('保存中にエラーが発生しました: $e')));
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
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  late TextEditingController _diaryController;
  bool _isEditing = false; // 編集モード（初期はOFF）
  int _localMood = -1; // 編集モード中の気分状態。未選択は -1

  // Hive の Box を初期化してキャッシュ
  final Box diaryBox = Hive.box('diary');

  @override
  void initState() {
    super.initState();
    String key = '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
    _diaryController = TextEditingController(text: globalDiaryMap[key] ?? '');
    _localMood = globalMoodMap[key] ?? -1;
  }

  @override
  void dispose() {
    _diaryController.dispose();
    super.dispose();
  }

  // 日付を1日進めたり戻したりするヘルパーメソッド
  void _changeDateByDays(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      String newKey = '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
      _diaryController.text = globalDiaryMap[newKey] ?? '';
      _localMood = globalMoodMap[newKey] ?? -1;
    });
  }

  Widget _buildDateRow() {
    String dateText = '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}';
    return Column(
      children: [
        // 日付表示と左右矢印
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_left),
              onPressed: () => _changeDateByDays(-1),
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
                      String newKey = '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_right),
              onPressed: () => _changeDateByDays(1),
            ),
          ],
        ),
        // 編集ON/OFFスイッチ
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text("編集"),
            Switch(
              value: _isEditing,
              onChanged: (bool value) {
                String key = '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
                if (!value) {
                  // 編集OFF時の保存処理
                  if (_diaryController.text.length > 100) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('日記は100文字以内で入力してください')),
                    );
                    return;
                  }
                  if (_localMood == -1) {
                    globalMoodMap.remove(key);
                    diaryBox.delete(key);
                  } else {
                    globalMoodMap[key] = _localMood;
                  }
                  globalMoodNotifier.value = Map.from(globalMoodMap);
                  diaryBox.put(key, {
                    'mood': _localMood,
                    'diary': _diaryController.text,
                  });
                  globalDiaryMap[key] = _diaryController.text;
                  globalDiaryNotifier.value = Map.from(globalDiaryMap);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('保存しました')),
                  );
                } else {
                  // 編集ON時は最新の値を反映
                  _localMood = globalMoodMap[key] ?? -1;
                }
                setState(() {
                  _isEditing = value;
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
                onPressed: null, // 編集OFFならタップ不可
              );
            }),
          );
        },
      );
    } else {
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
                _localMood = (_localMood == index) ? -1 : index;
              });
            },
          );
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String key = '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildDateRow(),
          const SizedBox(height: 16),
          _buildMoodButtons(key),
          const SizedBox(height: 16),
          const Text(
            'Diary:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          ValueListenableBuilder<Map<String, String>>(
            valueListenable: globalDiaryNotifier,
            builder: (context, diaryMap, child) {
              String currentDiary = diaryMap[key] ?? '';
              if (!_isEditing && _diaryController.text != currentDiary) {
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
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  onChanged: _isEditing
                      ? (text) {
                          globalDiaryMap[key] = text;
                          globalDiaryNotifier.value = Map.from(globalDiaryMap);
                        }
                      : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// My Page（マイページ）
class MyPage extends StatefulWidget {
  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  bool _enableBiometric = false;
  bool _enablePin = false;

  @override
  void initState() {
    super.initState();
    _loadAuthSettings();
  }

  Future<void> _loadAuthSettings() async {
    String? biometricFlag = await secureStorage.read(key: 'enableBiometric');
    String? pinFlag = await secureStorage.read(key: 'enablePin');
    setState(() {
      _enableBiometric = biometricFlag == 'true';
      _enablePin = pinFlag == 'true';
    });
  }

  Future<void> _updateAuthSetting(String key, bool value) async {
    await secureStorage.write(key: key, value: value.toString());
  }

  /// ログアウト処理
  Future<void> _logout() async {
    // 必要に応じてセッション情報のクリア等の処理を追加
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => StartupScreen()),
      (route) => false,
    );
  }

  /// アカウント削除処理
  Future<void> _deleteAccount() async {
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('アカウント削除'),
          content: Text('本当にアカウントを削除してもよろしいですか？\nこの操作は元に戻せません。'),
          actions: [
            TextButton(
              child: Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text('削除'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // secureStorage の全データ削除（必要なキーのみ削除することも可能です）
      await secureStorage.deleteAll();

      // Hiveに保存されている日記データを削除
      var diaryBox = await Hive.openBox('diary');
      await diaryBox.clear();

      // グローバル変数のクリア
      globalMoodMap.clear();
      globalDiaryMap.clear();
      globalMoodNotifier.value = Map.from(globalMoodMap);
      globalDiaryNotifier.value = Map.from(globalDiaryMap);

      // ログアウト後、認証画面へ遷移
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => StartupScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: ListView(
        children: [
          // サービスセクション
          ExpansionTile(
            title: Text('サービス'),
            subtitle: Text('利用規約 / プライバシーポリシー / ログアウト'),
            children: [
              ListTile(
                title: Text('利用規約'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TermsOfServicePage()),
                  );
                },
              ),
              ListTile(
                title: Text('プライバシーポリシー'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PrivacyPolicyPage()),
                  );
                },
              ),
              ListTile(title: Text('ログアウト'), onTap: _logout),
            ],
          ),

          Divider(),
          // 認証設定セクション
          ExpansionTile(
            title: Text('認証設定'),
            subtitle: Text('顔認証とPIN認証をON/OFFできます。両方ONの場合は顔認証優先、失敗時にPIN認証'),
            children: [
              SwitchListTile(
                title: Text('顔認証'),
                value: _enableBiometric,
                onChanged: (bool value) {
                  setState(() {
                    _enableBiometric = value;
                  });
                  _updateAuthSetting('enableBiometric', value);
                },
              ),
              SwitchListTile(
                title: Text('PIN認証'),
                value: _enablePin,
                onChanged: (bool value) {
                  setState(() {
                    _enablePin = value;
                  });
                  _updateAuthSetting('enablePin', value);
                  if (value) {
                    secureStorage.read(key: 'userPin').then((pin) {
                      if (pin == null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SetPinPage()),
                        );
                      }
                    });
                  }
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
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}

// 利用規約画面
class TermsOfServicePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('利用規約')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'ここに利用規約の内容を記述してください。\n\n'
          '【例】\n'
          '1. 本サービスは、ユーザーが安心して利用できることを目的としています。\n'
          '2. ユーザーは、本利用規約に同意の上でサービスを利用してください。\n'
          '3. 当社は、必要に応じて本利用規約を変更する場合があります。\n'
          '（以下、詳細な利用規約の文章を記載）',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

// プライバシーポリシー画面
class PrivacyPolicyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('プライバシーポリシー')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'ここにプライバシーポリシーの内容を記述してください。\n\n'
          '【例】\n'
          '1. 当社は、ユーザーの個人情報を適切に保護します。\n'
          '2. ユーザーの同意なく第三者に個人情報を提供することはありません。\n'
          '3. 本ポリシーは、必要に応じて改訂されます。\n'
          '（以下、詳細なプライバシーポリシーの文章を記載）',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
