ruleset sensor_profile {
    meta {
      name "sensor_profile"
      provides threshold, smsNumber
    }
    global {
        threshold = function(){
            ent:threshold
        }
        smsNumber = function(){
            ent:smsNumber
        }
    }
    
    rule profile_updated {
        select when sensor profile_updated
        pre {
            
        }
        send_directive("profile", "done")
        always {
            ent:sensorName := event:attrs{"name"} => event:attrs{"name"} | ent:sensorName
            ent:sensorLocation := event:attrs{"location"} => event:attrs{"location"} | ent:sensorLocation
            ent:smsNumber := event:attrs{"number"} => event:attrs{"number"} | ent:smsNumber
            ent:threshold := event:attrs{"threshold"} => event:attrs{"threshold"} | ent:threshold
        }
    }

    rule get_profile {
        select when sensor get_profile
        send_directive("profile", {"name": ent:sensorName, "location": ent:sensorLocation, "number": ent:smsNumber, "threshold": ent:threshold })
    }
}
  
  
// w base channels allow *:
// ckku3kpa900mhkmj421l66168