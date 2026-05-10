import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/hiker.dart';

class HikerListScreen extends StatefulWidget {
  const HikerListScreen({super.key});

  @override
  State<HikerListScreen> createState() => _HikerListScreenState();
}

class _HikerListScreenState extends State<HikerListScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Hiker> _hikers = [];

  @override
  void initState() {
    super.initState();
    _loadHikers();
  }

  Future<void> _loadHikers() async {
    final hikers = await _db.getHikers();
    setState(() {
      _hikers = hikers;
    });
  }

  Future<void> _addHiker() async {
    final nameController = TextEditingController();
    final deviceIdController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AlertDialog(
          backgroundColor: const Color(0xFF0F172A).withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: Column(
            children: [
              const Text('REGISTER PERSONNEL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
              const SizedBox(height: 8),
              Container(height: 2, width: 40, color: Colors.blueAccent),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameController, 'FULL NAME', Icons.person_outline),
              const SizedBox(height: 16),
              _buildDialogField(deviceIdController, 'DEVICE ID (hikot-xx)', Icons.sensors_outlined),
            ],
          ),
          actionsPadding: const EdgeInsets.all(20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text('ABORT', style: TextStyle(color: Colors.white.withOpacity(0.4), letterSpacing: 1, fontWeight: FontWeight.bold))
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 10)],
              ),
              child: ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty || deviceIdController.text.trim().isEmpty) {
                    return;
                  }
                  await _db.insertHiker(Hiker(
                    name: nameController.text.trim(),
                    deviceId: deviceIdController.text.trim(),
                  ));
                  if (mounted) {
                    Navigator.pop(dialogContext);
                    _loadHikers();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('DEPLOY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent.withOpacity(0.7), size: 18),
        labelText: hint,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, letterSpacing: 1),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.blueAccent)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('TEAM ROSTER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 3, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Decor
          Positioned(top: -150, right: -150, child: _buildAmbientGlow(Colors.blueAccent.withOpacity(0.05))),
          
          _hikers.isEmpty 
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 120, 20, 100),
                itemCount: _hikers.length,
                itemBuilder: (context, index) => _buildHikerCard(_hikers[index]),
              ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addHiker,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.black,
        elevation: 10,
        icon: const Icon(Icons.add_moderator_outlined),
        label: const Text('DEPLOY CLIMBER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12)),
      ),
    );
  }

  Widget _buildAmbientGlow(Color color) {
    return Container(
      width: 400, height: 400,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, Colors.transparent])),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_moon_outlined, size: 80, color: Colors.white.withOpacity(0.03)),
          const SizedBox(height: 24),
          Text('NO PERSONNEL DEPLOYED', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildHikerCard(Hiker hiker) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Personnel Avatar
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.blueAccent.withOpacity(0.2), Colors.blueAccent.withOpacity(0.2)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.1)),
                  ),
                  child: Center(
                    child: Text(
                      hiker.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hiker.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                            child: Text(hiker.deviceId, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.circle, size: 6, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(width: 8),
                          Text('ACTIVE', style: TextStyle(color: Colors.teal.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions
                IconButton(
                  icon: Icon(Icons.delete_sweep_outlined, color: Colors.redAccent.withOpacity(0.3), size: 22),
                  onPressed: () async {
                    if (hiker.id != null) {
                      await _db.deleteHiker(hiker.id!);
                      _loadHikers();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

