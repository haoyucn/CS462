ruleset wovyn_base {
    meta {
      name "wovyn_base"
      use module message
      use module sensor_profile
      configure using 
        heart_beat_second = 20
      shares showT
      provides showT
    }
    global {
      temperature_threshold = sensor_profile:threshold() => sensor_profile:threshold() | 74.1
      showT = function(){
        temperature_threshold
      }
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
        logS = tempF > temperature_threshold => "get high temperature: " + tempF + "-----------" | "not exceeding"
        k = klog(logS)
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
      // message:send_sms(messageContent, reciever) setting(content)
    }

    rule nothinghappends{
      select when wovyn connect
      send_directive("content", {"abs": "bbb"})
    }
}
  
  
// w base channels allow *:
// ckku3kpa900mhkmj421l66168