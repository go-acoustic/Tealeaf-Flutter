import 'tealeaf_model.dart';

class BasicConfig {
  Tealeaf? tealeaf;

  BasicConfig({this.tealeaf});

  BasicConfig.fromJson(Map<String, dynamic> json) {
    tealeaf =
        json['Tealeaf'] != null ? Tealeaf.fromJson(json['Tealeaf']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (tealeaf != null) {
      data['Tealeaf'] = tealeaf!.toJson();
    }
    return data;
  }
}
