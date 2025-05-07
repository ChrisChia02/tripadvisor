import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
//import 'package:flutter_braintree/flutter_braintree.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'auth_services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripadvisor/mongodb.dart';
import 'database_helper.dart';
import 'mongodb.dart';
import 'package:intl/intl.dart';
import 'postgresql_service.dart';
import 'screens/trip_generator_screen.dart';

class Destination {
  final String name;
  final String description;
  final List<String> images;
  final List<PointOfInterest> hotels;
  final List<PointOfInterest> attractions;
  final List<PointOfInterest> restaurants;

  Destination({
    required this.name,
    required this.description,
    required this.images,
    required this.hotels,
    required this.attractions,
    required this.restaurants,
  });
}

class PointOfInterest {
  final String id;
  final String name;
  final String? category; // Make nullable
  final String? description; // Make nullable
  final double rating;
  final int reviewCount;
  final String? location; // Make nullable
  final String? imageUrl; // Make nullable
  final String thumbnail;
  final double lat;
  final double lng;

  PointOfInterest({
    required this.id,
    required this.name,
    this.category,
    this.description,
    required this.rating,
    required this.reviewCount,
    this.location,
    this.imageUrl,
    required this.thumbnail,
    required this.lat,
    required this.lng,
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  await MongoDatabase.connect();
  final authService = AuthService();
  await authService.initAuthListener(); // Start listening to auth changes

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: "/login",
      routes: {
        "/login": (context) => LoginPage(),
        "/locationPermission": (context) => LocationPermissionPage(),
        "/notificationPermission": (context) => NotificationPermissionPage(),
        "/register": (context) => RegisterPage(),
        "/forgotPassword": (context) => ForgotPasswordPage(),
        "/home": (context) => HomePage(),
      },
    ),
  );
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User logged in - go to HomePage
        if (snapshot.hasData) {
          return HomePage();
        }

        // User not logged in - go to LoginPage
        return LoginPage();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: LoginPage());
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black54,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      // 1. Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      final uid = userCredential.user?.uid;
      if (uid == null) throw Exception('No UID after login');

      // 2. Fetch complete user data
      final response = await http.get(
        Uri.parse('https://trip-advisor-woil.onrender.com/users/$uid'),
      );

      debugPrint(
        'Backend response: ${response.body}',
      ); // Verify this shows all fields

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);

        // 3. Store user data (using Firebase UID instead of simple_id)
        await Future.wait([
          const FlutterSecureStorage().write(key: 'uid', value: uid),
          if (userData['username'] != null)
            const FlutterSecureStorage().write(
              key: 'username',
              value: userData['username'],
            ),
          if (userData['gender'] != null)
            const FlutterSecureStorage().write(
              key: 'gender',
              value: userData['gender'],
            ),
          if (userData['phone'] != null)
            const FlutterSecureStorage().write(
              key: 'phone',
              value: userData['phone'],
            ),
        ]);

        Navigator.pushReplacementNamed(context, "/home");
      }
    } catch (e) {
      debugPrint('Login error: $e');
      // You might want to show an error message to the user
      showToast("Login failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 🔥 Google Sign-In Function
  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // User canceled sign-in

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        // ✅ Check if user already exists in Firestore
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection("User")
                .doc(user.uid)
                .get();

        if (!userDoc.exists) {
          // 🔥 If new user, create a document with email and auto-incremented user ID
          int userCount =
              (await FirebaseFirestore.instance.collection("User").get())
                  .docs
                  .length;
          String newUserID = "user${userCount + 1}";

          await FirebaseFirestore.instance
              .collection("User")
              .doc(newUserID)
              .set({
                "Email": user.email,
                "Password":
                    "GoogleSignIn", // No password stored, just for reference
                "UserID": newUserID,
              });
        }

        showToast("Google Sign-In successful!");
        Navigator.pushReplacementNamed(context, "/locationPermission");
      }
    } catch (e) {
      showToast("Google Sign-In failed: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              showToast("Continuing as Guest...");
              Navigator.pushReplacementNamed(context, "/locationPermission");
            },
            child: Text(
              "Skip",
              style: TextStyle(color: Colors.blue, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Login",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 30),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 15),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),

              GestureDetector(
                onTap: () {
                  Navigator.pushReplacementNamed(context, "/forgotPassword");
                },
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Forgot Password?",
                    style: TextStyle(color: Colors.blue, fontSize: 14),
                  ),
                ),
              ),
              SizedBox(height: 10),

              GestureDetector(
                onTap: () {
                  Navigator.pushReplacementNamed(context, "/register");
                },
                child: Text(
                  "Not having an account yet? Register here",
                  style: TextStyle(color: Colors.blue, fontSize: 14),
                ),
              ),
              SizedBox(height: 30),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5856D6),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed:
                    _isLoading
                        ? null
                        : () async {
                          setState(() => _isLoading = true);
                          try {
                            await _login();
                          } catch (e) {
                            debugPrint('Error: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Login failed: ${e.toString()}',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          "Login",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
              ),
              SizedBox(height: 20),

              Text("Or continue with"),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  await _signInWithGoogle();
                },
                child: Image.asset("assets/google_icon.png", width: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  String? _selectedGender;
  bool _isLoading = false;

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black54,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> _register() async {
    if (_usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _selectedGender == null ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      showToast("Please fill in all fields.");
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      showToast("Passwords do not match!");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String email = _emailController.text.trim();
      String password = _passwordController.text.trim();
      String username = _usernameController.text.trim();
      String phone = _phoneController.text.trim();
      String gender = _selectedGender ?? "Other"; // Default if not selected

      // **STEP 1: Create Firebase Auth user**
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      String firebaseUserId =
          userCredential.user!.uid; // Firebase-generated unique ID

      // **STEP 2: Get next user document number for Firestore**
      QuerySnapshot userSnapshot =
          await FirebaseFirestore.instance.collection("User").get();
      int userCount = userSnapshot.docs.length + 1;
      String firestoreUserId = "user$userCount"; // e.g., user2, user3

      // **STEP 3: Store email & password in Firestore**
      await FirebaseFirestore.instance
          .collection("User")
          .doc(firestoreUserId)
          .set({
            "userID": firestoreUserId,
            "Email": email,
            "Password": password, // 🔥 Avoid storing plaintext passwords
          });

      // **STEP 4: Store user info in MySQL via Node.js**
      final response = await http.post(
        Uri.parse(
          "https://trip-advisor-woil.onrender.com/register",
        ), // Change to your backend URL
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "firebaseUserId": firebaseUserId, // Store Firebase UID in Database
          "email": email,
          "username": username,
          "gender": gender,
          "phone": phone,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        showToast("Registration successful!");
        Navigator.pushReplacementNamed(context, "/login");
      } else {
        showToast("Database error: ${response.body}");
      }
    } catch (e) {
      showToast("Error: ${e.toString()}");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Registration"),
        centerTitle: true,
        backgroundColor: Color(0xFF628EFF),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, "/login");
          },
        ),
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Register",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 30),

                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: "Username",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 15),

                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 15),

                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: "Phone Number",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 15),

                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "Gender",
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedGender,
                  items:
                      ["Male", "Female", "Other"].map((String gender) {
                        return DropdownMenuItem<String>(
                          value: gender,
                          child: Text(gender),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedGender = newValue;
                    });
                  },
                ),
                SizedBox(height: 15),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 15),

                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),

                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacementNamed(context, "/login");
                  },
                  child: Text(
                    "Already have an account? Login here",
                    style: TextStyle(color: Colors.blue, fontSize: 14),
                  ),
                ),
                SizedBox(height: 30),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF5856D6),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  onPressed: _isLoading ? null : _register,
                  child:
                      _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                            "Register",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black54,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> _resetPassword() async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      showToast("Please enter your email");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Check if the email exists in Firestore
      QuerySnapshot userSnapshot =
          await FirebaseFirestore.instance
              .collection("User")
              .where("Email", isEqualTo: email)
              .get();

      if (userSnapshot.docs.isEmpty) {
        showToast("User not found");
      } else {
        // Step 2: If user exists, send reset password email
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        showToast("Reset link sent to your email");
      }
    } catch (e) {
      showToast("Error: ${e.toString()}");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Forgot Password"),
        centerTitle: true,
        backgroundColor: Color(0xFF628EFF),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, "/login"); // ✅ FIXED
          },
        ),
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Enter your email to reset password",
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5856D6),
                  minimumSize: Size(double.infinity, 50),
                ),
                onPressed: _isLoading ? null : _resetPassword,
                child:
                    _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                          "Reset Password",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LocationPermissionPage extends StatelessWidget {
  Future<void> _requestLocationPermission(BuildContext context) async {
    PermissionStatus status = await Permission.location.request();

    if (status.isGranted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => NotificationPermissionPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Location permission is required for better recommendations.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Enable Location"),
        centerTitle: true,
        backgroundColor: Color(0xFF628EFF),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, size: 100, color: Colors.blueAccent),
              SizedBox(height: 20),
              Text(
                "Discover traveler-recommended spots near you, wherever you are.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5856D6),
                  minimumSize: Size(200, 50),
                ),
                onPressed: () => _requestLocationPermission(context),
                child: Text(
                  "Enable Location",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              SizedBox(height: 15),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacementNamed(
                    context,
                    "/notificationPermission",
                  );
                },
                child: Text(
                  "Not Now",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationPermissionPage extends StatelessWidget {
  Future<void> _requestNotificationPermission(BuildContext context) async {
    PermissionStatus status = await Permission.notification.request();

    if (status.isGranted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Notification permission is required for trip updates.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Enable Notifications"),
        centerTitle: true,
        backgroundColor: Color(0xFF628EFF),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_active,
                size: 100,
                color: Colors.orangeAccent,
              ),
              SizedBox(height: 20),
              Text(
                "Get updates on the latest price drops and deals for your trip!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5856D6),
                  minimumSize: Size(200, 50),
                ),
                onPressed: () => _requestNotificationPermission(context),
                child: Text(
                  "Enable Notifications",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              SizedBox(height: 15),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacementNamed(context, "/home");
                },
                child: Text(
                  "Not Now",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen());
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isSearching = false;
  TextEditingController _searchController = TextEditingController();
  List<int> _navigationHistory = [];
  String? userId; // Store user ID dynamically
  bool _isSearchLoading = false;
  Destination? _searchResult;
  TabController? _tabController;
  List<Destination> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _fetchUserId();
    // Initialize tab controller for destination results
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _fetchUserId({bool isGuest = false}) async {
    try {
      if (isGuest) {
        setState(() {
          userId = "guest_${DateTime.now().millisecondsSinceEpoch}";
          print("🛠️ Guest session started: $userId");
        });
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Fetch the user's _id from your backend
          final response = await http.get(
            Uri.parse(
              "https://trip-advisor-woil.onrender.com/users/${user.uid}",
            ),
            headers: {"Content-Type": "application/json"},
          );

          if (response.statusCode == 200) {
            final userData = jsonDecode(response.body);
            setState(() {
              userId = user.uid; // Store Firebase UID locally
              print("✅ User logged in: $userId");
            });
          }
        } else {
          throw Exception("⚠️ No authenticated user");
        }
      }
    } catch (e) {
      print("❗ Error fetching user: $e");

      Future.microtask(() {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Continue as guest")));
        _fetchUserId(isGuest: true); // Fallback to guest
      });
    }

    // Timeout safeguard
    Future.delayed(Duration(seconds: 5), () {
      if (mounted && userId == null) {
        print("⏳ Timeout - Falling back to guest mode");
        Future.microtask(() {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Starting guest mode")));
          _fetchUserId(isGuest: true);
        });
      }
    });
  }

  final List<String> _pageTitles = ["Home", "Plan", "Trip", "Account"];

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      _navigationHistory.add(
        _selectedIndex,
      ); // Save current page before switching
      setState(() {
        _selectedIndex = index;
        _isSearching = false; // Exit search mode
        _searchController.clear();
      });
    }
  }

  // Add this method to handle search
  void _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearchLoading = true;
    });

    try {
      final result = await DestinationService().getDestinationInfo(query);
      setState(() {
        _searchResult = result;
        _isSearchLoading = false;

        // Add to recent searches if it's a valid result
        if (result != null) {
          // Check if this destination is already in recent searches
          // Compare by whatever unique identifier or property combination makes sense
          final existingIndex = _recentSearches.indexWhere(
            (place) => place == result || place.toString() == result.toString(),
            // If Destination has a name property: place.name == result.name
          );

          // If it exists, remove it (will be added to the front)
          if (existingIndex != -1) {
            _recentSearches.removeAt(existingIndex);
          }

          // Add to the beginning of the list
          _recentSearches.insert(0, result);

          // Keep only the 5 most recent searches
          if (_recentSearches.length > 5) {
            _recentSearches = _recentSearches.sublist(0, 5);
          }
        }
      });
    } catch (e) {
      setState(() {
        _isSearchLoading = false;
      });
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching for destination: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prevents null error by showing a loading spinner before `userId` is available
    if (userId == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ), // Show loading indicator
      );
    }

    // Pages with dynamic userId passed to ProfilePage
    final List<Widget> _pages = [
      _isSearching && _searchResult != null
          ? _buildSearchResultsContent()
          : HomeContent(
            recentSearches: _recentSearches,
          ), // Pass recent searches here
      PlanPage(),
      SampleTripsPage(),
      ProfilePage(userId: userId!),
    ];

    return WillPopScope(
      onWillPop: () async {
        if (_isSearching) {
          setState(() {
            _isSearching = false;
            _searchController.clear();
          });
          return false; // Prevent actual back navigation
        } else if (_navigationHistory.isNotEmpty) {
          setState(() {
            _selectedIndex =
                _navigationHistory.removeLast(); // Go back to last visited page
          });
          return false;
        }
        return true; // Exit app if no history left
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Color(0xFF628EFF),
          toolbarHeight: 80,
          centerTitle: true,
          title:
              _isSearching
                  ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search destinations...",
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (query) => _performSearch(query),
                  )
                  : Text(
                    _pageTitles[_selectedIndex],
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
          leading:
              _selectedIndex == 0 && !_isSearching
                  ? null
                  : _isSearching
                  ? null
                  : IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: () {
                      if (_isSearching) {
                        setState(() {
                          _isSearching = false;
                          _searchController.clear();
                        });
                      } else if (_navigationHistory.isNotEmpty) {
                        setState(() {
                          _selectedIndex = _navigationHistory.removeLast();
                        });
                      }
                    },
                  ),
          actions: [
            if (_selectedIndex == 0) // Search only on Home
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) _searchController.clear();
                  });
                },
              ),
          ],
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Color(0xFF628EFF),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 14,
            unselectedFontSize: 12,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.white,
            currentIndex: _selectedIndex,
            elevation: 0,
            onTap: _onItemTapped,
            items: [
              _buildNavItem(Icons.home, "Home", 0),
              _buildNavItem(Icons.calendar_today, "Plan", 1),
              _buildNavItem(Icons.flight_takeoff, "Trip", 2),
              _buildNavItem(Icons.person, "Account", 3),
            ],
          ),
        ),
      ),
    );
  }

  // Add this new method to build search results
  Widget _buildSearchResultsContent() {
    return Column(
      children: [
        // Show loading indicator if still searching
        if (_isSearchLoading)
          Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Destination Header with Images
                  Container(
                    height: 300,
                    child: PageView.builder(
                      itemCount:
                          _searchResult!.images.length > 0
                              ? _searchResult!.images.length
                              : 1,
                      itemBuilder: (context, index) {
                        if (_searchResult!.images.isEmpty) {
                          return Container(
                            color: Colors.grey.shade300,
                            child: Center(child: Text('No images available')),
                          );
                        }

                        return Image.network(
                          _searchResult!.images[index],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey.shade300,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                          : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade300,
                              child: Center(child: Text('Image not available')),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Title and Description
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Destination Title
                        Text(
                          _searchResult!.name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),

                        // Description
                        Text(
                          _searchResult!.description,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),

                        SizedBox(height: 24),

                        // Category cards that navigate to dedicated pages
                        _buildCategoryCard(
                          "Attractions",
                          Icons.attractions,
                          "Discover amazing things to do",
                          () => _navigateToCategoryPage("attractions"),
                        ),

                        _buildCategoryCard(
                          "Hotels",
                          Icons.hotel,
                          "Find your perfect stay",
                          () => _navigateToCategoryPage("hotels"),
                        ),

                        _buildCategoryCard(
                          "Restaurants",
                          Icons.restaurant,
                          "Explore local dining options",
                          () => _navigateToCategoryPage("restaurants"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryCard(
    String title,
    IconData icon,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF628EFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 28, color: Color(0xFF628EFF)),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToCategoryPage(String categoryType) {
    // This is where we'll handle navigation to the specific category pages
    if (_searchResult == null) return;

    if (categoryType == "hotels") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => HotelsPage(
                destination: _searchResult!.name,
                hotels: _searchResult!.hotels,
              ),
        ),
      );
    } else if (categoryType == "restaurants") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => RestaurantsPage(
                destination: _searchResult!.name,
                restaurants: _searchResult!.restaurants,
              ),
        ),
      );
    } else if (categoryType == "attractions") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => AttractionsPage(
                destination: _searchResult!.name,
                attractions: _searchResult!.attractions,
              ),
        ),
      );
    }
  }

  // Helper method to build tab content
  Widget _buildTabContent(List<PointOfInterest> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('No items found'),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading:
                item.thumbnail.isNotEmpty
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.thumbnail,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade300,
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    )
                    : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade300,
                      child: Icon(Icons.image, color: Colors.grey),
                    ),
            title: Text(item.name),
            subtitle: Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber),
                Text(
                  ' ${item.rating > 0 ? item.rating.toStringAsFixed(1) : "N/A"}',
                ),
                SizedBox(width: 8),
                Text(
                  '(${item.reviewCount > 0 ? item.reviewCount : "No"} reviews)',
                ),
              ],
            ),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Navigate to detail page for this POI
              _navigateToPoiDetail(item);
            },
          ),
        );
      },
    );
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF628EFF),
        ),
      ),
    );
  }

  // Helper method to build lists of points of interest
  Widget _buildPoiListView(List<PointOfInterest> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('No items found'),
        ),
      );
    }

    return ListView.builder(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading:
                item.thumbnail.isNotEmpty
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.thumbnail,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade300,
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    )
                    : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade300,
                      child: Icon(Icons.image, color: Colors.grey),
                    ),
            title: Text(item.name),
            subtitle: Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber),
                Text(
                  ' ${item.rating > 0 ? item.rating.toStringAsFixed(1) : "N/A"}',
                ),
                SizedBox(width: 8),
                Text(
                  '(${item.reviewCount > 0 ? item.reviewCount : "No"} reviews)',
                ),
              ],
            ),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Navigate to detail page for this POI
              _navigateToPoiDetail(item);
            },
          ),
        );
      },
    );
  }

  void _navigateToPoiDetail(PointOfInterest poi) {
    // Simply show a modal or dialog with basic POI information
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // POI name header
                Text(
                  poi.name,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),

                // POI image
                if (poi.thumbnail.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      poi.thumbnail,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) => Container(
                            height: 180,
                            color: Colors.grey.shade300,
                            child: Center(
                              child: Icon(Icons.image_not_supported),
                            ),
                          ),
                    ),
                  ),
                SizedBox(height: 16),

                // Rating info
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      '${poi.rating > 0 ? poi.rating.toStringAsFixed(1) : "N/A"}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Text('(${poi.reviewCount} reviews)'),
                  ],
                ),

                // Removed the location section that was causing the error
                Spacer(),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.favorite_border),
                      label: Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF628EFF),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        // Simple snackbar feedback instead of actual implementation
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Saved to favorites')),
                        );
                      },
                    ),
                    ElevatedButton.icon(
                      icon: Icon(Icons.add),
                      label: Text('Add to Trip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF628EFF),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        // Simple snackbar feedback
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added to trip')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
    IconData icon,
    String label,
    int index,
  ) {
    bool isSelected = _selectedIndex == index;

    return BottomNavigationBarItem(
      icon: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.black : Colors.white),
            Text(
              label,
              style: TextStyle(color: isSelected ? Colors.black : Colors.white),
            ),
          ],
        ),
      ),
      label: "",
    );
  }
}

