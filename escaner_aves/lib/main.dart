import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;

List<CameraDescription> cameras = [];
List> historialEscaneos = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const EscanerAvesApp());
}

class EscanerAvesApp extends StatelessWidget {
  const EscanerAvesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Escaner de aves',
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
        title: const Text('Escaner de aves', style: TextStyle(fontWeight: FontWeight.bold)),
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
          
          // Normalización MobileNetV2 [-1.0, 1.0]
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

      // ===================================================================
      // DICCIONARIO DE TRADUCCIÓN AL ESPAÑOL PARA TUS CLASES DE AVES
      // ===================================================================
      final Map<String, String> traduccionesAves = {
        'acadian_flycatcher': 'Mosquero acadio',
        'american_crow': 'Cuervo americano',
        'american_goldfinch': 'Jilguero americano',
        'american_pipit': 'Bisbita americano',
        'american_redstart': 'Cuitlacoche americano / Fósforo',
        'american_three_toed_woodpecker': 'Carpintero tridáctilo',
        'anna_hummingbird': 'Colibrí de Anna',
        'artic_tern': 'Gaviotín ártico',
        'baird_sparrow': 'Gorrión de Baird',
        'baltimore_oriole': 'Turpial de Baltimore',
        'bank_swallow': 'Golondrina ribereña',
        'barn_swallow': 'Golondrina común',
        'bay_breasted_warbler': 'Chipe pechicafé',
        'belted_kingfisher': 'Martín pescador norteño',
        'bewick_wren': 'Cucarachero de Bewick',
        'black_and_white_warbler': 'Chipe trepador',
        'black_billed_cuckoo': 'Cuclillo piquinegro',
        'black_capped_vireo': 'Vireo cabecinegro',
        'black_footed_albatross': 'Albatros de patas negras',
        'black_tern': 'Gaviotín negro',
        'black_throated_blue_warbler': 'Chipe azul gargantinegro',
        'black_throated_sparrow': 'Gorrión gargantinegro',
        'blue_grosbeak': 'Picogrueso azul',
        'blue_headed_vireo': 'Vireo de cabeza azul',
        'blue_jay': 'Arrendajo azul',
        'blue_winged_warbler': 'Chipe aliazul',
        'bobolink': 'Tordo bobolink',
        'bohemian_waxwing': 'Ampelis bohemio',
        'brandt_cormorant': 'Cormorán de Brandt',
        'brewer_blackbird': 'Zanate de Brewer',
        'brewer_sparrow': 'Gorrión de Brewer',
        'bronzed_cowbird': 'Tordo ojirrojo',
        'brown_creeper': 'Trepador café',
        'cactus_wren': 'Cucarachero de cactus',
        'california_gull': 'Gaviota californiana',
        'canada_warbler': 'Chipe canadiense',
        'cape_glossy_starling': 'Estornino brillante',
        'cape_may_warbler': 'Chipe de Cape May',
        'cardinal': 'Cardenal norteño',
        'carolina_wren': 'Cucarachero de Carolina',
        'caspian_tern': 'Gaviotín caspio',
        'cedar_waxwing': 'Ampelis americano',
        'cerulean_warbler': 'Chipe cerúleo',
        'chestnut_sided_warbler': 'Chipe flanco-cesta',
        'chipping_sparrow': 'Gorrión cejiblanco',
        'chuck_will_widow': 'Chotacabras de Carolin',
        'clark_nutcracker': 'Cascanueces de Clark',
        'clay_colored_sparrow': 'Gorrión arcilloso',
        'cliff_swallow': 'Golondrina risueña',
        'common_raven': 'Cuervo común',
        'common_tern': 'Gaviotín común',
        'crested_aulet': 'mérgulo crestado',
        'crow': 'Cuervo',
        'dark_eyed_junco': 'Junco ojioscuro',
        'downy_woodpecker': 'Carpintero pubescente',
        'duck': 'Pato',
        'eared_grebe': 'Zampullín cuellinegro',
        'eastern_towhee': 'Toquí collarejo',
        'elegant_tern': 'Gaviotín elegante',
        'european_goldfinch': 'Jilguero europeo',
        'evening_grosbeak': 'Picogrueso vespertino',
        'field_sparrow': 'Gorrión llanero',
        'fish_crow': 'Cuervo pescador',
        'forsters_tern': 'Gaviotín de Forster',
        'fox_sparrow': 'Gorrión rústico',
        'frigatebird': 'Fragata',
        'gadwall': 'Ánade friso',
        'geococcyx': 'Correcaminos',
        'glaucous_winged_gull': 'Gaviota de alas glaucas',
        'golden_winged_warbler': 'Chipe alidorado',
        'grasshopper_sparrow': 'Gorrión chapulinero',
        'gray_catbird': 'Maullador gris',
        'gray_crowned_rosy_finch': 'Pinzón rosado',
        'gray_kingbird': 'Tirano gris',
        'great_crested_flycatcher': 'Atrapamoscas crestado',
        'great_grey_shrike': 'Alcaudón norteño',
        'green_jay': 'Urraca hermosa',
        'green_kingfisher': 'Martín pescador verde',
        'green_tailed_towhee': 'Toquí coliverde',
        'green_violetear': 'Colibrí orejivioleta verde',
        'groove_billed_ani': 'Garrapatero piquiestriado',
        'harris_sparrow': 'Gorrión de Harris',
        'heermann_gull': 'Gaviota de Heermann',
        'hen': 'Gallina',
        'henslow_sparrow': 'Gorrión de Henslow',
        'herring_gull': 'Gaviota argéntea',
        'hooded_merganser': 'Pato capuchino',
        'hooded_oriole': 'Turpial cuculate',
        'hooded_warbler': 'Chipe capuchino',
        'horned_grebe': 'Zampullín cornudo',
        'horned_lark': 'Alondra cornuda',
        'horned_puffin': 'Frailecillo corniculado',
        'house_sparrow': 'Gorrión doméstico',
        'house_wren': 'Cucarachero común',
        'hummingbird': 'Colibrí',
        'indigo_bunting': 'Semillero azul',
        'ivory_gull': 'Gaviota marfil',
        'kentucky_warbler': 'Chipe de Kentucky',
        'laysan_albatross': 'Albatros de Laysan',
        'lazuli_bunting': 'Semillero lazulita',
        'le_conte_sparrow': 'Gorrión de LeConte',
        'least_auklet': 'Mérgulo mínimo',
        'least_flycatcher': 'Atrapamoscas mínimo',
        'least_tern': 'Gaviotín mínimo',
        'lincoln_sparrow': 'Gorrión de Lincoln',
        'loggerhead_shrike': 'Alcaudón verdugo',
        'long_tailed_jaeger': 'Stercorario rabudo',
        'louisiana_waterthrush': 'Chinito de Luisiana',
        'magnolia_warbler': 'Chipe magnolio',
        'mangrove_cuckoo': 'Cuclillo manglero',
        'marsh_wren': 'Cucarachero de ciénaga',
        'mockingbird': 'Sinsonte',
        'mourning_warbler': 'Chipe lúgubre',
        'myrtle_warbler': 'Chipe coronado',
        'nashville_warbler': 'Chipe de Nashville',
        'nelson_sharp_tailed_sparrow': 'Gorrión colifino',
        'northern_flicker': 'Carpintero norteño',
        'northern_fulmar': 'Fulmar boreal',
        'northern_waterthrush': 'Chipe acuático norteño',
        'olive_sided_flycatcher': 'Atrapamoscas oliváceo',
        'orange_crowned_warbler': 'Chipe celino',
        'orchard_oriole': 'Turpial huertero',
        'ovenbird': 'Reyezuelo hormiguero',
        'owl': 'Búho / Lechuza',
        'pacific_loon': 'Colimbo del Pacífico',
        'painted_bunting': 'Siete colores / Pintinto',
        'parakeet_auklet': 'Mérgulo lorito',
        'parrot': 'Loro / Perico',
        'peacock': 'Pavo real',
        'pelagic_cormorant': 'Cormorán pelágico',
        'penguin': 'Pingüino',
        'philadelphia_vireo': 'Vireo de Filadelfia',
        'pied_billed_grebe': 'Zampullín picogrueso',
        'pied_kingfisher': 'Martín pescador pío',
        'pigeon': 'Paloma',
        'pileated_woodpecker': 'Carpintero crestado',
        'pine_grosbeak': 'Picogrueso pinero',
        'pine_warbler': 'Chipe pinero',
        'prairie_warbler': 'Chipe de pradera',
        'prothonotary_warbler': 'Chipe protonotario',
        'purple_finch': 'Pinzón morado',
        'red_bellied_woodpecker': 'Carpintero ventrirrojo',
        'red_breasted_merganser': 'Mergujo pechirrojo',
        'red_cockaded_woodpecker': 'Carpintero capirotado',
        'red_eyed_vireo': 'Vireo ojirrojo',
        'red_faced_cormorant': 'Cormorán de cara roja',
        'red_legged_kittiwake': 'Gaviota tridáctila de patas rojas',
        'red_winged_blackbird': 'Tordo alirrojo',
        'rhinoceros_auklet': 'Mérgulo Rinoceronte',
        'ring_billed_gull': 'Gaviota de pico anillado',
        'ringed_kingfisher': 'Martín pescador de collar',
        'rock_wren': 'Cucarachero roquero',
        'rose_breasted_grosbeak': 'Picogrueso pechirrosa',
        'ruby_throated_hummingbird': 'Colibrí gargantirruby',
        'rufous_hummingbird': 'Colibrí rufo',
        'rusty_blackbird': 'Zanate ferruginoso',
        'sage_thrasher': 'Cuitlacoche sabanero',
        'savannah_sparrow': 'Gorrión sabanero',
        'sayornis': 'Fibí de Say',
        'scarlet_tanager': 'Tángara escarlata',
        'scissor_tailed_flycatcher': 'Tijereta sabanera',
        'scott_oriole': 'Turpial de Scott',
        'seaside_sparrow': 'Gorrión marino',
        'shiny_cowbird': 'Tordo brillante',
        'slaty_backed_gull': 'Gaviota dorsigrís',
        'song_sparrow': 'Gorrión cantor',
        'sooty_albatross': 'Albatros sombrío',
        'sparrow': 'Gorrión',
        'spotted_catbird': 'Maullador manchado',
        'summer_tanager': 'Tángara veranera',
        'swainson_warbler': 'Chipe de Swainson',
        'tennessee_warbler': 'Chipe de Tennessee',
        'tree_sparrow': 'Gorrión molinero',
        'tree_swallow': 'Golondrina arbórea',
        'tropical_kingbird': 'Tirano tropical',
        'vermiliom_flycatcher': 'Mosquero cardenal',
        'vesper_sparrow': 'Gorrión vespertino',
        'warbling_vireo': 'Vireo cantor',
        'western_grebe': 'Zampullín elegante',
        'western_gull': 'Gaviota occidental',
        'western_meadowlark': 'Pradero occidental',
        'western_wood_pewee': 'Pibí occidental',
        'whip_poor_will': 'Chotacabras guitarrero',
        'white_breasted_kingfisher': 'Martín pescador pechiblanco',
        'white_breasted_nuthatch': 'Trepador pechiblanco',
        'white_crowned_sparrow': 'Gorrión coroniblanco',
        'white_eyed_vireo': 'Vireo ojiblanco',
        'white_necked_raven': 'Cuervo cuelliblanco',
        'white_pelican': 'Pelícano blanco',
        'white_throated_sparrow': 'Gorrión gargantiblanco',
        'winter_wren': 'Chochín sencillo',
        'worm_eating_warbler': 'Chipe gusanero',
        'yellow_bellied_flycatcher': 'Atrapamoscas ventriamarillo',
        'yellow_billed_cuckoo': 'Cuclillo piquigualdo',
        'yellow_breasted_chat': 'Andarríos amarillo',
        'yellow_headed_blackbird': 'Tordo cabeciaramarilla',
        'yellow_throated_vireo': 'Vireo gargantiamarilla',
      };

      String nombreOriginal = objetoDetectado.trim().toLowerCase();
      String nombreEspanol = traduccionesAves[nombreOriginal] ?? objetoDetectado.replaceAll('_', ' ');

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _mostrarCuadro = false;
        });

        String hora = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
        historialEscaneos.add({
          "nombre": nombreEspanol,
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
                  nombreEspanol,
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