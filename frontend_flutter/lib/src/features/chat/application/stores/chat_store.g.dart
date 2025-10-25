// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ChatStore on _ChatStore, Store {
  late final _$sessionsAtom = Atom(
    name: '_ChatStore.sessions',
    context: context,
  );

  @override
  ObservableList<ChatSession> get sessions {
    _$sessionsAtom.reportRead();
    return super.sessions;
  }

  @override
  set sessions(ObservableList<ChatSession> value) {
    _$sessionsAtom.reportWrite(value, super.sessions, () {
      super.sessions = value;
    });
  }

  late final _$activeChatIdAtom = Atom(
    name: '_ChatStore.activeChatId',
    context: context,
  );

  @override
  String get activeChatId {
    _$activeChatIdAtom.reportRead();
    return super.activeChatId;
  }

  @override
  set activeChatId(String value) {
    _$activeChatIdAtom.reportWrite(value, super.activeChatId, () {
      super.activeChatId = value;
    });
  }

  late final _$messagesAtom = Atom(
    name: '_ChatStore.messages',
    context: context,
  );

  @override
  ObservableList<ChatMessage> get messages {
    _$messagesAtom.reportRead();
    return super.messages;
  }

  @override
  set messages(ObservableList<ChatMessage> value) {
    _$messagesAtom.reportWrite(value, super.messages, () {
      super.messages = value;
    });
  }

  late final _$perChatUsdAtom = Atom(
    name: '_ChatStore.perChatUsd',
    context: context,
  );

  @override
  ObservableMap<String, double> get perChatUsd {
    _$perChatUsdAtom.reportRead();
    return super.perChatUsd;
  }

  @override
  set perChatUsd(ObservableMap<String, double> value) {
    _$perChatUsdAtom.reportWrite(value, super.perChatUsd, () {
      super.perChatUsd = value;
    });
  }

  late final _$perChatInTokensAtom = Atom(
    name: '_ChatStore.perChatInTokens',
    context: context,
  );

  @override
  ObservableMap<String, int> get perChatInTokens {
    _$perChatInTokensAtom.reportRead();
    return super.perChatInTokens;
  }

  @override
  set perChatInTokens(ObservableMap<String, int> value) {
    _$perChatInTokensAtom.reportWrite(value, super.perChatInTokens, () {
      super.perChatInTokens = value;
    });
  }

  late final _$perChatOutTokensAtom = Atom(
    name: '_ChatStore.perChatOutTokens',
    context: context,
  );

  @override
  ObservableMap<String, int> get perChatOutTokens {
    _$perChatOutTokensAtom.reportRead();
    return super.perChatOutTokens;
  }

  @override
  set perChatOutTokens(ObservableMap<String, int> value) {
    _$perChatOutTokensAtom.reportWrite(value, super.perChatOutTokens, () {
      super.perChatOutTokens = value;
    });
  }

  late final _$usageAtom = Atom(name: '_ChatStore.usage', context: context);

  @override
  CostUsage? get usage {
    _$usageAtom.reportRead();
    return super.usage;
  }

  @override
  set usage(CostUsage? value) {
    _$usageAtom.reportWrite(value, super.usage, () {
      super.usage = value;
    });
  }

  late final _$totalUsdAtom = Atom(
    name: '_ChatStore.totalUsd',
    context: context,
  );

  @override
  double get totalUsd {
    _$totalUsdAtom.reportRead();
    return super.totalUsd;
  }

  @override
  set totalUsd(double value) {
    _$totalUsdAtom.reportWrite(value, super.totalUsd, () {
      super.totalUsd = value;
    });
  }

  late final _$totalInputTokensAtom = Atom(
    name: '_ChatStore.totalInputTokens',
    context: context,
  );

  @override
  int get totalInputTokens {
    _$totalInputTokensAtom.reportRead();
    return super.totalInputTokens;
  }

  @override
  set totalInputTokens(int value) {
    _$totalInputTokensAtom.reportWrite(value, super.totalInputTokens, () {
      super.totalInputTokens = value;
    });
  }

  late final _$totalOutputTokensAtom = Atom(
    name: '_ChatStore.totalOutputTokens',
    context: context,
  );

  @override
  int get totalOutputTokens {
    _$totalOutputTokensAtom.reportRead();
    return super.totalOutputTokens;
  }

  @override
  set totalOutputTokens(int value) {
    _$totalOutputTokensAtom.reportWrite(value, super.totalOutputTokens, () {
      super.totalOutputTokens = value;
    });
  }

  late final _$runningAtom = Atom(name: '_ChatStore.running', context: context);

  @override
  bool get running {
    _$runningAtom.reportRead();
    return super.running;
  }

  @override
  set running(bool value) {
    _$runningAtom.reportWrite(value, super.running, () {
      super.running = value;
    });
  }

  late final _$connectionAtom = Atom(
    name: '_ChatStore.connection',
    context: context,
  );

  @override
  ConnectionStatus get connection {
    _$connectionAtom.reportRead();
    return super.connection;
  }

  @override
  set connection(ConnectionStatus value) {
    _$connectionAtom.reportWrite(value, super.connection, () {
      super.connection = value;
    });
  }

  late final _$sendTaskAsyncAction = AsyncAction(
    '_ChatStore.sendTask',
    context: context,
  );

  @override
  Future<void> sendTask(String text) {
    return _$sendTaskAsyncAction.run(() => super.sendTask(text));
  }

  late final _$initAsyncAction = AsyncAction(
    '_ChatStore.init',
    context: context,
  );

  @override
  Future<void> init() {
    return _$initAsyncAction.run(() => super.init());
  }

  late final _$_ChatStoreActionController = ActionController(
    name: '_ChatStore',
    context: context,
  );

  @override
  String createNewChat({String? title}) {
    final _$actionInfo = _$_ChatStoreActionController.startAction(
      name: '_ChatStore.createNewChat',
    );
    try {
      return super.createNewChat(title: title);
    } finally {
      _$_ChatStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setActiveChat(String id) {
    final _$actionInfo = _$_ChatStoreActionController.startAction(
      name: '_ChatStore.setActiveChat',
    );
    try {
      return super.setActiveChat(id);
    } finally {
      _$_ChatStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void renameChat(String id, String title) {
    final _$actionInfo = _$_ChatStoreActionController.startAction(
      name: '_ChatStore.renameChat',
    );
    try {
      return super.renameChat(id, title);
    } finally {
      _$_ChatStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void removeChat(String id) {
    final _$actionInfo = _$_ChatStoreActionController.startAction(
      name: '_ChatStore.removeChat',
    );
    try {
      return super.removeChat(id);
    } finally {
      _$_ChatStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
sessions: ${sessions},
activeChatId: ${activeChatId},
messages: ${messages},
perChatUsd: ${perChatUsd},
perChatInTokens: ${perChatInTokens},
perChatOutTokens: ${perChatOutTokens},
usage: ${usage},
totalUsd: ${totalUsd},
totalInputTokens: ${totalInputTokens},
totalOutputTokens: ${totalOutputTokens},
running: ${running},
connection: ${connection}
    ''';
  }
}
