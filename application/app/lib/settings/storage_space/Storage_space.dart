import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class StorageSpace extends StatefulWidget {
  const StorageSpace({super.key});

  @override
  State<StorageSpace> createState() => _StorageSpaceState();
}

class _StorageSpaceState extends State<StorageSpace> with SingleTickerProviderStateMixin {
  double totalSpace = 0;
  double freeSpace = 0;
  double usedSpace = 0;

  late AnimationController _controller;
  late Animation<double> _animation;

  Future<void> fetchDiskInfo() async {
    Map<String, dynamic> config = json.decode(await rootBundle.loadString('assets/host_helper.json'));
  
    String url = config['host'] == 'local'
      ? '${config['local_ip']}:${config['local_port']}${config['dir'][0]['settings/storage_space']}'
      : '${config['global']}${config['dir'][0]['settings/storage_space']}';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        totalSpace = data['totalSpace'].toDouble();
        freeSpace = data['freeSpace'].toDouble();
        usedSpace = data['usedSpace'].toDouble();
      });
    } else {
      print('Ошибка при получении данных: ${response.statusCode}');
    }
  }

  List<SegmentData> getData() {
    double usedPercentage = usedSpace / totalSpace;
    double freePercentage = freeSpace / totalSpace;

    return [
      SegmentData(
        percentage: freePercentage,
        color: const Color.fromARGB(255, 79, 176, 255),
        label: "Свободно (${freeSpace.toInt()}ГБ)"
      ),
      SegmentData(
        percentage: usedPercentage,
        color: const Color.fromARGB(255, 255, 100, 79),
        label: "Занято (${usedSpace.toInt()}ГБ)"
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    fetchDiskInfo();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    )..addListener(() {
      setState(() {});
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [

        CustomPaint(
          size: const Size(150, 150),
          painter: CircleChartPainter(
            data: getData(),
            progress: _animation.value,
            totalSpace: totalSpace,
          ),
        ),

        const SizedBox(height: 25),

        const Text(
          "Дисковое пространство",
          style: TextStyle(
            fontSize: 19,
            fontFamily: "Ubuntu"
          ),
        ),

        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ...getData().map((segment)=> Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: segment.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Text(segment.label, style: const TextStyle(fontSize: 15)),
              ],
            )),
          ]
        ),

      ],
    );
  }
}


class CircleChartPainter extends CustomPainter {
  final List<SegmentData> data;
  final double progress;
  final double totalSpace;

  CircleChartPainter({
    required this.data,
    required this.progress,
    required this.totalSpace,
    });

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 23;
    final double radius = (size.width - strokeWidth) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const double paddingAngle = 0.02;

    double startAngle = -pi / 2;

    for (var segment in data) {
      final animatedPercentage = segment.percentage * progress;

      final sweepAngle = 2 * pi * animatedPercentage - paddingAngle;

      if (sweepAngle > 0) {
        paint.color = segment.color;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
          paint,
        );

        final double textAngle = startAngle + sweepAngle / 2;
        final Offset textOffset = Offset(
          center.dx + (radius - strokeWidth / 2) * cos(textAngle),
          center.dy + (radius - strokeWidth / 2) * sin(textAngle),
        );

        _drawText(
          canvas,
          textOffset,
          '${(animatedPercentage * 100).toInt()}%',
          const TextStyle(
            color: Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: "Ubuntu",
          ),
        );
      }

      startAngle += sweepAngle + paddingAngle;
    }

    _drawText(
      canvas,
      center,
      '${totalSpace.toInt()}ГБ',
      const TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: "Ubuntu",
      ),
    );
  }

  void _drawText(Canvas canvas, Offset position, String text, TextStyle style) {
    final TextSpan span = TextSpan(
      text: text,
      style: style,
    );
    final TextPainter textPainter = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final Offset offset = Offset(
      position.dx - textPainter.width / 2,
      position.dy - textPainter.height / 2,
    );

    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class SegmentData {
  final double percentage;
  final Color color;
  final String label;

  SegmentData({required this.percentage, required this.color, required this.label});
}