class HotelsPage extends StatefulWidget {
  final String destination;
  final List<PointOfInterest> hotels;

  HotelsPage({required this.destination, required this.hotels});

  @override
  _HotelsPageState createState() => _HotelsPageState();
}

class _HotelsPageState extends State<HotelsPage> {
  DateTime _checkInDate = DateTime.now().add(Duration(days: 1));
  DateTime _checkOutDate = DateTime.now().add(Duration(days: 3));
  int _adults = 2;
  int _children = 0;
  int _rooms = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF628EFF),
        title: Text("Hotels in ${widget.destination}"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Booking filters
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Find your perfect stay",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),

                // Date selection
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Check-in",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "${_checkInDate.day}/${_checkInDate.month}/${_checkInDate.year}",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context, false),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Check-out",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "${_checkOutDate.day}/${_checkOutDate.month}/${_checkOutDate.year}",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Room and Guest selection
                Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Guests and Rooms",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "$_adults Adults, $_children Children, $_rooms Rooms",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          GestureDetector(
                            onTap: _showGuestRoomPicker,
                            child: Icon(
                              Icons.edit,
                              color: Color(0xFF628EFF),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Hotel List
          Expanded(
            child:
                widget.hotels.isEmpty
                    ? Center(child: Text("No hotels found in this destination"))
                    : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: widget.hotels.length,
                      itemBuilder: (context, index) {
                        final hotel = widget.hotels[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Hotel Image
                              ClipRRect(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child:
                                    hotel.thumbnail.isNotEmpty
                                        ? Image.network(
                                          hotel.thumbnail,
                                          height: 150,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Container(
                                              height: 150,
                                              color: Colors.grey.shade300,
                                              child: Icon(
                                                Icons.image_not_supported,
                                              ),
                                            );
                                          },
                                        )
                                        : Container(
                                          height: 150,
                                          color: Colors.grey.shade300,
                                          child: Icon(Icons.image),
                                        ),
                              ),

                              // Hotel Details
                              Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hotel.name,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 8),

                                    // Rating
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '${hotel.rating > 0 ? hotel.rating.toStringAsFixed(1) : "N/A"}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text('(${hotel.reviewCount} reviews)'),

                                        Spacer(),
                                        SaveButton(
                                          placeId: hotel.id,
                                          placeName: hotel.name,
                                          placeType: 'hotel',
                                          destination: widget.destination,
                                          imageUrl: hotel.thumbnail,
                                          rating: hotel.rating,
                                          reviewCount: hotel.reviewCount,
                                          lat: hotel.lat, // Pass latitude
                                          lng: hotel.lng, // Pass longitude
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),

                                    // Price range (dummy data)
                                    Row(
                                      children: [
                                        Text(
                                          "\RM${99 + index * 20} - \RM${199 + index * 30}",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF628EFF),
                                          ),
                                        ),
                                        Text(" / night"),
                                      ],
                                    ),
                                    SizedBox(height: 16),

                                    // View Details button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed:
                                            () => _showHotelDetails(hotel),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF628EFF),
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: Text("View Details"),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isCheckIn) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isCheckIn ? _checkInDate : _checkOutDate,
      firstDate: isCheckIn ? DateTime.now() : _checkInDate,
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Color(0xFF628EFF)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInDate = picked;
          // Make sure check-out is after check-in
          if (_checkOutDate.isBefore(_checkInDate) ||
              _checkOutDate.isAtSameMomentAs(_checkInDate)) {
            _checkOutDate = _checkInDate.add(Duration(days: 1));
          }
        } else {
          _checkOutDate = picked;
        }
      });
    }
  }

  void _showGuestRoomPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Guests & Rooms",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 24),

                  // Adults
                  _buildCounterRow(
                    "Adults",
                    _adults,
                    (value) {
                      setModalState(() {
                        _adults = value;
                      });
                      setState(() {
                        _adults = value;
                      });
                    },
                    1,
                    10,
                  ),
                  Divider(height: 32),

                  // Children
                  _buildCounterRow(
                    "Children",
                    _children,
                    (value) {
                      setModalState(() {
                        _children = value;
                      });
                      setState(() {
                        _children = value;
                      });
                    },
                    0,
                    6,
                  ),
                  Divider(height: 32),

                  // Rooms
                  _buildCounterRow(
                    "Rooms",
                    _rooms,
                    (value) {
                      setModalState(() {
                        _rooms = value;
                      });
                      setState(() {
                        _rooms = value;
                      });
                    },
                    1,
                    5,
                  ),
                  SizedBox(height: 24),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF628EFF),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text("Apply"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCounterRow(
    String label,
    int value,
    Function(int) onChanged,
    int min,
    int max,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        Row(
          children: [
            IconButton(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: Icon(Icons.remove_circle_outline),
              color: value > min ? Color(0xFF628EFF) : Colors.grey,
            ),
            SizedBox(
              width: 40,
              child: Text(
                "$value",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: Icon(Icons.add_circle_outline),
              color: value < max ? Color(0xFF628EFF) : Colors.grey,
            ),
          ],
        ),
      ],
    );
  }

  void _showHotelDetails(PointOfInterest hotel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: EdgeInsets.only(top: 20),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.all(16),
                        children: [
                          // Hotel name header
                          Text(
                            hotel.name,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),

                          // Hotel image
                          if (hotel.thumbnail.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                hotel.thumbnail,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) => Container(
                                      height: 200,
                                      color: Colors.grey.shade300,
                                      child: Center(
                                        child: Icon(Icons.image_not_supported),
                                      ),
                                    ),
                              ),
                            ),
                          SizedBox(height: 16),

                          // Rating info
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber),
                              SizedBox(width: 4),
                              Text(
                                '${hotel.rating > 0 ? hotel.rating.toStringAsFixed(1) : "N/A"}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 8),
                              Text('(${hotel.reviewCount} reviews)'),
                            ],
                          ),
                          SizedBox(height: 16),

                          // Price and booking details
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Booking Summary",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 12),
                                _buildBookingDetail(
                                  "Check-in",
                                  "${_checkInDate.day}/${_checkInDate.month}/${_checkInDate.year}",
                                ),
                                _buildBookingDetail(
                                  "Check-out",
                                  "${_checkOutDate.day}/${_checkOutDate.month}/${_checkOutDate.year}",
                                ),
                                _buildBookingDetail(
                                  "Guests",
                                  "$_adults Adults, $_children Children",
                                ),
                                _buildBookingDetail("Rooms", "$_rooms"),
                                Divider(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Total Price:",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "\$${(99 + hotel.reviewCount % 100) * _calculateNights() * _rooms}",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF628EFF),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 24),

                          // Book now button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  () => _startPayment(
                                    context,
                                    placeName: hotel.name,
                                    placeLat: hotel.lat,
                                    placeLng: hotel.lng,
                                  ), // Call payment function
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF628EFF),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                "Book Now",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Future<void> _startPayment(
    BuildContext context, {
    required String placeName,
    required double placeLat,
    required double placeLng,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    // Case 1: Guest or not logged in
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to make payments')),
      );
      return;
    }

    final firebaseUid = user.uid;
    final planId =
        'your_plan_id_here'; // Replace this with your actual plan ID logic

    try {
      debugPrint('Initiating payment for Firebase UID: $firebaseUid');

      final response = await http.post(
        Uri.parse('https://trip-advisor-woil.onrender.com/pay'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': firebaseUid,
          'plan_id': null,
          'amount': 198.00,
          'plan_name': 'Premium Plan',
          'place_name': placeName,
          'place_lat': placeLat,
          'place_lng': placeLng,
        }),
      );

      if (response.statusCode == 200) {
        final paymentData = jsonDecode(response.body);
        final approvalUrl = paymentData['approval_url'];

        debugPrint('Payment initiated. Redirecting to: $approvalUrl');

        if (await canLaunchUrl(Uri.parse(approvalUrl))) {
          await launchUrl(
            Uri.parse(approvalUrl),
            mode: LaunchMode.externalApplication,
            webOnlyWindowName: '_blank',
          );
        }
      } else {
        throw Exception('Payment failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Payment error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${e.toString()}')),
      );
    }
  }

  Widget _buildBookingDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  int _calculateNights() {
    return _checkOutDate.difference(_checkInDate).inDays;
  }

  void _bookHotel(PointOfInterest hotel) {
    // Here you would handle the booking process
    // For now, just show a confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Booking confirmed at ${hotel.name}!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class BookingSuccessScreen extends StatefulWidget {
  final String userId;
  const BookingSuccessScreen({super.key, required this.userId});

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> {
  String? placeName;
  DateTime? bookedAt;

  @override
  void initState() {
    super.initState();
    _fetchBookingAndAddToCalendar();
  }

  Future<void> _fetchBookingAndAddToCalendar() async {
    try {
      final res = await http.get(
        Uri.parse(
          "https://trip-advisor-woil.onrender.com/latest-booking/${widget.userId}",
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        placeName = data["place_name"] ?? "Hotel Booking";
        bookedAt = DateTime.parse(data["booked_at"]);
      } else {
        debugPrint("Failed to get booking: ${res.body}");
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Booking Success")),
      body: Center(
        child:
            placeName == null
                ? const CircularProgressIndicator()
                : Text("🎉 Booking at $placeName added to calendar!"),
      ),
    );
  }
}

class RestaurantsPage extends StatefulWidget {
  final String destination;
  final List<PointOfInterest> restaurants;

  RestaurantsPage({required this.destination, required this.restaurants});

  @override
  _RestaurantsPageState createState() => _RestaurantsPageState();
}

class _RestaurantsPageState extends State<RestaurantsPage> {
  String _selectedCuisine = 'All';
  List<String> _cuisineTypes = [
    'All',
    'Italian',
    'Asian',
    'American',
    'Mexican',
    'Seafood',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF628EFF),
        title: Text("Restaurants in ${widget.destination}"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Cuisine filter
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Find your perfect meal",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),

                // Cuisine selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        _cuisineTypes.map((cuisine) {
                          bool isSelected = _selectedCuisine == cuisine;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCuisine = cuisine;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? Color(0xFF628EFF)
                                          : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? Color(0xFF628EFF)
                                            : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  cuisine,
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.black,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Restaurant List
          Expanded(
            child:
                widget.restaurants.isEmpty
                    ? Center(
                      child: Text("No restaurants found in this destination"),
                    )
                    : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: widget.restaurants.length,
                      itemBuilder: (context, index) {
                        final restaurant = widget.restaurants[index];
                        // Dummy cuisine type data (would come from your API in a real app)
                        final cuisineType =
                            _cuisineTypes[index % (_cuisineTypes.length - 1) +
                                1];

                        // Filter by cuisine if not "All"
                        if (_selectedCuisine != 'All' &&
                            cuisineType != _selectedCuisine) {
                          return SizedBox.shrink();
                        }

                        return Card(
                          margin: EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Restaurant Image
                              ClipRRect(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child:
                                    restaurant.thumbnail.isNotEmpty
                                        ? Image.network(
                                          restaurant.thumbnail,
                                          height: 150,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Container(
                                              height: 150,
                                              color: Colors.grey.shade300,
                                              child: Icon(
                                                Icons.image_not_supported,
                                              ),
                                            );
                                          },
                                        )
                                        : Container(
                                          height: 150,
                                          color: Colors.grey.shade300,
                                          child: Icon(Icons.image),
                                        ),
                              ),

                              // Restaurant Details
                              Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            restaurant.name,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Color(
                                              0xFF628EFF,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            cuisineType,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF628EFF),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),

                                    // Rating
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '${restaurant.rating > 0 ? restaurant.rating.toStringAsFixed(1) : "N/A"}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '(${restaurant.reviewCount} reviews)',
                                        ),
                                        Spacer(),
                                        // Price level indicator (dummy data)
                                        Text(
                                          '\$' * ((index % 3) + 1),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),

                                    // Hours (dummy data)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          index % 2 == 0
                                              ? "Open now · Closes at 10PM"
                                              : "Opens tomorrow at 11AM",
                                          style: TextStyle(
                                            color:
                                                index % 2 == 0
                                                    ? Colors.green
                                                    : Colors.red,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Spacer(),

                                        SaveButton(
                                          placeId: restaurant.id,
                                          placeName: restaurant.name,
                                          placeType: 'restaurant',
                                          destination: widget.destination,
                                          imageUrl: restaurant.thumbnail,
                                          rating: restaurant.rating,
                                          reviewCount: restaurant.reviewCount,
                                          lat: restaurant.lat, // Pass latitude
                                          lng: restaurant.lng, // Pass longitude
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),

                                    // Reservation button
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed:
                                                () => _viewRestaurantMenu(
                                                  restaurant,
                                                ),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                color: Color(0xFF628EFF),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text("View Menu"),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed:
                                                () => _bookReservation(
                                                  restaurant,
                                                ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Color(
                                                0xFF628EFF,
                                              ),
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text("Book Table"),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  void _viewRestaurantMenu(PointOfInterest restaurant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${restaurant.name} Menu",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          _buildMenuSection("Starters"),
                          _buildMenuSection("Main Courses"),
                          _buildMenuSection("Desserts"),
                          _buildMenuSection("Drinks"),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildMenuSection(String title) {
    // Generate dummy menu items
    List<Map<String, dynamic>> items = List.generate(
      4,
      (index) => {
        "name": "$title Item ${index + 1}",
        "description":
            "Delicious ${title.toLowerCase()} with fresh ingredients and special sauce.",
        "price": (9.99 + (index * 2) + (title == "Main Courses" ? 10 : 0))
            .toStringAsFixed(2),
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF628EFF),
          ),
        ),
        SizedBox(height: 8),
        ...items.map((item) => _buildMenuItem(item)).toList(),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item["name"],
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  item["description"],
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(
            "\$${item["price"]}",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _bookReservation(PointOfInterest restaurant) {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              DateTime selectedDate = DateTime.now();
              String selectedTime = "7:00 PM";
              int partySize = 2;

              return AlertDialog(
                title: Text("Reserve a Table"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),

                    // Date picker
                    Text("Date", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Time picker
                    Text("Time", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 18),
                          SizedBox(width: 8),
                          Text(selectedTime),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Party size
                    Text(
                      "Party Size",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people, size: 18),
                          SizedBox(width: 8),
                          Text("$partySize people"),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Reservation at ${restaurant.name} confirmed!',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF628EFF),
                      foregroundColor: Colors.white,
                    ),
                    child: Text("Book"),
                  ),
                ],
              );
            },
          ),
    );
  }
}

class AttractionsPage extends StatefulWidget {
  final String destination;
  final List<PointOfInterest> attractions;

  AttractionsPage({required this.destination, required this.attractions});

  @override
  _AttractionsPageState createState() => _AttractionsPageState();
}

class _AttractionsPageState extends State<AttractionsPage> {
  String _selectedCategory = 'All';
  List<String> _categories = [
    'All',
    'Museums',
    'Parks',
    'Historic Sites',
    'Entertainment',
    'Shopping',
  ];
  bool _isLoading = false;
  List<PointOfInterest> _enhancedAttractions = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _enhancedAttractions = [...widget.attractions];

    _enhanceAttractionsWithDetails();
  }

  Future<void> _enhanceAttractionsWithDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Start with the attractions passed from the parent widget
      List<PointOfInterest> enhancedList = [];

      // Process each attraction to enhance it with categories and descriptions
      for (final attraction in widget.attractions) {
        // Determine category based on available information
        String category = _determineCategory(attraction);

        // Enhance with Wikipedia data if needed
        PointOfInterest enhancedAttraction = attraction;
        if (attraction.description == null || attraction.description!.isEmpty) {
          enhancedAttraction = await _enrichWithWikipediaData(attraction);
        }

        // Convert thumbnail to full image URL if needed
        String? imageUrl = enhancedAttraction.imageUrl;
        String thumbnail = enhancedAttraction.thumbnail;

        if (imageUrl == null && thumbnail.isNotEmpty) {
          // Replace maxwidth=100 with maxwidth=400 for better quality
          imageUrl = thumbnail.replaceAll('maxwidth=100', 'maxwidth=400');
        }

        // Add enhanced attraction to our list
        enhancedList.add(
          PointOfInterest(
            id: enhancedAttraction.id,
            name: enhancedAttraction.name,
            category: category,
            description: enhancedAttraction.description,
            rating: enhancedAttraction.rating,
            reviewCount: enhancedAttraction.reviewCount,
            location: enhancedAttraction.location ?? widget.destination,
            imageUrl: imageUrl,
            thumbnail: thumbnail, // Include the required thumbnail parameter
            lat: enhancedAttraction.lat,
            lng: enhancedAttraction.lng,
          ),
        );
      }

      setState(() {
        _enhancedAttractions = enhancedList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load attraction details: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  String _determineCategory(PointOfInterest attraction) {
    // Try to determine category based on name and any other available info
    String name = attraction.name.toLowerCase();

    if (name.contains('museum') ||
        name.contains('gallery') ||
        name.contains('art')) {
      return 'Museums';
    } else if (name.contains('park') ||
        name.contains('garden') ||
        name.contains('nature')) {
      return 'Parks';
    } else if (name.contains('castle') ||
        name.contains('monument') ||
        name.contains('historic') ||
        name.contains('temple') ||
        name.contains('ruins') ||
        name.contains('palace') ||
        name.contains('ancient') ||
        name.contains('heritage')) {
      return 'Historic Sites';
    } else if (name.contains('theater') ||
        name.contains('cinema') ||
        name.contains('entertainment') ||
        name.contains('amusement') ||
        name.contains('fun') ||
        name.contains('adventure')) {
      return 'Entertainment';
    } else if (name.contains('mall') ||
        name.contains('shop') ||
        name.contains('market') ||
        name.contains('store')) {
      return 'Shopping';
    }

    // Default category based on random assignment if we can't determine
    // In a real app, you might want to fetch this from an API or use more sophisticated logic
    List<String> defaultCategories = [
      'Museums',
      'Historic Sites',
      'Entertainment',
    ];
    return defaultCategories[Random().nextInt(defaultCategories.length)];
  }

  Future<PointOfInterest> _enrichWithWikipediaData(
    PointOfInterest attraction,
  ) async {
    // We'll use your existing approach for Wikipedia data
    try {
      final String wikiUrl =
          'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(attraction.name)}';
      final response = await http.get(Uri.parse(wikiUrl));

      if (response.statusCode == 200) {
        final wikiData = json.decode(response.body);

        // Update attraction with Wikipedia description if available
        String? description = attraction.description;
        if (wikiData['extract'] != null) {
          description = wikiData['extract'];
        }

        // Update attraction with Wikipedia image if available
        String? imageUrl = attraction.imageUrl;
        if (wikiData['thumbnail']?['source'] != null &&
            (attraction.imageUrl == null || attraction.imageUrl!.isEmpty)) {
          imageUrl = wikiData['thumbnail']['source'];
        }

        // Return enhanced attraction
        return PointOfInterest(
          id: attraction.id,
          name: attraction.name,
          category: attraction.category,
          description: description,
          rating: attraction.rating,
          reviewCount: attraction.reviewCount,
          location: attraction.location,
          imageUrl: imageUrl,
          thumbnail:
              attraction.thumbnail, // Include the required thumbnail parameter
          lat: attraction.lat,
          lng: attraction.lng,
        );
      }
    } catch (e) {
      print('Failed to fetch Wikipedia data for ${attraction.name}: $e');
    }

    // Return the original attraction if enrichment fails
    return attraction;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF628EFF),
        title: Text("Attractions in ${widget.destination}"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Category filter
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Discover amazing attractions",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                // Category selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        _categories.map((category) {
                          bool isSelected = _selectedCategory == category;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = category;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? Color(0xFF628EFF)
                                          : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Attractions list
          Expanded(
            child:
                _isLoading
                    ? _buildLoadingView()
                    : _errorMessage != null
                    ? _buildErrorView()
                    : _buildAttractionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF628EFF)),
          SizedBox(height: 16),
          Text(
            "Loading attraction details...",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            _errorMessage ?? "An error occurred",
            style: TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _enhanceAttractionsWithDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF628EFF),
              foregroundColor: Colors.white,
            ),
            child: Text("Try Again"),
          ),
        ],
      ),
    );
  }

  Widget _buildAttractionsList() {
    // If enhancement process has not been completed, use the original list
    List<PointOfInterest> displayAttractions =
        _enhancedAttractions.isEmpty
            ? widget.attractions
            : _enhancedAttractions;

    // Filter attractions based on selected category
    List<PointOfInterest> filteredAttractions =
        _selectedCategory == 'All'
            ? displayAttractions
            : displayAttractions
                .where((attraction) => attraction.category == _selectedCategory)
                .toList();

    if (filteredAttractions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "No attractions found in this category",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredAttractions.length,
      itemBuilder: (context, index) {
        final attraction = filteredAttractions[index];
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Attraction image
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child:
                    attraction.imageUrl != null
                        ? Image.network(
                          attraction.imageUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 180,
                              width: double.infinity,
                              color: Colors.grey.shade300,
                              child: Icon(
                                Icons.broken_image,
                                size: 64,
                                color: Colors.grey,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 180,
                              width: double.infinity,
                              color: Colors.grey.shade200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                          : null,
                                  color: Color(0xFF628EFF),
                                ),
                              ),
                            );
                          },
                        )
                        : Container(
                          height: 180,
                          width: double.infinity,
                          color: Colors.grey.shade300,
                          child: Icon(
                            Icons.image,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                        ),
              ),

              // Attraction details
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            attraction.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF628EFF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            attraction.category ?? 'Place',
                            style: TextStyle(
                              color: Color(0xFF628EFF),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    if (attraction.description != null)
                      Text(
                        attraction.description!,
                        style: TextStyle(color: Colors.grey.shade700),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 18),
                        SizedBox(width: 4),
                        Text(
                          "${attraction.rating?.toStringAsFixed(1) ?? 'N/A'}",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (attraction.reviewCount != null &&
                            attraction.reviewCount! > 0)
                          Text(
                            " (${attraction.reviewCount})",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        SizedBox(width: 24),
                        Icon(Icons.place, color: Colors.red, size: 18),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            attraction.location ?? widget.destination,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                        Spacer(),
                        SaveButton(
                          placeId: attraction.id,
                          placeName: attraction.name,
                          placeType: 'attraction',
                          destination: widget.destination,
                          imageUrl: attraction.imageUrl,
                          rating: attraction.rating,
                          reviewCount: attraction.reviewCount,
                          lat: attraction.lat, // Pass latitude
                          lng: attraction.lng, // Pass longitude
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to attraction details page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AttractionDetailsPage(
                                  attraction: attraction,
                                ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF628EFF),
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "View Details",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AttractionDetailsPage extends StatelessWidget {
  final PointOfInterest attraction;

  const AttractionDetailsPage({Key? key, required this.attraction})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Attraction Details')),
      body: Container(),
    );
  }
}

class DestinationService {
  final String apiKey = 'AIzaSyDmnBCSQ3jVr9L54w_iaDlzxHGdcb5lx8A';

  Future<Destination> getDestinationInfo(String destination) async {
    try {
      // 1. First, get basic place information
      final placeResult = await _getPlaceDetails(destination);

      // 2. Get inspirational travel description
      final travelDescription = await _getInspirationalDescription(
        placeResult.name,
      );

      // 3. Get hotels near the destination
      final hotels = await _getNearbyPlaces(placeResult.placeId, 'hotel');

      // 4. Get attractions near the destination
      final attractions = await _getNearbyPlaces(
        placeResult.placeId,
        'tourist_attraction',
      );

      // 5. Get restaurants near the destination
      final restaurants = await _getNearbyPlaces(
        placeResult.placeId,
        'restaurant',
      );

      return Destination(
        name: placeResult.name,
        description: travelDescription,
        images: placeResult.images,
        hotels: hotels,
        attractions: attractions,
        restaurants: restaurants,
      );
    } catch (e) {
      print('Error fetching destination data: $e');
      throw Exception('Could not load destination information');
    }
  }

  Future<String> _getInspirationalDescription(String placeName) async {
    try {
      // First, attempt to get basic info from Wikipedia
      final baseInfoUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&prop=pageimages|description&titles=$placeName&format=json&utf8=1',
      );

      final baseInfoResponse = await http.get(baseInfoUrl);
      final baseInfoData = json.decode(baseInfoResponse.body);

      // Extract the page ID from the response
      final pages = baseInfoData['query']['pages'];
      final pageId = pages.keys.first;

      // Now get geographical and cultural information
      final infoUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&titles=$placeName&prop=extracts&exintro=true&explaintext=true&format=json',
      );

      final infoResponse = await http.get(infoUrl);
      final infoData = json.decode(infoResponse.body);

      String extractText = "";
      if (infoData['query']['pages'][pageId].containsKey('extract')) {
        extractText = infoData['query']['pages'][pageId]['extract'];
      }

      // Format the description to be more travel-inspirational
      return _formatTravelDescription(extractText, placeName);
    } catch (e) {
      print('Error fetching inspirational description: $e');

      // If all else fails, generate a generic inspirational description
      return _generateGenericDescription(placeName);
    }
  }

  String _formatTravelDescription(String rawText, String placeName) {
    if (rawText.isEmpty) {
      return _generateGenericDescription(placeName);
    }

    // Split text into sentences
    List<String> sentences = rawText.split(RegExp(r'(?<=[.!?])\s+'));

    // Keep only sentences that have cultural, geographical, or aesthetic value
    List<String> relevantSentences =
        sentences.where((sentence) {
          String lower = sentence.toLowerCase();
          return lower.contains('culture') ||
              lower.contains('famous') ||
              lower.contains('known for') ||
              lower.contains('beautiful') ||
              lower.contains('historic') ||
              lower.contains('ancient') ||
              lower.contains('traditional') ||
              lower.contains('natural') ||
              lower.contains('popular') ||
              lower.contains('unique') ||
              lower.contains('landscape') ||
              lower.contains('heritage');
        }).toList();

    // If we found relevant sentences, use them
    if (relevantSentences.isNotEmpty) {
      // Limit to 2-3 sentences
      if (relevantSentences.length > 3) {
        relevantSentences = relevantSentences.sublist(0, 3);
      }

      // Join the sentences and add a travel hook
      String description = relevantSentences.join(' ');

      // Add an inspirational hook if not already present
      if (!description.toLowerCase().contains('visit') &&
          !description.toLowerCase().contains('experience') &&
          !description.toLowerCase().contains('discover')) {
        description +=
            ' Discover the unique charm and beauty that makes $placeName a must-visit destination.';
      }

      return description;
    } else {
      // If no relevant sentences, use first 1-2 sentences + generic description
      if (sentences.isNotEmpty) {
        int endIndex = min(2, sentences.length);
        String intro = sentences.sublist(0, endIndex).join(' ');
        return '$intro Discover the unique charm and beauty that makes $placeName a must-visit destination.';
      } else {
        return _generateGenericDescription(placeName);
      }
    }
  }

  String _generateGenericDescription(String placeName) {
    // List of inspirational travel description templates
    List<String> templates = [
      "Experience the rich culture and breathtaking landscapes of $placeName, where ancient traditions blend seamlessly with modern attractions.",
      "Discover $placeName, a destination renowned for its stunning natural beauty, vibrant local culture, and unforgettable experiences.",
      "$placeName enchants visitors with its unique blend of cultural heritage, picturesque scenery, and warm hospitality.",
      "Immerse yourself in the charm of $placeName, where every street corner tells a story and every vista captivates the imagination.",
      "Journey to $placeName and explore its timeless beauty, cultural treasures, and hidden gems waiting to be discovered.",
    ];

    // Return a random template
    return templates[DateTime.now().millisecondsSinceEpoch % templates.length];
  }

  Future<PlaceDetails> _getPlaceDetails(String placeName) async {
    // First, get the place ID from the name
    final findPlaceUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=$placeName&inputtype=textquery&fields=place_id,name,formatted_address,photos,geometry&key=$apiKey',
    );

    final findPlaceResponse = await http.get(findPlaceUrl);
    final findPlaceData = json.decode(findPlaceResponse.body);

    if (findPlaceData['status'] != 'OK' ||
        findPlaceData['candidates'].isEmpty) {
      throw Exception('Place not found');
    }

    final placeId = findPlaceData['candidates'][0]['place_id'];

    // Now get detailed information about the place
    final detailsUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=name,formatted_address,photos,rating,user_ratings_total,geometry&key=$apiKey',
    );

    final detailsResponse = await http.get(detailsUrl);
    final detailsData = json.decode(detailsResponse.body);

    final location = detailsData['result']['geometry']['location'];
    final lat = location['lat'];
    final lng = location['lng'];

    if (detailsData['status'] != 'OK') {
      throw Exception('Could not fetch place details');
    }

    final result = detailsData['result'];

    // Extract photos
    List<String> photoUrls = [];
    if (result.containsKey('photos') && result['photos'].isNotEmpty) {
      for (var i = 0; i < min(5, result['photos'].length); i++) {
        final photoReference = result['photos'][i]['photo_reference'];
        photoUrls.add(
          'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=$apiKey',
        );
      }
    }

    // Default description
    String description = 'Explore the wonders of $placeName.';

    return PlaceDetails(
      placeId: placeId,
      name: result['name'],
      description: description,
      images: photoUrls,
      rating: result.containsKey('rating') ? result['rating'].toDouble() : 0.0,
      reviewCount:
          result.containsKey('user_ratings_total')
              ? result['user_ratings_total']
              : 0,
      lat: location['lat'], // Add this
      lng: location['lng'], // Add this
    );
  }

  Future<List<PointOfInterest>> _getNearbyPlaces(
    String placeId,
    String type,
  ) async {
    // Implementation remains the same as before
    // ...

    // First, get the place location (lat/lng)
    final placeUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$apiKey',
    );

    final placeResponse = await http.get(placeUrl);
    final placeData = json.decode(placeResponse.body);

    if (placeData['status'] != 'OK') {
      throw Exception('Could not fetch place location');
    }

    final location = placeData['result']['geometry']['location'];
    final lat = location['lat'];
    final lng = location['lng'];

    // Now search for nearby places of the specified type
    final nearbyUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=5000&type=$type&key=$apiKey',
    );

    final nearbyResponse = await http.get(nearbyUrl);
    final nearbyData = json.decode(nearbyResponse.body);

    if (nearbyData['status'] != 'OK') {
      return []; // Return empty list if no results
    }

    List<PointOfInterest> places = [];

    for (var i = 0; i < min(10, nearbyData['results'].length); i++) {
      final place = nearbyData['results'][i];

      String photoUrl = '';
      if (place.containsKey('photos') && place['photos'].isNotEmpty) {
        final photoReference = place['photos'][0]['photo_reference'];
        photoUrl =
            'https://maps.googleapis.com/maps/api/place/photo?maxwidth=100&photoreference=$photoReference&key=$apiKey';
      }

      places.add(
        PointOfInterest(
          id: place['place_id'],
          name: place['name'],
          rating:
              place.containsKey('rating') ? place['rating'].toDouble() : 0.0,
          reviewCount:
              place.containsKey('user_ratings_total')
                  ? place['user_ratings_total']
                  : 0,
          thumbnail: photoUrl,
          lat: place['geometry']['location']['lat'],
          lng: place['geometry']['location']['lng'],
        ),
      );
    }

    return places;
  }
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String description;
  final List<String> images;
  final double rating;
  final int reviewCount;
  final double lat;
  final double lng;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.description,
    required this.images,
    required this.rating,
    required this.reviewCount,
    required this.lat,
    required this.lng,
  });
}

