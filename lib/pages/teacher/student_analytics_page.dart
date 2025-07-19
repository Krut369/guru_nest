import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/analytics_service.dart';

class StudentAnalyticsPage extends StatefulWidget {
  final String userId;
  const StudentAnalyticsPage({Key? key, required this.userId})
      : super(key: key);

  @override
  State<StudentAnalyticsPage> createState() => _StudentAnalyticsPageState();
}

class _StudentAnalyticsPageState extends State<StudentAnalyticsPage> {
  final _analyticsService = AnalyticsService();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _analyticsData;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final analytics =
          await _analyticsService.getStudentAnalytics(widget.userId);
      setState(() {
        _analyticsData = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load analytics data: [31m${e.toString()}[0m';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Responsive base font: 14 for small, 18 for medium, 22 for large screens
    final double baseFont = screenWidth >= 1200
        ? 22
        : screenWidth >= 800
            ? 18
            : 14;
    final isTablet = screenWidth > 768;
    final isDesktop = screenWidth > 1024;
    final double cardPadding = isDesktop
        ? 32
        : isTablet
            ? 24
            : 16;
    final double gridSpacing = isTablet ? 16 : 12;
    final int gridCount = isDesktop ? 4 : (isTablet ? 3 : 2);

    return Scaffold(
      appBar: AppBar(
        title: Text('Student Analytics ',
            style: TextStyle(fontSize: baseFont + 2)),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(_error!,
                          style: TextStyle(
                              color: AppTheme.errorRed, fontSize: baseFont),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _loadAnalyticsData,
                          child: const Text('Retry')),
                    ],
                  ),
                )
              : _analyticsData == null || _analyticsData!.isEmpty
                  ? Center(
                      child: Text('No analytics data available',
                          style: TextStyle(fontSize: baseFont)))
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildOverviewCards(
                              context, gridCount, gridSpacing, baseFont),
                          SizedBox(height: cardPadding),
                          _buildQuizProgressChart(
                              context, baseFont, cardPadding, isTablet),
                          SizedBox(height: cardPadding),
                          _buildRecentActivity(context, baseFont, cardPadding),
                          SizedBox(height: cardPadding),
                          _buildCourseProgress(context, baseFont, cardPadding),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildOverviewCards(BuildContext context, int gridCount,
      double gridSpacing, double baseFont) {
    final userReport = _analyticsData!['user_report'] as Map<String, dynamic>?;
    final averageQuizScore =
        _analyticsData!['average_quiz_score'] as double? ?? 0.0;
    if (userReport == null) {
      return Center(
          child:
              Text('No overview data', style: TextStyle(fontSize: baseFont)));
    }
    final metrics = [
      {
        'title': 'Quiz Score',
        'value':
            '${((userReport['average_quiz_score'] ?? 0.0) as num).toStringAsFixed(1)}%',
        'icon': Icons.quiz,
        'color': AppTheme.successGreen,
        'subtitle': 'Average',
      },
      {
        'title': 'Quizzes',
        'value': (userReport['total_quizzes'] ?? 0).toString(),
        'icon': Icons.assignment,
        'color': AppTheme.warningOrange,
        'subtitle': 'Taken',
      },
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220, // Max card width in pixels
        mainAxisSpacing: gridSpacing,
        crossAxisSpacing: gridSpacing,
        childAspectRatio: 1.0,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return _AnalyticsCard(
          title: metric['title'] as String,
          value: metric['value'] as String,
          icon: metric['icon'] as IconData,
          color: metric['color'] as Color,
          subtitle: metric['subtitle'] as String,
          baseFont: baseFont,
        );
      },
    );
  }

  Widget _buildQuizProgressChart(BuildContext context, double baseFont,
      double cardPadding, bool isTablet) {
    final quizResults = _analyticsData!['quiz_results'] as List<dynamic>?;
    if (quizResults == null || quizResults.isEmpty) {
      return const SizedBox.shrink();
    }
    // Sort by taken_at
    final sortedResults = List<Map<String, dynamic>>.from(quizResults)
      ..sort((a, b) => DateTime.parse(a['taken_at'])
          .compareTo(DateTime.parse(b['taken_at'])));
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedResults.length; i++) {
      final score = (sortedResults[i]['score'] as num?)?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), score));
    }
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
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
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart,
                      color: AppTheme.primaryBlue, size: baseFont + 4),
                  const SizedBox(width: 8),
                  Text('Quiz Progress',
                      style: TextStyle(
                          fontSize: baseFont + 2,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue)),
                ],
              ),
              SizedBox(height: baseFont),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  height: isTablet ? baseFont * 13 : baseFont * 9,
                  width: (spots.length * 60).clamp(240, 1000).toDouble(),
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: baseFont * 2.2,
                            interval: 20,
                            getTitlesWidget: (value, meta) => Text(
                                '${value.toInt()}%',
                                style: TextStyle(
                                    fontSize: baseFont - 2,
                                    color: AppTheme.primaryBlue)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= sortedResults.length)
                                return const SizedBox.shrink();
                              final date = DateTime.parse(
                                  sortedResults[idx]['taken_at']);
                              return Text('${date.day}/${date.month}',
                                  style: TextStyle(
                                      fontSize: baseFont - 4,
                                      color: AppTheme.primaryBlue));
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                          show: true,
                          horizontalInterval: 20,
                          getDrawingHorizontalLine: (value) => const FlLine(
                              color: Colors.white24, strokeWidth: 1)),
                      borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.white24, width: 1)),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppTheme.primaryBlue,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                              show: true,
                              color: AppTheme.primaryBlue.withOpacity(0.08)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: baseFont / 2),
              Text('Shows your quiz scores over time.',
                  style: TextStyle(
                      fontSize: baseFont - 2, color: AppTheme.primaryBlue)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(
      BuildContext context, double baseFont, double cardPadding) {
    final recentActivity = _analyticsData!['recent_activity'] as List<dynamic>?;
    if (recentActivity == null || recentActivity.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
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
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                children: [
                  Icon(Icons.history, size: baseFont * 3, color: Colors.white),
                  SizedBox(height: baseFont),
                  Text('No Recent Activity',
                      style: TextStyle(
                          fontSize: baseFont + 4,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activity hvbn',
            style: TextStyle(
                fontSize: baseFont + 4,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue)),
        SizedBox(height: baseFont),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentActivity.length,
          itemBuilder: (context, index) {
            final activity = recentActivity[index];
            return _ActivityItem(
              title: activity['title'] as String,
              timestamp: activity['timestamp'] as String,
              icon: activity['icon'] as IconData,
              color: activity['color'] as Color,
              baseFont: baseFont,
            );
          },
        ),
      ],
    );
  }

  Widget _buildCourseProgress(
      BuildContext context, double baseFont, double cardPadding) {
    final enrollments = _analyticsData!['enrollments'] as List<dynamic>?;
    if (enrollments == null || enrollments.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(cardPadding / 1.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school,
                    color: AppTheme.primaryBlue, size: baseFont + 4),
                const SizedBox(width: 8),
                Text('Enrolled Courses',
                    style: TextStyle(
                        fontSize: baseFont + 2, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: baseFont),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: enrollments.length,
              itemBuilder: (context, index) {
                final enrollment = enrollments[index];
                final course = enrollment['courses'] as Map<String, dynamic>?;
                return ListTile(
                  leading: Icon(Icons.book,
                      color: AppTheme.primaryBlue, size: baseFont + 2),
                  title: Text(course?['title'] ?? 'Untitled Course',
                      style: TextStyle(fontSize: baseFont)),
                  subtitle: Text('Enrolled: ${enrollment['enrolled_at'] ?? ''}',
                      style: TextStyle(fontSize: baseFont - 2)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final double baseFont;
  const _AnalyticsCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color,
      required this.subtitle,
      required this.baseFont});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
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
        child: Padding(
          padding: EdgeInsets.all(baseFont * 1.1), // Responsive padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(baseFont * 0.5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: baseFont * 2, color: Colors.white),
              ),
              SizedBox(height: baseFont / 1.5),
              Text(
                value,
                style: TextStyle(
                    fontSize: baseFont + 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: baseFont / 3),
              Text(
                title,
                style: TextStyle(fontSize: baseFont + 2, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: baseFont / 6),
              Text(
                subtitle,
                style: TextStyle(fontSize: baseFont, color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String title;
  final String timestamp;
  final IconData icon;
  final Color color;
  final double baseFont;
  const _ActivityItem(
      {required this.title,
      required this.timestamp,
      required this.icon,
      required this.color,
      required this.baseFont});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
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
          leading: Icon(icon, color: Colors.white, size: baseFont + 4),
          title: Text(title,
              style: TextStyle(fontSize: baseFont, color: Colors.white)),
          subtitle: Text(timestamp,
              style: TextStyle(fontSize: baseFont - 2, color: Colors.white70)),
        ),
      ),
    );
  }
}
