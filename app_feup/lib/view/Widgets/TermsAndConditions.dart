import 'package:uni/controller/load_static/TermsAndConditions.dart';
import 'package:flutter/cupertino.dart';

class TermsAndConditions extends StatelessWidget {

  static String termsAndConditionsSaved = "Carregando os Termos e Condições...";

  @override
  Widget build(BuildContext context) {
    final Future<String> termsAndConditionsFuture = readTermsAndConditions();
    return FutureBuilder(
      future: termsAndConditionsFuture,
      builder: (BuildContext context, AsyncSnapshot<String> termsAndConditions) {
        if(termsAndConditions.connectionState == ConnectionState.done){
            termsAndConditionsSaved = termsAndConditions.data;
        }
        return Text(termsAndConditionsSaved); 
      }
    );
  }

}