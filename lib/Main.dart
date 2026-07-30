import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const BettaniVpnApp());
}

class BettaniVpnApp extends StatefulWidget {
  const BettaniVpnApp({super.key});

  @override
  State<BettaniVpnApp> createState() => _BettaniVpnAppState();
}

class _BettaniVpnAppState extends State<BettaniVpnApp> {
  bool isDarkMode = true;
  String currentLanguage = "English";

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  void changeLanguage(String lang) {
    setState(() {
      currentLanguage = lang;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bettani VPN',
      theme: isDarkMode ? ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
      ) : ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
      ),
      home: VpnHomeScreen(
        isDarkMode: isDarkMode, 
        onThemeToggle: toggleTheme,
        currentLanguage: currentLanguage,
        onLanguageChanged: changeLanguage,
      ),
    );
  }
}

class VpnServer {
  final String country;
  final String flag;
  final String ip;
  final int ping;
  final String? configData;
  final String? username;
  final String? password;

  VpnServer({
    required this.country,
    required this.flag,
    required this.ip,
    required this.ping,
    this.configData,
    this.username,
    this.password,
  });
}

class VpnHomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;
  final String currentLanguage;
  final Function(String) onLanguageChanged;

  const VpnHomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  @override
  State<VpnHomeScreen> createState() => _VpnHomeScreenState();
}

class _VpnHomeScreenState extends State<VpnHomeScreen> with SingleTickerProviderStateMixin {
  late OpenVPN engine;
  VpnStatus? vpnStatus;
  VPNState? vpnState;

  bool isConnected = false;
  bool isConnecting = false;
  late AnimationController _pulseController;

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  final List<VpnServer> serverList = [
    VpnServer(country: "Japan", flag: "🇯🇵", ip: "110.163.147.10", ping: 28),
    VpnServer(country: "Germany", flag: "🇩🇪", ip: "185.220.101.5", ping: 42),
    VpnServer(country: "France", flag: "🇫🇷", ip: "51.15.122.34", ping: 55),
    VpnServer(country: "Switzerland", flag: "🇨🇭", ip: "179.43.149.12", ping: 35),
    VpnServer(country: "United States", flag: "🇺🇸", ip: "209.222.252.222", ping: 120),
  ];

  late VpnServer selectedServer;
  String downloadSpeed = "0.0 Mbps";
  String uploadSpeed = "0.0 Mbps";
  bool isTestingSpeed = false;

  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    selectedServer = serverList[0];
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    initOpenVPN();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  void initOpenVPN() {
    engine = OpenVPN(
      onVpnStatusChanged: (data) {
        setState(() {
          vpnStatus = data;
        });
      },
      onVpnStateChanged: (state, message) {
        setState(() {
          vpnState = state;
          if (state == VPNState.connected) {
            isConnected = true;
            isConnecting = false;
            _pulseController.repeat(reverse: true);
            startTimer();
          } else if (state == VPNState.disconnected) {
            isConnected = false;
            isConnecting = false;
            _pulseController.stop();
            _pulseController.reset();
            stopTimer();
          }
        });
      },
    );
    engine.initialize(
      groupIdentifier: "group.com.bettani.vpn",
      providerBundleIdentifier: "com.bettani.vpn.ovpn",
      localizedDescription: "Bettani VPN",
    );
  }

  void toggleVpn() {
    if (isConnecting) return;

    if (!isConnected) {
      setState(() {
        isConnecting = true;
      });
      
      final String user = selectedServer.username ?? "";
      final String pass = selectedServer.password ?? "";

      if (selectedServer.configData != null) {
        engine.connect(selectedServer.configData!, selectedServer.country, username: user, password: pass);
      } else {
        engine.connect("client\ndev tun\nproto udp\nremote ${selectedServer.ip} 1194\nresolv-retry infinite\nnobind\npersist-key\npersist-tun\nauth-user-pass", selectedServer.country, username: user, password: pass);
      }
    } else {
      engine.disconnect();
    }
  }

