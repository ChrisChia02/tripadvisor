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
  final double? latitude; // Make nullable
  final double? longitude; // Make nullable

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
    this.latitude,
    this.longitude,
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    initialRoute: "/login",
    routes: {
      "/login": (context) => LoginPage(),
      "/locationPermission": (context) => LocationPermissionPage(),
      "/register": (context) => RegisterPage(), 
      "/forgotPassword": (context) => ForgotPasswordPage(),
    },
  ));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
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
  setState(() {
    _isLoading = true;
  });

  try {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    // 🔥 1. Fetch user document from Firestore
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection("User") // Check the exact name of your collection
        .where("Email", isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      showToast("User not found! Please register.");
      return;
    }

    // 🔥 2. Retrieve the user's password from Firestore
    var userData = querySnapshot.docs.first.data() as Map<String, dynamic>;

    if (userData["Password"] != password) {
      showToast("Incorrect password! Try again.");
      return;
    }

    // 🔥 3. If credentials are correct, navigate to home
    showToast("Login successful!");
    Navigator.pushReplacementNamed(context, "/locationPermission");
  } catch (e) {
    showToast("Error: ${e.toString()}");
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

/// 🔥 Google Sign-In Function
  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // User canceled sign-in

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // ✅ Check if user already exists in Firestore
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance.collection("User").doc(user.uid).get();

        if (!userDoc.exists) {
          // 🔥 If new user, create a document with email and auto-incremented user ID
          int userCount = (await FirebaseFirestore.instance.collection("User").get()).docs.length;
          String newUserID = "user${userCount + 1}";

          await FirebaseFirestore.instance.collection("User").doc(newUserID).set({
            "Email": user.email,
            "Password": "GoogleSignIn", // No password stored, just for reference
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
              Text("Login", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              SizedBox(height: 30),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder()),
              ),
              SizedBox(height: 15),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder()),
              ),
              SizedBox(height: 10),

              GestureDetector(
                onTap: () {
                  Navigator.pushReplacementNamed(context, "/forgotPassword");
                },
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text("Forgot Password?", style: TextStyle(color: Colors.blue, fontSize: 14)),
                ),
              ),
              SizedBox(height: 10),

              GestureDetector(
                onTap: () {
                  Navigator.pushReplacementNamed(context, "/register");
                },
                child: Text("Not having an account yet? Register here", style: TextStyle(color: Colors.blue, fontSize: 14)),
              ),
              SizedBox(height: 30),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5856D6),
                  minimumSize: Size(double.infinity, 50),
                ),
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Login", style: TextStyle(fontSize: 18, color: Colors.white)),
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
  final TextEditingController _confirmPasswordController = TextEditingController();
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
    UserCredential userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    String firebaseUserId = userCredential.user!.uid; // Firebase-generated unique ID

    // **STEP 2: Get next user document number for Firestore**
    QuerySnapshot userSnapshot =
        await FirebaseFirestore.instance.collection("User").get();
    int userCount = userSnapshot.docs.length + 1;
    String firestoreUserId = "user$userCount"; // e.g., user2, user3

    // **STEP 3: Store email & password in Firestore**
    await FirebaseFirestore.instance.collection("User").doc(firestoreUserId).set({
      "userID": firestoreUserId, 
      "Email": email,
      "Password": password, // 🔥 Avoid storing plaintext passwords
    });

    // **STEP 4: Store user info in MySQL via Node.js**
    final response = await http.post(
      Uri.parse("http://192.168.0.10:3000/register"), // Change to your backend URL
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "firebaseUserId": firebaseUserId, // Store Firebase UID in MySQL
        "email": email,
        "username": username,
        "gender": gender,
        "phone": phone,
      }),
    );

    if (response.statusCode == 200) {
      showToast("Registration successful!");
      Navigator.pushReplacementNamed(context, "/login");
    } else {
      showToast("MySQL error: ${response.body}");
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
                Text("Register", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                SizedBox(height: 30),

                TextField(controller: _usernameController, decoration: InputDecoration(labelText: "Username", border: OutlineInputBorder())),
                SizedBox(height: 15),

                TextField(controller: _emailController, decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder())),
                SizedBox(height: 15),

                TextField(controller: _phoneController, decoration: InputDecoration(labelText: "Phone Number", border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                SizedBox(height: 15),

                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
                  value: _selectedGender,
                  items: ["Male", "Female", "Other"].map((String gender) {
                    return DropdownMenuItem<String>(value: gender, child: Text(gender));
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedGender = newValue;
                    });
                  },
                ),
                SizedBox(height: 15),

                TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder())),
                SizedBox(height: 15),

                TextField(controller: _confirmPasswordController, obscureText: true, decoration: InputDecoration(labelText: "Confirm Password", border: OutlineInputBorder())),
                SizedBox(height: 10),

                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacementNamed(context, "/login");
                  },
                  child: Text("Already have an account? Login here", style: TextStyle(color: Colors.blue, fontSize: 14)),
                ),
                SizedBox(height: 30),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5856D6), minimumSize: Size(double.infinity, 50)),
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text("Register", style: TextStyle(fontSize: 18, color: Colors.white)),
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
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
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
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Reset Password", style: TextStyle(fontSize: 18, color: Colors.white)),
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
        SnackBar(content: Text("Location permission is required for better recommendations.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Enable Location"), centerTitle: true, backgroundColor: Color(0xFF628EFF)),
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
                child: Text("Enable Location", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              SizedBox(height: 15),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => NotificationPermissionPage()));
                },
                child: Text(
                  "Not Now",
                  style: TextStyle(fontSize: 16, color: Colors.blue, decoration: TextDecoration.underline),
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
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Notification permission is required for trip updates.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Enable Notifications"), centerTitle: true, backgroundColor: Color(0xFF628EFF)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_active, size: 100, color: Colors.orangeAccent),
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
                child: Text("Enable Notifications", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              SizedBox(height: 15),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomePage()));
                },
                child: Text(
                  "Not Now",
                  style: TextStyle(fontSize: 16, color: Colors.blue, decoration: TextDecoration.underline),
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
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

  // Function to fetch user ID from Firebase Auth
  void _fetchUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userId = user.uid; // Get Firebase Auth user ID
      });
    }
  }

  final List<String> _pageTitles = ["Home", "Plan", "Trip", "Account"];

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      _navigationHistory.add(_selectedIndex); // Save current page before switching
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
          (place) => place == result || place.toString() == result.toString()
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
      SnackBar(content: Text('Error searching for destination: $e'))
    );
  }
}

  @override
  Widget build(BuildContext context) {
    // Prevents null error by showing a loading spinner before `userId` is available
    if (userId == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()), // Show loading indicator
      );
    }

    // Pages with dynamic userId passed to ProfilePage
    final List<Widget> _pages = [
      _isSearching && _searchResult != null 
          ? _buildSearchResultsContent() 
          : HomeContent(recentSearches: _recentSearches),  // Pass recent searches here
      PlanPage(),
      TripPage(),
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
            _selectedIndex = _navigationHistory.removeLast(); // Go back to last visited page
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
          title: _isSearching
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
          leading: _selectedIndex == 0 && !_isSearching
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
        Expanded(
          child: Center(child: CircularProgressIndicator()),
        )
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
                    itemCount: _searchResult!.images.length > 0 ? _searchResult!.images.length : 1,
                    itemBuilder: (context, index) {
                      if (_searchResult!.images.isEmpty) {
                        return Container(
                          color: Colors.grey.shade300,
                          child: Center(
                            child: Text('No images available'),
                          ),
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
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade300,
                            child: Center(
                              child: Text('Image not available'),
                            ),
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

Widget _buildCategoryCard(String title, IconData icon, String subtitle, VoidCallback onTap) {
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
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
        builder: (context) => HotelsPage(
          destination: _searchResult!.name,
          hotels: _searchResult!.hotels,
        ),
      ),
    );
  } else if (categoryType == "restaurants") {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantsPage(
          destination: _searchResult!.name,
          restaurants: _searchResult!.restaurants,
        ),
      ),
    );
  } else if (categoryType == "attractions") {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttractionsPage(
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
          leading: item.thumbnail.isNotEmpty
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
                        child: Icon(Icons.image_not_supported, color: Colors.grey),
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
              Text(' ${item.rating > 0 ? item.rating.toStringAsFixed(1) : "N/A"}'),
              SizedBox(width: 8),
              Text('(${item.reviewCount > 0 ? item.reviewCount : "No"} reviews)'),
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
            leading: item.thumbnail.isNotEmpty
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
                          child: Icon(Icons.image_not_supported, color: Colors.grey),
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
                Text(' ${item.rating > 0 ? item.rating.toStringAsFixed(1) : "N/A"}'),
                SizedBox(width: 8),
                Text('(${item.reviewCount > 0 ? item.reviewCount : "No"} reviews)'),
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
    builder: (context) => Container(
      padding: EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // POI name header
          Text(
            poi.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
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
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  color: Colors.grey.shade300,
                  child: Center(child: Icon(Icons.image_not_supported)),
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

  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
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
            Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white)),
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

  HotelsPage({
    required this.destination,
    required this.hotels,
  });

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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                
                // Date selection
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "$_adults Adults, $_children Children, $_rooms Rooms",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
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
            child: widget.hotels.isEmpty
                ? Center(
                    child: Text("No hotels found in this destination"),
                  )
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
                              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                              child: hotel.thumbnail.isNotEmpty
                                  ? Image.network(
                                      hotel.thumbnail,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          height: 150,
                                          color: Colors.grey.shade300,
                                          child: Icon(Icons.image_not_supported),
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
                                      Icon(Icons.star, color: Colors.amber, size: 18),
                                      SizedBox(width: 4),
                                      Text(
                                        '${hotel.rating > 0 ? hotel.rating.toStringAsFixed(1) : "N/A"}',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(width: 8),
                                      Text('(${hotel.reviewCount} reviews)'),
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
                                      onPressed: () => _showHotelDetails(hotel),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF628EFF),
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
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
            colorScheme: ColorScheme.light(
              primary: Color(0xFF628EFF),
            ),
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
          if (_checkOutDate.isBefore(_checkInDate) || _checkOutDate.isAtSameMomentAs(_checkInDate)) {
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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

  Widget _buildCounterRow(String label, int value, Function(int) onChanged, int min, int max) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: value > min
                  ? () => onChanged(value - 1)
                  : null,
              icon: Icon(Icons.remove_circle_outline),
              color: value > min ? Color(0xFF628EFF) : Colors.grey,
            ),
            SizedBox(
              width: 40,
              child: Text(
                "$value",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: value < max
                  ? () => onChanged(value + 1)
                  : null,
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
      builder: (context) => DraggableScrollableSheet(
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
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 200,
                              color: Colors.grey.shade300,
                              child: Center(child: Icon(Icons.image_not_supported)),
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
                            _buildBookingDetail("Check-in", "${_checkInDate.day}/${_checkInDate.month}/${_checkInDate.year}"),
                            _buildBookingDetail("Check-out", "${_checkOutDate.day}/${_checkOutDate.month}/${_checkOutDate.year}"),
                            _buildBookingDetail("Guests", "$_adults Adults, $_children Children"),
                            _buildBookingDetail("Rooms", "$_rooms"),
                            Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          onPressed: () {
                            Navigator.pop(context);
                            _bookHotel(hotel);
                          },
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

  Widget _buildBookingDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
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

class RestaurantsPage extends StatefulWidget {
  final String destination;
  final List<PointOfInterest> restaurants;

  RestaurantsPage({
    required this.destination,
    required this.restaurants,
  });

  @override
  _RestaurantsPageState createState() => _RestaurantsPageState();
}

class _RestaurantsPageState extends State<RestaurantsPage> {
  String _selectedCuisine = 'All';
  List<String> _cuisineTypes = ['All', 'Italian', 'Asian', 'American', 'Mexican', 'Seafood', 'Other'];
  
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                
                // Cuisine selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _cuisineTypes.map((cuisine) {
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
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Color(0xFF628EFF) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? Color(0xFF628EFF) : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              cuisine,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
            child: widget.restaurants.isEmpty
                ? Center(
                    child: Text("No restaurants found in this destination"),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: widget.restaurants.length,
                    itemBuilder: (context, index) {
                      final restaurant = widget.restaurants[index];
                      // Dummy cuisine type data (would come from your API in a real app)
                      final cuisineType = _cuisineTypes[index % (_cuisineTypes.length - 1) + 1];
                      
                      // Filter by cuisine if not "All"
                      if (_selectedCuisine != 'All' && cuisineType != _selectedCuisine) {
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
                              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                              child: restaurant.thumbnail.isNotEmpty
                                  ? Image.network(
                                      restaurant.thumbnail,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          height: 150,
                                          color: Colors.grey.shade300,
                                          child: Icon(Icons.image_not_supported),
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
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF628EFF).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
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
                                      Icon(Icons.star, color: Colors.amber, size: 18),
                                      SizedBox(width: 4),
                                      Text(
                                        '${restaurant.rating > 0 ? restaurant.rating.toStringAsFixed(1) : "N/A"}',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(width: 8),
                                      Text('(${restaurant.reviewCount} reviews)'),
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
                                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                      SizedBox(width: 4),
                                      Text(
                                        index % 2 == 0 ? "Open now · Closes at 10PM" : "Opens tomorrow at 11AM",
                                        style: TextStyle(
                                          color: index % 2 == 0 ? Colors.green : Colors.red,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  
                                  // Reservation button
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _viewRestaurantMenu(restaurant),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: Color(0xFF628EFF)),
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: Text("View Menu"),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => _bookReservation(restaurant),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xFF628EFF),
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
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
      builder: (context) => DraggableScrollableSheet(
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
        "description": "Delicious ${title.toLowerCase()} with fresh ingredients and special sauce.",
        "price": (9.99 + (index * 2) + (title == "Main Courses" ? 10 : 0)).toStringAsFixed(2),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  item["description"],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(
            "\$${item["price"]}",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _bookReservation(PointOfInterest restaurant) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
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
                Text(restaurant.name, style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                
                // Date picker
                Text("Date", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                Text("Party Size", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      content: Text('Reservation at ${restaurant.name} confirmed!'),
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

  AttractionsPage({
    required this.destination,
    required this.attractions,
  });

  @override
  _AttractionsPageState createState() => _AttractionsPageState();
}

class _AttractionsPageState extends State<AttractionsPage> {
  String _selectedCategory = 'All';
  List<String> _categories = ['All', 'Museums', 'Parks', 'Historic Sites', 'Entertainment', 'Shopping'];
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
      enhancedList.add(PointOfInterest(
        id: enhancedAttraction.id,
        name: enhancedAttraction.name,
        category: category,
        description: enhancedAttraction.description,
        rating: enhancedAttraction.rating,
        reviewCount: enhancedAttraction.reviewCount,
        location: enhancedAttraction.location ?? widget.destination,
        imageUrl: imageUrl,
        thumbnail: thumbnail, // Include the required thumbnail parameter
        latitude: enhancedAttraction.latitude,
        longitude: enhancedAttraction.longitude,
      ));
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
    
    if (name.contains('museum') || name.contains('gallery') || name.contains('art')) {
      return 'Museums';
    } else if (name.contains('park') || name.contains('garden') || name.contains('nature')) {
      return 'Parks';
    } else if (name.contains('castle') || name.contains('monument') || 
              name.contains('historic') || name.contains('temple') || 
              name.contains('ruins') || name.contains('palace') || 
              name.contains('ancient') || name.contains('heritage')) {
      return 'Historic Sites';
    } else if (name.contains('theater') || name.contains('cinema') || 
              name.contains('entertainment') || name.contains('amusement') || 
              name.contains('fun') || name.contains('adventure')) {
      return 'Entertainment';
    } else if (name.contains('mall') || name.contains('shop') || 
              name.contains('market') || name.contains('store')) {
      return 'Shopping';
    }
    
    // Default category based on random assignment if we can't determine
    // In a real app, you might want to fetch this from an API or use more sophisticated logic
    List<String> defaultCategories = ['Museums', 'Historic Sites', 'Entertainment'];
    return defaultCategories[Random().nextInt(defaultCategories.length)];
  }
  
  Future<PointOfInterest> _enrichWithWikipediaData(PointOfInterest attraction) async {
  // We'll use your existing approach for Wikipedia data
  try {
    final String wikiUrl = 'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(attraction.name)}';
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
      if (wikiData['thumbnail']?['source'] != null && (attraction.imageUrl == null || attraction.imageUrl!.isEmpty)) {
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
        thumbnail: attraction.thumbnail, // Include the required thumbnail parameter
        latitude: attraction.latitude,
        longitude: attraction.longitude,
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                // Category selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((category) {
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
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Color(0xFF628EFF) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
            child: _isLoading
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
          Text("Loading attraction details...", style: TextStyle(color: Colors.grey)),
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
    List<PointOfInterest> displayAttractions = _enhancedAttractions.isEmpty ? 
        widget.attractions : _enhancedAttractions;
    
    // Filter attractions based on selected category
    List<PointOfInterest> filteredAttractions = _selectedCategory == 'All'
        ? displayAttractions
        : displayAttractions.where((attraction) => 
            attraction.category == _selectedCategory).toList();
    
    if (filteredAttractions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "No attractions found in this category",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
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
                child: attraction.imageUrl != null
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
                            child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
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
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / 
                                      loadingProgress.expectedTotalBytes!
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
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (attraction.reviewCount != null && attraction.reviewCount! > 0)
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
                            style: TextStyle(
                              color: Colors.grey.shade700,
                            ),
                          ),
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
                            builder: (context) => AttractionDetailsPage(attraction: attraction),
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
  
  const AttractionDetailsPage({Key? key, required this.attraction}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
    appBar: AppBar(
      title: Text('Attraction Details'),
    ),
    body: Container(),
    );
  }
}

class DestinationService {
  final String apiKey = 'AIzaSyCKlRMcBAifI8ZrUoUegs6phg370RPgWIA';
  
  Future<Destination> getDestinationInfo(String destination) async {
    try {
      // 1. First, get basic place information
      final placeResult = await _getPlaceDetails(destination);
      
      // 2. Get inspirational travel description
      final travelDescription = await _getInspirationalDescription(placeResult.name);
      
      // 3. Get hotels near the destination
      final hotels = await _getNearbyPlaces(placeResult.placeId, 'hotel');
      
      // 4. Get attractions near the destination
      final attractions = await _getNearbyPlaces(placeResult.placeId, 'tourist_attraction');
      
      // 5. Get restaurants near the destination
      final restaurants = await _getNearbyPlaces(placeResult.placeId, 'restaurant');
      
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
        'https://en.wikipedia.org/w/api.php?action=query&prop=pageimages|description&titles=$placeName&format=json&utf8=1'
      );
      
      final baseInfoResponse = await http.get(baseInfoUrl);
      final baseInfoData = json.decode(baseInfoResponse.body);
      
      // Extract the page ID from the response
      final pages = baseInfoData['query']['pages'];
      final pageId = pages.keys.first;
      
      // Now get geographical and cultural information
      final infoUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&titles=$placeName&prop=extracts&exintro=true&explaintext=true&format=json'
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
    List<String> relevantSentences = sentences.where((sentence) {
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
        description += ' Discover the unique charm and beauty that makes $placeName a must-visit destination.';
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
      "Journey to $placeName and explore its timeless beauty, cultural treasures, and hidden gems waiting to be discovered."
    ];
    
    // Return a random template
    return templates[DateTime.now().millisecondsSinceEpoch % templates.length];
  }

  Future<PlaceDetails> _getPlaceDetails(String placeName) async {
    // First, get the place ID from the name
    final findPlaceUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=$placeName&inputtype=textquery&fields=place_id,name,formatted_address,photos&key=$apiKey'
    );
    
    final findPlaceResponse = await http.get(findPlaceUrl);
    final findPlaceData = json.decode(findPlaceResponse.body);
    
    if (findPlaceData['status'] != 'OK' || findPlaceData['candidates'].isEmpty) {
      throw Exception('Place not found');
    }
    
    final placeId = findPlaceData['candidates'][0]['place_id'];
    
    // Now get detailed information about the place
    final detailsUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=name,formatted_address,photos,rating,user_ratings_total&key=$apiKey'
    );
    
    final detailsResponse = await http.get(detailsUrl);
    final detailsData = json.decode(detailsResponse.body);
    
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
          'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=$apiKey'
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
      reviewCount: result.containsKey('user_ratings_total') ? result['user_ratings_total'] : 0,
    );
  }

  Future<List<PointOfInterest>> _getNearbyPlaces(String placeId, String type) async {
    // Implementation remains the same as before
    // ...
    
    // First, get the place location (lat/lng)
    final placeUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$apiKey'
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
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=5000&type=$type&key=$apiKey'
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
        photoUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=100&photoreference=$photoReference&key=$apiKey';
      }
      
      places.add(PointOfInterest(
        id: place['place_id'],
        name: place['name'],
        rating: place.containsKey('rating') ? place['rating'].toDouble() : 0.0,
        reviewCount: place.containsKey('user_ratings_total') ? place['user_ratings_total'] : 0,
        thumbnail: photoUrl,
      ));
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
  
  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.description,
    required this.images,
    required this.rating,
    required this.reviewCount,
  });
}

class HomeContent extends StatelessWidget {
  final List<Destination> recentSearches;
  
  const HomeContent({
    Key? key,
    this.recentSearches = const [],
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Only show "Recently Viewed" section if there are items to display
        if (recentSearches.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Recently Viewed", 
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          Container(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: recentSearches.length,
              itemBuilder: (context, index) {
                final destination = recentSearches[index];
                return Container(
                  width: 120,
                  margin: EdgeInsets.only(left: 16, right: index == recentSearches.length - 1 ? 16 : 0),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      // Use whatever property Destination has that represents its name
                      // For example: destination.name, destination.title, etc.
                      destination.toString(), // Replace with actual property
                      style: TextStyle(color: Colors.white, fontSize: 18)
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class PlanPage extends StatefulWidget {
  @override
  _PlanPageState createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  bool _hasCreatedTrip = false; // Track if at least one trip is created

  void _createTrip() {
    setState(() {
      _hasCreatedTrip = true; // Enable the AI trip button after creating a trip
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5856D6),
                minimumSize: Size(250, 50),
              ),
              onPressed: _createTrip, // Enables AI button after clicking
              child: Text("Create a trip +", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5856D6),
                minimumSize: Size(250, 50),
              ),
              onPressed: _hasCreatedTrip ? () {} : null, // Disabled if no trip is created
              child: Text("Build a trip with AI", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
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

  void _navigateToTripDetails(String tripName) {
    if (tripName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a trip name!')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripDetailsPage(tripName: tripName),
      ),
    );
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
              child: const Text('Create a New Trip'),
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

class TripDetailsPage extends StatelessWidget {
  final String tripName;

  const TripDetailsPage({Key? key, required this.tripName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a Trip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 200,
            color: Colors.grey[300],
            child: const Icon(Icons.image, size: 100),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tripName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: const [
                    Text('Places saved (0)'),
                    Text('Itinerary'),
                    Text('Recommend'),
                  ],
                ),
                const Divider(),
                const ListTile(title: Text('Things to Do (0)')),
                const ListTile(title: Text('Food (0)')),
                const ListTile(title: Text('Stay (0)')),
              ],
            ),
          ),
        ],
      ),
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
      isGuest = true;
      _userData = null;
    }
  }

  Future<Map<String, dynamic>> fetchUserData(String? userId) async {
    if (userId == null) {
      return {
        "username": "Guest",
        "gender": "N/A",
        "phone": "N/A",
        "profile_picture": "assets/profile_placeholder.png"
      };
    }

    final response = await http.get(Uri.parse("http://192.168.0.7:3000/user/$userId"));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load user data");
    }
  }

  Future<void> _pickImage() async {
  final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);

  if (pickedFile != null) {
    setState(() {
      _imageFile = File(pickedFile.path);
    });
  }
}

  void showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        Text("Plan the best trip", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Text("Get travel recommendations, share reviews, and organize trip ideas.",
            textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
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
      } 
      else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
        // If error or no data found, show guest-like view
        return Center(child: Text("No user data available. Please sign in."));
      }

      final userData = snapshot.data!;
      String profileImageUrl = userData["profile_picture"] != null
          ? "http://192.168.0.7.113:3000${userData["profile_picture"]}"
          : "assets/profile_placeholder.png";

      return Column(
        children: [
          SizedBox(height: 30),
          GestureDetector(
            onTap: _pickImage,
            child: CircleAvatar(
              radius: 50,
              backgroundImage: profileImageUrl.startsWith("http")
                  ? NetworkImage(profileImageUrl)
                  : AssetImage(profileImageUrl) as ImageProvider,
            ),
          ),
          SizedBox(height: 10),
          Text(userData["username"], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text("Gender: ${userData["gender"]}"),
          Text("Phone: ${userData["phone"]}"),
          SizedBox(height: 20),
          _buildProfileOption(Icons.calendar_today, "Bookings", context, BookingsPage()),
          _buildProfileOption(Icons.person, "Profile", context, ProfileDetailsPage(userId: FirebaseAuth.instance.currentUser!.uid)),
          _buildProfileOption(Icons.notifications, "Notifications", context, NotificationsPage()),
          _buildProfileOption(Icons.settings, "Preferences", context, PreferencesPage()),
          _buildProfileOption(Icons.support, "Support", context, SupportPage()),
          Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5856D6),
                minimumSize: Size(double.infinity, 50),
              ),
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: Text("Log Out", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ),
        ],
      );
    },
  );
}


  Widget _buildProfileOption(IconData icon, String title, BuildContext context, Widget page) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: TextStyle(fontSize: 18)),
      trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black54),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => page)),
    );
  }
}

class BookingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bookings"), centerTitle: true, backgroundColor: Color(0xFF628EFF), toolbarHeight: 80),
      body: Center(child: Text("Bookings Page", style: TextStyle(fontSize: 20))),
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
    final response = await http.get(Uri.parse("http://192.168.0.7:3000/user/$userId"));
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
      body: widget.userId == null
          ? _buildGuestView(context)
          : FutureBuilder<Map<String, dynamic>>(
              future: _userData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                      child: Text(
                          "No user data found. Please sign in or try again later.",
                          style: TextStyle(color: Colors.redAccent),
                      ));
                }

                final userData = snapshot.data!;
                String profileImageUrl = userData["profile_picture"] != null
                    ? "http://192.168.0.7:3000${userData["profile_picture"]}"
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
                                backgroundImage: profileImageUrl.startsWith("http")
                                    ? NetworkImage(profileImageUrl)
                                    : AssetImage(profileImageUrl) as ImageProvider,
                              ),
                            ),
                            SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(userData["username"],
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                SizedBox(height: 5),
                                Text("Gender: ${userData["gender"]}",
                                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                                SizedBox(height: 5),
                                Text("Phone: ${userData["phone"]}",
                                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 30),
                        _buildProfileOption(Icons.settings, "Preferences", context, PreferencesPage()),
                        _buildProfileOption(Icons.support, "Support", context, SupportPage()),
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
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5856D6)),
              onPressed: () {
                Navigator.pushReplacementNamed(context, "/login");
              },
              child: Text("Sign In", style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 30),
            _buildProfileOption(Icons.settings, "Preferences", context, PreferencesPage()),
            _buildProfileOption(Icons.support, "Support", context, SupportPage()),
          ],
        ),
      ),
    );
  }

  // --- Pick Profile Image (Disabled for Guests) ---
  Future<void> _pickImage() async {
    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sign in to change profile picture.")));
      return;
    }

    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      // Upload function can be implemented here
    }
  }

  // --- Profile Options Row ---
  Widget _buildProfileOption(IconData icon, String title, BuildContext context, Widget page) {
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
      appBar: AppBar(title: Text("Notifications"), centerTitle: true, toolbarHeight: 80, backgroundColor: Color(0xFF628EFF)),
      body: Center(child: Text("Notifications Page", style: TextStyle(fontSize: 20))),
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