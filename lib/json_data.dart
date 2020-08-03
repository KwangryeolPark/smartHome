class JsonData{
  final String Message;
  final String Status1;
  final String Status2;

  JsonData({this.Message, this.Status1, this.Status2});

  factory JsonData.fromJson(Map<String, dynamic> json) {
    return JsonData(
      Message: json['Message'] as String,
      Status1: json['Status1'] as String,
      Status2: json['Status2'] as String
    );
  }

  @override
  String toString() => "Message : $Message, Status1 : $Status1, Status2 : $Status2";
}