ruleset temperature_store {
    meta {

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
                x["temperature"] < ent:violationLowest
            })
        }

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
}