class HomeContent extends StatefulWidget {
  final List<Destination> recentSearches;
  final List<Destination> recommendedPlaces;

  const HomeContent({
    Key? key,
    this.recentSearches = const [],
    this.recommendedPlaces = const [],
  }) : super(key: key);

  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  late Timer _timer;
  int _currentImageIndex = 0;
  final List<String> _recommendedImages = [
    'assets/images/central_park.jpg',
    'assets/images/eiffel_tower.jpg',
    // Add more image paths as needed
  ];

  @override
  void initState() {
    super.initState();
    _startImageRotation();
  }

  void _startImageRotation() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {
        _currentImageIndex =
            (_currentImageIndex + 1) % _recommendedImages.length;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recently Viewed Section
          if (widget.recentSearches.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Recently Viewed",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.recentSearches.length,
                itemBuilder: (context, index) {
                  final destination = widget.recentSearches[index];
                  return _buildDestinationCard(destination);
                },
              ),
            ),
          ],
          // Recommended Places Section
          if (_recommendedImages.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Recommended Places",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 200, // Adjust the height as needed
              child: PageView.builder(
                itemCount: _recommendedImages.length,
                controller: PageController(viewportFraction: 0.8),
                itemBuilder: (context, index) {
                  return _buildImageCard(_recommendedImages[index]);
                },
              ),
            ),
          ],
          const SizedBox(height: 26),
          GestureDetector(
            onTap: () async {
              final shouldRefresh = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (context) => TripGeneratorScreen()),
              );
              // Optionally handle refresh if HomeContent is part of PlanPage or similar
              if (shouldRefresh == true && mounted) {
                // Trigger any refresh logic if needed (e.g., reload trips)
                // If HomeContent is within PlanPage, this may not be necessary
              }
            },

            child: Container(
              width: double.infinity, // Fit screen width
              height: 330, // Adjust height as needed
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                    'assets/images/AI.jpg',
                  ), // Specify your image
                  fit:
                      BoxFit
                          .cover, // Scale to cover while maintaining aspect ratio
                ),
              ),
              child: Center(
                child: Text(
                  ' ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black.withOpacity(0.5),
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationCard(Destination destination) {
    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.circular(10),
        image:
            destination.images.isNotEmpty
                ? DecorationImage(
                  image: AssetImage(destination.images[0]),
                  fit: BoxFit.cover,
                )
                : null,
      ),
      child: Center(
        child: Text(
          destination.name,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildImageCard(String imagePath) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(imagePath, fit: BoxFit.cover),
      ),
    );
  }
}

