import 'dart:ui';

import 'package:dart_openai/openai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chatgpt/cubit/setting_cubit.dart';
import 'package:flutter_chatgpt/repository/conversation.dart';
import 'package:get_it/get_it.dart';

class MessageRepository {
  static final MessageRepository _instance = MessageRepository._internal();

  factory MessageRepository() {
    return _instance;
  }

  MessageRepository._internal() {
    init();
  }

  void postMessage(Message message, ValueChanged<Message> onResponse,
      ValueChanged<Message> onError, ValueChanged<Message> onSuccess) async {
    List<Message> messages = await ConversationRepository()
        .getMessagesByConversationUUid(message.conversationId);
    _getResponseFromGpt(messages, onResponse, onError, onSuccess);
  }

  void init() {
    OpenAI.apiKey = GetIt.instance
        .get<UserSettingCubit>()
        .state
        .key;
    OpenAI.baseUrl = GetIt.instance
        .get<UserSettingCubit>()
        .state
        .baseUrl;
  }

  void _getResponseFromGpt(List<Message> messages,
      ValueChanged<Message> onResponse,
      ValueChanged<Message> errorCallback,
      ValueChanged<Message> onSuccess) async {
    List<OpenAIChatCompletionChoiceMessageModel> openAIMessages = [];
    //将messages反转
    messages = messages.reversed.toList();
    while (true) {
      // 将messages里面的每条消息的内容取出来拼接在一起
      String content = "";
      for (Message message in messages) {
        content = content + message.text;
        if (content.length < 1800) {
          // 插入到 openAIMessages 第一个位置
          openAIMessages.insert(
              0,
              OpenAIChatCompletionChoiceMessageModel(
                content: message.text,
                role: message.role,
              ));
        }
      }
      break;
    }
    var message = Message(
        conversationId: messages.first.conversationId,
        text: "",
        role: OpenAIChatMessageRole.assistant); //仅仅第一个返回了角色
    if (GetIt.instance
        .get<UserSettingCubit>()
        .state
        .useStream) {
      Stream<OpenAIStreamChatCompletionModel> chatStream = OpenAI.instance.chat
          .createStream(
          model: GetIt.instance
              .get<UserSettingCubit>()
              .state
              .gptModel,
          messages: openAIMessages);
      chatStream.listen(
            (chatStreamEvent) {
          if (chatStreamEvent.choices.first.delta.content != null) {
            message.text =
                message.text + chatStreamEvent.choices.first.delta.content!;
            onResponse(message);
          }
        },
        onError: (error) {
          message.text = error.message;
          errorCallback(message);
        },
        onDone: () {
          onSuccess(message);
        },
      );
    } else {
      print('xxx messages: $openAIMessages');
      try {
        var response = await OpenAI.instance.chat.create(
          model: GetIt.instance
              .get<UserSettingCubit>()
              .state
              .gptModel,
          messages: openAIMessages,
        );
        message.text = response.choices.first.message.content;
        onSuccess(message);
      } catch (e) {
        message.text = e.toString();
        errorCallback(message);
      }
    }
  }

  deleteMessage(int messageId) {
    ConversationRepository().deleteMessage(messageId);
  }
}
