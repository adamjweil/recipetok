import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/poke_service.dart';
import 'dart:async';

class PokeButton extends StatefulWidget {
  final String userId;

  const PokeButton({
    super.key,
    required this.userId,
  });

  @override
  State<PokeButton> createState() => _PokeButtonState();
}

class _PokeButtonState extends State<PokeButton> {
  final _pokeService = PokeService();
  bool _isLoading = false;
  Duration? _cooldown;
  Timer? _cooldownTimer;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _checkCooldown();
    _checkFollowStatus();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkCooldown() async {
    try {
      final cooldown = await _pokeService.getCooldown(widget.userId);
      if (mounted) {
        setState(() => _cooldown = cooldown);
        
        // If there's a cooldown, start a timer to update it
        if (cooldown != null) {
          _startCooldownTimer();
        }
      }
    } catch (e) {
      debugPrint('Error checking cooldown: $e');
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_cooldown == null) {
        timer.cancel();
        return;
      }

      if (_cooldown!.inSeconds <= 0) {
        setState(() => _cooldown = null);
        timer.cancel();
        return;
      }

      setState(() {
        _cooldown = _cooldown! - const Duration(minutes: 1);
      });
    });
  }

  Future<void> _checkFollowStatus() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      
      if (mounted) {
        final List following = userDoc.data()?['following'] ?? [];
        setState(() {
          _isFollowing = following.contains(widget.userId);
        });
      }
    } catch (e) {
      debugPrint('Error checking follow status: $e');
    }
  }

  Future<void> _handlePoke() async {
    if (_isLoading || _cooldown != null) return;

    if (!_isFollowing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to follow this user before you can poke them'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _pokeService.pokeUser(widget.userId);
      await _checkCooldown();
    } catch (e) {
      debugPrint('Error poking user: $e');
      if (mounted) {
        // If it's a cooldown error, update the cooldown state
        if (e.toString().contains('Cannot poke user yet')) {
          await _checkCooldown();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to poke user: ${e.toString()}')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatCooldown(Duration duration) {
    if (duration.inHours >= 1) {
      return '~${duration.inHours}h';
    } else if (duration.inMinutes >= 1) {
      return '~${duration.inMinutes}m';
    } else {
      return '~1m';  // Show at least 1 minute remaining
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = _cooldown != null;
    final String buttonText = isDisabled ? _formatCooldown(_cooldown!) : 'Poke';

    return ElevatedButton(
      onPressed: isDisabled ? null : _handlePoke,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[100],
        foregroundColor: Colors.black87,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        minimumSize: const Size(0, 36),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
              ),
            )
          : Text(
              buttonText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
} 