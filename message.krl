ruleset message {
    meta {
        use module twilio
            with
            auth_token = meta:rulesetConfig{"auth_token"}
            SID = meta:rulesetConfig{"SID"}
            SSID = meta:rulesetConfig{"SSID"}
        use module sensor_profile
        shares message
        provide message, send_sms
    }
    global {
      
        send_sms = defaction(message, reciever) {
            twilio:send_sms(message, reciever);
        }

        message = function(messageId, fromNum, toNum) {
            twilio:messages(messageId, fromNum, toNum)
        }
    }

    rule send_sms_1 {
        select when send sms
        pre {
          message = event:attrs{"message"} => event:attrs{"message"} | "empty message"; // Equals bar at this point
          reciever = sensor_profile:smsNumber() => sensor_profile:smsNumber() | "+18014208731"; // Equals bar at this point
        }
        send_sms(message, reciever)  setting(content)
      }
}