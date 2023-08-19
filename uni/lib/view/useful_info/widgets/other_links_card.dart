import 'package:flutter/material.dart';
import 'package:uni/generated/l10n.dart';
import 'package:uni/view/common_widgets/generic_expansion_card.dart';
import 'package:uni/view/useful_info/widgets/link_button.dart';

/// Manages the 'Current account' section inside the user's page (accessible
/// through the top-right widget with the user picture)
class OtherLinksCard extends GenericExpansionCard {
  const OtherLinksCard({super.key});

  @override
  Widget buildCardContent(BuildContext context) {
    return Column(
      children: [
        LinkButton(title: S.of(context).print, link: 'https://print.up.pt')
      ],
    );
  }

  @override
  String getTitle(BuildContext context) => S.of(context).other_links;
}
