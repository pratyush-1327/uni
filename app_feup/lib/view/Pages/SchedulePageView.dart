import 'package:flutter/material.dart';
import '../Pages/GeneralPageView.dart';
import 'package:app_feup/controller/parsers/parser-schedule.dart';
import 'package:app_feup/model/AppState.dart';
import 'package:app_feup/view/widgets/ScheduleSlot.dart';
import 'package:flutter_redux/flutter_redux.dart';

class SchedulePageView extends GeneralPageView {

  SchedulePageView(
    {Key key,
      @required this.tabController,
      @required this.daysOfTheWeek,
      @required this.aggLectures});

  final List<String> daysOfTheWeek;
  final List<List<Lecture>> aggLectures;
  final TabController tabController;

  @override
  Widget getBody(BuildContext context) {
    final MediaQueryData queryData = MediaQuery.of(context);

    return new Column(
      children: <Widget>[
        new Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(width: 1.0, color: Colors.grey),
            ),
          ),
          constraints: BoxConstraints(maxHeight: 150.0),
          child: new Material(
            color: Colors.white,
            child: new TabBar(
              controller: tabController,
              isScrollable: true,
              unselectedLabelColor: Colors.grey,
              labelColor: Colors.grey,
              indicatorWeight: 3.0,
              indicatorColor: Colors.grey,
              labelPadding: EdgeInsets.all(0.0),
              tabs: createTabs(queryData),
            ),
          ),
        ),
        new Expanded(
          child: new TabBarView(
            controller: tabController,
            children: createSchedule(context),
          ),
        ),
      ],
    );
  }

  List<Widget> createTabs(queryData) {
    List<Widget> tabs = List<Widget>();
    for( var i = 0; i < daysOfTheWeek.length; i++) {
      tabs.add(
          new Container(
            width:  queryData.size.width * 1/3,
            child: new Tab(text: daysOfTheWeek[i]),
          )
      );
    }
    return tabs;
  }

  List<Widget> createSchedule(context) {
    List<Widget> tabBarViewContent = List<Widget>();
    for(int i = 0; i < daysOfTheWeek.length; i++) {
      tabBarViewContent.add(createScheduleByDay(i));
    }
    return tabBarViewContent;
  }

  List<Widget> createScheduleRows(lectures){
    List<Widget> scheduleContent = List<Widget>();
    for(int i = 0; i < lectures.length; i++) {
      Lecture lecture = lectures[i];
      scheduleContent.add(new ScheduleSlot(
      subject: lecture.subject,
      typeClass: lecture.typeClass,
      rooms: lecture.room,
      begin: lecture.startTime,
      end: lecture.endTime,
      teacher: lecture.teacher,
      ));
    }
    return scheduleContent;
  }

  Widget createScheduleByDay(day) {
    return StoreConnector<AppState, List<dynamic>>(
        converter: (store) => store.state.content['schedule'],
        builder: (context, lectures){

          if(aggLectures[day].length >= 1) {
            return Container(
                child: new Column(
                  mainAxisSize: MainAxisSize.min,
                  children: createScheduleRows(aggLectures[day]),
                )
            );
          } else {
            return Center(child: Text("Não possui aulas à " + daysOfTheWeek[day] + "."));
          }
        }
    );
  }
}