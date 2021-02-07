ruleset wovyn_base {
    meta {
      name "wovyn_base"
      use module message
      configure using 
        heart_beat_second = 20
    }
    global {
      temperature_threshold = 75.31
    }
    rule process_heartbeat {
      select when wovyn heartbeat where event:attrs{"genericThing"}
      pre{
        heatbeatinfo = event:attrs
      }
      send_directive("content", heatbeatinfo);
      fired {
        raise wovyn event "new_temperature_reading"
        attributes {"temperature": event:attrs{"genericThing"}["data"]["temperature"],
                    "time": time:now()}
      }
    }

    rule find_high_temps{
      select when wovyn new_temperature_reading
      pre{
        tempF = event:attrs{"temperature"}[0]["temperatureF"]
        k = klog("get high temperature: " + tempF + "-----------")
      }
      always{
        raise wovyn event "threshold_violation"
        attributes event:attrs
        if tempF > temperature_threshold
      }
    }

    rule threshold_notification {
      select when wovyn threshold_violation
      pre{
        tempF = event:attrs{"temperature"}[0]["temperatureF"]
        time = event:attrs{"time"}
        messageContent = "At " + time + " temperature " + tempF +" exceeding threshold"
        reciever = "+18014208731" 
        k = klog("temperature "+ tempF +" exceeding threshold, send sms -----------")
      }
      message:send_sms(messageContent, reciever) setting(content)
    }
}
  
  
// w base channels allow *:
// ckku3kpa900mhkmj421l66168