class TripPage extends StatefulWidget {
  @override
  _TripPageState createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  final TextEditingController _tripNameController = TextEditingController();

  void _navigateToTripDetails(String tripName) async {
    if (tripName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a trip name!')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Save the basic trip first
      await MongoDatabase.saveTrip(user.uid, {
        'name': tripName,
        'createdAt': DateTime.now(),
        'itinerary': [],
      });
      await PostgreSQLService.saveTrip(user.uid, {
        'name': tripName,
        'createdAt': DateTime.now(),
        'itinerary': [],
      });

      // Then navigate to details page and wait for result
      final shouldRefresh = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => TripDetailsPage(tripName: tripName),
        ),
      );

      // If we got a refresh flag, pop back to PlanPage
      if (shouldRefresh == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create trip: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a Trip'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Place a cool name for your Trip',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tripNameController,
              decoration: const InputDecoration(
                hintText: 'Exp: Weekend in Penang Island',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _navigateToTripDetails(_tripNameController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5856D6),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                'Create a New Trip',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tripNameController.dispose();
    super.dispose();
  }
}

class TripDetailsPage extends StatefulWidget {
  final String tripName;
  final Map<String, dynamic>? tripData;
  const TripDetailsPage({Key? key, required this.tripName, this.tripData})
    : super(key: key);

