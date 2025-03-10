import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert'; // For JSON encoding/decoding
import 'package:http/http.dart' as http; // For HTTP requests
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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

// Register Page with Toast
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

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isSearching = false;
  TextEditingController _searchController = TextEditingController();
  List<int> _navigationHistory = [];
  String? userId; // Store user ID dynamically

  @override
  void initState() {
    super.initState();
    _fetchUserId(); // Fetch user ID when home screen loads
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
      HomeContent(),
      PlanPage(),
      TripPage(),
      ProfilePage(userId: userId!), // ✅ Now it's safe to pass userId
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
                    hintText: "Search...",
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
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

class HomeContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Recently Viewed", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Container(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(
                width: 120,
                margin: EdgeInsets.only(left: 16, right: index == 4 ? 16 : 0),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text("Place ${index + 1}", style: TextStyle(color: Colors.white, fontSize: 18))),
              );
            },
          ),
        ),
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
  TextEditingController _tripNameController = TextEditingController();

  void _createTrip() {
    String tripName = _tripNameController.text.trim();
    if (tripName.isNotEmpty) {
      // TODO: Implement trip creation logic
      print("New Trip Created: $tripName");
      // You can navigate or save trip details here
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Place a cool name for your Trip",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 40),
            TextField(
              controller: _tripNameController,
              decoration: InputDecoration(
                hintText: "Exp: Weekend in Penang Island",
                border: OutlineInputBorder(),
                filled: true,

                fillColor: Colors.grey[200],
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ElevatedButton(
                onPressed: _createTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5856D6),
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15), // Button rounded border
                  ),
                ),
                child: Text("Create a New Trip", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
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
  late Future<Map<String, dynamic>> _userData;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _userData = fetchUserData(widget.userId);
  }

  Future<Map<String, dynamic>> fetchUserData(String userId) async {
    final response = await http.get(Uri.parse("http://192.168.0.10:3000/user/$userId"));
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
      await _uploadProfilePicture();
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_imageFile == null) return;
    var request = http.MultipartRequest(
      "POST",
      Uri.parse("http://192.168.0.10:3000/uploadProfilePic/${widget.userId}")
    );
    request.files.add(await http.MultipartFile.fromPath("profilePic", _imageFile!.path));

    var response = await request.send();
    if (response.statusCode == 200) {
      showToast("Profile picture updated!");
      setState(() {
        _userData = fetchUserData(widget.userId);
      });
    } else {
      showToast("Upload failed!");
    }
  }

  void showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _userData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error loading data"));
          } else if (!snapshot.hasData) {
            return Center(child: Text("No user data found"));
          }

          final userData = snapshot.data!;
          String profileImageUrl = userData["profile_picture"] != null
              ? "http://192.168.0.10:3000${userData["profile_picture"]}"
              : "assets/profile_placeholder.png";

          return Column(
            children: [
              SizedBox(height: 30),
              GestureDetector(
                onTap: _pickImage,  // Tap profile picture to change
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
              _buildProfileOption(Icons.person, "Profile", context, ProfileDetailsPage(userId: widget.userId)),
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
                  onPressed: () {
                    // TODO: Implement logout function
                  },
                  child: Text("Log Out", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

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
  final String userId;
  ProfileDetailsPage({required this.userId});

  @override
  _ProfileDetailsPageState createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  late Future<Map<String, dynamic>> _userData;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _userData = fetchUserData(widget.userId);
  }

  Future<Map<String, dynamic>> fetchUserData(String userId) async {
    final response = await http.get(Uri.parse("http://192.168.0.10:3000/user/$userId"));
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
      await _uploadProfilePicture();
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_imageFile == null) return;

    var request = http.MultipartRequest(
      "POST",
      Uri.parse("http://192.168.0.10:3000/uploadProfilePic/${widget.userId}")
    );
    request.files.add(await http.MultipartFile.fromPath("profilePic", _imageFile!.path));

    var response = await request.send();
    if (response.statusCode == 200) {
      showToast("Profile picture updated!");
      setState(() {
        _userData = fetchUserData(widget.userId);
      });
    } else {
      showToast("Upload failed!");
    }
  }

  void showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile Details"),
        centerTitle: true,
        toolbarHeight: 80,
        backgroundColor: Color(0xFF628EFF),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              // TODO: Implement edit profile function
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _userData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error loading data"));
          } else if (!snapshot.hasData) {
            return Center(child: Text("No user data found"));
          }

          final userData = snapshot.data!;
          String profileImageUrl = userData["profile_picture"] != null
              ? "http://192.168.0.10:3000${userData["profile_picture"]}"
              : "assets/profile_placeholder.png";

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header Row (Profile Pic + User Details)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Profile Picture (Tap to change)
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 45,
                          backgroundImage: profileImageUrl.startsWith("http")
                              ? NetworkImage(profileImageUrl)
                              : AssetImage(profileImageUrl) as ImageProvider,
                        ),
                      ),
                      SizedBox(width: 15),

                      // User Details
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userData["username"], style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          SizedBox(height: 5),
                          Text("Gender: ${userData["gender"]}", style: TextStyle(fontSize: 16, color: Colors.grey)),
                          SizedBox(height: 5),
                          Text("Phone: ${userData["phone"]}", style: TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),

                  SizedBox(height: 30),

                  // Biography Section
                  Text("Biography", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text("A passionate traveler exploring the world one trip at a time.", style: TextStyle(fontSize: 16)),

                  SizedBox(height: 40),

                  // Photos Section (With Card for Emphasis)
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 3,
                    child: Padding(
                      padding: EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Photos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF5856D6),
                              minimumSize: Size(double.infinity, 50),
                            ),
                            onPressed: () {
                              // TODO: Implement photo upload function
                            },
                            child: Text("Upload a photo", style: TextStyle(fontSize: 16, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 30),

                  // Reviews Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    padding: EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF5856D6),
                            minimumSize: Size(double.infinity, 50),
                          ),
                          onPressed: () {
                            // TODO: Implement write review function
                          },
                          child: Text("Write a review", style: TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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