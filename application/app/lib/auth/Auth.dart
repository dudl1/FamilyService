import 'dart:async';
import 'package:app/animations/routing_animations.dart';
import 'package:app/host_helper.dart';
import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Auth extends StatefulWidget {
  const Auth({super.key});

  @override
  State<Auth> createState() => _AuthState();
}

class _AuthState extends State<Auth> with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  bool _showCursor = false;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();

  late AnimationController _controller;


  Future<void> auth_user(_formKey, _usernameController, context) async {
    String url = await host_helper('auth/Auth');

    final user_name = _usernameController.text;
    final response = await http.get(
      Uri.parse(url+user_name),
    );

    void notificationBar(BuildContext context, String message, Color backgroundColor, IconData icon) {
      Flushbar(
        message: message,
        duration: const Duration(milliseconds: 1400),
        margin: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(8),
        backgroundColor: backgroundColor,
        flushbarPosition: FlushbarPosition.TOP,
        icon: Icon(
          icon,
          color: Colors.white,
        ),
      ).show(context);
    }

    if (response.statusCode == 201) {

      Map<String, dynamic> data = jsonDecode(response.body);
      String user_id = data['user_id'];
      List<int> avatar = List<int>.from(data['avatar']['data']);
      String created_at = data['created_at'];

      notificationBar(context, 'Аккаунт создан успешно', const Color.fromARGB(255, 42, 187, 13), Icons.favorite_rounded);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool('isAuthenticated', true);
      prefs.setString('user_id', user_id);
      prefs.setString('avatar', jsonEncode(avatar));
      prefs.setString('created_at', created_at);

      _focusNode.unfocus();

      Future.delayed(const Duration(milliseconds: 2500), () {
        routing_animations(context, "vertical", const MyApp());
      });

    } else if (response.statusCode == 400) {
      notificationBar(context, 'Пользователь с таким именем уже существует', const Color.fromARGB(255, 235, 171, 33), Icons.visibility);
    } else {
      notificationBar(context, 'Ошибка: ${response.statusCode}', const Color.fromARGB(255, 235, 33, 33), Icons.error);
    }
  }


  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() {
        _showCursor = _focusNode.hasFocus;
      });
    });

    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _focusNode.dispose();

    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    double keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(
          "Вход в ДомСервис",
          style: TextStyle(
            fontFamily: "Ubuntu"
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(225, 255, 255, 255),
        elevation: 0,
      ),
      body: AnimatedPadding(
        curve: Curves.easeInOutQuint,
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.only(bottom: isKeyboardVisible ? keyboardHeight + 5 : 0),
        child: Stack(
          children: [
            
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width - 60,
                child: Stack(
                  children: [

                    Transform.translate(
                      offset: const Offset(0, -45),
                      child: const Text(
                        "Давайте знакомиться 🖐",
                        style: TextStyle(
                          fontSize: 20,
                        )
                      ),
                    ),

                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(17),
                          borderSide: BorderSide.none,
                        ),
                        hintText: 'Ваше имя',
                      ),
                      focusNode: _focusNode,
                      showCursor: _showCursor,
                      cursorColor: const Color.fromARGB(255, 75, 75, 75),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Имя пользователя не может быть пустым';
                        }
                        return null;
                      },
                    ),

                  ],
                )
              ),
            ),
        
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: MediaQuery.sizeOf(context).width - 60,
                height: 55,
                child: ElevatedButton(
                  onPressed: ()  {
                    auth_user(
                      _formKey,
                      _usernameController,
                      context
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                    backgroundColor: const Color.fromARGB(255, 79, 176, 255),
                    shadowColor: Colors.transparent,
                    elevation: 0,
                  ),
                  child: const Text(
                    "Войти",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16
                    ),
                  ),
                ),
              ),
            )
            
          ],
        ),
      ),
    );
  }
}