import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/theme/app_theme.dart';
import '../../views/dashboard/sections/analytics_section.dart';
import '../../widgets/custom_app_bar.dart';

class StudentDetailPage extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentDetailPage({
    super.key,
    required this.student,
  });

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _enrolledCourses = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEnrolledCourses();
  }

  Future<void> _loadEnrolledCourses() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await supabase.Supabase.instance.client
          .from('enrollments')
          .select('''
            *,
            courses (
              id,
              title,
              description,
              image_url
            )
          ''')
          .eq('student_id', widget.student['id'])
          .order('enrolled_at', ascending: false);

      setState(() {
        _enrolledCourses = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Student Details'),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    AppTheme.primaryBlue.withOpacity(0.03),
                    AppTheme.primaryBlue.withOpacity(0.05),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                    child: widget.student['avatar_url'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.network(
                              widget.student['avatar_url'],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: AppTheme.primaryBlue,
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 50,
                            color: AppTheme.primaryBlue,
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.student['full_name'] ?? 'Unknown Student',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.student['email'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoChip(
                        Icons.calendar_today,
                        'Joined: ${_formatDate(widget.student['created_at'])}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('View Analytics'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnalyticsFullScreenPage(
                              studentId:
                                  widget.student['id'], // Pass the student ID
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Enrolled Courses',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Center(child: Text('Error: $_error'))
            else if (_enrolledCourses.isEmpty)
              Center(
                child: Card(
                  elevation: 2,
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          AppTheme.primaryBlue.withOpacity(0.03),
                          AppTheme.primaryBlue.withOpacity(0.05),
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 32, horizontal: 24),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school,
                          size: 64,
                          color: Colors.white,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No enrolled courses',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _enrolledCourses.length,
                itemBuilder: (context, index) {
                  final enrollment = _enrolledCourses[index];
                  final course = enrollment['courses'] as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            AppTheme.primaryBlue.withOpacity(0.03),
                            AppTheme.primaryBlue.withOpacity(0.05),
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: course['thumbnail_url'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  course['thumbnail_url'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.school),
                                    );
                                  },
                                ),
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.school),
                              ),
                        title: Text(
                          course['title'] ?? 'Untitled Course',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          course['description'] ?? 'No description available',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          'Enrolled: ${_formatDate(enrollment['enrolled_at'])}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
