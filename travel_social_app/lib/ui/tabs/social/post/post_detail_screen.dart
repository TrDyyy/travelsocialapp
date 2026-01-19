import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/post.dart';
import '../../../../states/post_provider.dart';
import '../widgets/post_item.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final post = await postProvider.getPostById(widget.postId);

    setState(() {
      _post = post;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bài viết')),
      resizeToAvoidBottomInset: false,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _post == null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Không tìm thấy bài viết',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(child: PostItem(post: _post!)),
    );
  }
}