  @override
  _TripDetailsPageState createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> {
  late String _currentTripName;
  final TextEditingController _tripNameController = TextEditingController();
  bool _isEditing = false;
  File? _tripImage;
  int _selectedTabIndex = 0;
  List<SavedPlace> _tripPlaces = [];
  List<ItineraryItem> _itineraryItems = [];
  String? userId;
  List<SavedPlace> _hotels = [];
  List<SavedPlace> _restaurants = [];
  List<SavedPlace> _attractions = [];
  List<PointOfInterest> _recommendedPlaces = [];
  bool _isLoadingRecommendations = false;
  String? _tripId; // Add this to track MongoDB trip ID
  bool _isSaving = false;
  bool _isLoading = false;
  String? _selectedImage;
  bool _isImagePickerOpen = false;
  TripPictureType _selectedPicture = TripPictureType.none;

  @override
  void initState() {
    super.initState();
    _currentTripName = widget.tripName;
    _tripNameController.text = _currentTripName;
    userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _loadTripPlaces(); // Add this method
    }
    _loadTripData();
    if (widget.tripData?['pictureType'] != null) {
      _selectedPicture = TripPictureType.values.firstWhere(
        (e) => e.toString() == widget.tripData!['pictureType'],
        orElse: () => TripPictureType.none,
      );
    }
  }

  Future<void> _showImagePicker() async {
    if (_isImagePickerOpen) return;
    _isImagePickerOpen = true;

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Select Trip Picture'),
            content: SizedBox(
              width: double.maxFinite,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: TripPictureType.values.length - 1, // exclude 'none'
                itemBuilder: (context, index) {
                  final pictureType = TripPictureType.values[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedPicture = pictureType);
                      Navigator.pop(context);
                    },
                    child: Stack(
                      children: [
                        Image.asset(
                          pictureType.assetPath,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        if (_selectedPicture == pictureType)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          ),
    );
    _isImagePickerOpen = false;
  }

  Future<void> _loadTripData() async {
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final trips = await MongoDatabase.getUserTrips(userId!);
      final existingTrip = trips.firstWhere(
        (trip) => trip['name'] == widget.tripName,
        orElse: () => {},
      );

      if (existingTrip.isNotEmpty) {
        setState(() {
          // Handle both String and ObjectId cases
          _tripId =
              existingTrip['_id']?.toString() ?? existingTrip['_id']?.$oid;
          _itineraryItems =
              (existingTrip['itinerary'] as List?)
                  ?.map((item) => ItineraryItem.fromMap(item))
                  ?.toList() ??
              [];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading trip: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTrip() async {
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      final tripData = {
        'name': _currentTripName,
        'pictureType': _selectedPicture.toString(),
        'itinerary': _itineraryItems.map((item) => item.toMap()).toList(),
        'updatedAt': DateTime.now(),
      };

      if (_tripId == null) {
        await MongoDatabase.saveTrip(userId!, tripData);
      } else {
        await MongoDatabase.updateTrip(_tripId!, tripData);
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Trip saved successfully')));
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save trip: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Map<DateTime, List<ItineraryItem>> get groupedItineraryItems {
    final map = <DateTime, List<ItineraryItem>>{};

    for (final item in _itineraryItems) {
      // Normalize date by removing time component
      final date = DateTime(item.date.year, item.date.month, item.date.day);
      if (!map.containsKey(date)) {
        map[date] = [];
      }
      map[date]!.add(item);
    }

    // Sort each day's items by arrival time
    map.forEach((date, items) {
      items.sort((a, b) => a.arrivalTime.hour.compareTo(b.arrivalTime.hour));
    });

    return map;
  }

  List<DateTime> get sortedDates {
    return groupedItineraryItems.keys.toList()..sort();
  }

  Future<void> _loadTripPlaces() async {
    try {
      // Load places from MongoDB for this user
      final places = await MongoDatabase.getSavedPlaces(userId!);

      // Categorize the places by type
      final categorizedPlaces = _categorizePlaces(
        places.map((place) => SavedPlace.fromMap(place)).toList(),
      );

      setState(() {
        _hotels = categorizedPlaces['hotels'] ?? [];
        _restaurants = categorizedPlaces['restaurants'] ?? [];
        _attractions = categorizedPlaces['attractions'] ?? [];
      });
    } catch (e) {
      print('Error loading trip places: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load saved places')));
    }
  }

  Map<String, List<SavedPlace>> _categorizePlaces(List<SavedPlace> places) {
    final Map<String, List<SavedPlace>> categorized = {
      'hotels': [],
      'restaurants': [],
      'attractions': [],
    };

    for (final place in places) {
      switch (place.type) {
        case 'hotel':
          categorized['hotels']!.add(place);
          break;
        case 'restaurant':
          categorized['restaurants']!.add(place);
          break;
        case 'attraction':
          categorized['attractions']!.add(place);
          break;
        default:
          // Handle unexpected types if needed
          break;
      }
    }

    return categorized;
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _tripImage = File(pickedFile.path);
      });
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _currentTripName = _tripNameController.text;
      }
    });
  }

  void _addToItinerary(SavedPlace place) {
    final parentContext = context; // Save the parent context

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AddToItineraryDialog(
          place: place,
          onAdd: (date, time, notes) {
            setState(() {
              _itineraryItems.add(
                ItineraryItem(
                  place: place,
                  date: date,
                  arrivalTime: time,
                  notes: notes,
                ),
              );
            });
            Navigator.pop(dialogContext);
            ScaffoldMessenger.of(parentContext).showSnackBar(
              SnackBar(content: Text('Added ${place.name} to itinerary')),
            );
          },
        );
      },
    );
  }

