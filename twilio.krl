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
