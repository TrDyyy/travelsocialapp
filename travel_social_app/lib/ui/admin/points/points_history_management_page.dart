import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';

class PointsHistoryManagementPage extends StatefulWidget {
  const PointsHistoryManagementPage({Key? key}) : super(key: key);

  @override
  State<PointsHistoryManagementPage> createState() => _PointsHistoryManagementPageState();
}

class _PointsHistoryManagementPageState extends State<PointsHistoryManagementPage> {
  List<Map<String, dynamic>> _pointHistory = [];
  bool _isLoading = true;
  bool _isLoadingUsers = false;
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _loadPointHistory();
  }

  Future<void> _loadPointHistory() async {
    setState(() {
      _isLoading = true;
      _isLoadingUsers = false;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('point_history')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();
      final history = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      setState(() {
        _pointHistory = history;
        _isLoading = false;
        _isLoadingUsers = true;
      });
      // Lấy danh sách userId duy nhất
      final userIds = history.map((e) => e['userId'] as String?).where((id) => id != null).toSet();
      final userNames = <String, String>{};
      for (final userId in userIds) {
        if (userId == null) continue;
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          final name = userDoc.data()?['name'] ?? userId;
          userNames[userId] = name;
        } catch (_) {
          userNames[userId] = userId;
        }
      }
      setState(() {
        _userNames = userNames;
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingUsers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý lịch sử điểm'),
        backgroundColor: const Color(0xFF6AB89E), // Màu xanh đồng bộ với quản lý biểu cảm
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _isLoading || _isLoadingUsers ? null : _loadPointHistory,
          ),
        ],
      ),
      body: (_isLoading || _isLoadingUsers)
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: DataTable2(
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    minWidth: 1200,
                    headingRowColor: MaterialStateProperty.all(Colors.green.withOpacity(0.2)),
                    headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 15),
                    columns: const [
                      DataColumn2(label: Text('Người dùng'), size: ColumnSize.M),
                      DataColumn2(label: Text('Hành động'), size: ColumnSize.S),
                      DataColumn2(label: Text('Mô tả'), size: ColumnSize.L),
                      DataColumn2(label: Text('Điểm'), size: ColumnSize.S),
                      DataColumn2(label: Text('Thời gian'), size: ColumnSize.S),
                      DataColumn2(label: Text('Xem'), size: ColumnSize.S),
                    ],
                    rows: _pointHistory.map((point) {
                      final timestamp = point['timestamp'];
                      String timeStr = '-';
                      if (timestamp is Timestamp) {
                        final date = timestamp.toDate();
                        timeStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                      }
                      final userId = point['userId'] ?? '-';
                      final userName = _userNames[userId] ?? userId;
                      return DataRow(
                        cells: [
                          DataCell(Text(userName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          DataCell(Text(point['action'] ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          DataCell(Text(point['description'] ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis)),
                          DataCell(Text('${point['points'] ?? 0}')),
                          DataCell(Text(timeStr)),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.remove_red_eye, color: Colors.green),
                              tooltip: 'Xem chi tiết',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) {
                                    return AlertDialog(
                                      title: const Text('Chi tiết metadata'),
                                      content: SingleChildScrollView(
                                        child: Text(point['metadata'] != null ? point['metadata'].toString() : 'Không có dữ liệu'),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(),
                                          child: const Text('Đóng'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
    );
  }
}