  void _reorderItinerary(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _itineraryItems.removeAt(oldIndex);
      _itineraryItems.insert(newIndex, item);
    });
  }

  Future<void> _editTrip() async {
    if (_tripId == null) return;

    final newName = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder:
            (context) => EditTripPage(
              tripId: _tripId!,
              currentName: _currentTripName,
              onSave: _updateTripName,
              onDelete: _deleteTrip,
            ),
      ),
    );

    if (newName != null && mounted) {
      setState(() {
        _currentTripName = newName;
        _tripNameController.text = newName;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Trip name updated')));
      Navigator.pop(context, true);
    }
  }

  Future<String> _updateTripName(String newName) async {
    try {
      await MongoDatabase.updateTrip(_tripId!, {
        'name': newName,
        'updatedAt': DateTime.now(),
      });
      return newName;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update trip name: $e')));
      throw e;
    }
  }

  Future<void> _deleteTrip() async {
    try {
      await MongoDatabase.deleteTrip(_tripId!);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Trip deleted')));
      Navigator.pop(context); // Return to previous screen
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete trip: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true); // Return true to indicate refresh needed
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trip Details'),
          backgroundColor: Color(0xFF628EFF),
          actions: [
            IconButton(icon: Icon(Icons.edit), onPressed: _editTrip),
            IconButton(
              icon:
                  _isSaving
                      ? CircularProgressIndicator(color: Colors.white)
                      : Icon(Icons.save),
              onPressed: _isSaving ? null : _saveTrip,
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            GestureDetector(
              onTap: _showImagePicker,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child:
                    _selectedImage != TripPictureType.none
                        ? Image.asset(
                          _selectedPicture.assetPath,
                          fit: BoxFit.cover,
                        )
                        : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 50),
                            Text('Select Trip Picture'),
                          ],
                        ),
              ),
            ),

            // Trip name section
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0),
              child:
                  _isEditing
                      ? TextField(
                        controller: _tripNameController,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Unnamed Trip',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                      : Text(
                        _currentTripName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),

            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTabButton(
                    0,
                    'Places (${_hotels.length + _restaurants.length + _attractions.length})',
                  ),
                  _buildTabButton(1, 'Itinerary (${_itineraryItems.length})'),
                  _buildTabButton(2, 'Recommend'),
                ],
              ),
            ),
            Divider(height: 1),

            // Tab content
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  // Places tab
                  _buildPlacesTab(),

                  // Itinerary tab
                  _buildItineraryTab(),

                  // Recommend tab
                  _buildRecommendTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String title) {
    return TextButton(
      onPressed: () => setState(() => _selectedTabIndex = index),
      style: TextButton.styleFrom(
        foregroundColor:
            _selectedTabIndex == index ? Color(0xFF628EFF) : Colors.grey,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontWeight:
              _selectedTabIndex == index ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildPlacesTab() {
    final allPlaces = [..._hotels, ..._restaurants, ..._attractions];

    if (allPlaces.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No places saved yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              'Save hotels, restaurants and attractions to see them here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SavedPlacesPage()),
                ).then((_) => _loadTripPlaces()); // Refresh after returning
              },
              child: Text('View Saved Places'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hotels.isNotEmpty) _buildCategorySection('Hotels', _hotels),
          if (_restaurants.isNotEmpty)
            _buildCategorySection('Restaurants', _restaurants),
          if (_attractions.isNotEmpty)
            _buildCategorySection('Attractions', _attractions),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String title, List<SavedPlace> places) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        ListView.builder(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: places.length,
          itemBuilder: (context, index) {
            final place = places[index];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading:
                    place.imageUrl != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            place.imageUrl!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.place, size: 50);
                            },
                          ),
                        )
                        : Icon(Icons.place, size: 50),
                title: Text(place.name),
                subtitle: Text('${place.destination}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () => _addToItinerary(place),
                    ),
                    SaveButton(
                      placeId: place.id,
                      placeName: place.name,
                      placeType: place.type,
                      destination: place.destination,
                      imageUrl: place.imageUrl,
                      rating: place.rating,
                      reviewCount: place.reviewCount,
                      lat: place.lat, // Pass latitude
                      lng: place.lng, // Pass longitude
                      onChanged: _loadTripPlaces,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildItineraryTab() {
    if (_itineraryItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No itinerary items yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              'Add places from your saved places to create an itinerary',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, dateIndex) {
        final date = sortedDates[dateIndex];
        final items = groupedItineraryItems[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                DateFormat('EEEE, MMMM d').format(date),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),

            // Items for this date
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: items.length,
              onReorder: (oldIndex, newIndex) {
                _reorderItineraryItem(date, oldIndex, newIndex);
              },
              itemBuilder: (context, itemIndex) {
                final item = items[itemIndex];
                return Card(
                  key: Key('${item.place.id}-${item.date}-${item.arrivalTime}'),
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading:
                        item.place.imageUrl != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.place.imageUrl!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.place, size: 50);
                                },
                              ),
                            )
                            : Icon(Icons.place, size: 50),
                    title: Text(item.place.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Arrival: ${item.arrivalTime.format(context)}'),
                        if (item.notes != null && item.notes!.isNotEmpty)
                          Text(
                            'Notes: ${item.notes!}',
                            style: TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () => _editItineraryItem(item),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeItineraryItem(item),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Divider(),
          ],
        );
      },
    );
  }

  void _reorderItineraryItem(DateTime date, int oldIndex, int newIndex) {
    setState(() {
      final items = groupedItineraryItems[date]!;
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);

      // Update the main list
      _itineraryItems =
          groupedItineraryItems.values.expand((items) => items).toList();
    });
  }

  void _removeItineraryItem(ItineraryItem item) {
    setState(() {
      _itineraryItems.remove(item);
    });
  }

  void _editItineraryItem(ItineraryItem item) {
    showDialog(
      context: context,
      builder:
          (context) => AddToItineraryDialog(
            place: item.place,
            initialDate: item.date,
            initialTime: item.arrivalTime,
            initialNotes: item.notes,
            onAdd: (date, time, notes) {
              setState(() {
                _itineraryItems.remove(item);
                _itineraryItems.add(
                  ItineraryItem(
                    place: item.place,
                    date: date,
                    arrivalTime: time,
                    notes: notes,
                  ),
                );
              });
              Navigator.pop(context);
            },
          ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildRecommendTab() {
    if (_isLoadingRecommendations) {
      return Center(child: CircularProgressIndicator());
    }

    if (_recommendedPlaces.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Get recommendations',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              'Discover great places to add to your trip',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchRecommendations,
              child: Text('Get Recommendations'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recommended Places',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _fetchRecommendations,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recommendedPlaces.length,
            itemBuilder: (context, index) {
              final place = _recommendedPlaces[index];
              return Card(
                margin: EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading:
                      place.thumbnail.isNotEmpty
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              place.thumbnail,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          )
                          : Icon(Icons.place, size: 50),
                  title: Text(place.name),
                  subtitle: Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber),
                      Text(' ${place.rating.toStringAsFixed(1)}'),
                      SizedBox(width: 8),
                      Text('(${place.reviewCount} reviews)'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () => _addRecommendedToItinerary(place),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Add this method to fetch recommendations
  Future<void> _fetchRecommendations() async {
    setState(() => _isLoadingRecommendations = true);

    try {
      // Get current trip destination (you might need to modify this)
      final destination = _currentTripName;

      // Fetch recommendations from your backend or API
      final result = await DestinationService().getDestinationInfo(destination);

      setState(() {
        // Combine hotels, restaurants and attractions
        _recommendedPlaces = [
          ...result.hotels,
          ...result.restaurants,
          ...result.attractions,
        ];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load recommendations: $e')),
      );
    } finally {
      setState(() => _isLoadingRecommendations = false);
    }
  }

  // Add this method to handle adding recommended places
  void _addRecommendedToItinerary(PointOfInterest place) {
    // Save the parent context before showing dialog
    final parentContext = context;

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AddToItineraryDialog(
          place: SavedPlace(
            id: place.id,
            name: place.name,
            type: _getPlaceType(place),
            destination: _currentTripName,
            imageUrl: place.imageUrl ?? place.thumbnail,
            rating: place.rating,
            reviewCount: place.reviewCount,
            lat: place.lat, // Pass latitude
            lng: place.lng, // Pass longitude
          ),
          onAdd: (date, time, notes) {
            setState(() {
              _itineraryItems.add(
                ItineraryItem(
                  place: SavedPlace(
                    id: place.id,
                    name: place.name,
                    type: _getPlaceType(place),
                    destination: _currentTripName,
                    imageUrl: place.imageUrl ?? place.thumbnail,
                    rating: place.rating,
                    reviewCount: place.reviewCount,
                    lat: place.lat, // Pass latitude
                    lng: place.lng, // Pass longitude
                  ),
                  date: date,
                  arrivalTime: time,
                  notes: notes,
                ),
              );
            });
            Navigator.pop(dialogContext);

            // Use the parentContext which has Scaffold ancestor
            ScaffoldMessenger.of(parentContext).showSnackBar(
              SnackBar(content: Text('Added ${place.name} to itinerary')),
            );
          },
        );
      },
    );
  }

  String _getPlaceType(PointOfInterest place) {
    if (place is Hotel) return 'hotel';
    if (place is Restaurant) return 'restaurant';
    return 'attraction';
  }
}

class ItineraryItem {
  final SavedPlace place;
  final DateTime date;
  final TimeOfDay arrivalTime;
  String? notes;

  ItineraryItem({
    required this.place,
    required this.date,
    required this.arrivalTime,
    this.notes,
  });

  // Helper method to combine date and time
  DateTime get fullDateTime {
    return DateTime(
      date.year,
      date.month,
      date.day,
      arrivalTime.hour,
      arrivalTime.minute,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'place': place.toMap(),
      'date': date.toIso8601String(),
      'arrivalTime': '${arrivalTime.hour}:${arrivalTime.minute}',
      'notes': notes,
    };
  }

  factory ItineraryItem.fromMap(Map<String, dynamic> map) {
    // Default to current time if parsing fails
    TimeOfDay defaultTime = TimeOfDay.now();

    try {
      final timeParts = (map['arrivalTime'] as String? ?? '12:00').split(':');
      return ItineraryItem(
        place: SavedPlace.fromMap(map['place']),
        date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
        arrivalTime: TimeOfDay(
          hour: int.tryParse(timeParts[0]) ?? defaultTime.hour,
          minute: int.tryParse(timeParts[1]) ?? defaultTime.minute,
        ),
        notes: map['notes'],
      );
    } catch (e) {
      print('Error parsing itinerary item: $e');
      return ItineraryItem(
        place: SavedPlace.fromMap(map['place']),
        date: DateTime.now(),
        arrivalTime: defaultTime,
        notes: map['notes'],
      );
    }
  }
}

class Hotel extends PointOfInterest {
  Hotel({
    required String id,
    required String name,
    required double rating,
    required int reviewCount,
    required String thumbnail,
    required double lat,
    required double lng,
    String? imageUrl,
  }) : super(
         id: id,
         name: name,
         rating: rating,
         reviewCount: reviewCount,
         thumbnail: thumbnail,
         imageUrl: imageUrl,
         lat: lat,
         lng: lng,
       );
}

class Restaurant extends PointOfInterest {
  Restaurant({
    required String id,
    required String name,
    required double rating,
    required int reviewCount,
    required String thumbnail,
    required double lat,
    required double lng,
    String? imageUrl,
  }) : super(
         id: id,
         name: name,
         rating: rating,
         reviewCount: reviewCount,
         thumbnail: thumbnail,
         imageUrl: imageUrl,
         lat: lat,
         lng: lng,
       );
}

class Attraction extends PointOfInterest {
  Attraction({
    required String id,
    required String name,
    required double rating,
    required int reviewCount,
    required String thumbnail,
    required double lat,
    required double lng,
    String? imageUrl,
  }) : super(
         id: id,
         name: name,
         rating: rating,
         reviewCount: reviewCount,
         thumbnail: thumbnail,
         imageUrl: imageUrl,
         lat: lat,
         lng: lng,
       );
}

class AddToItineraryDialog extends StatefulWidget {
  final SavedPlace place;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final String? initialNotes;
  final Function(DateTime date, TimeOfDay time, String? notes) onAdd;

  const AddToItineraryDialog({
    Key? key,
    required this.place,
    this.initialDate,
    this.initialTime,
    this.initialNotes,
    required this.onAdd,
  }) : super(key: key);

  @override
  _AddToItineraryDialogState createState() => _AddToItineraryDialogState();
}

class _AddToItineraryDialogState extends State<AddToItineraryDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedTime = widget.initialTime ?? TimeOfDay.now();
    _notesController = TextEditingController(text: widget.initialNotes);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Add this method to handle time selection
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add to Itinerary'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text('Date'),
              subtitle: Text(DateFormat('MMM d, y').format(_selectedDate)),
              trailing: Icon(Icons.arrow_drop_down),
              onTap: () => _selectDate(context),
            ),
            ListTile(
              leading: Icon(Icons.access_time),
              title: Text('Arrival Time'),
              subtitle: Text(_selectedTime.format(context)),
              trailing: Icon(Icons.arrow_drop_down),
              onTap: () => _selectTime(context),
            ),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                icon: Icon(Icons.note),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onAdd(
              _selectedDate,
              _selectedTime,
              _notesController.text.isNotEmpty ? _notesController.text : null,
            );
          },
          child: Text(widget.initialDate == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}

class ProfilePage extends StatefulWidget {
  final String userId;
  ProfilePage({required this.userId});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<Map<String, dynamic>>? _userData;
  File? _imageFile;
  bool isGuest = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userData = fetchUserData(user.uid);
    } else {
      isGuest = false;
      _userData = null;
    }
  }

  Future<Map<String, dynamic>> fetchUserData(String? userId) async {
    if (userId == null) {
      isGuest = true;
      return {
        "username": "Guest",
        "gender": "N/A",
        "phone": "N/A",
        "profile_picture": "assets/profile_placeholder.png",
      };
    }

    try {
      final response = await http.get(
        Uri.parse("https://trip-advisor-woil.onrender.com/users/$userId"),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        print(
          "Error: Failed to load user data (Status Code: ${response.statusCode})",
        );
        return {
          "username": "Guest",
          "gender": "N/A",
          "phone": "N/A",
          "profile_picture": "assets/profile_placeholder.png",
        };
      }
    } catch (e) {
      print("Exception: $e");
      return {
        "username": "Guest",
        "gender": "N/A",
        "phone": "N/A",
        "profile_picture": "assets/profile_placeholder.png",
      };
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void showToast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isGuest ? _buildGuestView(context) : _buildUserView(),
    );
  }

  Widget _buildGuestView(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.account_circle, size: 100, color: Colors.grey),
        SizedBox(height: 10),
        Text(
          "Plan the best trip",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Text(
          "Get travel recommendations, share reviews, and organize trip ideas.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.pushReplacementNamed(context, "/login"),
          child: Text("Sign In"),
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5856D6)),
        ),
        SizedBox(height: 30),
        _buildGuestOption(Icons.settings, "Preferences"),
        _buildGuestOption(Icons.support, "Support"),
      ],
    );
  }

  Widget _buildGuestOption(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: TextStyle(fontSize: 18)),
      trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black54),
      onTap: () => showToast("Sign in to access $title"),
    );
  }

  Widget _buildUserView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _userData,
      builder: (context, snapshot) {
        if (isGuest || snapshot.connectionState == ConnectionState.waiting) {
          // Show guest view or loading indicator if user is not logged in
          return _buildGuestView(context);
        } else if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          // If error or no data found, show guest-like view
          return Center(child: Text("No user data available. Please sign in."));
        }

        final userData = snapshot.data!;
        String profileImageUrl =
            userData["profile_picture"] != null
                ? "https://trip-advisor-woil.onrender.com${userData["profile_picture"]}"
                : "assets/profile_placeholder.png";

        return Column(
          children: [
            SizedBox(height: 30),
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage:
                    profileImageUrl.startsWith("http")
                        ? NetworkImage(profileImageUrl)
                        : AssetImage(profileImageUrl) as ImageProvider,
              ),
            ),
            SizedBox(height: 10),
            Text(
              userData["username"]?.toString() ?? "Username not available",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              "Gender: ${userData["gender"]?.toString() ?? "Not specified"}",
            ),
            Text("Phone: ${userData["phone"]?.toString() ?? "Not provided"}"),
            SizedBox(height: 20),
            _buildProfileOption(
              Icons.calendar_today,
              "Bookings",
              context,
              BookingsPage(),
            ),
            _buildProfileOption(
              Icons.person,
              "Profile",
              context,
              ProfileDetailsPage(
                userId: FirebaseAuth.instance.currentUser!.uid,
              ),
            ),
            _buildProfileOption(
              Icons.notifications,
              "Notifications",
              context,
              NotificationsPage(),
            ),
            _buildProfileOption(
              Icons.settings,
              "Preferences",
              context,
              PreferencesPage(),
            ),
            _buildProfileOption(
              Icons.support,
              "Support",
              context,
              SupportPage(),
            ),
            Spacer(),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5856D6),
                  minimumSize: Size(double.infinity, 50),
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();

                  // Navigate to login screen and clear navigation stack
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  );
                },
                child: Text(
                  "Log Out",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileOption(
    IconData icon,
    String title,
    BuildContext context,
    Widget page,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: TextStyle(fontSize: 18)),
      trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black54),
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          ),
    );
  }
}

