import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';

class StudentPaymentScreen extends StatefulWidget {
  final String courseId;
  final double amount;
  final String courseTitle;

  const StudentPaymentScreen({
    super.key,
    required this.courseId,
    required this.amount,
    required this.courseTitle,
  });

  @override
  State<StudentPaymentScreen> createState() => _StudentPaymentScreenState();
}

class _StudentPaymentScreenState extends State<StudentPaymentScreen> {
  late Razorpay _razorpay;
  String _paymentResult = '';
  final supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _openRazorpayCheckout() {
    var options = {
      'key': 'rzp_test_rpY97GkGC0vj6S',
      'amount': (widget.amount * 100).toInt(), // Amount in paise
      'name': 'Parth Prajapati',
      'description': 'Payment for ${widget.courseTitle}',
      'prefill': {
        'contact': '',
        'email': '',
      },
      'currency': 'INR',
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> ensureUserInUsersTable(String studentId) async {
    final response =
        await supabase.from('users').select().eq('id', studentId).maybeSingle();
    if (response == null) {
      final user = _authService.currentUser;
      await supabase.from('users').insert({
        'id': studentId,
        'full_name': user?.fullName ?? 'Unknown',
        'email': user?.email ?? '',
        'password': user?.password ?? 'dummy', // Added password field
        'role': user?.role.toString().split('.').last ?? 'student',
        'created_at': user?.createdAt.toIso8601String() ??
            DateTime.now().toIso8601String(),
        // Add other fields if needed
      });
    }
  }

  Future<void> enrollInCourse(String courseId) async {
    final studentId = _authService.currentUser?.id;
    if (studentId == null)
      throw Exception('No student_id found in AuthService.');
    await ensureUserInUsersTable(studentId);

    try {
      await supabase.from('enrollments').insert({
        'student_id': studentId,
        'course_id': courseId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Duplicate key error
        throw Exception('You are already enrolled in this course.');
      } else {
        rethrow;
      }
    }
  }

  Future<void> _enrollAndReturn() async {
    try {
      await enrollInCourse(widget.courseId);
      if (mounted) {
        context.go('/course/${widget.courseId}');
      }
    } catch (e) {
      if (mounted) {
        _showResultDialog('❌ Enrollment failed: $e');
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() {
      _paymentResult =
          '✅ Payment Successful\nPayment ID: ${response.paymentId}';
    });
    await _enrollAndReturn();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() {
      _paymentResult = '❌ Payment Failed\n${response.message}';
    });
    _showResultDialog(_paymentResult);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() {
      _paymentResult = 'Wallet Selected: ${response.walletName}';
    });
    _showResultDialog(_paymentResult);
  }

  void _showResultDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Payment Result'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Payment'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.school,
                          size: 48, color: Colors.deepPurple),
                      const SizedBox(height: 16),
                      Text(
                        widget.courseTitle,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Course ID: ${widget.courseId}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Amount: ₹${widget.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.payment, size: 24),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _openRazorpayCheckout,
                  label: Text(
                    'Pay ₹${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (_paymentResult.isNotEmpty) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _paymentResult.startsWith('✅')
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _paymentResult.startsWith('✅')
                            ? Icons.check_circle
                            : Icons.error,
                        color: _paymentResult.startsWith('✅')
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _paymentResult,
                          style: TextStyle(
                            color: _paymentResult.startsWith('✅')
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
