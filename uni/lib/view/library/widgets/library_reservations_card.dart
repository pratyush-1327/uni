import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:tuple/tuple.dart';
import 'package:uni/model/app_state.dart';
import 'package:uni/model/entities/library_reservation.dart';
import 'package:uni/model/entities/time_utilities.dart';
import 'package:uni/utils/drawer_items.dart';
import 'package:uni/view/common_widgets/generic_card.dart';

class LibraryReservationsCard extends GenericCard {
  LibraryReservationsCard({Key? key}) : super(key: key);

  const LibraryReservationsCard.fromEditingInformation(
      Key key, bool editingMode, Function()? onDelete)
      : super.fromEditingInformation(key, editingMode, onDelete);

  @override
  onClick(BuildContext context) =>
      Navigator.pushNamed(context, '/${DrawerItem.navLibrary.title}');

  @override
  String getTitle() => 'Gabinetes Reservados';

  @override
  Widget buildCardContent(BuildContext context) {
    return StoreConnector<AppState,
            Tuple2<List<LibraryReservation>?, RequestStatus?>>(
        converter: (store) => Tuple2(store.state.content['reservations'],
            store.state.content['reservationsStatus']),
        builder: (context, roomsInfo) {
          if (roomsInfo.item2 == null ||
              roomsInfo.item2 == RequestStatus.busy) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return RoomsList(roomsInfo.item1);
          }
        });
  }
}

class RoomsList extends StatelessWidget {
  final List<LibraryReservation>? reservations;

  const RoomsList(this.reservations, {super.key});

  @override
  Widget build(context) {
    if (reservations == null || reservations!.isEmpty) {
      return Center(
          child: Text('Não tens salas reservadas!',
              style: Theme.of(context).textTheme.headline6,
              textAlign: TextAlign.center));
    }
    final List<Widget> rooms = [];

    for (int i = 0; i < reservations!.length && i < 2; i++) {
      rooms.add(RoomRow(reservations![i]));
    }

    return Column(children: rooms);
  }
}

class RoomRow extends StatelessWidget {
  final LibraryReservation? reservation;
  late final String hoursStart;
  late final String hoursEnd;
  late final String weekDay;
  late final String day;
  late final String month;

  RoomRow(this.reservation, {super.key}) {
    hoursStart = DateFormat('HH:mm').format(reservation!.startDate);
    hoursEnd = DateFormat('HH:mm')
        .format(reservation!.startDate.add(reservation!.duration));
    weekDay = TimeString.getWeekdaysStrings()[reservation!.startDate.weekday];
    day = DateFormat('dd').format(reservation!.startDate);
    initializeDateFormatting();
    month = DateFormat('MMMM', 'pt').format(reservation!.startDate);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            border:
                Border.all(color: Theme.of(context).dividerColor, width: 0.5),
            borderRadius: const BorderRadius.all(Radius.circular(7))),
        margin: const EdgeInsets.all(8),
        child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Column(children: [
                Text(
                  hoursStart,
                  style: Theme.of(context).textTheme.bodyText1,
                ),
                Text(
                  hoursEnd,
                  style: Theme.of(context).textTheme.bodyText1,
                )
              ]),
              Column(
                children: [
                  Text(reservation!.room,
                      //textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headline5?.apply(
                          color: Theme.of(context).colorScheme.tertiary)),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 2)),
                  Text(
                    '$weekDay, $day de $month',
                    style: Theme.of(context).textTheme.subtitle1,
                  )
                ],
              ),
              getRemoveButton(context)
            ]));
  }

  Widget getRemoveButton(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints(
          minHeight: kMinInteractiveDimension / 3,
          minWidth: kMinInteractiveDimension / 3),
      icon: const Icon(Icons.close),
      iconSize: 24,
      color: Colors.grey,
      alignment: Alignment.centerRight,
      tooltip: 'Cancelar reserva',
      onPressed: () => {},
    );
  }
}