class BookingsPage extends StatefulWidget {
  @override
  _BookingsPageState createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  List<dynamic> _bookings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // Case 1: Guest user
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Please sign in to view bookings";
        });
        return;
      }

      // Case 2: Registered user - Fetch simple_id first
      // Fetch bookings
      final bookingsResponse = await http.get(
        Uri.parse(
          "https://trip-advisor-woil.onrender.com/api/bookings?user_id=${user.uid}",
        ),
      );

      if (bookingsResponse.statusCode == 200) {
        setState(() {
          _bookings = jsonDecode(bookingsResponse.body);
          _isLoading = false;
        });
      } else {
        throw Exception("No bookings found");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll("Exception: ", "");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Bookings"),
        centerTitle: true,
        backgroundColor: Color(0xFF628EFF),
        toolbarHeight: 80,
      ),
      body: _buildBody(),
      floatingActionButton:
          _errorMessage != null
              ? FloatingActionButton(
                onPressed: _fetchBookings,
                child: Icon(Icons.refresh),
                backgroundColor: Colors.orange,
              )
              : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 18, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchBookings,
              child: Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF628EFF), // Changed from 'primary'
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      );
    }

    return _bookings.isEmpty
        ? Center(
          child: Text(
            "No bookings yet",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        )
        : RefreshIndicator(
          onRefresh: _fetchBookings,
          child: ListView.builder(
            itemCount: _bookings.length,
            itemBuilder:
                (context, index) => BookingCard(
                  booking: _bookings[index],
                  onTap: () => _showBookingDetails(_bookings[index]),
                ),
          ),
        );
  }

  void _showBookingDetails(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Booking Details"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //_DetailRow("Plan:", booking["plan_name"]),
                _DetailRow(
                  "Amount:",
                  "MYR ${(double.parse(booking["amount"].toString())).toStringAsFixed(2)}",
                ),
                _DetailRow("Status:", booking["status"]),
                _DetailRow("Date:", booking["booked_at"]?.split('T')[0]),
                if (booking["paypal_transaction_id"] != null)
                  _DetailRow(
                    "Transaction ID:",
                    booking["paypal_transaction_id"],
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final lat = booking["place_lat"];
                  final lng = booking["place_lng"];
                  if (lat != null && lng != null) {
                    final googleMapsUrl =
                        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng";
                    launchUrl(Uri.parse(googleMapsUrl));
                  }
                },
                child: Text("Navigate"),
              ),
            ],
          ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 10),
          Expanded(child: Text(value ?? "N/A")),
        ],
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  final dynamic booking;
  final VoidCallback? onTap; // Add this line

  const BookingCard({
    Key? key,
    required this.booking,
    this.onTap, // Add this parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        // Wrap with InkWell for tap effect
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking["place_name"] ?? "Unnamed Plan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "Amount: MYR ${double.tryParse(booking["amount"].toString())?.toStringAsFixed(2) ?? "0.00"}",
              ),
              Text("Status: ${booking["status"]}"),
              Text("Date: ${booking["booked_at"]?.split('T')[0]}"),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileDetailsPage extends StatefulWidget {
  final String? userId;
  ProfileDetailsPage({this.userId});

  @override
  _ProfileDetailsPageState createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  late Future<Map<String, dynamic>>? _userData;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      _userData = fetchUserData(widget.userId!);
    } else {
      _userData = null; // User skipped login
    }
  }

  Future<Map<String, dynamic>> fetchUserData(String userId) async {
    final response = await http.get(
      Uri.parse("https://trip-advisor-woil.onrender.com/users/$userId"),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load user data");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile Details"),
        centerTitle: true,
        toolbarHeight: 80,
        backgroundColor: Color(0xFF628EFF),
      ),
      body:
          widget.userId == null
              ? _buildGuestView(context)
              : FutureBuilder<Map<String, dynamic>>(
                future: _userData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        "No user data found. Please sign in or try again later.",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }

                  final userData = snapshot.data!;
                  String profileImageUrl =
                      userData["profile_picture"] != null
                          ? "https://trip-advisor-woil.onrender.com${userData["profile_picture"]}"
                          : "assets/profile_placeholder.png";

                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => _pickImage(),
                                child: CircleAvatar(
                                  radius: 45,
                                  backgroundImage:
                                      profileImageUrl.startsWith("http")
                                          ? NetworkImage(profileImageUrl)
                                          : AssetImage(profileImageUrl)
                                              as ImageProvider,
                                ),
                              ),
                              SizedBox(width: 15),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userData["username"],
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    "Gender: ${userData["gender"]}",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    "Phone: ${userData["phone"]}",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 30),
                          _buildProfileOption(
                            Icons.settings,
                            "Preferences",
                            context,
                            PreferencesPage(),
                          ),
                          _buildProfileOption(
                            Icons.support,
                            "Support",
                            context,
                            SupportPage(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }

  // --- Guest View ---
  Widget _buildGuestView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle, size: 100, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              "Welcome, Guest!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              "Sign in to unlock travel recommendations, share reviews, and organize trip ideas.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5856D6),
              ),
              onPressed: () {
                Navigator.pushReplacementNamed(context, "/login");
              },
              child: Text("Sign In", style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 30),
            _buildProfileOption(
              Icons.settings,
              "Preferences",
              context,
              PreferencesPage(),
            ),
            _buildProfileOption(
              Icons.support,
              "Support",
              context,
              SupportPage(),
            ),
          ],
        ),
      ),
    );
  }

  // --- Pick Profile Image (Disabled for Guests) ---
  Future<void> _pickImage() async {
    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sign in to change profile picture.")),
      );
      return;
    }

    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      // Upload function can be implemented here
    }
  }

  // --- Profile Options Row ---
  Widget _buildProfileOption(
    IconData icon,
    String title,
    BuildContext context,
    Widget page,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: TextStyle(fontSize: 18)),
      trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black54),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
    );
  }
}

class NotificationsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Notifications"),
        centerTitle: true,
        toolbarHeight: 80,
        backgroundColor: Color(0xFF628EFF),
      ),
      body: Center(
        child: Text("Notifications Page", style: TextStyle(fontSize: 20)),
      ),
    );
  }
}

class PreferencesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Preferences"),
        centerTitle: true,
        toolbarHeight: 80,
        backgroundColor: Color(0xFF628EFF),
      ),
      body: ListView(
        children: [
          _buildPreferenceOption(Icons.person, "Account Info"),
          _buildPreferenceOption(Icons.language, "Language & Currency"),
          _buildPreferenceOption(Icons.attach_money, "Budget"),
          _buildPreferenceOption(Icons.payment, "Payment Preference"),
          _buildPreferenceOption(Icons.notifications, "Notification"),
          _buildPreferenceOption(Icons.location_on, "Location"),
          _buildPreferenceOption(Icons.privacy_tip, "Privacy"),
        ],
      ),
    );
  }

  Widget _buildPreferenceOption(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: TextStyle(fontSize: 18)),
      trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black54),
      onTap: () {
        // TODO: Navigate to respective pages
      },
    );
  }
}

class SupportPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Support"),
        centerTitle: true,
        toolbarHeight: 80,
        backgroundColor: Color(0xFF628EFF),
      ),
      body: ListView(
        children: [
          _buildPreferenceOption(Icons.person, "Help center"),
          _buildPreferenceOption(Icons.language, "Contact Us"),
          _buildPreferenceOption(Icons.attach_money, "Term of use"),
        ],
      ),
    );
  }

  Widget _buildPreferenceOption(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: TextStyle(fontSize: 18)),
      trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black54),
      onTap: () {
        // TODO: Navigate to respective pages
      },
    );
  }
}

class SavedPlace {
  final String id;
  final String name;
  final String type;
  final String destination;
  final String? imageUrl;
  final double rating;
  final int reviewCount;
  final DateTime? createdAt;
  final double lat; // Add latitude
  final double lng; // Add longitude

  SavedPlace({
    required this.id,
    required this.name,
    required this.type,
    required this.destination,
    this.imageUrl,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.createdAt,
    required this.lat, // Make required
    required this.lng, // Make required
  });

  factory SavedPlace.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return SavedPlace(
        id: 'default_place',
        name: 'Default Place',
        type: 'attraction',
        destination: 'Unknown',
        lat: 0.0, // Default value
        lng: 0.0, // Default value
      );
    }

    return SavedPlace(
      id: map['id']?.toString() ?? 'unknown_id',
      name: map['name']?.toString() ?? 'Unnamed Place',
      type: map['type']?.toString() ?? 'attraction',
      destination: map['destination']?.toString() ?? 'Unknown',
      imageUrl: map['imageUrl']?.toString(),
      rating: map['rating']?.toDouble() ?? 0.0,
      reviewCount: map['reviewCount'] ?? 0,
      createdAt:
          map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'].toString())
              : null,
      lat: map['lat']?.toDouble() ?? 0.0, // Parse latitude
      lng: map['lng']?.toDouble() ?? 0.0, // Parse longitude
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'destination': destination,
      'imageUrl': imageUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'createdAt': createdAt?.toIso8601String(),
      'lat': lat, // Include latitude
      'lng': lng, // Include longitude
    };
  }
}

class SavedPlacesPage extends StatefulWidget {
  @override
  _SavedPlacesPageState createState() => _SavedPlacesPageState();
}

class _SavedPlacesPageState extends State<SavedPlacesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<SavedPlace>> _savedPlaces;
  String? userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _savedPlaces = _getSavedPlaces(userId!);
    } else {
      _savedPlaces = Future.value([]);
    }
  }

  Future<List<SavedPlace>> _getSavedPlaces(String userId) async {
    try {
      final places = await MongoDatabase.getSavedPlaces(userId);
      return places.map((place) => SavedPlace.fromMap(place)).toList();
    } catch (e) {
      print('Error getting saved places: $e');
      return [];
    }
  }

  void _refreshPlaces() {
    if (userId != null) {
      setState(() {
        _savedPlaces = _getSavedPlaces(userId!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Places'),
        backgroundColor: Color(0xFF628EFF),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Hotels', icon: Icon(Icons.hotel)),
            Tab(text: 'Restaurants', icon: Icon(Icons.restaurant)),
            Tab(text: 'Attractions', icon: Icon(Icons.attractions)),
          ],
        ),
      ),
      body: FutureBuilder<List<SavedPlace>>(
        future: _savedPlaces,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No saved places yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'Save hotels, restaurants, and attractions to see them here',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final places = snapshot.data!;
          return TabBarView(
            controller: _tabController,
            children: [
              _buildPlacesList(places.where((p) => p.type == 'hotel').toList()),
              _buildPlacesList(
                places.where((p) => p.type == 'restaurant').toList(),
              ),
              _buildPlacesList(
                places.where((p) => p.type == 'attraction').toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlacesList(List<SavedPlace> places) {
    if (places.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No saved ${_getPlaceType(_tabController.index)} yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: places.length,
      itemBuilder: (context, index) {
        final place = places[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading:
                place.imageUrl != null
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        place.imageUrl!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.place, size: 50);
                        },
                      ),
                    )
                    : Icon(Icons.place, size: 50),
            title: Text(place.name),
            subtitle: Text(place.destination),
            trailing: SaveButton(
              placeId: place.id,
              placeName: place.name,
              placeType: place.type,
              destination: place.destination,
              imageUrl: place.imageUrl,
              rating: place.rating,
              reviewCount: place.reviewCount,
              lat: place.lat, // Pass latitude
              lng: place.lng, // Pass longitude
              onChanged: _refreshPlaces,
            ),
          ),
        );
      },
    );
  }

  String _getPlaceType(int index) {
    switch (index) {
      case 0:
        return 'hotels';
      case 1:
        return 'restaurants';
      case 2:
        return 'attractions';
      default:
        return 'places';
    }
  }
}

// Helper extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

class SaveButton extends StatefulWidget {
  final String placeId;
  final String placeName;
  final String placeType;
  final String destination;
  final String? imageUrl;
  final double rating;
  final int reviewCount;
  final double lat; // Add latitude
  final double lng; // Add longitude
  final VoidCallback? onChanged;

  const SaveButton({
    Key? key,
    required this.placeId,
    required this.placeName,
    required this.placeType,
    required this.destination,
    this.imageUrl,
    required this.rating,
    required this.reviewCount,
    required this.lat, // Add latitude
    required this.lng, // Add longitude
    this.onChanged,
  }) : super(key: key);

