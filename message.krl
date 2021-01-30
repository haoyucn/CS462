ruleset message {
    meta {
        use module twilio
            with
            auth_token = meta:rulesetConfig{"auth_token"}
            SID = meta:rulesetConfig{"SID"}
            SSID = meta:rulesetConfig{"SSID"}

        shares message
        provide message
    }
    global {
      
        send_sms = defaction(message, reciever) {
            twilio:send_sms(message, reciever);
        }

        message = function(messageId, fromNum, toNum) {
            twilio:messages(messageId, fromNum, toNum)
        }
    }

    rule send_sms {
        select when send sms
        pre {
          message = event:attrs{"message"} => event:attrs{"message"} | "empty message"; // Equals bar at this point
          reciever = event:attrs{"reciever"} => event:attrs{"reciever"} | "+18014208731"; // Equals bar at this point
        }
        send_sms(message, reciever)  setting(content)
      }
}