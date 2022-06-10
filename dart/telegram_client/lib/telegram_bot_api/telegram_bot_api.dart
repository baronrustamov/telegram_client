// ignore_for_file: non_constant_identifier_names, slash_for_doc_comments, empty_catches

/**
Licensed under the MIT License <http://opensource.org/licenses/MIT>.
SPDX-License-Identifier: MIT
Copyright (c) 2021 Azkadev Telegram Client <http://github.com/azkadev/telegram_client>.
Permission is hereby  granted, free of charge, to any  person obtaining a copy
of this software and associated  documentation files (the "Software"), to deal
in the Software  without restriction, including without  limitation the rights
to  use, copy,  modify, merge,  publish, distribute,  sublicense, and/or  sell
copies  of  the Software,  and  to  permit persons  to  whom  the Software  is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE  IS PROVIDED "AS  IS", WITHOUT WARRANTY  OF ANY KIND,  EXPRESS OR
IMPLIED,  INCLUDING BUT  NOT  LIMITED TO  THE  WARRANTIES OF  MERCHANTABILITY,
FITNESS FOR  A PARTICULAR PURPOSE AND  NONINFRINGEMENT. IN NO EVENT  SHALL THE
AUTHORS  OR COPYRIGHT  HOLDERS  BE  LIABLE FOR  ANY  CLAIM,  DAMAGES OR  OTHER
LIABILITY, WHETHER IN AN ACTION OF  CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE  OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. 
**/

part of telegram_client;

/// Telegram Bot Api library:
/// example:
/// ```dart
/// TelegramBotApi tg = TelegramBotApi("token_bot");
/// tg.api.request("sendMessage", {
///   "chat_id": 12345,
///   "text": "Hello world"
/// });
/// ````
///
class TelegramBotApi {
  final String _token;

  final Map _options = {
    "botPath": "/bot/",
    "userPath": "/user/",
    "port": 8080,
    "type": "bot",
    "logger": false,
    "api": "https://api.telegram.org/",
    "allowed_updates": [
      "message",
      "edited_message",
      "channel_post",
      "edited_channel_post",
      "inline_query",
      "chosen_inline_result",
      "callback_query",
      "shipping_query",
      "pre_checkout_query",
      "poll",
      "poll_answer",
      "my_chat_member",
      "chat_member",
      "chat_join_request"
    ],
  };

  EventEmitter emitter = EventEmitter();
  Isolate? receiveIsolate;
  ReceivePort? receivePort;

  /// list methods:
  /// api:
  /// ```dart
  /// tg.api.request("getMe");
  /// ```
  ///
  TelegramBotApi(this._token, [Map? option]) {
    if (_token.isEmpty) {
      throw "please fill token bot";
    }
    if (option != null) {
      _options.addAll(option);
    }
  }

  /// call latest [Bot Api](https://core.telegram.org/bots/api#available-methods)
  /// example:
  /// [sendMessage]()
  /// ```dart
  /// tg.api.request("sendMessage", {
  ///    "chat_id": 12345,
  ///    "text": "hello world",
  ///    "reply_markup": {
  ///       "inline_keyboard": [
  ///           [
  ///               {
  ///                 "text": "Azkadev",
  ///                 "url": "https://github.com/azkadev"
  ///               }
  ///           ]
  ///       ]
  ///    }
  /// });
  /// ```
  ///

  /// add this for handle update api
  void on(String type_update, void Function(UpdateApi update) callback) async {
    if (type_update.isEmpty) {
      throw {"message": "please add type_update"};
    }
    if (type_update.toString().toLowerCase() == "update") {
      emitter.on("update", null, (Event ev, context) {
        return callback(UpdateApi(ev.eventData as Map));
      });
    }
  }

