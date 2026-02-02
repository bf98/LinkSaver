import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ChangeNotifierProvider(create: (_) => ThemeProvider(), child: MyApp()),
  );
}

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;

  ThemeProvider() {
    _loadTheme();
  }

  bool get isDarkMode => _isDarkMode;

  Future<void> _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: "linksaver",
      theme: themeProvider.isDarkMode ? ThemeData.dark() : ThemeData.light(),
	  debugShowCheckedModeBanner: false,
      home: AuthWrapper(),
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get user {
    return _auth.authStateChanges();
  }


  Future<String?> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String uid = result.user!.uid;

      await _firestore.collection('users').doc(uid).set({'email': email});

      return "Registrazione effettuata con successo";
    } on FirebaseAuthException catch (e) {
	  return "Errore Registrazione: ${e.code}, ${e.message}";
    } catch (e) {
      return "Errore generale durante la registrazione: $e";
    }
  }

  Future<String?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return "Log-In effettuato con successo";
    } on FirebaseAuthException catch (e) {
	  return "Errore Log-In: ${e.code}, ${e.message}";
    } catch (e) {
      return "Errore generale durante il login: $e";
    }
  }


  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print("Utente disconnesso con successo");
    } catch (e) {
      print("Errore durante la disconnessione: ${e}");
    }
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasData) {
          return HomeScreen();
        } else {
          return SignInScreen();
        }
      },
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true; 

  @override 
  void initState() {
	super.initState();
	_emailController.addListener(_updateButtonState);
	_passwordController.addListener(_updateButtonState);
  }

  void _updateButtonState() {
	setState(() {});
  }
  
  @override 
  void dispose() {
	_emailController.dispose();
	_passwordController.dispose();
	super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText; 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Accedi")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
		  mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    _togglePasswordVisibility(); 
                  },
                ),
              ),
              obscureText: _obscureText, 
            ),
			SizedBox(height: 25),
            ElevatedButton(
              onPressed: (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) ? () async {
                String? user = await _auth.signInWithEmailAndPassword(
                  _emailController.text,
                  _passwordController.text,
                );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(user ?? '.')),
                  );
				  print(user);
              } : null,
              child: const Text('Accedi'),
            ),
            ElevatedButton(
              onPressed: (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) ? () async {
                String? user = await _auth.registerWithEmailAndPassword(
                  _emailController.text,
                  _passwordController.text,
                );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(user ?? '.')),
                  );
				  print(user);
              } : null,
              child: const Text('Registrati'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  final List<Widget> _screens = [LinksScreen(), ProfileScreen()];

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Links'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profilo'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? avatarUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadAvatar();
  }

  Future<void> loadAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        avatarUrl = userDoc.get('avatar');
      });
    }
  }

  Future<String?> saveAvatarToInternalStorage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    if (image == null) {
      return null;
    }

    final directory = await getApplicationDocumentsDirectory();
    final Directory avatarsDir = Directory('${directory.path}/avatars');

    if (!await avatarsDir.exists()) {
      await avatarsDir.create(recursive: true);
    }

    final String filePath = '${avatarsDir.path}/${image.name}';

    final File localImage = File(filePath);
    await localImage.writeAsBytes(await image.readAsBytes());

    return filePath;
  }

  Future<void> updateUserAvatar(String imagePath) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'avatar': imagePath},
      );
    }
  }

  Future<void> changeAvatar() async {
    final String? imagePath = await saveAvatarToInternalStorage();
    if (imagePath != null) {
      await updateUserAvatar(imagePath);
      setState(() {
        avatarUrl = imagePath;
      });
      print("Avatar aggiornato con successo!");
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthService _auth = AuthService();
    final user = FirebaseAuth.instance.currentUser;
    final String email = user?.email ?? "Email non disponibile";

    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profilo"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: changeAvatar,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? FileImage(File(avatarUrl!))
                    : const AssetImage('avatars/default_avatar.jpg')
                          as ImageProvider,
              ),
            ),
			SizedBox(height: 25),
            Text(email),
			SizedBox(height: 25),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: changeAvatar,
              child: const Text("Cambia Avatar"),
            ),
			SizedBox(height: 10),
            ElevatedButton(
              onPressed: themeProvider.toggleTheme,
              child: const Text("Cambia Tema"),
            ),
          ],
        ),
      ),
    );
  }
}

class LinkItem {
  String title;
  String url;
  bool isFavorite;

  LinkItem({required this.title, required this.url, this.isFavorite = false});

  Map<String, dynamic> toMap() {
    return {'title': title, 'url': url, 'isFavorite': isFavorite};
  }
}

