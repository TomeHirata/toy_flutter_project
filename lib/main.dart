import 'dart:convert';
import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'First Flutter Application',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

enum UserType {
  chatGPT,
  user,
} 

class Message {
  UserType userType;
  String content;
  Message(this.userType, this.content);
}

var openaiKey = "YOUR KEY";

Future<String> fetchReply(String prompt) async {
  final response = await http
      .post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: { 
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openaiKey',
        },
        body: jsonEncode({
          'model': "gpt-3.5-turbo-0301",
          "messages": [{"role": "user", "content": prompt}]
        })
      );

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    // todo: make it a struct
    final data = jsonDecode(response.body);
    return data["choices"][0]["message"]["content"];
  } else {
    print(response.body);
    print(response.statusCode);
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load reply');
  }
}

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();
  var currentPrompt = "";
  var conversation = <Message>[];

  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }

  var favorites = <WordPair>[];

  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current);
    }
    notifyListeners();
  }

  void setPrompt(String prompt) {
    currentPrompt = prompt;
  }

  void initPrompt() {
    currentPrompt = "";
    notifyListeners();
  }

  void addMessage(Message message) {
    conversation.add(message);
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;  

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = GeneratorPage();
        break;
      case 1:
        page = FavoritesPage();
        break;
      case 2:
        page = ChatPage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }
    var theme = Theme.of(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  indicatorColor: theme.colorScheme.secondary,
                  unselectedLabelTextStyle: const TextStyle(color: Colors.white),
                  selectedLabelTextStyle: TextStyle(color: Colors.white, backgroundColor: theme.focusColor),
                  extended: constraints.maxWidth >= 600,
                  destinations: [
                    NavigationRailDestination(
                      icon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.favorite),
                      label: Text('Favorites'),
                    ),
                    NavigationRailDestination(
                      icon: FaIcon(FontAwesomeIcons.robot),
                      label: Text('ChatGPT'),
                    ),
                  ],
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (value) {
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                ),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.background,
                  child: page,
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Center(
      child: Column(
        children: [
          ListView(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('You have '
                    '${appState.favorites.length} favorites:'),
              ),
              for (var pair in appState.favorites)
                ListTile(
                  leading: Icon(Icons.favorite),
                  title: Text(pair.asLowerCase),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Center(
      child: Stack(
        children: [
          Container(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            margin: const EdgeInsets.only(bottom: 80), // todo: align with button height
            child: ListView(
              shrinkWrap: true,
              physics: ClampingScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                ),
                for (var message in appState.conversation)
                  Material(
                    child: ListTile(
                      tileColor: message.userType == UserType.chatGPT ? Color.fromARGB(255, 201, 201, 201) : Colors.white,
                      leading: message.userType == UserType.chatGPT ? (FaIcon(FontAwesomeIcons.robot)) : FaIcon(FontAwesomeIcons.user),
                      title: Text(message.content),
                    ),
                  )
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Send a message',
                      ),
                      onChanged: (text) {
                        appState.setPrompt(text);
                      },
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    appState.addMessage(Message(UserType.user, appState.currentPrompt));
          
                    final res = await fetchReply(appState.currentPrompt);
                    appState.addMessage(Message(UserType.chatGPT, res));
                    appState.initPrompt();
                  },
                  child: Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var pair = appState.current;

    IconData icon;
    if (appState.favorites.contains(pair)) {
      icon = Icons.favorite;
    } else {
      icon = Icons.favorite_border;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BigCard(currentPair: pair),
          SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  appState.toggleFavorite();
                },
                icon: Icon(icon),
                label: Text('Like'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  appState.getNext();
                },
                child: Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.currentPair,
  });

  final WordPair currentPair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          currentPair.asLowerCase,
          style: style,
          semanticsLabel: "${currentPair.first} ${currentPair.second}",
        ),
      ),
    );
  }
}