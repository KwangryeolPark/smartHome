#include <SPI.h>
#include <Ethernet.h>
#include <Servo.h>

byte mac[] = {
  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED
};
IPAddress ip(175, 114, 243, 11);

EthernetServer server(80);

Servo servo;

#define ILLUMINATION_PIN  A0
#define illuminationThreshold   1000

#define SERVO_PIN 2
#define maxServoDegree  0
#define minServoDegree  100

#define BODY_DETECTIOR_PIN  A1

void setup() {
  Serial.begin(9600);
  while (!Serial);
  Serial.println("Ethernet WebServer");

  Ethernet.begin(mac, ip);

  if (Ethernet.hardwareStatus() == EthernetNoHardware) {
    Serial.println("Ethernet shield was not found.  Sorry, can't run without hardware. :(");
    while (true);
  }
  if (Ethernet.linkStatus() == LinkOFF) {
    Serial.println("Ethernet cable is not connected.");
  }

  // start the server
  server.begin();
  Serial.print("server is at ");
  Serial.println(Ethernet.localIP());
}

String readString = "";
bool blinderPos = false;  //기본 내리기
bool autoBlinder = true;  //
bool bulb = true;
void loop() {
  // listen for incoming clients
  EthernetClient client = server.available();
  if (client) {
    Serial.println("new client");
    // an http request ends with a blank line
    boolean currentLineIsBlank = true;
    while (client.connected()) {
      if (client.available()) {
        char c = client.read();
        readString += c;

        Serial.write(c);
        if (c == '\n' && currentLineIsBlank) {
          if (readString.indexOf("GET") != -1){   //GET으로 데이터를 받을 때
            sendJsonData(&client, "OK2", "onFire", "intruder"); 
          }
          else {  //POST로 데이터를 받을 때
            Serial.println("\nPOST Received");
            while (client.available()) {  //데이터 받기
              String jsonData = client.readString();
              Serial.println(jsonData);
              char Message = jsonData.charAt(12); //0 : 자동모드인지 아닌지, 1 : 블라인더 위치, 2 : 아두이노의 데이터 요청
              char Data = jsonData.charAt(23);
              switch (Message - '0') {
                case 0: //오토 블라인더 관련
                  sendJsonData(&client, "OK0", "", "");
                  autoBlinder = (Data - '0' == 1) ? true : false;
                  Serial.println("오토 블라인더 상태 " + String(blinderPos));
                  break;
                  
                case 1: //수동 모드 관련
                  sendJsonData(&client, "OK1", "", "");
                  blinderPos = (Data - '0' == 1) ? true : false;
                  Serial.println("블라인더 상태 " + String(blinderPos));
                  break;
                  
                case 2:
                  sendJsonData(&client, "OK2", "", "");
                  break;

                case 3: //조명 관련
                  if(Data - '0' == 1) bulb = true;
                  else bulb = false;
                break;
              }
            }
          }
          // send a standard http response header
          break;
        }
        if (c == '\n')  currentLineIsBlank = true;
        else if (c != '\r') currentLineIsBlank = false;
      }
    }

    client.stop();
    readString = "";
    Serial.println("client disconnected");
  }

  if(autoBlinder == true) {
    uint16_t ligthness = analogRead(ILLUMINATION_PIN);
    if(ligthness >= illuminationThreshold) servo.write(minServoDegree); //내리기
    else servo.write(maxServoDegree); //올리기
  } else {
    if(blinderPos = true) servo.write(maxServoDegree);
    else servo.write(minServoDegree);
  }
  
}

void sendJsonData(EthernetClient *client, String data1, String data2, String data3) {
  String data = "{\"Message\":\"" + data1 + "\",\"Status1\":\"" + data2 + "\",\"Status2\":\"" + data3 + "\"}";
  client -> println("HTTP/1.1 200 OK");
  client -> println("Content-Type: application/json");
  client -> println("content-length: " + String(data.length()));  // the connection will be closed after completion of the response
  client -> println();
  client -> print(data);
}
