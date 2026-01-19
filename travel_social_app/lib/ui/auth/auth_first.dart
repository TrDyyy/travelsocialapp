import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travel_social_app/states/auth_provider.dart';
import 'package:travel_social_app/utils/constants.dart';
import 'components/login_tab.dart';
import 'components/register_tab.dart';

class AuthFirst extends StatefulWidget {
  const AuthFirst({super.key});

  @override
  State<AuthFirst> createState() => _AuthFirstState();
}

class _AuthFirstState extends State<AuthFirst>
    with SingleTickerProviderStateMixin {
  bool isLogin = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          isLogin = _tabController.index == 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = AppSizes.screenHeight(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.zero,
              children: [
                // Header với cờ Việt Nam và bản đồ
                _buildHeader(context, screenHeight),

                SizedBox(
                  height: AppSizes.padding(context, SizeCategory.xlarge),
                ),

                // Tabs Đăng nhập/Đăng ký
                _buildTabSelector(context),

                SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

                // Form Container with responsive constraints
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.padding(
                          context,
                          SizeCategory.large,
                        ),
                      ),
                      child: _buildFormContainer(context),
                    ),
                  ),
                ),

                SizedBox(
                  height: AppSizes.padding(context, SizeCategory.xxlarge),
                ),
              ],
            ),

            // Loading overlay from AuthProvider
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                if (authProvider.isLoading) {
                  return Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build header với logo và title
  Widget _buildHeader(BuildContext context, double screenHeight) {
    return Container(
      height: screenHeight * 0.3,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.only(
          bottomRight: Radius.circular(
            AppSizes.radius(context, SizeCategory.xxxlarge),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon cờ với ngôi sao vàng
            Container(
              width: AppSizes.container(context, SizeCategory.small) * 1.2,
              height: AppSizes.container(context, SizeCategory.small) * 0.8,
              decoration: BoxDecoration(
                color: AppColors.vietnamRed,
                borderRadius: BorderRadius.circular(
                  AppSizes.radius(context, SizeCategory.small),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.star,
                  color: const Color(0xFFFDD835),
                  size: AppSizes.icon(context, SizeCategory.large),
                ),
              ),
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
            Text(
              "CHẠM LÀ CHẠY",
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.xlarge),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
                shadows: const [
                  Shadow(
                    offset: Offset(0, 2),
                    blurRadius: 4,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
            Text(
              "Khám phá vùng đất\nnghìn năm văn hiến",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.small),
                color: Colors.white,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build tab selector với animation mượt mà
  Widget _buildTabSelector(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.padding(context, SizeCategory.large),
      ),
      child: Container(
        height: AppSizes.container(context, SizeCategory.small),
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.xlarge),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.xlarge),
            ),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppTheme.getTextPrimaryColor(context),
          unselectedLabelColor: AppTheme.getTextSecondaryColor(context),
          labelStyle: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.medium),
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.medium),
            fontWeight: FontWeight.w500,
          ),
          tabs: const [Tab(text: 'Đăng nhập'), Tab(text: 'Đăng ký')],
        ),
      ),
    );
  }

  /// Build form container với content switching
  Widget _buildFormContainer(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.xlarge)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.large),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        height: AppSizes.screenHeight(context) * 0.5,
        child: TabBarView(
          controller: _tabController,
          physics: const BouncingScrollPhysics(),
          children: const [LoginTab(), RegisterTab()],
        ),
      ),
    );
  }
}
