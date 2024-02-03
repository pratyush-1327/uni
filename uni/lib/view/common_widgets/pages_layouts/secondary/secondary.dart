import 'package:flutter/material.dart';
import 'package:uni/view/common_widgets/pages_layouts/general/general.dart';
import 'package:uni/view/common_widgets/pages_layouts/general/widgets/bottom_navigation_bar.dart';
import 'package:uni/view/common_widgets/pages_layouts/general/widgets/refresh_state.dart';
import 'package:uni/view/common_widgets/pages_layouts/general/widgets/top_navigation_bar.dart';

/// Page with a back button on top
abstract class SecondaryPageViewState<T extends StatefulWidget>
    extends GeneralPageViewState<T> {
  @override
  Scaffold getScaffold(BuildContext context, Widget body) {
    return Scaffold(
      appBar: AppTopNavbar(
        title: getTitle(),
        leftButton: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: BackButton(),
        ),
        rightButton: getTopRightButton(context),
      ),
      bottomNavigationBar: AppBottomNavbar(
        parentContext: context,
      ),
      body: RefreshState(onRefresh: onRefresh, child: body),
    );
  }

  String? getTitle() {
    return null;
  }

  Widget? getTopRightButton(BuildContext context) {
    return null;
  }
}
