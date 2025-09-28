import 'package:flutter/material.dart';

import 'package:nash/pages/account_page.dart';

class OtherAccountPage extends StatelessWidget {
  final String userId;
  const OtherAccountPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return AccountPage(userId: userId, readOnly: true, anonymousDisplay: true);
  }
}
