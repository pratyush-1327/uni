import 'package:duration_picker/duration_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uni/generated/l10n.dart';
import 'package:uni/model/entities/library_reservation.dart';
import 'package:uni/model/providers/lazy/library_reservations_provider.dart';
import 'package:uni/model/providers/startup/session_provider.dart';
import 'package:uni/model/providers/state_providers.dart';
import 'package:uni/view/common_widgets/toast_message.dart';
import 'package:uni/view/lazy_consumer.dart';
import 'package:uni/view/library/widgets/reservation_row.dart';
import 'package:uni/view/library/widgets/reservation_row_shimmer.dart';

class LibraryReservationsTab extends StatelessWidget {
  const LibraryReservationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return LazyConsumer<LibraryReservationsProvider, List<LibraryReservation>>(
      builder: (context, reservations) {
        return LibraryReservationsTabView(reservations);
      },
      contentLoadingWidget: const ReservationRowShimmer(),
      hasContent: (reservations) =>
          reservations.isNotEmpty ||
          Provider.of<LibraryReservationsProvider>(
            context,
            listen: false,
          ).isReserving,
      onNullContent: Column(
        children: [
          Text(
            S.of(context).no_data,
            style: const TextStyle(fontSize: 18),
          ),
          const CreateReservationButton(),
        ],
      ),
    );
  }

  Future<void> refresh(BuildContext context) async {
    await Provider.of<LibraryReservationsProvider>(context, listen: false)
        .forceRefresh(context);
  }
}

class LibraryReservationsTabView extends StatelessWidget {
  const LibraryReservationsTabView(this.reservations, {super.key});
  final List<LibraryReservation> reservations;

  @override
  Widget build(BuildContext context) {
    final rooms = <Widget>[];

    for (var i = 0; i < reservations.length; i++) {
      rooms.add(
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          margin: const EdgeInsets.all(8),
          child: ReservationRow(reservations[i]),
        ),
      );
    }
    if (Provider.of<LibraryReservationsProvider>(context, listen: true)
        .isReserving) {
      rooms.add(const ReservationRowShimmer());
    }
    return ListView(children: [
      ...rooms,
      const CreateReservationButton(),
    ]);
  }
}

class CreateReservationButton extends StatelessWidget {
  const CreateReservationButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.add),
      iconSize: 35,
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (BuildContext toastContext) {
            return ReservationPicker(
              context: context,
              toastContext: toastContext,
            );
          },
        );
      },
    );
  }
}

class ReservationPicker extends StatefulWidget {
  const ReservationPicker({
    required this.context,
    required this.toastContext,
    super.key,
  });
  final BuildContext context;
  final BuildContext toastContext;

  @override
  State<StatefulWidget> createState() => ReservationPickerState();
}

class ReservationPickerState extends State<ReservationPicker> {
  DateTime? date;
  TimeOfDay? time;
  Duration? duration;
  TextEditingController dateInput = TextEditingController();
  TextEditingController durationInput = TextEditingController();
  TextEditingController timeInput = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actionsPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      title: const Center(child: Text('Reservar Sala')),
      actions: <Widget>[
        TextField(
          controller: dateInput,
          decoration: const InputDecoration(
            icon: Icon(Icons.calendar_today),
            labelText: 'Data',
          ),
          readOnly: true,
          onTap: () => onTapDate(context),
        ),
        TextField(
          controller: timeInput,
          decoration: const InputDecoration(
            icon: Icon(Icons.schedule),
            labelText: 'Hora',
          ),
          readOnly: true,
          onTap: () => onTapTime(context),
        ),
        TextField(
          controller: durationInput,
          decoration: const InputDecoration(
            icon: Icon(Icons.timer),
            labelText: 'Duração',
          ),
          readOnly: true,
          onTap: () => onTapDuration(context),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => {
                //Navigator.of(context).pop(),
                makeReservation(context),
              },
              child: const Text('Confirmar'),
            ),
          ],
        )
      ],
    );
  }

  Future<void> onTapDate(BuildContext context) async {
    await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    ).then(
      (datePicked) => setState(() {
        date = datePicked;
        dateInput.text =
            DateFormat('dd-MM-yyyy').format(date ?? DateTime.now());
      }),
    );
  }

  Future<void> onTapTime(BuildContext context) async {
    await showTimePicker(context: context, initialTime: TimeOfDay.now()).then(
      (timePicked) => setState(() {
        time = timePicked;
        timeInput.text = (timePicked ?? TimeOfDay.now()).format(context);
      }),
    );
  }

  Future<void> onTapDuration(BuildContext context) async {
    await showDurationPicker(
      context: context,
      initialTime: const Duration(hours: 1),
    ).then(
      (durationPicked) => setState(() {
        duration = durationPicked;
        durationInput.text = (durationPicked ?? const Duration(hours: 1))
            .toString()
            .split(':00.')
            .first
            .padLeft(5, '0');
      }),
    );
  }

  Future<void> makeReservation(BuildContext context) async {
    Navigator.of(widget.toastContext).pop();
    if (date != null && time != null && duration != null) {
      final session =
          Provider.of<SessionProvider>(widget.context, listen: false).state!;

      final stateProviders = StateProviders.fromContext(context);

      final durationMinutes = duration!.inMinutes.remainder(60);
      final result =
          await stateProviders.libraryReservationsProvider.makeReservation(
        session,
        DateFormat('yyyy-MM-dd').format(date!),
        time!.hour.toString() +
            ((time!.minute > 0 && time!.minute <= 30) ? '' : ',5'),
        ((durationMinutes > 0 && durationMinutes <= 30)
            ? '${duration!.inHours},5'
            : (duration!.inHours + 1).toString()),
      );

      await displayToast(success: result);
    }
  }

  Future<void> displayToast({
    bool success = true,
  }) async {
    if (success) {
      await ToastMessage.success(
        widget.context,
        S.of(widget.context).library_create_success,
      );
    } else {
      await ToastMessage.error(
        widget.context,
        S.of(widget.context).library_create_error,
      );
    }
  }
}