  /// add this for multithread on flutter apps
  Future<void> initIsolate() async {
    receivePort = ReceivePort();
    receivePort!.listen((message) {
      emitter.emit("update", null, message);
    });
    receiveIsolate = await Isolate.spawn((List args) async {
      final SendPort sendPortToMain = args[0];
      final Map option = args[1];
      final String token = args[2];
      TelegramBotApi tg = TelegramBotApi(token, option);
      var offset = 0;
      List allowed_updates = [];
      int milliseconds = 1;
      if (option["allowed_updates"] is List) {
        allowed_updates = option["allowed_updates"];
      }
      if (option["delay_duration"] is int) {
        milliseconds = option["delay_duration"];
      }
      while (true) {
        await Future.delayed(Duration(milliseconds: milliseconds));
        Map parameters = {
          "offset": offset,
        };
        try {
          parameters.addAll({"allowed_updates": allowed_updates});
        } catch (e) {}
        var getUpdates = await tg.request("getUpdates", parameters);
        if (getUpdates is Map && getUpdates["ok"] is bool && getUpdates["ok"]) {
          List updates = [];
          try {
            updates = getUpdates["result"];
          } catch (e) {}
          if (updates.isNotEmpty) {
            for (var i = 0; i < updates.length; i++) {
              var loop_data = updates[i];
              try {
                offset = (loop_data["update_id"] + 1);
              } catch (e) {}
              sendPortToMain.send(loop_data);
            }
          }
        }
      }
    }, [
      receivePort!.sendPort,
      _options,
      _token,
    ], onExit: receivePort!.sendPort, onError: receivePort!.sendPort);
  }

  /// call api latest [bot api](https://core.telegram.org/bots/api#available-methods)
  /// example:
  /// ```dart
  /// request("sendMessage", {
  ///   "chat_id": 123456,
  ///   "text": "<b>Hello</b> <code>word</code>",
  ///   "parse_mode": "html"
  /// });
  /// ```
  dynamic request(String method,
      [Map? parameters, bool? is_form = false]) async {
    parameters ??= {};
    is_form ??= false;
    var option = {
      "method": "post",
    };
    var url =
        "${_options["api"].toString()}${_options["type"].toString()}${_token.toString()}/${method.toString()}";
    if (is_form) {
      Map params = parameters;
      var form = MultipartRequest("post", Uri.parse(url));
      params.forEach((key, value) async {
        if (typeData(value) == "object") {
          if (typeData(value["is_post_file"]) == "boolean" &&
              value["is_post_file"]) {
            var files = await MultipartFile.fromPath(key, value["file_path"]);
            form.files.add(files);
          } else {
            form.fields[key] = convert.json.encode(value);
          }
        } else if (typeData(value) == "string") {
          form.fields[key] = value;
        } else {
          form.fields[key] = value.toString();
        }
      });
      var response = await form.send();
      if (response.statusCode == 200) {
        var res = await Response.fromStream(response);
        return convert.json.decode(res.body);
      } else {
        var res = await Response.fromStream(response);
        throw convert.json.decode(res.body);
      }
    } else {
      option["body"] = convert.json.encode(parameters);
      var response = await post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          "Access-Control-Allow-Origin": "*",
          "Content-Type": "application/json",
        },
        body: option["body"],
      );
      if (response.statusCode == 200) {
        if (method.toString().toLowerCase() == "getfile") {
          var getFile = convert.json.decode(response.body);
          var url =
              "${option["api"].toString().toLowerCase()}file/${option["type"].toString().toLowerCase()}";
          getFile["result"]["file_url"] =
              "$url$_token/${getFile["result"]["file_path"]}";
          return getFile;
        } else {
          return convert.json.decode(response.body);
        }
      } else {
        throw convert.json.decode(response.body);
      }
    }
  }

  /// call api latest [bot api](https://core.telegram.org/bots/api#available-methods) with upload file
  /// example:
  /// ```dart
  /// requestForm("sendDocument", {
  ///   "chat_id": 123456,
  ///   "document": tg.file("./doc.json"),
  ///   "parse_mode": "html"
  /// });
  /// ```
  dynamic requestForm(method, [var parameters]) async {
    return await request(method, parameters, true);
  }

  /// example:
  /// ```dart
  /// tg.file("./doc.json"),
  /// ```
  dynamic file(path, [var option]) {
    Map<String, dynamic> jsonData = {"is_post_file": true};
    if (RegExp(r"^(./|/)", caseSensitive: false).hasMatch(path)) {
      var filename = path
          .toString()
          .replaceAll(RegExp(r"^(./|/)", caseSensitive: false), "");
      jsonData["file_name"] = filename;
      jsonData["file_path"] = path;
      if (typeData(option) == "object") {
        jsonData.addAll(option);
      }
    } else {
      jsonData["is_post_file"] = false;
      jsonData["file_path"] = path;
    }
    return jsonData;
  }
}

/// Update td for make update support raw, raw api, raw api light
class UpdateApi {
  late Map update;

  /// Update td for make update support raw, raw api, raw api light
  UpdateApi(this.update);

  /// update api raw from api
  Map get raw {
    return update;
  }

  /// Update more pretty with minimalist
  Map get raw_api_light {
    return update;
  }

  /// Update more pretty with minimalist
  Map get raw_api {
    return update;
  }
}