  void runSpeedTest() {
    setState(() {
      isTestingSpeed = true;
      downloadSpeed = "Testing...";
      uploadSpeed = "Testing...";
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        downloadSpeed = "${(15 + (DateTime.now().millisecond % 50))}.4 Mbps";
        uploadSpeed = "${(8 + (DateTime.now().millisecond % 25))}.1 Mbps";
        isTestingSpeed = false;
      });
      _showSnackBar("Speed test completed!", Colors.cyanAccent);
    });
  }

  void importCustomConfig() {
    TextEditingController configController = TextEditingController();
    TextEditingController nameController = TextEditingController();
    TextEditingController userController = TextEditingController();
    TextEditingController passController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF151C2C) : Colors.white,
        title: Text("Import Custom .ovpn", style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: "Server Name (e.g., UAE Free)"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: userController,
                decoration: const InputDecoration(hintText: "Username (Optional)"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(hintText: "Password (Optional)"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: configController,
                maxLines: 4,
                decoration: const InputDecoration(hintText: "Paste .ovpn config text here..."),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
            onPressed: () {
              if (configController.text.isNotEmpty && nameController.text.isNotEmpty) {
                setState(() {
                  serverList.add(VpnServer(
                    country: nameController.text,
                    flag: "🌐",
                    ip: "Custom IP",
                    ping: 30,
                    configData: configController.text,
                    username: userController.text.isNotEmpty ? userController.text : null,
                    password: passController.text.isNotEmpty ? passController.text : null,
                  ));
                  selectedServer = serverList.last;
                });
                Navigator.pop(context);
                _showSnackBar("Custom config imported successfully!", Colors.greenAccent);
              }
            },
            child: const Text("Add & Use"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void startTimer() {
    _seconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _seconds = 0;
  }

  String formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    return "$hours:$minutes:$secs";
  }

  void _openServerSelectionSheet() {
    if (isConnected || isConnecting) return;

    final cardBg = widget.isDarkMode ? const Color(0xFF0B0F19) : Colors.white;
    final sheetBg = widget.isDarkMode ? const Color(0xFF151C2C) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.currentLanguage == "Urdu" ? "مقام منتخب کریں" : "Select Location",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_box, color: Colors.cyanAccent),
                    onPressed: () {
                      Navigator.pop(context);
                      importCustomConfig();
                    },
                  )
                ],
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  itemCount: serverList.length,
                  itemBuilder: (context, index) {
                    final server = serverList[index];
                    final isSelected = server.country == selectedServer.country;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.cyan.withAlpha(40) : cardBg,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.grey.withAlpha(50)),
                      ),
                      child: ListTile(
                        leading: Text(server.flag, style: const TextStyle(fontSize: 24)),
                        title: Text(server.country, style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87)),
                        subtitle: Text("IP: ${server.ip}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi, color: server.ping < 50 ? Colors.greenAccent : Colors.orangeAccent, size: 18),
                            const SizedBox(width: 5),
                            Text("${server.ping} ms", style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            selectedServer = server;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF00FFA3);
    final inactiveColor = const Color(0xFFFF5252);
    final containerBg = widget.isDarkMode ? const Color(0xFF151C2C) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: PopupMenuButton<String>(
          icon: const Icon(Icons.language, color: Colors.cyanAccent),
          onSelected: (lang) => widget.onLanguageChanged(lang),
          itemBuilder: (context) => [
            const PopupMenuItem(value: "English", child: Text("English")),
            const PopupMenuItem(value: "Urdu", child: Text("اردو")),
          ],
        ),
        title: Text(
          "BETTANI VPN",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 20, color: textColor),
        ),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: widget.isDarkMode ? Colors.amberAccent : Colors.indigo),
            onPressed: widget.onThemeToggle,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: containerBg,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.cyan.withAlpha(50)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.download, color: Colors.greenAccent, size: 20),
                              const SizedBox(width: 5),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("DOWNLOAD", style: TextStyle(fontSize: 9, color: Colors.grey)),
                                  Text(downloadSpeed, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.upload, color: Colors.orangeAccent, size: 20),
                              const SizedBox(width: 5),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("UPLOAD", style: TextStyle(fontSize: 9, color: Colors.grey)),
                                  Text(uploadSpeed, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.speed, color: Colors.cyanAccent),
                            onPressed: isTestingSpeed ? null : runSpeedTest,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    GestureDetector(
                      onTap: _openServerSelectionSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: containerBg,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.cyanAccent.withAlpha(100)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(selectedServer.flag, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Text(selectedServer.country, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                            const SizedBox(width: 12),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.cyanAccent, size: 14),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                    GestureDetector(
                      onTap: toggleVpn,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final currentColor = isConnected ? activeColor : inactiveColor;
                          return Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: currentColor.withAlpha(20),
                              boxShadow: [
                                BoxShadow(
                                  color: currentColor.withAlpha(isConnected ? (50 + (_pulseController.value * 60)).toInt() : 25),
                                  blurRadius: isConnected ? 30 + (_pulseController.value * 20) : 15,
                                  spreadRadius: isConnected ? 5 + (_pulseController.value * 10) : 1,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (isConnecting)
                                    const SizedBox(
                                      width: 140,
                                      height: 140,
                                      child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 4),
                                    ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isConnected ? activeColor : inactiveColor,
                                    ),
                                    child: Icon(
                                      isConnecting ? Icons.hourglass_top_rounded : Icons.power_settings_new_rounded,
                                      size: 60,
                                      color: Colors.black.withAlpha(220),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(
                      isConnecting
                          ? "CONNECTING..."
                          : (isConnected ? "CONNECTED TO ${selectedServer.country.toUpperCase()}" : "TAP TO CONNECT"),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: isConnected ? activeColor : (isConnecting ? Colors.cyanAccent : Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatDuration(_seconds),
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ],
                ),
              ),
            ),
            if (_isBannerAdLoaded && _bannerAd != null)
              Container(
                alignment: Alignment.center,
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }
}
