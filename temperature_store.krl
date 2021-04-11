ruleset temperature_store {
    meta {
        use module sensor_profile
        use module io.picolabs.subscription alias subs
        shares temperatures, threshold_violations, inrange_temperatures, printWellKnowTX, getMessageId, getRec
        provide  threshold_violations, inrange_temperatures
    }
    global {
        records = []
        violationRecords = []
        temperatures  = function() {
            ent:records
        }
        threshold_violations = function() {
            ent:violationRecords
        }
        inrange_temperatures = function () {
            ent:records.filter(function(x) {
                x["temperature"] < sensor_profile:threshold() => sensor_profile:threshold() | 74.1
            })
        }

        message_reciever = defaction(channelId, messageId, sensorId, temp, timeStamp, thresholdUpdate) {
            every {
                http:post(<<http://192.168.1.2:3000/sky/event/#{channelId}/messagereciever/gossip/heartbeat>>
                    ,
                    json={
                        "message":{
                            "MessageID": messageId,
                            "SensorID": sensorId,
                            "Temperature": temp,
                            "Timestamp": timeStamp,
                            "CounterUpdate": thresholdUpdate
                        }
                    }
                )
            }
        }
        printWellKnowTX = function(){
            ent:subscriptionTx
        }
        getRec = function() {
            ent:recivers 
        }

        getMessageId = function(){
            ent:messageId
        }
    }

    rule report_last_reading {
        select when wovyn recentreadings
        pre {
            z = ent:records.slice(ent:records.length()-6, ent:records.length()-1)
            x = z.length() > 0 => z | ent:records
        }
        send_directive("readings", x)
    }
    rule report_violation_log {
        select when wovyn violations
        pre {
            z = ent:violationRecords.slice(ent:violationRecords.length()-6, ent:violationRecords.length()-1)
            x = z.length() > 0 => z | ent:violationRecords
        }
        send_directive("readings", x)
    }
    rule collect_temperatures {
        select when wovyn new_temperature_reading
        pre{
            tempF = event:attrs{"temperature"}[0]["temperatureF"]
            time = event:attrs{"time"}
            temps = temperatures()
        }
        always {
            ent:records := temps.append({"temperature": tempF, "timestamp": time})
        }
    }

    rule collect_threshold_violations {
        select when wovyn threshold_violation
        pre{
            tempF = event:attrs{"temperature"}[0]["temperatureF"]
            time = event:attrs{"time"}
        }
        always {
            ent:violationRecords :=  ent:violationRecords.append({"temperature": tempF, "timestamp": time})
            ent:violationLowest := ent:violationLowest > tempF => tempF | ent:violationLowest
        }
    }
    rule clear_temeratures {
        select when sensor reading_reset 
        always {
            ent:violationRecords := []
            ent:records := []
            ent:violationLowest:= 1000 
        }
    }
    rule init {
        select when a b 
        always {
            ent:violationRecords:= []
            ent:records:= []
            ent:violationLowest:= 1000 
            ent:recivers := []
            ent:messageId := 0 
        }
    }

    rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        pre {
            zs = event:attrs
            my_role = event:attr("Rx_role")
            their_role = event:attr("Tx_role")
            id = event:attrs{"Id"}
        }
        always {
          raise wrangler event "pending_subscription_approval"
            attributes event:attrs
          ent:subscriptionTx := event:attr("Tx")
          ent:sensorId := id
        }
    }

    rule notify_observers_new_readings {
        select when wovyn new_temperature_reading
        pre {
            tempF = event:attrs{"temperature"}[0]["temperatureF"]
            time = event:attrs{"time"}
            temps = temperatures()
            t = {"temperature": tempF, "timestamp": time}
        }
        event:send({
            "eci":ent:subscriptionTx,
            "domain":"sensor", "name":"subscription_feed",
            "attrs":{
                "wellKnown_Tx":subs:wellKnown_Rx(){"id"},
                "reading": temps
            }
        })
    }

    // this is to answer the subscription request
    rule sendData_to_observers {
        select when wovyn readings_update
        pre {
            temps = temperatures()
            corrId = event:attrs{"corrId"}
            sensorName = event:attrs{"sensorName"}
        }
        event:send({
            "eci":ent:subscriptionTx,
            "domain":"sensor", "name":"subscription_answer_reading_req",
            "attrs":{
                "wellKnown_Tx":subs:wellKnown_Rx(){"id"},
                "reading": temps,
                "corrId": corrId,
                "sensorName": sensorName
            }
        })
    }

    rule notify_observer_threshold_violation {
        select when wovyn threshold_violation
        pre {
            tempF = event:attrs{"temperature"}[0]["temperatureF"]
            time = event:attrs{"time"}
        }
        event:send({
            "eci":ent:subscriptionTx,
            "domain":"sensor", "name":"subscription_threshold_violation",
            "attrs":{
                "wellKnown_Tx":subs:wellKnown_Rx(){"id"},
                "violation": {"temperature": tempF, "timestamp": time}
            }
        })
    }

    rule add_message_reciever {
        select when message_reciever add
        pre {
            channelId = event:attrs{"reciever_channel_id"}
        }
        always {
            ent:recivers := ent:recivers.defaultsTo([]).append(channelId)
          }
    }

    rule message_recievers {
        select when wovyn new_temperature_reading
        foreach ent:recivers setting(channelId)
            pre{
                tempF = event:attrs{"temperature"}[0]["temperatureF"]
                time = event:attrs{"time"}
                sensorId = ent:sensorId
                messageId = ent:messageId => ent:messageId | 0
                nmid = messageId + 1
                thresholdVio = tempF > sensor_profile:threshold() => 1 | 0
                thresholdUpdate = thresholdVio - ent:vioState
            }
            message_reciever(channelId, messageId, sensorId, tempF, time, thresholdUpdate) 
            fired {

            }
            finally {
                ent:messageId := nmid
                ent:vioState := thresholdVio
            }
    
    }   
    

}