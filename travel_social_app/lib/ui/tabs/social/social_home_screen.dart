import 'package:flutter/material.dart';
import '../../../utils/constants.dart';
import 'post/post_list_screen.dart';
import 'group/group_community_list_screen.dart';

/// Màn hình chính của Social với 2 tabs: Trang chủ và Cộng đồng
class SocialHomeScreen extends StatefulWidget {
  const SocialHomeScreen({super.key});

  @override
  State<SocialHomeScreen> createState() => _SocialHomeScreenState();
}

class _SocialHomeScreenState extends State<SocialHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getSurfaceColor(context),
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.getTextPrimaryColor(context),
          labelColor: AppTheme.getTextPrimaryColor(context),
          unselectedLabelColor: AppTheme.getTextSecondaryColor(context),
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.home), text: 'Trang chủ'),
            Tab(icon: Icon(Icons.groups), text: 'Cộng đồng'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Tab 1: Trang chủ - Post thường (public)
          PostListScreen(),

          // Tab 2: Cộng đồng - Danh sách groups
          GroupCommunityListScreen(),
        ],
      ),
    );
  }
}