Future<void> addFav(String uid, LinkItem item) async {
  try {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);

    Map<String, dynamic> linkData = {
      'title': item.title,
      'url': item.url,
      'isFavorite': item.isFavorite,
    };

    if (item.isFavorite) {
      await userDocRef
          .collection('links')
          .doc(item.title)
          .set(linkData, SetOptions(merge: true));
      print("Link aggiunto ai preferiti");
    } else {
      await userDocRef.collection('links').doc(item.title).update({
        'isFavorite': false,
      });
      print("Link rimosso dai preferiti");
    }
  } catch (e) {
    print('Errore aggiunta link ai preferiti: $e');
  }
}

class LinksScreen extends StatefulWidget {
  @override
  _LinksScreenState createState() => _LinksScreenState();
}

class _LinksScreenState extends State<LinksScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _linkController = TextEditingController();
  String? filter;
  bool showFavoritesOnly = false;
  int linksCount = 0;
  List<LinkItem> links = [];

  @override
  void initState() {
    super.initState();
    _fetchLinks();
    _fetchLinksCount();
  }

  Future<int> getLinksCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      QuerySnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('links')
          .get();

      return userDoc.docs.length;
    }

    return 0;
  }

  Future<void> _fetchLinks() async {
    if (_auth.currentUser != null) {
      final uid = _auth.currentUser!.uid;

      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('links')
          .get();

      setState(() {
        links = snapshot.docs.map((doc) {
          return LinkItem(
            title: doc['title'],
            url: doc['url'],
            isFavorite: doc['isFavorite'] ?? false,
          );
        }).toList();
      });
    }
  }

  Future<void> _fetchLinksCount() async {
    if (_auth.currentUser != null) {
      int count = await getLinksCount();
      setState(() {
        linksCount = count;
      });
    }
  }

  Future<void> _addLink(String title) async {
    if (_auth.currentUser != null && _linkController.text.isNotEmpty) {
      final uid = _auth.currentUser!.uid;

      final newLink = {
        'title': title,
        'url': _linkController.text,
        'isFavorite': false,
      };

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('links')
          .doc(title)
          .set(newLink);

      _linkController.clear();
      _fetchLinks();
      _fetchLinksCount();
    }
  }

  Future<void> _removeLink(LinkItem item) async {
    try {
      String uid = _auth.currentUser!.uid;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('links')
          .doc(item.title)
          .delete();

      setState(() {
        links.remove(item);
      });

      print("Link rimosso");
      _fetchLinksCount();
    } catch (e) {
      print('Errore rimozione link: $e');
    }
  }

  void _showAddLinkDialog() {
    final TextEditingController _titleController = TextEditingController();
	_titleController.clear();
	_linkController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Aggiungi Link'),
          content: Column(
			mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(hintText: 'Inserisci un titolo'),
              ),
              TextField(
                controller: _linkController,
                decoration: InputDecoration(hintText: 'Inserisci un link'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _addLink(_titleController.text);
                Navigator.of(context).pop();
              },
              child: Text('Aggiungi'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Annulla'),
            ),
          ],
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Cerca'),
          content: TextField(
            onChanged: (value) {
              setState(() {
                filter = value;
              });
            },
            decoration: InputDecoration(hintText: 'Cerca per Titolo'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  filter = '';
                });
                Navigator.of(context).pop();
              },
              child: Text('Clear'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Chiudi'),
            ),
          ],
        );
      },
    );
  }

  void _toggleFavorite() {
    setState(() {
      showFavoritesOnly = !showFavoritesOnly;
    });
  }

  void _refreshLinks() {
    _fetchLinks();
  }

  @override
  Widget build(BuildContext context) {
    List<LinkItem> filteredLinks = filter == null || filter!.isEmpty
        ? links
        : links.where((link) => link.title.toLowerCase().contains(filter!.toLowerCase())).toList();

    if (showFavoritesOnly) {
      filteredLinks = filteredLinks.where((link) => link.isFavorite).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('I Tuoi Link'),
        actions: [
          Text('Tot: $linksCount'),
          IconButton(icon: Icon(Icons.search), onPressed: _showFilterDialog),
          IconButton(icon: Icon(showFavoritesOnly ? Icons.star : Icons.star_border), onPressed: _toggleFavorite),
        ],
      ),
      body: ListView.builder(
        itemCount: filteredLinks.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(filteredLinks[index].title),
            subtitle: Text(filteredLinks[index].url),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    filteredLinks[index].isFavorite
                        ? Icons.star
                        : Icons.star_border,
                    color: filteredLinks[index].isFavorite
                        ? Colors.yellow
                        : null,
                  ),
                  onPressed: () {
                    setState(() {
                      filteredLinks[index].isFavorite =
                          !filteredLinks[index].isFavorite;
                      String uid = _auth.currentUser!.uid;
                      addFav(uid, filteredLinks[index]);
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    _removeLink(filteredLinks[index]);
                  },
                ),
              ],
            ),
            onTap: () async {
              Clipboard.setData(
                ClipboardData(text: filteredLinks[index].url),
              ).then((_) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Link copiato')));
              });
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddLinkDialog();
        },
        tooltip: 'Aggiungi Link',
        child: Icon(Icons.add),
      ),
    );
  }
}
