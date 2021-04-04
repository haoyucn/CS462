ruleset gossip {
    meta {
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
        shares tryFilterMap, messages, getSeenMessage,showPeerSources, showPeerSubscriber
    }
    global {
        tryFilterMap = function(){
            m = {"b": 1, "a": 2}
            m.filter(function(v,k){
                v <2    
            })
        }

        getSeenMessage = function(){
            c = ent:messages.map(function(v, k) {
                z = v.reduce(function(a, b){
                    return (b{"MessageID"} - a{"MessageID"}) == 1 => b| a
                })
                t = z{"MessageID"} + 1
                t != v.length() => 0 | z{"MessageID"}
            })
            c
        }

        getMissingMessages = function(missingMessageSensor) {
            missingMessages = ent:messages.filter(function(v,k){
                missingMessageSensor.get(k)
            })
            missingMessages
        }

        addMissingMessages = function(missingMessages) {
            ent:messages.map(function(v,k){
                missingMessages.get(k) => missingMessages.get(k) | v 
            })
        }

        messages = function(){
            ent:messages
        }

        getSeentts = function(){
            c = ent:tts.map(function(v, k) {
                z = v.reduce(function(a, b){
                    (b{"MessageID"} - a{"MessageID"}) == 1 => b| a
                })
                z{"MessageID"} != v.length() => 0 | z{"MessageID"}
            })
            c
        }
        showPeerSources = function(){
            ent:sources
        }

        showPeerSubscriber = function() {
            ent:subscriptionTxs
        }
    }


    rule init_gossip_pico {
        select when gossip init 
        pre {
            name = random:uuid()
        }
        always {
            ent:messages := {}
            // ent:fakeMessages := {}
            ent:sources := []
            ent:subscriptionTxs := {}
            ent:name := name
            ent:messageOn := true
        }
    }

    rule recieve_sensor_feed {
        select when gossip heartbeat
        pre {
            message = event:attrs{"message"}
            // t = klog("qwesss", message.encode())
            MessageID = message{"MessageID"}
            SensorID = message{"SensorID"}
            Temperature = message{"Temperature"}
            Timestamp = message{"Timestamp"}
            
            sensorMessages = ent:messages{SensorID} =>  ent:messages{SensorID} | []
            messagesAfterAdd = sensorMessages.append(message)

        }
        always {
            ent:messages := ent:messages.defaultsTo({}).put(SensorID, messagesAfterAdd)

            raise gossip event "spread_rumor"
                attributes {
                    "Timestamp": Timestamp,
                    "Temperature": Temperature,
                    "SensorID" : SensorID,
                    "MessageID": MessageID
                }
        }
    }

    rule spread_rumor {
        select when gossip spread_rumor
        foreach ent:subscriptionTxs setting(v,k)
            pre {
                tx = v
                subscriberName = k
                MessageID = event:attrs{"MessageID"}
                SensorID = event:attrs{"SensorID"}
                Temperature = event:attrs{"Temperature"}
                Timestamp = event:attrs{"Timestamp"}
                rumor = {
                    "Timestamp": Timestamp,
                    "Temperature": Temperature,
                    "SensorID" : SensorID,
                    "MessageID": MessageID
                }
            }
            if ent:messageOn then
            event:send({
                "eci": tx,
                "domain":"gossip", "name":"rumor",
                "attrs":{
                    "wellKnown_Tx":subs:wellKnown_Rx(){"id"},
                    "rumor": rumor
                }
            })
    }

    rule process_new_rumor {
        select when gossip rumor
        pre {
            rumor = event:attrs{"rumor"}
            sensorId = rumor{"SensorID"}
            messageId = rumor{"MessageID"}
            sensorHistory = ent:messages{sensorId} => ent:messages{sensorId} | []
            duplicatedMessage = sensorHistory.filter(function(x) {x{"MessageID"} == messageId})
            isNewRumor = duplicatedMessage.length() == 0 => true | false

            newSensorHistory = sensorHistory.append(rumor)
        }
        if isNewRumor && ent:messageOn then
            send_directive("abs")
        fired {
            ent:messages := ent:messages.defaultsTo({}).put(sensorId, newSensorHistory)
            raise gossip event "spread_rumor"
                attributes {
                    "Timestamp": rumor{"Timestamp"},
                    "Temperature": rumor{"Temperature"},
                    "SensorID" : rumor{"SensorID"},
                    "MessageID": rumor{"MessageID"}
                }

        }
    }

    rule share_seen_messages {
        select when gossip send_seen_message
        foreach ent:sources setting(sourceEci)
            pre {
                seenMessage = getSeenMessage()
            }
            if ent:messageOn then
            event:send({
                "eci":sourceEci,
                "domain":"gossip", "name":"seen",
                "attrs":{
                    "seenMessage": seenMessage,
                    "name": ent:name
                }
            })
    }

    rule process_new_seen_message{
        select when gossip seen
        pre {
            name = event:attrs{"name"}
            tx = ent:subscriptionTxs{name}
            seenMessage = event:attrs{"seenMessage"}
            selfSeenMessage = getSeenMessage()
            missingMessagesSensors = selfSeenMessage.filter(function(v,k){
                seenMessage{k} => seenMessage{k} < v | true
            })
            sendMissingMessage = missingMessagesSensors.keys().length() > 0 => true | false
            missingMessages= getMissingMessages(missingMessagesSensors)

        }
        if ent:messageOn then
        event:send({
            "eci": tx,
            "domain":"gossip", "name":"missing_messages",
            "attrs":{
                "wellKnown_Tx":subs:wellKnown_Rx(){"id"},
                "missingMessages": missingMessages
            }
        })
        
    }

    rule records_missing_messages {
        select when gossip missing_messages
        pre {
            missingMessages = event:attrs{"missingMessages"}
            completeMessages = addMissingMessages(missingMessages)
        }
        always {
            ent:messages := completeMessages if ent:messageOn
        }
    }

    // ckn27sarl0018twj4c4bo1w9b

    rule subscribe_to {
        select when gossip subscribe_to
        pre {
            wellKnowEci = event:attrs{"eci"}
        }
        always {
            raise wrangler event "subscription" 
            attributes
                { 
                    "name" : ent:name,
                    "Tx_role": "gossip_spreader",
                    "Rx_role": "gossip_listener",
                    "channel_type": "subscription",
                    "wellKnown_Tx" : wellKnowEci
                }
        }
    }

    rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        pre {
            my_role = event:attr("Rx_role")
            their_role = event:attr("Tx_role")
            id = event:attrs{"Id"}
            roleCorrect = my_role == "gossip_spreader" => true | false
            subscriberName = event:attrs{"name"}
        }
        if roleCorrect then
            send_directive("readings", {"s":123})
        fired {
            raise wrangler event "pending_subscription_approval"
                attributes event:attrs
            ent:subscriptionTxs :=  ent:subscriptionTxs.defaultsTo({}).put(subscriberName, event:attr("Tx"))
        }
    }

    rule process_new_sub_acceptance {
        select when wrangler subscription_added
        pre {
            eci = event:attrs{"Tx"}
            name = event:attrs{"name"}
            role = event:attrs{"Rx_role"}
            id = event:attrs{"Id"}
            p = {"id": id, "eci":eci, "blocked": false}
        }
        if role == "gossip_spreader" && name == ent:name then
            send_directive("get subs")
        fired {
            ent:sources := ent:sources.defaultsTo([]).append(eci);
        }
    }
    rule taggle_status {
        select when status taggle
        pre {
            ns = ent:messageOn => false | true
        }
        always {
            ent:messageOn := ns
        }
    }

    rule schedule_heartbeat {
        select when gossip scheduler
        pre{
            interval = event:attrs{"interval"}
            intervalFrame = "*/"+ interval +" * * * * *"
        }
        
        always{
          schedule gossip event "send_seen_message" repeat intervalFrame
        }
      }

    // rule trydsP{
    //     select when fake id
    //     pre {
    //         messageId = ent:messageId => ent:messageId | 0

    //     }
    // }
}