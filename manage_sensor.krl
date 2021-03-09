ruleset manage_sensors {
    meta {
        configure using 
            temperature_storeURL = "file:///home/haoyu/Documents/cs462ds/temperature_store.krl"  
            wovyn_baseURL = "file:///home/haoyu/Documents/cs462ds/wovyn_base.krl"
            sensor_profileURL = "file:///home/haoyu/Documents/cs462ds/sensor_profile.krl"
            emitterURL = "file:///home/haoyu/Documents/cs462ds/emitter.krl" 
        use module io.picolabs.wrangler alias wrangler
        use module message
        shares show_sensors , get_all_temp_records, get_sensor_temp_records, listSubscriptions, showSubscriptionFeeds
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
        listSubscriptions = function() {
            ent:subs
        }
        showChildren = function() {
            wrangler:children()
        }

        showSubscriptionFeeds = function() {
            ent:readings
        }

        get_sensor_temp_records = function(sensor_id) {
            eci = ent:sensors{sensor_id}{"eci"}
            wrangler:picoQuery(eci,"temperature_store","temperatures", {});
        }

        get_all_temp_records = function(){
            readings = []
            // c = ent:sensors.filter(function(v, k) {
            //     x = get_sensor_temp_records(k)
            //     y = klog(x)
            //     readings = readings.append(x)
            //     x1 = klog(readings)
            //     true
            // })

            m = ent:sensors.keys().map(function(k) {
                get_sensor_temp_records(k)
            })

            r = m.reduce(function(a, b){
                a.append(b)
            })
            return {"readings": r}
            
        }

    }

    rule initialize_sensors {
        select when sensor needs_initialization
        always {
          ent:sensors := {}
          ent:subs :={}
          ent:readings := {}
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

    rule subcribe_new_child {
        select when wrangler new_child_created
        
        pre {
            the_sensor = {"eci": event:attrs{"eci"}}
            sensor_id = event:attrs{"sensor_id"}
            sensorName = nameFromID(sensor_id)
        }
            
        fired {
            raise wrangler event "subscription" 
            attributes
                { 
                    "name" : sensorName,
                    "Tx_role": "sensor",
                    "Rx_role": "manager",
                    "channel_type": "subscription",
                    "wellKnown_Tx" : the_sensor.get("eci")
                }
        }
    }
    
    rule add_to_sublist {
        select when wrangler subscription_added
        pre {
            eci = event:attrs{"Tx"}
            name = event:attrs{"name"}
            role = event:attrs{"Rx_role"}
            id = event:attrs{"Id"}
            p = {"id": id, "eci":eci  }
        }
        if role == "sensor" then
            send_directive("get subs")
        fired {
            ent:subs := ent:subs.defaultsTo({}).put(name, p);
        }
    }

    rule subscribe_existing_sensor {
        select when sensor sub_existing
        pre {
          
          name = event:attrs{"name"}
          wellKnown_Tx = event:attrs{"wellKnown_Tx"}
          Tx_role = event:attrs{"Tx_role"} => event:attrs{"Tx_role"} | "sensor"
          Rx_role = event:attrs{"Rx_role"} => event:attrs{"Rx_role"} | "manager"
          channel_type = event:attrs{"channel_type"} => event:attrs{"channel_type"} | "subscription"
        //   Tx_host = (event:attr("Tx_host").isnull() || event:attr("Tx_host") == "" => null | event:attr("Tx_host"))
        }
        
        always {
          raise wrangler event "subscription"
            attributes {"name": name,
                       "Tx_role": Tx_role,
                       "Rx_role": Rx_role,
                       "Tx_host": null,
                       "channel_type": channel_type,
                       "wellKnown_Tx": wellKnown_Tx}
        }
      }

    rule read_subscription_feed {
        select when sensor subscription_feed
        pre {
            wellKnown_Tx = event:attrs{"wellKnown_Tx"}
            r = event:attrs{"reading"}
            
        }

        always{
            ent:readings := ent:readings.defaultsTo({}).put(wellKnown_Tx, r);
        }

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

    rule get_subscription_temps{
        select when sensor get_subscription_temp
        foreach ent:subs setting(v, k)
            pre {
                eci = v{"eci"}
            }
            event:send({
                "eci":eci,
                "domain":"wovyn", "name":"readings_update",
                "attrs":{
                }
            })
    }

    rule subscription_threshold_violation{
        select when sensor subscription_threshold_violation
            pre {
                violation = event:attrs{"violation"}
                time = violation{"timestamp"}
                messageContent = "At " + time + " temperature " + violation{"temperature"} +" exceeding threshold"
                reciever = "+18014208731" 
            }
            message:send_sms(messageContent, reciever) setting(content)
    }

    

}