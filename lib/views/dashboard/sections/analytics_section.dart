import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AnalyticsSection extends StatefulWidget {
  const AnalyticsSection({super.key});

  @override
  State<AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<AnalyticsSection> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _stats = {
    'totalCourses': 0,
    'totalStudents': 0,
    'totalRevenue': 0,
    'activeStudents': 0,
    'recentEnrollments': [],
    'monthlyRevenue': [0, 0, 0, 0, 0, 0],
    'courseDistribution': [
      {'name': 'Development', 'count': 0},
      {'name': 'Design', 'count': 0},
      {'name': 'Business', 'count': 0},
      {'name': 'Marketing', 'count': 0},
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Simulate loading data
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _stats = {
          'totalCourses': 12,
          'totalStudents': 156,
          'totalRevenue': 2500,
          'activeStudents': 89,
          'recentEnrollments': [
            {
              'studentName': 'John Doe',
              'courseName': 'Flutter Development',
              'date': '2 hours ago',
            },
            {
              'studentName': 'Jane Smith',
              'courseName': 'UI/UX Design',
              'date': '5 hours ago',
            },
            {
              'studentName': 'Mike Johnson',
              'courseName': 'Digital Marketing',
              'date': '1 day ago',
            },
          ],
          'monthlyRevenue': [1200, 1800, 1500, 2000, 2200, 2500],
          'courseDistribution': [
            {'name': 'Development', 'count': 5},
            {'name': 'Design', 'count': 3},
            {'name': 'Business', 'count': 2},
            {'name': 'Marketing', 'count': 2},
          ],
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load analytics data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textGrey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Revenue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        _stats['monthlyRevenue'].length,
                        (index) => FlSpot(
                          index.toDouble(),
                          _stats['monthlyRevenue'][index].toDouble(),
                        ),
                      ),
                      isCurved: true,
                      color: AppTheme.primaryBlue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseDistribution() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Course Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...List.generate(
              _stats['courseDistribution'].length,
              (index) {
                final category = _stats['courseDistribution'][index];
                Color categoryColor = AppTheme.primaryBlue;
                if (index == 1) categoryColor = AppTheme.successGreen;
                if (index == 2) categoryColor = AppTheme.warningOrange;
                if (index == 3) categoryColor = AppTheme.errorRed;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          category['name'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: categoryColor,
                          ),
                        ),
                      ),
                      Text(
                        '${category['count']} courses',
                        style: TextStyle(
                          color: categoryColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_stats['recentEnrollments'].isEmpty)
              const Center(
                child: Text(
                  'No recent activity to display',
                  style: TextStyle(
                    color: AppTheme.textGrey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    _stats['recentEnrollments'].length,
                    (index) {
                      final enrollment = _stats['recentEnrollments'][index];
                      return GestureDetector(
                        onTap: () {
                          _showEnrollmentDetails(context, enrollment);
                        },
                        child: Container(
                          width: MediaQuery.of(context).size.width -
                              80, // Full width minus padding
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    enrollment['studentName']
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.primaryBlue,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      enrollment['studentName'],
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Text(
                                          'Enrolled in ',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.textGrey,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            enrollment['courseName'],
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.primaryBlue,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  enrollment['date'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEnrollmentDetails(
      BuildContext context, Map<String, dynamic> enrollment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.borderGrey,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor:
                                AppTheme.primaryBlue.withOpacity(0.1),
                            child: const Icon(
                              Icons.person,
                              color: AppTheme.primaryBlue,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  enrollment['studentName'],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enrolled ${enrollment['date']}',
                                  style: const TextStyle(
                                    color: AppTheme.textGrey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Course Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              enrollment['courseName'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Course Progress',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: 0.3,
                              backgroundColor:
                                  AppTheme.primaryBlue.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryBlue),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '30% Completed',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.errorRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalyticsData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analytics Overview',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildStatCard(
                  title: 'Total Courses',
                  value: _stats['totalCourses'].toString(),
                  icon: Icons.school,
                  color: AppTheme.primaryBlue,
                  subtitle: 'Active courses',
                ),
                _buildStatCard(
                  title: 'Total Students',
                  value: _stats['totalStudents'].toString(),
                  icon: Icons.people,
                  color: AppTheme.successGreen,
                  subtitle: 'Enrolled students',
                ),
                _buildStatCard(
                  title: 'Total Revenue',
                  value: '\$${_stats['totalRevenue'].toString()}',
                  icon: Icons.attach_money,
                  color: AppTheme.warningOrange,
                  subtitle: 'This month',
                ),
                _buildStatCard(
                  title: 'Active Students',
                  value: _stats['activeStudents'].toString(),
                  icon: Icons.trending_up,
                  color: AppTheme.errorRed,
                  subtitle: 'Currently learning',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildRevenueChart(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildCourseDistribution(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRecentActivity(),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
