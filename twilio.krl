ruleset twilio {
  meta {
    name "hao's twilio"
    configure using 
      auth_token = ""  
      SID = ""
      SSID = ""
    provides send_sms, messages
  }
  global {
    send_sms = defaction(message, reciever) {
      every {
        http:post(<<https://#{SID}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{SID}/Messages.json>>, 
          form = {
              "Body" : message,
              "From" : "+14126853196",
              "To" : reciever,
              "MessagingServiceSid": SSID
          }) setting(response)
          send_directive("message_sent", {"content": response{"content"}.decode()}) 
      }
    }


    messages = function(messageId, fromNum, toNum){
      url = messageId == "" => <<https://#{SID}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{SID}/Messages>> |  <<https://#{SID}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{SID}/Messages/#{messageId}.json>>
      qp = {}
      exp = fromNum => qp.put("From", fromNum) | ""
      exp2 = toNum => qp.put("To", toNum) | ""
      http:get(url, qs = qp){"content"}.decode()
    }
  }
}


// {"auth_token":"319d36db7d3ffb04d07b6fc15da364ea","SID":"AC2cdef5ff96ab6b128e6551525584ecb5", "SSID" : "MG1dddab521a8f93b418725105908dbf71"}
//+14126853196
// messageid = SMd9c5b8852f264d8488a2b11d6b504126
//