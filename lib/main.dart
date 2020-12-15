import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notecard',
      theme: ThemeData(
      brightness: Brightness.light,
      /* light theme settings */
    ),
    darkTheme: ThemeData(
    brightness: Brightness.dark,
    /* dark theme settings */
    ),
    themeMode: ThemeMode.dark,
    /* ThemeMode.system to follow system theme,
         ThemeMode.light for light theme,
         ThemeMode.dark for dark theme
      */
//      ThemeData(
//
//        // This is the theme of your application.
//        //
//        // Try running your application with "flutter run". You'll see the
//        // application has a blue toolbar. Then, without quitting the app, try
//        // changing the primarySwatch below to Colors.green and then invoke
//        // "hot reload" (press "r" in the console where you ran "flutter run",
//        // or simply save your changes to "hot reload" in a Flutter IDE).
//        // Notice that the counter didn't reset back to zero; the application
//        // is not restarted.
//        primarySwatch: Colors.blue,
//        // This makes the visual density adapt to the platform that you run
//        // the app on. For desktop platforms, the controls will be smaller and
//        // closer together (more dense) than on mobile platforms.
//        visualDensity: VisualDensity.adaptivePlatformDensity,
//      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String speech_time = "00:00:00";
  final speechController = TextEditingController();
  ScrollController _scrollController = ScrollController();

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  bool playing = false;
  int _word_per_minute = 6;

  _launchURL(url) async {

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void play_pause(){
    setState(() {
      playing = !playing;
    });

  }

  String yourspeech = '''
''';
  ///SCROLLL
//  bool scroll = false;
////  int speedFactor = 20;

  _scroll() {
    double maxExtent = _scrollController.position.maxScrollExtent;
    double distanceDifference = maxExtent - _scrollController.offset;
    double durationDouble = distanceDifference / _word_per_minute;


    _scrollController.animateTo(_scrollController.position.maxScrollExtent,
        duration: Duration(seconds: durationDouble.toInt()),
        curve: Curves.linear);
  }

  String setDuration() {

    double maxExtent = _scrollController.position.maxScrollExtent;
    double durationDouble = maxExtent / _word_per_minute;
    Duration duration  = Duration(seconds: durationDouble.toInt());
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    setState(() {
      speech_time = "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    });

  }



  _toggleScrolling() {
    setDuration();
    setState(() {
      playing = !playing;
    });

    if (playing) {

      _scroll();

    } else {
      _scrollController.animateTo(_scrollController.offset,
          duration: Duration(seconds: 1), curve: Curves.linear);
    }
  }

  double scaleSmallDevice(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // For tiny devices.
    if (size.height < 600) {
      return 0.7;
    }
    else if (size.height < 1080) {
      return 1;
    }else{
      return 1.4;
    }

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      key: _scaffoldKey,
        endDrawer: Drawer(

          child: ListView(


            padding: EdgeInsets.zero,
            children: <Widget>[
              DrawerHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Notecard App',
                      style: TextStyle(color: Colors.black),
                    ),
                    Text(
                      'Type your text and press play to start your speech.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    Row(
                      children: <Widget>[
                        Container(
                          margin: EdgeInsets.all(10),
                          child: Tooltip(
                            message: 'See the code',
                            child: IconButton(
                              icon: FaIcon(FontAwesomeIcons.github,
                                  color: Colors.blueAccent),
                              highlightColor: Colors.blueAccent,
                              onPressed: () {
                                String url =
                                    'https://zmsp.github.io';
                                _launchURL(url);
                              },
                            ),
                          ),
                        ),

                      ],
                    ),
                  ],
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).accentColor,
                  image: DecorationImage(

                    image: AssetImage('assets/images/menu_bg.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              ListTile(
                title: TextField(
                  decoration: InputDecoration(
                      border: InputBorder.none,
                      labelText: 'Speech',
                      hintText: 'Type your speech '
                  ),
                  keyboardType: TextInputType.multiline,
                  controller: speechController,
                  minLines: 5,//Normal textInputField will be displayed
                  maxLines: 30,// when user presses enter it will adapt to it
                ),
                subtitle: RaisedButton.icon(
                  icon: Icon(playing? Icons.pause: Icons.play_arrow),
                  label: Text("Continue"),
                  onPressed: () {
                    setDuration();

                  },
                ),
              ),

            ],
          ),
        ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: [

            IconButton(icon: Icon(Icons.add), onPressed: () {
              setState(() {_word_per_minute++; setDuration();});
            }),

            IconButton(icon: Icon(Icons.remove), onPressed: () {
              setState(() {_word_per_minute--; setDuration();});
            }),
            Text("speed: $_word_per_minute time: $speech_time "),


            Spacer(),
            IconButton(icon: Icon(Icons.menu), onPressed: () {_scaffoldKey.currentState.openEndDrawer();}),
            IconButton(icon: Icon(Icons.help), onPressed: () {}),
//            IconButton(icon: Icon(Icons.help), onPressed: () {}),
//            IconButton(icon: Icon(Icons.settings), onPressed: () {}),
          ],
        ),
      ),
      floatingActionButton:
      FloatingActionButton(child: Icon(playing? Icons.pause: Icons.play_arrow), onPressed: () {
        _toggleScrolling();

      }),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: Stack(
          children: <Widget>[
      Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white,
            Colors.black,
            Colors.white,
          ])
    ),
    ),

    Center(
    child:


    SingleChildScrollView(
      controller: _scrollController,
       child: Column(children: [
         Container(
           height: MediaQuery.of(context).size.height * 0.5,
         ),
         Container(
           constraints: BoxConstraints(minWidth: 400, maxWidth: 800),
           child: Text(
               speechController.text,
             maxLines: 1000,
             style: new TextStyle(
               fontSize: 30.0 * scaleSmallDevice(context) ,
             ),

           ),
         ),

       ],)
    ),)]
    ),
    );
  }
}
