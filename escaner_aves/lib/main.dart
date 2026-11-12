import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;

List<CameraDescription> cameras = [];
List<Map<String, dynamic>> historialEscaneos = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const ExploradorAvesApp());
}

class ExploradorAvesApp extends StatelessWidget {
  const ExploradorAvesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Identificador de Aves',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MenuPrincipal(),
    );
  }
}

class MenuPrincipal extends StatelessWidget {
  const MenuPrincipal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal[50],
      appBar: AppBar(
        title: const Text('Explorador de Aves', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco_rounded, size: 120, color: Colors.teal),
            const SizedBox(height: 20),
            const Text(
              '¿Qué especie vamos a identificar hoy?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PantallaEscaner()),
                );
              },
              icon: const Icon(Icons.camera_alt, size: 28),
              label: const Text('Identificar Ave', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PantallaRegistro()),
                );
              },
              icon: const Icon(Icons.library_books_rounded, size: 28),
              label: const Text('Ver Bitácora', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                side: const BorderSide(color: Colors.teal, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PantallaEscaner extends StatefulWidget {
  const PantallaEscaner({super.key});

  @override
  State<PantallaEscaner> createState() => _PantallaEscanerState();
}

class _PantallaEscanerState extends State<PantallaEscaner> {
  late CameraController _controller;
  bool _isCameraInitialized = false;
  bool _isAnalyzing = false;
  bool _mostrarCuadro = false;

  Interpreter? _interpreter;
  List<String> _etiquetas = [];

  @override
  void initState() {
    super.initState();
    _inicializarCamara();
    _cargarModelo();
  }

  Future<void> _inicializarCamara() async {
    var status = await Permission.camera.request();
    if (status.isGranted) {
      _controller = CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);
      try {
        await _controller.initialize();
        if (!mounted) return;
        setState(() { _isCameraInitialized = true; });
      } catch (e) {
        debugPrint("Error al inicializar la cámara: $e");
      }
    }
  }

  Future<void> _cargarModelo() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/modelo_aves.tflite');
      String etiquetasTxt = await rootBundle.loadString('assets/etiquetas.txt');
      _etiquetas = etiquetasTxt.split('\n').where((e) => e.trim().isNotEmpty).toList();
      debugPrint("¡Modelo cargado! Aves aprendidas: ${_etiquetas.length}");
    } catch (e) {
      debugPrint("Error al cargar la Inteligencia Artificial: $e");
    }
  }

  Future<void> _analizarAve() async {
    if (_interpreter == null || _etiquetas.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _mostrarCuadro = true;
    });

    try {
      final imageFile = await _controller.takePicture();
      final bytes = await File(imageFile.path).readAsBytes();

      img.Image? originalImage = img.decodeImage(bytes);
      img.Image resizedImage = img.copyResize(originalImage!, width: 224, height: 224);

      var input = List.generate(1, (i) => List.generate(224, (y) => List.generate(224, (x) => List.generate(3, (c) => 0.0))));
      
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixel(x, y);
          
          // Normalización estricta de MobileNetV2 a escala [-1.0, 1.0]
          input[0][y][x][0] = (pixel.r.toDouble() - 127.5) / 127.5;
          input[0][y][x][1] = (pixel.g.toDouble() - 127.5) / 127.5;
          input[0][y][x][2] = (pixel.b.toDouble() - 127.5) / 127.5;
        }
      }

      var output = List.generate(1, (i) => List.filled(_etiquetas.length, 0.0));
      _interpreter!.run(input, output);

      double probMaxima = 0;
      int indiceMaximo = 0;
      for (int i = 0; i < _etiquetas.length; i++) {
        if (output[0][i] > probMaxima) {
          probMaxima = output[0][i];
          indiceMaximo = i;
        }
      }

      String objetoDetectado = _etiquetas[indiceMaximo];
      String nombreLimpio = objetoDetectado.replaceAll('_', ' ');

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _mostrarCuadro = false;
        });

        String hora = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
        historialEscaneos.add({
          "nombre": nombreLimpio,
          "hora": hora,
          "certeza": "${(probMaxima * 100).toStringAsFixed(1)}%"
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Resultado del análisis', textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nombreLimpio,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('Certeza de IA: ${(probMaxima * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
                )
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Error durante el escaneo: $e");
      setState(() {
        _isAnalyzing = false;
        _mostrarCuadro = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enfoca el ave'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isCameraInitialized
          ? Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CameraPreview(_controller),
                ),
                if (_mostrarCuadro)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: DibujanteDeCuadro(),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: _isAnalyzing
                        ? const CircularProgressIndicator(color: Colors.teal)
                        : ElevatedButton.icon(
                            onPressed: _analizarAve,
                            icon: const Icon(Icons.search, size: 30),
                            label: const Text('¡Identificar!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              elevation: 10,
                            ),
                          ),
                  ),
                )
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.teal)),
    );
  }
}

class DibujanteDeCuadro extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.tealAccent
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2.5),
      width: 250,
      height: 250,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(15)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PantallaRegistro extends StatelessWidget {
  const PantallaRegistro({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal[50],
      appBar: AppBar(
        title: const Text('Bitácora de Aves'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: historialEscaneos.isEmpty
          ? const Center(
              child: Text(
                'Aún no has registrado ningún ave.\n¡Sal a explorar!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: historialEscaneos.length,
              itemBuilder: (context, index) {
                final item = historialEscaneos[historialEscaneos.length - 1 - index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.eco, color: Colors.white),
                    ),
                    title: Text(item["nombre"]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text('Avistado a las ${item["hora"]} (${item['certeza']})'),
                  ),
                );
              },
            ),
    );
  }
}