  @override
  _SaveButtonState createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  late Future<bool> _isSavedFuture;
  String? userId;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _isSavedFuture = MongoDatabase.isPlaceSaved(userId!, widget.placeId);
    } else {
      _isSavedFuture = Future.value(false);
    }
  }

  Future<void> _toggleSave(bool currentStatus) async {
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please sign in to save places')));
      return;
    }

    try {
      if (currentStatus) {
        await MongoDatabase.removePlace(userId!, widget.placeId);
        await PostgreSQLService.removePlace(userId!, widget.placeId);
      } else {
        await MongoDatabase.savePlace(userId!, {
          'id': widget.placeId,
          'name': widget.placeName,
          'type': widget.placeType,
          'destination': widget.destination,
          'imageUrl': widget.imageUrl,
          'rating': widget.rating,
          'reviewCount': widget.reviewCount,
          'createdAt': DateTime.now().toIso8601String(),
          'lat': widget.lat, // Save latitude
          'lng': widget.lng, // Save longitude
        });
        await PostgreSQLService.savePlace(userId!, {
          'id': widget.placeId,
          'name': widget.placeName,
          'type': widget.placeType,
          'destination': widget.destination,
          'imageUrl': widget.imageUrl,
          'rating': widget.rating,
          'reviewCount': widget.reviewCount,
          'createdAt': DateTime.now().toIso8601String(),
          'lat': widget.lat, // Save latitude
          'lng': widget.lng, // Save longitude
        });
      }

      setState(() {
        _isSavedFuture = Future.value(!currentStatus);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentStatus
                ? 'Saved ${widget.placeName} to your places'
                : 'Removed ${widget.placeName} from saved places',
          ),
        ),
      );
      if (widget.onChanged != null) {
        widget.onChanged!();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving place: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isSavedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return IconButton(
            icon: Icon(Icons.bookmark_border, color: Colors.grey),
            onPressed: null,
          );
        }

        final isSaved = snapshot.data ?? false;

        return IconButton(
          icon: Icon(
            isSaved ? Icons.bookmark : Icons.bookmark_border,
            color: isSaved ? Colors.blue : Colors.grey,
          ),
          onPressed: () => _toggleSave(isSaved),
        );
      },
    );
  }
}

class EditTripPage extends StatefulWidget {
  final String tripId;
  final String currentName;
  final Function(String newName) onSave;
  final Function() onDelete;

  const EditTripPage({
    Key? key,
    required this.tripId,
    required this.currentName,
    required this.onSave,
    required this.onDelete,
  }) : super(key: key);

  @override
  _EditTripPageState createState() => _EditTripPageState();
}

class _EditTripPageState extends State<EditTripPage> {
  late TextEditingController _nameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Trip'),
            content: Text(
              'Are you sure you want to delete this trip? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      widget.onDelete();
      Navigator.pop(context); // Close the edit page
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Trip'),
        actions: [
          IconButton(
            icon:
                _isSaving
                    ? CircularProgressIndicator(color: Colors.white)
                    : Icon(Icons.save),
            onPressed:
                _isSaving
                    ? null
                    : () async {
                      if (_nameController.text.trim().isNotEmpty) {
                        setState(() => _isSaving = true);
                        await widget.onSave(_nameController.text.trim());
                        Navigator.pop(
                          context,
                          _nameController.text.trim(),
                        ); // Return the new name
                      }
                    },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Trip Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _confirmDelete,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Delete Trip'),
            ),
          ],
        ),
      ),
    );
  }
}

class SampleTripsPage extends StatelessWidget {
  static const routeName = '/sampleTrips';

  final List<Map<String, dynamic>> sampleTrips = [
    {
      'id': '1',
      'name': 'Weekend in Penang',
      'description': 'Explore the best of Penang in 2 days',
      'image': 'assets/images/sample_penang.jpg',
      'itinerary': [
        {
          'day': 1,
          'activities': [
            {
              'name': 'Visit Kek Lok Si Temple',
              'time': '09:00',
              'notes': 'Largest Buddhist temple in Malaysia',
            },
            {
              'name': 'Lunch at Gurney Drive',
              'time': '12:30',
              'notes': 'Try local hawker food',
            },
            {
              'name': 'Explore George Town Street Art',
              'time': '14:00',
              'notes': 'Walk around the heritage area',
            },
          ],
        },
        {
          'day': 2,
          'activities': [
            {
              'name': 'Penang Hill',
              'time': '08:00',
              'notes': 'Take the funicular train up',
            },
            {
              'name': 'Batu Ferringhi Beach',
              'time': '13:00',
              'notes': 'Relax by the beach',
            },
          ],
        },
      ],
    },
    {
      'id': '2',
      'name': 'Kuala Lumpur City Tour',
      'description': 'Experience the highlights of KL',
      'image': 'assets/images/sample_kl.jpg',
      'itinerary': [
        {
          'day': 1,
          'activities': [
            {
              'name': 'Petronas Twin Towers',
              'time': '10:00',
              'notes': 'Visit the observation deck',
            },
            {
              'name': 'Batu Caves',
              'time': '14:00',
              'notes': 'Climb the colorful steps',
            },
          ],
        },
      ],
    },
    // Add more sample trips as needed
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sample Trips'),
        backgroundColor: Color(0xFF628EFF),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: sampleTrips.length,
        itemBuilder: (context, index) {
          final trip = sampleTrips[index];
          return Card(
            margin: EdgeInsets.only(bottom: 16),
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              leading:
                  trip['image'] != null
                      ? Image.asset(
                        trip['image'],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                      : Icon(Icons.trip_origin, size: 50),
              title: Text(
                trip['name'],
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(trip['description']),
              trailing: Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SampleTripDetailsPage(trip: trip),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class SampleTripDetailsPage extends StatelessWidget {
  final Map<String, dynamic> trip;

  const SampleTripDetailsPage({Key? key, required this.trip}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(trip['name']),
        backgroundColor: Color(0xFF628EFF),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please sign in to save trips')),
                );
                return;
              }

              try {
                // Convert sample itinerary to database format
                List<Map<String, dynamic>> formattedItinerary = [];

                for (var day in trip['itinerary'] ?? []) {
                  for (var activity in day['activities'] ?? []) {
                    formattedItinerary.add({
                      'place': {
                        'id':
                            activity['id'] ??
                            'place_${DateTime.now().millisecondsSinceEpoch}',
                        'name': activity['name'] ?? 'Unnamed Activity',
                        'type': activity['type'] ?? 'attraction',
                        'destination': trip['name'] ?? 'Unknown Destination',
                        'imageUrl': activity['imageUrl'],
                        'rating': activity['rating']?.toDouble() ?? 4.0,
                        'reviewCount': activity['reviewCount'] ?? 0,
                      },
                      'date':
                          DateTime.now()
                              .add(Duration(days: day['day'] ?? 0))
                              .toIso8601String(),
                      'arrivalTime': activity['time'] ?? '12:00',
                      'notes': activity['notes'],
                    });
                  }
                }

                await MongoDatabase.saveTrip(user.uid, {
                  'name': trip['name'] ?? 'New Trip',
                  'itinerary': formattedItinerary,
                  'isSample': true,
                  'createdAt': DateTime.now(),
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Trip saved successfully!')),
                );
                Navigator.pop(context, true);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to save trip: ${e.toString()}'),
                  ),
                );
                print('Error saving trip: $e');
                print('Trip data: ${trip.toString()}');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trip['image'] != null)
              Image.asset(
                trip['image'],
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            SizedBox(height: 16),
            Text(trip['description'], style: TextStyle(fontSize: 16)),
            SizedBox(height: 24),
            Text(
              'Itinerary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ..._buildItinerary(trip['itinerary']),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildItinerary(List<dynamic> itinerary) {
    List<Widget> widgets = [];
    for (var day in itinerary) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Day ${day['day']}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ...day['activities'].map<Widget>((activity) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 8, left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16),
                          SizedBox(width: 8),
                          Text(
                            activity['time'],
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(activity['name'], style: TextStyle(fontSize: 16)),
                      if (activity['notes'] != null &&
                          activity['notes'].isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(left: 24, top: 4),
                          child: Text(
                            activity['notes'],
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}

// trip_picture_type.dart
enum TripPictureType { beach, city, mountain, cultural, food, none }

extension TripPictureTypeExtension on TripPictureType {
  String get assetPath {
    switch (this) {
      case TripPictureType.beach:
        return 'assets/trip_images/beach.jpg';
      case TripPictureType.city:
        return 'assets/trip_images/city.jpg';
      case TripPictureType.mountain:
        return 'assets/trip_images/mountain.jpg';
      case TripPictureType.cultural:
        return 'assets/trip_images/cultural.jpg';
      case TripPictureType.food:
        return 'assets/trip_images/food.jpg';
      case TripPictureType.none:
        return 'assets/trip_images/none.jpg';
    }
  }

  String get displayName {
    switch (this) {
      case TripPictureType.beach:
        return 'Beach';
      case TripPictureType.city:
        return 'City';
      case TripPictureType.mountain:
        return 'Mountain';
      case TripPictureType.cultural:
        return 'Cultural';
      case TripPictureType.food:
        return 'Food';
      case TripPictureType.none:
        return 'None';
    }
  }
}

class PlanPage extends StatefulWidget {
  //Plan page
  @override
  _PlanPageState createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  List<Map<String, dynamic>> _userTrips = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserTrips();
  }

  Future<void> _loadUserTrips() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final trips = await MongoDatabase.getUserTrips(user.uid);
      setState(() => _userTrips = trips);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load trips: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatTripDates(Map<String, dynamic> trip) {
    // Extract dates from itinerary if available
    if (trip['itinerary'] != null && (trip['itinerary'] as List).isNotEmpty) {
      List<DateTime> dates = [];

      for (var item in trip['itinerary']) {
        if (item['date'] != null) {
          // Convert the date string to DateTime
          DateTime date;
          if (item['date'] is String) {
            date = DateTime.parse(item['date']);
          } else {
            // Handle MongoDB date format if needed
            date = DateTime.fromMillisecondsSinceEpoch(
              item['date']['\$date'] is int
                  ? item['date']['\$date']
                  : int.parse(item['date']['\$date']['\$numberLong']),
            );
          }

          // Add only unique dates
          if (!dates.any(
            (d) =>
                d.year == date.year &&
                d.month == date.month &&
                d.day == date.day,
          )) {
            dates.add(date);
          }
        }
      }

      dates.sort();

      if (dates.isNotEmpty) {
        final startDate = dates.first;
        final endDate = dates.last;

        // Format the dates
        final startDay = startDate.day;
        final endDay = endDate.day;
        final month = _getMonthName(endDate.month);
        final year = endDate.year;

        return '$startDay - $endDay $month $year';
      }
    }

    // Default if no dates available
    return 'No dates set';
  }

  String _getMonthName(int month) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return monthNames[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Trip list - now extends to the full height of the screen
          if (_userTrips.isEmpty && !_isLoading)
            Center(
              child: Text(
                "No trips created yet!\nStart by creating your first trip.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          if (_userTrips.isNotEmpty)
            ListView.builder(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                180,
              ), // Add bottom padding for the buttons
              itemCount: _userTrips.length,
              itemBuilder: (context, index) {
                final trip = _userTrips[index];
                return GestureDetector(
                  onTap: () async {
                    final shouldRefresh = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => TripDetailsPage(
                              tripName: trip['name'],
                              tripData: trip,
                            ),
                      ),
                    );
                    if (shouldRefresh == true && mounted) {
                      _loadUserTrips();
                    }
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          // Trip image
                          Container(
                            height: 180,
                            width: double.infinity,
                            child:
                                trip['pictureType'] != null
                                    ? Image.asset(
                                      TripPictureType.values
                                          .firstWhere(
                                            (e) =>
                                                e.toString() ==
                                                trip['pictureType'],
                                            orElse: () => TripPictureType.none,
                                          )
                                          .assetPath,
                                      fit: BoxFit.cover,
                                    )
                                    : Image.asset(
                                      'assets/trip_images/default_trip.jpg', // Add a default image
                                      fit: BoxFit.cover,
                                    ),
                          ),

                          // Places count badge
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${trip['itinerary']?.length ?? 0} places',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),

                          // Trip details at bottom
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trip['name'],
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _formatTripDates(trip),
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          // Buttons at the bottom in a floating container
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF5856D6),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    onPressed: () async {
                      final shouldRefresh = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (context) => TripPage()),
                      );
                      if (shouldRefresh == true && mounted) {
                        _loadUserTrips(); // Refresh the trip list
                      }
                    },
                    child: Text(
                      "Create a trip +",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF5856D6),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SavedPlacesPage(),
                        ),
                      );
                    },
                    child: Text(
                      "View Saved Places",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF5856D6),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    onPressed: () async {
                      final shouldRefresh = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TripGeneratorScreen(),
                        ),
                      );
                      if (shouldRefresh == true && mounted) {
                        _loadUserTrips(); // Refresh the trip list
                      }
                    },
                    child: Text(
                      "Build a trip with AI",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Show loading indicator if loading
          if (_isLoading) Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
