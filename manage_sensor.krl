ruleset manage_sensors {
    meta {
        configure using 
            temperature_storeURL = "file:///home/haoyu/Documents/cs462ds/temperature_store.krl"  
            wovyn_baseURL = "file:///home/haoyu/Documents/cs462ds/wovyn_base.krl"
            sensor_profileURL = "file:///home/haoyu/Documents/cs462ds/sensor_profile.krl"
            emitterURL = "file:///home/haoyu/Documents/cs462ds/emitter.krl" 
        use module io.picolabs.wrangler alias wrangler
        shares show_sensors , get_all_temp_records
    }
    global {
        defaultRuleSetURLs = [ "file:///home/haoyu/Documents/cs462ds/sensor_profile.krl", 
                            "file:///home/haoyu/Documents/cs462ds/wovyn_base.krl", 
                            "file:///home/haoyu/Documents/cs462ds/temperature_store.krl",
                            "file:///home/haoyu/Documents/cs462ds/emitter.krl"]
        show_sensors = function() {
            ent:sensors
        }
        nameFromID = function(sensor_id) {
            "sensor " + sensor_id
        }

        showChildren = function() {
            wrangler:children()
        }

        get_sensor_temp_records = function(sensor_id) {
            eci = ent:sensors{sensor_id}{"eci"}
            wrangler:picoQuery(eci,"temperature_store","temperatures", {});
        }

        get_all_temp_records = function(){
            readings = []
            c = ent:sensors.filter(function(v, k) {
                readings.append(get_sensor_temp_records(k))
            })
            return {"readings": readings}
            
        }

    }

    rule initialize_sensors {
        select when sensor needs_initialization
        always {
          ent:sensors := {}
        }
    }

    rule new_sensor {
        select when sensor new_sensor
        pre {
            sensor_id = event:attrs{"sensor_id"}
            exists = ent:sensors && ent:sensors >< sensor_id
        }
        if exists then
            send_directive("sensor_ready", {"sensor_id":sensor_id})
        notfired {
            raise wrangler event "new_child_request"
                attributes { "name": nameFromID(sensor_id), "backgroundColor": "#ff69b4", "sensor_id": sensor_id }
        }
    }

    

    rule store_new_sensor {
        select when wrangler new_child_created
        foreach defaultRuleSetURLs setting(murls)
            pre {
            the_sensor = {"eci": event:attrs{"eci"}}
            sensor_id = event:attrs{"sensor_id"}
            x = klog("found new child: " + event:attrs.encode())
            
            }
            if sensor_id
            then event:send(
                { "eci": the_sensor.get("eci"), 
                "eid": "install-ruleset",
                "domain": "wrangler", "type": "install_ruleset_request",
                "attrs": {
                    "url": murls,
                }
                }
            )
        fired {
          ent:sensors{sensor_id} := the_sensor
          raise sensor event "child_profile_update"
            attributes event:attrs on final
        }
    }

    rule update_child_sensor_profile {
        select when sensor child_profile_update
        pre{
            the_sensor = {"eci": event:attrs{"eci"}}
            sensor_id = event:attrs{"sensor_id"}
            sensorName = nameFromID(sensor_id)
        }
        event:send(
            { 
                "eci": the_sensor.get("eci"), 
                "eid": "profile_update",
                "domain": "sensor", "type": "profile_updated",
                "attrs": {
                    "name": sensorName,
                    "location": "Hao's place",
                    "number": "+18014208731",
                    "threshold": "71.1"
                }
            }
        )
    }
    
    rule sensor_profile_info {
        select when sensor get_profile
        pre {
            sensor_id = event:attrs{"sensor_id"}
            exists = ent:sensors && ent:sensors >< sensor_id
            eci = ent:sensors{sensor_id}{"eci"}
            answer = wrangler:picoQuery(eci,"sensor_profile","get_profile_f", {}); 
        }
        if exists
            then send_directive(answer)
    }

    rule remove_sensor {
        select when sensor unneeded_sensor
        pre {
            sensor_id = event:attrs{"sensor_id"}
            exists = ent:sensors && ent:sensors >< sensor_id
            eci = ent:sensors{sensor_id}{"eci"}
        }
        if exists && eci then
            send_directive("deleting_section", {"sensor_id":sensor_id})
        fired {
            raise wrangler event "child_deletion_request"
                attributes {"eci": eci};
            clear ent:sensors{sensor_id}
        }
    }

    rule get_all_temp_records_r {
        select when sensor get_all_temp
        pre {
            x = get_all_temp_records()
        }
        send_directive(x)
    }
    
    rule get_all_children {
        select when sensor show_children
        pre {
            x = show_sensors()         
        }
        send_directive(x)
    }
 
}