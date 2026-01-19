import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/post.dart';
import '../../../utils/constants.dart';
import '../social/widgets/post_item.dart';

/// Màn hình hiển thị danh sách bài viết đã lưu của người dùng
class SavePostListScreen extends StatefulWidget {
  const SavePostListScreen({super.key});

  @override
  State<SavePostListScreen> createState() => _SavePostListScreenState();
}

class _SavePostListScreenState extends State<SavePostListScreen> {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Bài viết đã lưu',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Text(
            'Vui lòng đăng nhập để xem bài viết đã lưu',
            style: TextStyle(
              color: AppTheme.getTextSecondaryColor(context),
              fontSize: AppSizes.font(context, SizeCategory.medium),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Bài viết đã lưu',
          style: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.large),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('posts')
                .where('isSavedBy', arrayContains: _currentUserId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: AppSizes.icon(context, SizeCategory.xxxlarge),
                    color: AppColors.error,
                  ),
                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.medium),
                  ),
                  Text(
                    'Đã xảy ra lỗi khi tải bài viết',
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.medium),
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                  ),
                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.small),
                  ),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.small),
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryGreen,
                strokeWidth: 3,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: AppSizes.icon(context, SizeCategory.xxxlarge),
                    color: AppTheme.getIconSecondaryColor(context),
                  ),
                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.medium),
                  ),
                  Text(
                    'Chưa có bài viết nào được lưu',
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.large),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                  ),
                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.small),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.padding(context, SizeCategory.large),
                    ),
                    child: Text(
                      'Hãy lưu các bài viết yêu thích để xem lại sau',
                      style: TextStyle(
                        fontSize: AppSizes.font(context, SizeCategory.medium),
                        color: AppTheme.getTextSecondaryColor(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }

          final posts =
              snapshot.data!.docs
                  .map((doc) => Post.fromFirestore(doc))
                  .toList();

          return ListView.separated(
            controller: _scrollController,
            padding: EdgeInsets.all(
              AppSizes.padding(context, SizeCategory.medium),
            ),
            itemCount: posts.length,
            separatorBuilder:
                (context, index) => SizedBox(
                  height: AppSizes.padding(context, SizeCategory.medium),
                ),
            itemBuilder: (context, index) {
              return PostItem(post: posts[index]);
            },
          );
        },
      ),
    );
  }
}
