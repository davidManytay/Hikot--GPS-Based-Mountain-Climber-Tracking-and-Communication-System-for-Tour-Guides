import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/hiker.dart';
import '../theme/app_theme.dart';

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
          backgroundColor: HikotColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
          title: Column(
            children: [
              const Text('REGISTER PERSONNEL', style: HikotTextStyles.label),
              const SizedBox(height: 12),
              Container(height: 1, width: 40, color: HikotColors.primary.withOpacity(0.5)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameController, 'FULL NAME', Icons.person_outline),
              const SizedBox(height: 16),
              _buildDialogField(deviceIdController, 'DEVICE ID (e.g., node-01)', Icons.sensors_outlined),
            ],
          ),
          actionsPadding: const EdgeInsets.all(20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text('CANCEL', style: TextStyle(color: HikotColors.textSecondary, letterSpacing: 0.5))
            ),
            ElevatedButton(
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
                backgroundColor: HikotColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('DEPLOY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: HikotColors.accent, size: 18),
        labelText: hint,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, letterSpacing: 1),
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: HikotColors.primary, width: 1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HikotColors.darkBackground,
      appBar: AppBar(
        title: const Text('TEAM ROSTER', style: HikotTextStyles.label),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          _hikers.isEmpty 
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                itemCount: _hikers.length,
                itemBuilder: (context, index) => _buildHikerCard(_hikers[index]),
              ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addHiker,
        backgroundColor: HikotColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.white.withOpacity(0.05))),
        icon: const Icon(Icons.person_add_outlined, size: 20),
        label: const Text('ADD PERSONNEL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 10)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 24),
          Text('NO PERSONNEL REGISTERED', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildHikerCard(Hiker hiker) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: HikotColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Personnel Icon
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: HikotColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.person, color: HikotColors.accent, size: 24),
              ),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hiker.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(hiker.deviceId, style: const TextStyle(color: HikotColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1))),
                      const SizedBox(width: 8),
                      Text('REGISTERED', style: TextStyle(color: HikotColors.success.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            IconButton(
              icon: Icon(Icons.delete_outline, color: HikotColors.error.withOpacity(0.4), size: 20),
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
    );
  }
}

