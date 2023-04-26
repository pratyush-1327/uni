import 'package:http/http.dart';
import 'package:uni/controller/fetchers/session_dependant_fetcher.dart';
import 'package:uni/controller/networking/network_router.dart';
import 'package:uni/controller/parsers/parser_library_reservation.dart';
import 'package:uni/model/entities/library_reservation.dart';
import 'package:uni/model/entities/session.dart';

/// Get the library rooms' reservations from the website
class LibraryReservationsFetcherHtml implements SessionDependantFetcher {
  @override
  List<String> getEndpoints(Session session) {
    // TO DO: Implement parsers for all faculties
    // and dispatch for different fetchers
    final String url =
        '${NetworkRouter.getBaseUrl('feup')}res_recursos_geral.pedidos_list?pct_tipo_grupo_id=3';
    return [url];
  }

  Future<List<LibraryReservation>> getReservations(Session session) async {
    final String baseUrl = getEndpoints(session)[0];
    final Future<Response> response =
        NetworkRouter.getWithCookies(baseUrl, {}, session);
    final List<LibraryReservation> reservations =
        await response.then((response) => getReservationsFromHtml(response));

    return reservations;
  }

}