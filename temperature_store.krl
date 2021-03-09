ruleset temperature_store {
    meta {
        use module sensor_profile
        use module io.picolabs.subscription alias subs
        shares temperatures, threshold_violations, inrange_temperatures
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
        }
    }

    rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        pre {
            my_role = event:attr("Rx_role")
            their_role = event:attr("Tx_role")
        }
        always {
          raise wrangler event "pending_subscription_approval"
            attributes event:attrs
          ent:subscriptionTx := event:attr("Tx")
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

    rule sendData_to_observers {
        select when wovyn readings_update
        pre {
            temps = temperatures()
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
}