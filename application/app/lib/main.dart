import 'package:app/animations/routing_animations.dart';
import 'package:app/auth/Auth.dart';
import 'package:app/custome/custom_image_picker.dart';
import 'package:app/host_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'dart:async'; // Добавляем для StreamController

void main() {
  runApp(const MyApp());
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool?> _checkAuthStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? isAuthenticated = prefs.getBool('isAuthenticated');
    return isAuthenticated;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ДомСервис',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        fontFamily: "Ubuntu",
        useMaterial3: true,
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: Color.fromARGB(68, 107, 107, 107),
          selectionHandleColor: Color.fromARGB(255, 75, 75, 75),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          surfaceTintColor: Colors.white,
        ),
      ),
      home: FutureBuilder<bool?>(
        future: _checkAuthStatus(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data == true) {
            return const MyHomePage();
          } else {
            return const Auth();
          }
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Uint8List? avatarBytes;
  bool isLoading = true;
  late StreamController<List<FileInfo>> _fileStreamController;
  late Stream<List<FileInfo>> fileStream;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _fileStreamController = StreamController<List<FileInfo>>.broadcast();
    fileStream = _fileStreamController.stream;
    _fetchFiles();
  }

  Future<void> _loadAvatar() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? avatar = prefs.getString('avatar');

    if (avatar != null) {
      List<int> avatarBytesList = List<int>.from(json.decode(avatar));
      setState(() {
        avatarBytes = Uint8List.fromList(avatarBytesList);
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchFiles() async {
    try {
      String url = await host_helper('fetchFiles');  
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<FileInfo> files = data.map((file) => FileInfo.fromJson(file)).toList();
        _fileStreamController.add(files);
      } else {
        throw Exception('Не удалось загрузить файлы');
      }
    } catch (e) {
      _fileStreamController.addError(e);
    }
  }

  @override
  void dispose() {
    _fileStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double statusBarHeight = MediaQuery.paddingOf(context).top;
    double appBarHeight = kToolbarHeight + statusBarHeight;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      endDrawerEnableOpenDragGesture: true,
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        leadingWidth: 40,
        leading: Transform.translate(
          offset: const Offset(12, 0),
          child: isLoading
          ? Shimmer.fromColors(
              baseColor: const Color.fromARGB(255, 0, 0, 0),
              highlightColor: const Color.fromARGB(255, 87, 87, 87),
              child: const CircleAvatar(),
          ) : CircleAvatar(
            backgroundImage: MemoryImage(avatarBytes!),
          ),
        ),
        title: const Text(
          "ДомСервис",
          style: TextStyle(fontFamily: "Ubuntu"),
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
        centerTitle: true,
        backgroundColor: const Color.fromARGB(225, 255, 255, 255),
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: const Color.fromARGB(244, 255, 255, 255).withOpacity(0.0),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Padding(padding: EdgeInsets.only(top: appBarHeight)),

          StreamBuilder<List<FileInfo>>(
            stream: fileStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Ошибка: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Файлы не найдены'));
              } else {
                final fileList = snapshot.data!;
                return Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10.0,
                      mainAxisSpacing: 10.0,
                    ),
                    itemCount: fileList.length,
                    itemBuilder: (context, index) {
                      final file = fileList[index];
                      return GestureDetector(
                        onTap: () {
                          // Логика для просмотра файла
                        },
                        child: Image.network(
                          file.filePath,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            } else {
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          (loadingProgress.expectedTotalBytes ?? 1)
                                      : null,
                                ),
                              );
                            }
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(child: Icon(Icons.error));
                          },
                        ),
                      );
                    },
                  ),
                );
              }
            },
          ),

        ],
      ),
      floatingActionButton: SizedBox(
        width: 62,
        height: 62,
        child: FloatingActionButton(
          onPressed: () {
            showImagePickerModal(context);
          },
          elevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          backgroundColor: const Color.fromARGB(255, 106, 188, 255),
          child: const Icon(Icons.add, size: 25, color: Colors.white),
        ),
      ),
      backgroundColor: Colors.white,
      endDrawer: Drawer(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0,
        child: Column(
          children: [
            const Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 38, bottom: 30, right: 0, left: 18),
                child: Text(
                  'Настройки',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
            ListTile(
              title: const Row(
                children: [
                  Icon(Icons.storage_outlined),
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      'Дисковое пространство',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              onTap: () {},
            ),
            ListTile(
              title: const Row(
                children: [
                  Icon(Icons.delete_outline, color: Color.fromARGB(255, 255, 100, 79)),
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      'Выйти из аккаунта',
                      style: TextStyle(
                        color: Color.fromARGB(255, 255, 100, 79),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () {
                logout(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isAuthenticated', false);
    routing_animations(context, "horizontal", const Auth());
  }
}

class FileInfo {
  final String fileId;
  final String filePath;
  final String fileType;

  FileInfo({required this.fileId, required this.filePath, required this.fileType});

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    return FileInfo(
      fileId: json['file_id'],
      filePath: json['file_path'],
      fileType: json['file_type'],
    );
  }
}