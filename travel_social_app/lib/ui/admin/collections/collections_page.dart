import 'package:flutter/material.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../places/places_management_page.dart';
import '../users/users_management_page.dart';
import '../tourism_types/tourism_types_management_page.dart';
import '../reviews/reviews_management_page.dart';
import '../posts/posts_management_page.dart';
import '../notifications/notifications_management_page.dart';
import '../communities/communities_management_page.dart';
import '../chats/chats_management_page.dart';
import '../calls/calls_management_page.dart';
import '../friendships/friendships_management_page.dart';
import '../reactions/reactions_management_page.dart';
import '../place_edit_requests/place_edit_requests_management_page.dart';
import 'collection_detail_page.dart';
import '../points/points_history_management_page.dart';
import '../violations/violation_requests_list_page.dart';

/// Trang quản lý Collections
class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final AdminService _adminService = AdminService();
  List<String> _collections = [];
  Map<String, int> _collectionCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    setState(() => _isLoading = true);
    final collections = await _adminService.getAllCollections();
    final counts = <String, int>{};

    for (var collection in collections) {
      final count = await _adminService.getCollectionCount(collection);
      counts[collection] = count;
    }

    setState(() {
      _collections = collections;
      _collectionCounts = counts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Padding(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quản lý Collections',
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.xlarge),
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: AppTheme.getIconPrimaryColor(context),
                  ),
                  onPressed: _loadCollections,
                ),
              ],
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
            Expanded(
              child:
                  _isLoading
                      ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      )
                      : _buildCollectionsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionsList() {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _collections.length,
      itemBuilder: (context, index) {
        final collection = _collections[index];
        final count = _collectionCounts[collection] ?? 0;
        return _buildCollectionCard(collection, count);
      },
    );
  }

  Widget _buildCollectionCard(String collection, int count) {
    return Card(
      color: AppTheme.getSurfaceColor(context),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
      ),
      child: InkWell(
        onTap: () {
          if (collection == 'users') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UsersManagementPage(),
              ),
            );
          } else if (collection == 'places') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PlacesManagementPage(),
              ),
            );
          } else if (collection == 'tourismTypes') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TourismTypesManagementPage(),
              ),
            );
          } else if (collection == 'reviews') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReviewsManagementPage(),
              ),
            );
          } else if (collection == 'posts') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PostsManagementPage(),
              ),
            );
          } else if (collection == 'notifications') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsManagementPage(),
              ),
            );
          } else if (collection == 'communities') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CommunitiesManagementPage(),
              ),
            );
          } else if (collection == 'chats') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatsManagementPage(),
              ),
            );
          } else if (collection == 'calls') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CallsManagementPage(),
              ),
            );
          } else if (collection == 'friendships') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FriendshipsManagementPage(),
              ),
            );
          } else if (collection == 'reactions') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReactionsManagementPage(),
              ),
            );
          } else if (collection == 'placeEditRequests') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PlaceEditRequestsManagementPage(),
              ),
            );
          } else if (collection == 'point_history') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PointsHistoryManagementPage(),
              ),
            );
          } else if (collection == 'violationRequests') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ViolationRequestsListPage(),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        CollectionDetailPage(collectionName: collection),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
        child: Padding(
          padding: EdgeInsets.all(
            AppSizes.padding(context, SizeCategory.medium),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getCollectionIcon(collection),
                size: AppSizes.icon(context, SizeCategory.xxlarge),
                color: AppColors.primaryGreen,
              ),
              SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
              Flexible(
                child: Text(
                  collection,
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.large),
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
              Text(
                '$count bản ghi',
                style: TextStyle(
                  fontSize: AppSizes.font(context, SizeCategory.medium),
                  color: AppTheme.getTextSecondaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCollectionIcon(String collection) {
    switch (collection) {
      case 'users':
        return Icons.people;
      case 'places':
        return Icons.place;
      case 'placeEditRequests':
        return Icons.pending_actions;
      case 'tourismTypes':
        return Icons.category;
      case 'reviews':
        return Icons.star;
      case 'posts':
        return Icons.article;
      case 'notifications':
        return Icons.notifications;
      case 'communities':
        return Icons.groups;
      case 'chats':
        return Icons.chat;
      case 'calls':
        return Icons.phone;
      case 'friendships':
        return Icons.people_outline;
      case 'reactions':
        return Icons.emoji_emotions;
      case 'violationRequests':
        return Icons.report_problem;
      default:
        return Icons.storage;
    }
  }
}
