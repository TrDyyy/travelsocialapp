import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../../states/post_provider.dart';
import '../../../../utils/constants.dart';
import '../../../../services/user_service.dart';
import '../../../../services/review_service.dart';
import '../../../../services/place_service.dart';
import '../widgets/post_item.dart';
import 'create_post_screen.dart';

/// Màn hình danh sách posts
class PostListScreen extends StatefulWidget {
  final String?
  initialSearchQuery; // For searching by place name from place_detail

  const PostListScreen({super.key, this.initialSearchQuery});

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _userService = UserService();
  final _reviewService = ReviewService();
  final _placeService = PlaceService();
  final Map<String, String> _userNameCache = {}; // Cache userId -> userName
  final Map<String, String> _placeNameCache = {}; // Cache placeId -> placeName
  final Map<String, String> _reviewPlaceNameCache =
      {}; // Cache reviewId -> placeName for faster search
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Set initial search query if provided (from place detail)
    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!;
      _searchQuery = widget.initialSearchQuery!;
      _isSearching = true;
      // Trigger pre-fetch immediately for initial search
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onSearchChanged(widget.initialSearchQuery!);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Unfocus search when user starts scrolling
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when near bottom (200px before end)
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      postProvider.loadMore();
    }
  }

  /// Remove Vietnamese diacritics for fuzzy matching
  String _removeDiacritics(String str) {
    const vietnamese =
        'aàảãáạăằẳẵắặâầẩẫấậeèẻẽéẹêềểễếệiìỉĩíịoòỏõóọôồổỗốộơờởỡớợuùủũúụưừửữứựyỳỷỹýỵđ';
    const normalized =
        'aaaaaaaaaaaaaaaaaaeeeeeeeeeeeeiiiiiiooooooooooooooooooouuuuuuuuuuuuyyyyyd';

    var result = str.toLowerCase();
    for (var i = 0; i < vietnamese.length; i++) {
      result = result.replaceAll(vietnamese[i], normalized[i]);
    }
    return result;
  }

  /// Calculate Levenshtein distance for fuzzy matching
  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(
      s1.length + 1,
      (i) => List.filled(s2.length + 1, 0),
    );

    for (var i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= s1.length; i++) {
      for (var j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  /// Check if query fuzzy matches text
  bool _fuzzyMatches(String text, String query, {int threshold = 2}) {
    final normalizedText = _removeDiacritics(text.toLowerCase()).trim();
    final normalizedQuery = _removeDiacritics(query.toLowerCase()).trim();

    // Exact match (fastest)
    if (normalizedText.contains(normalizedQuery)) {
      return true;
    }

    // Split into words for partial matching
    final textWords = normalizedText.split(RegExp(r'\s+'));
    final queryWords = normalizedQuery.split(RegExp(r'\s+'));

    // Check if each query word fuzzy matches any text word
    for (final queryWord in queryWords) {
      if (queryWord.length < 2) continue; // Skip single chars

      bool foundMatch = false;
      for (final textWord in textWords) {
        // Check substring match
        if (textWord.contains(queryWord)) {
          foundMatch = true;
          break;
        }

        // Check Levenshtein distance for typos
        if (textWord.length >= queryWord.length - 1 &&
            textWord.length <= queryWord.length + 1) {
          final distance = _levenshteinDistance(textWord, queryWord);
          if (distance <= threshold) {
            foundMatch = true;
            break;
          }
        }
      }

      // All query words must match
      if (!foundMatch) return false;
    }

    return queryWords.isNotEmpty;
  }

  /// Get place name from cache or fetch via reviewId -> placeId -> place name
  Future<String?> _getPlaceNameFromReview(String reviewId) async {
    // Check reviewId cache first (fastest)
    if (_reviewPlaceNameCache.containsKey(reviewId)) {
      print(
        '✅ Found place name in reviewId cache: ${_reviewPlaceNameCache[reviewId]}',
      );
      return _reviewPlaceNameCache[reviewId];
    }

    try {
      // Fetch review to get placeId
      final review = await _reviewService.getReviewById(reviewId);
      if (review == null) {
        print('⚠️ Review not found for reviewId: $reviewId');
        return null;
      }

      final placeId = review.placeId;
      print('🔍 Found placeId: $placeId for reviewId: $reviewId');

      // Check placeId cache
      if (_placeNameCache.containsKey(placeId)) {
        final placeName = _placeNameCache[placeId]!;
        _reviewPlaceNameCache[reviewId] = placeName; // Cache by reviewId too
        print('✅ Found place name in placeId cache: $placeName');
        return placeName;
      }

      // Fetch place to get name
      final place = await _placeService.getPlaceById(placeId);
      if (place != null && mounted) {
        _placeNameCache[placeId] = place.name;
        _reviewPlaceNameCache[reviewId] = place.name; // Cache by reviewId too
        print('✅ Fetched and cached place name: ${place.name}');
        return place.name;
      }
    } catch (e) {
      print('❌ Error fetching place name from review: $e');
    }
    return null;
  }

  /// Get user name from cache or fetch from Firestore
  Future<String?> _getUserName(String userId) async {
    // Check cache first
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId];
    }

    // Fetch from Firestore
    try {
      final user = await _userService.getUserById(userId);
      if (user != null && mounted) {
        _userNameCache[userId] = user.name;
        return user.name;
      }
    } catch (e) {
      // Ignore errors, search will work without author name
    }
    return null;
  }

  /// Synchronous version for initial filtering (checks cache only)
  bool _matchesSearch(dynamic post, String query) {
    if (query.isEmpty) return true;

    // Search by content with fuzzy matching
    if (_fuzzyMatches(post.content, query)) {
      return true;
    }

    // Search by tagged place name with fuzzy matching
    if (post.taggedPlaceName != null &&
        _fuzzyMatches(post.taggedPlaceName!, query)) {
      return true;
    }

    // Search by place name from reviewId cache (for review share posts)
    if (post.reviewId != null) {
      final placeName = _reviewPlaceNameCache[post.reviewId];
      if (placeName != null && _fuzzyMatches(placeName, query)) {
        print(
          '🎯 Matched post with reviewId: ${post.reviewId} → place: $placeName',
        );
        return true;
      }
    }

    // Search by author name (cache only for sync filtering)
    final authorName = _userNameCache[post.userId];
    if (authorName != null && _fuzzyMatches(authorName, query)) {
      return true;
    }

    return false;
  }

  void _onSearchChanged(String query) async {
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
    });

    // Pre-fetch author names and place names for ALL posts (improves search accuracy)
    if (query.isNotEmpty) {
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      print(
        '🔎 Starting search for: "$query" in ${postProvider.posts.length} posts',
      );

      for (final post in postProvider.posts) {
        // Pre-fetch user names
        if (!_userNameCache.containsKey(post.userId)) {
          _getUserName(post.userId).then((_) {
            // Re-filter after fetching user name
            if (mounted && _searchQuery == query) {
              setState(() {}); // Trigger rebuild to show newly matched posts
            }
          });
        }

        // Pre-fetch place names from review share posts
        if (post.reviewId != null) {
          _getPlaceNameFromReview(post.reviewId!).then((placeName) {
            // Re-filter after fetching place name
            if (mounted && _searchQuery == query && placeName != null) {
              print('✅ Found post with reviewId matching place: $placeName');
              setState(() {}); // Trigger rebuild to show newly matched posts
            }
          });
        }
      }
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _isSearching = false;
    });
  }

  Future<void> _navigateToCreatePost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để tạo bài viết'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatePostScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final postProvider = Provider.of<PostProvider>(context);

    // Filter posts based on search query
    // Cache the filtered list to prevent race conditions during async updates
    final List<dynamic> allPosts = List.from(postProvider.posts);
    final filteredPosts =
        _isSearching
            ? allPosts
                .where((post) => _matchesSearch(post, _searchQuery))
                .toList()
            : allPosts;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: GestureDetector(
        onTap: () {
          // Unfocus search when tapping outside
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          }
        },
        child: Column(
          children: [
            // Search bar
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.padding(context, SizeCategory.medium),
                vertical: AppSizes.padding(context, SizeCategory.small),
              ),
              decoration: BoxDecoration(
                color: AppTheme.getSurfaceColor(context),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm bài viết, người dùng, địa điểm...',
                    hintStyle: TextStyle(
                      color: AppTheme.getTextSecondaryColor(context),
                      fontSize: AppSizes.font(context, SizeCategory.medium),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                    suffixIcon:
                        _isSearching
                            ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: AppTheme.getTextSecondaryColor(context),
                              ),
                              onPressed: _clearSearch,
                            )
                            : null,
                    filled: true,
                    fillColor: AppTheme.getInputBackgroundColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.radius(context, SizeCategory.medium),
                      ),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSizes.padding(
                        context,
                        SizeCategory.medium,
                      ),
                      vertical: AppSizes.padding(context, SizeCategory.small),
                    ),
                  ),
                ),
              ),
            ),

            // Search result count
            if (_isSearching && filteredPosts.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.padding(context, SizeCategory.medium),
                  vertical: AppSizes.padding(context, SizeCategory.small),
                ),
                decoration: BoxDecoration(
                  color: AppTheme.getSurfaceColor(context),
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.getBorderColor(context),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tìm thấy ${filteredPosts.length} bài viết',
                      style: TextStyle(
                        color: AppTheme.getTextSecondaryColor(context),
                        fontSize: AppSizes.font(context, SizeCategory.small),
                      ),
                    ),
                  ],
                ),
              ),

            // Posts list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await postProvider.refresh();
                },
                child:
                    postProvider.isLoading && postProvider.posts.isEmpty
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGreen,
                          ),
                        )
                        : filteredPosts.isEmpty && _isSearching
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Không tìm thấy bài viết nào',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Thử tìm kiếm với từ khóa khác',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                        : postProvider.posts.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.article_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Chưa có bài viết nào',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _navigateToCreatePost,
                                icon: const Icon(Icons.add),
                                label: const Text('Tạo bài viết đầu tiên'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.all(
                            AppSizes.padding(context, SizeCategory.medium),
                          ),
                          itemCount:
                              filteredPosts.length +
                              (postProvider.hasMore && !_isSearching ? 1 : 0),
                          // Tối ưu hiệu suất scroll
                          addAutomaticKeepAlives: true,
                          addRepaintBoundaries: true,
                          cacheExtent: 500, // Cache thêm 500px phía trước/sau
                          itemBuilder: (context, index) {
                            // Show loading indicator at bottom
                            if (index >= filteredPosts.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child:
                                      postProvider.isLoadingMore
                                          ? const CircularProgressIndicator(
                                            color: AppColors.primaryGreen,
                                          )
                                          : const SizedBox.shrink(),
                                ),
                              );
                            }

                            // Defensive check to prevent index out of range
                            if (index < 0 || index >= filteredPosts.length) {
                              return const SizedBox.shrink();
                            }

                            return PostItem(
                              key: ValueKey(filteredPosts[index].postId),
                              post: filteredPosts[index],
                              onDeleted: () {
                                // Provider sẽ tự động cập nhật
                              },
                            );
                          },
                        ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreatePost,
        backgroundColor: AppColors.primaryGreen,
        heroTag: 'createPostFAB', // Unique hero tag để tránh conflict
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
