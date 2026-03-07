import 'package:flutter_app/app/backend/models/learning-lesson-model.dart';
import 'package:get/get.dart';

class QuizStateController extends GetxController {
  final Rxn<QuizModel> dataQuiz = Rxn<QuizModel>();
  final Rxn<QuestionModel> itemQuestion = Rxn<QuestionModel>();
  final Rxn<dynamic> itemCheck = Rxn<dynamic>();

  void setData(value) {
    dataQuiz.value = value;
  }

  void setQuestion(value) {
    itemQuestion.value = value;
  }

  void setItemCheckuestion(value) {
    itemCheck.value = value;
  }
}
