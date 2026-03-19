// lib/screens/main_layout.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profiler_provider.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/header_widget.dart';
import 'dashboard_tab.dart';
import 'flame_graph_tab.dart';
import 'call_tree_tab.dart';
import 'method_list_tab.dart';
import 'thread_tab.dart';
import 'sql_tab.dart';
import 'invocation_tab.dart';
import '../models/profiler_models.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Tab> _tabs = const [
    Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
    Tab(icon: Icon(Icons.local_fire_department), text: 'Flame Graph'),
    Tab(icon: Icon(Icons.account_tree), text: 'Call Tree'),
    Tab(icon: Icon(Icons.list_alt), text: 'Methods'),
    Tab(icon: Icon(Icons.linear_scale), text: 'Threads'),
    Tab(icon: Icon(Icons.storage), text: 'SQL'),
    Tab(icon: Icon(Icons.timeline), text: 'Requests'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfilerProvider>();

    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar (240px) ──────────────────────────────
          const SidebarWidget(),
          VerticalDivider(width: 1),

          // ── Main Content ─────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Header
                const HeaderWidget(),
                Divider(height: 1),

                // Alert Banner
                if (provider.alerts.isNotEmpty)
                  _AlertBanner(alerts: provider.alerts),

                // Tab Bar
                Container(
                  color: Theme.of(context).cardColor,
                  child: TabBar(
                    controller: _tabController,
                    tabs: _tabs,
                    isScrollable: true,
                    indicatorColor: Colors.blueAccent,
                    labelColor: Colors.blueAccent,
                    unselectedLabelColor: Colors.white.withOpacity(0.6),
                  ),
                ),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      DashboardTab(),
                      FlameGraphTab(),
                      CallTreeTab(),
                      MethodListTab(),
                      ThreadTab(),
                      SqlTab(),
                      InvocationTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final List<ProfilerAlert> alerts;
  const _AlertBanner({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final latest = alerts.first;
    final color = latest.type.contains('DEADLOCK')
        ? Colors.red
        : latest.type.contains('HIGH_HEAP')
            ? Colors.orange
            : Colors.yellow.shade700;
    return Container(
      width: double.infinity,
      color: color.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: color, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(latest.message,
                style: TextStyle(color: color, fontSize: 13)),
          ),
          TextButton(
            onPressed: () =>
                context.read<ProfilerProvider>().clearAlerts(),
            child: Text('닫기', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
