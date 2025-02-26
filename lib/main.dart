import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

void main() {
  runApp(MyApp());
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

class LoginPage extends StatelessWidget {
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
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LocationPermissionPage()),
              );
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
                decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder()),
              ),
              SizedBox(height: 15),

              TextField(
                obscureText: true,
                decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder()),
              ),
              SizedBox(height: 10),

              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ForgotPasswordPage()));
                },
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text("Forgot Password?", style: TextStyle(color: Colors.blue, fontSize: 14)),
                ),
              ),
              SizedBox(height: 10),

              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterPage()));
                },
                child: Text("Not having an account yet? Register here", style: TextStyle(color: Colors.blue, fontSize: 14)),
              ),
              SizedBox(height: 30),

              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5856D6), minimumSize: Size(double.infinity, 50)),
                onPressed: () {
                  showToast("Login successful!");
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LocationPermissionPage()));
                },
                child: Text("Login", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              SizedBox(height: 20),

              Text("Or continue with"),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  showToast("Google login coming soon!");
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
class RegisterPage extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    String? selectedGender;
    return Scaffold(
      appBar: AppBar(title: Text("Registration"), centerTitle: true, backgroundColor: Color(0xFF628EFF)),
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Register", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              SizedBox(height: 30),

              TextField(
                decoration: InputDecoration(labelText: "Username", border: OutlineInputBorder()),
              ),
              SizedBox(height: 15),

              TextField(
                decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder()),
              ),
              SizedBox(height: 15),

              TextField(
                decoration: InputDecoration(labelText: "Phone Number", border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 15),

              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
                value: selectedGender,
                items: ["Male", "Female", "Other"].map((String gender) {
                  return DropdownMenuItem<String>(
                    value: gender,
                    child: Text(gender),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  selectedGender = newValue;
                },
              ),
              SizedBox(height: 15),

              TextField(
                obscureText: true,
                decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder()),
              ),
              SizedBox(height: 15),

              TextField(
                obscureText: true,
                decoration: InputDecoration(labelText: "Confirm Password", border: OutlineInputBorder()),
              ),
              SizedBox(height: 10),

              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Text("Already have an account? Login here", style: TextStyle(color: Colors.blue, fontSize: 14)),
              ),
              SizedBox(height: 30),

              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5856D6), minimumSize: Size(double.infinity, 50)),
                onPressed: () {
                  showToast("Registration successful!"); // Show toast message
                  Navigator.pop(context);
                },
                child: Text("Register", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Forgot Password Page (No Toast needed)
class ForgotPasswordPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Forgot Password"), centerTitle: true, backgroundColor: Color(0xFF628EFF)),
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Enter your email to reset password", style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
              SizedBox(height: 20),

              TextField(
                decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder()),
              ),
              SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5856D6), minimumSize: Size(double.infinity, 50)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Reset link sent to your email")));
                  Navigator.pop(context);
                },
                child: Text("Reset Password", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LocationPermissionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Enable Location"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                "Discover traveller recommended spots near you, wherever you are.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24),
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5856D6), minimumSize: Size(200, 50)),
              onPressed: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => NotificationPermissionPage()));
              },
              child: Text("Enable Location", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            SizedBox(height: 15),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => NotificationPermissionPage()));
              },
              child: Text(
                "Not Now",
                style: TextStyle(fontSize: 16, color: Colors.black, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationPermissionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Enable Notifications"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                "Get updates on the latest price drops and deals for your trip!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24),
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5856D6), minimumSize: Size(200, 50)),
              onPressed: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomePage()));
              },
              child: Text("Enable Notifications", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            SizedBox(height: 15),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomePage()));
              },
              child: Text(
                "Not Now",
                style: TextStyle(fontSize: 16, color: Colors.black, decoration: TextDecoration.underline),
              ),
            ),
          ],
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
  int _selectedIndex = 0; // Track selected tab
  bool _isSearching = false; // Track if user is in search mode
  TextEditingController _searchController = TextEditingController();
  List<int> _navigationHistory = []; // Track visited pages

  final List<String> _pageTitles = ["Home", "Plan", "Trip", "Account"];
  final List<Widget> _pages = [
    HomeContent(),
    PlanPage(),
    TripPage(),
    ProfilePage(),
  ];

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
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20)
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

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: 30),
          CircleAvatar(
            radius: 50,
            backgroundImage: AssetImage("assets/profile_placeholder.png"),
          ),
          SizedBox(height: 10),
          Text("Username", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          _buildProfileOption(Icons.calendar_today, "Bookings", context, BookingsPage()),
          _buildProfileOption(Icons.person, "Profile", context, ProfileDetailsPage()),
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
      ),
    );
  }

  Widget _buildProfileOption(IconData icon, String title, BuildContext context, Widget page) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: TextStyle(fontSize: 18)),
      trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black54),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
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

class ProfileDetailsPage extends StatelessWidget {
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header Row (Profile Pic + User Details)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Picture
                  CircleAvatar(
                    radius: 45,
                    backgroundImage: AssetImage("assets/profile_placeholder.png"), // Replace with actual profile image
                  ),
                  SizedBox(width: 15),

                  // User Details
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Username", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(height: 5),
                      Text("Joined: 2022", style: TextStyle(fontSize: 16, color: Colors.grey)),
                      SizedBox(height: 5),
                      Text("Location: Kuala Lumpur, Malaysia", style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                ],
              ),

              // **Added more space below profile details**
              SizedBox(height: 30),

              // Biography Section
              Text("Biography", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text(
                "A passionate traveler exploring the world one trip at a time.",
                style: TextStyle(fontSize: 16),
              ),

              // **Added more space before sections**
              SizedBox(height: 40),

              // **Photos Section (With Card for Emphasis)**
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

              // **More spacing between sections**
              SizedBox(height: 30),

              // **Reviews Section (More Visible with Background Color)**
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